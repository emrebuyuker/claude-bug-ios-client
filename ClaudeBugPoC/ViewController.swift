import UIKit
import FirebaseFunctions
import FirebaseFirestore
import Alamofire

// MARK: - Models

final class ProposedChange {
    enum Decision { case pending, accepted, rejected }

    let id: String
    let filePath: String
    let changeDescription: String
    let oldContent: String
    let newContent: String
    var decision: Decision = .pending

    init(id: String, filePath: String, changeDescription: String, oldContent: String, newContent: String) {
        self.id = id
        self.filePath = filePath
        self.changeDescription = changeDescription
        self.oldContent = oldContent
        self.newContent = newContent
    }
}

enum ChatItem {
    case user(String)
    case claude(String)
    case system(String)
    case proposal(ProposedChange)
    case actionPrompt(ActionPrompt)
    case jiraTicket(key: String, url: String, summary: String)
}

// Claude cevabından sonra kullanıcıya "Bug Aç" / "Kodu Düzenle" seçimini sunan kart.
final class ActionPrompt {
    enum State { case pending, bugOpened, codeRevealed, bugLoading }

    let bugDescription: String
    let pendingProposals: [ProposedChange]
    var state: State = .pending

    init(bugDescription: String, pendingProposals: [ProposedChange]) {
        self.bugDescription = bugDescription
        self.pendingProposals = pendingProposals
    }
}

// MARK: - Diff helpers

fileprivate enum DiffLineKind { case context, added, removed, separator }

fileprivate struct DiffLine {
    let kind: DiffLineKind
    let text: String
}

/// Build a unified-style diff between `old` and `new` showing only changed
/// lines plus `contextLines` of unchanged context above/below each hunk.
fileprivate func computeUnifiedDiff(
    old: String,
    new: String,
    contextLines: Int = 2
) -> [DiffLine] {
    let oldLines = old.components(separatedBy: "\n")
    let newLines = new.components(separatedBy: "\n")
    let diff = newLines.difference(from: oldLines)

    // Map offsets to changes
    var removedAtOld = [Int: String]()
    var insertedAtNew = [Int: String]()
    for change in diff {
        switch change {
        case let .remove(offset, element, _):
            removedAtOld[offset] = element
        case let .insert(offset, element, _):
            insertedAtNew[offset] = element
        }
    }

    // Walk both arrays, emitting lines in order
    var full: [DiffLine] = []
    var oldIdx = 0
    var newIdx = 0
    while oldIdx < oldLines.count || newIdx < newLines.count {
        if oldIdx < oldLines.count, removedAtOld[oldIdx] != nil {
            full.append(DiffLine(kind: .removed, text: oldLines[oldIdx]))
            oldIdx += 1
        } else if newIdx < newLines.count, insertedAtNew[newIdx] != nil {
            full.append(DiffLine(kind: .added, text: newLines[newIdx]))
            newIdx += 1
        } else if oldIdx < oldLines.count, newIdx < newLines.count {
            full.append(DiffLine(kind: .context, text: oldLines[oldIdx]))
            oldIdx += 1
            newIdx += 1
        } else {
            break
        }
    }

    // Collapse: keep only changed lines + N context around them
    let changedIdx = full.enumerated().compactMap { idx, line -> Int? in
        line.kind == .context ? nil : idx
    }
    if changedIdx.isEmpty { return [] }

    var keep = Set<Int>()
    for ci in changedIdx {
        let lo = max(0, ci - contextLines)
        let hi = min(full.count - 1, ci + contextLines)
        for j in lo...hi { keep.insert(j) }
    }

    var result: [DiffLine] = []
    var prev: Int?
    for i in keep.sorted() {
        if let p = prev, i > p + 1 {
            result.append(DiffLine(kind: .separator, text: "⋯"))
        }
        result.append(full[i])
        prev = i
    }
    return result
}

fileprivate func renderDiff(_ lines: [DiffLine]) -> NSAttributedString {
    let mono = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    let monoBold = UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)

    if lines.isEmpty {
        return NSAttributedString(
            string: LocalizationKey.View.AIChat.diffNoChanges.localize,
            attributes: [.font: mono, .foregroundColor: UIColor.secondaryLabel]
        )
    }

    let out = NSMutableAttributedString()
    for (i, line) in lines.enumerated() {
        let prefix: String
        var fg: UIColor = .label
        var bg: UIColor = .clear
        switch line.kind {
        case .added:
            prefix = "+ "
            fg = UIColor.systemGreen
            bg = UIColor.systemGreen.withAlphaComponent(0.12)
        case .removed:
            prefix = "- "
            fg = UIColor.systemRed
            bg = UIColor.systemRed.withAlphaComponent(0.12)
        case .context:
            prefix = "  "
            fg = .label
        case .separator:
            prefix = "  "
            fg = .tertiaryLabel
        }

        let body = prefix + line.text + (i == lines.count - 1 ? "" : "\n")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: line.kind == .separator ? monoBold : mono,
            .foregroundColor: fg,
            .backgroundColor: bg,
        ]
        out.append(NSAttributedString(string: body, attributes: attrs))
    }
    return out
}

// MARK: - ViewController

final class ViewController: UIViewController {

    // MARK: Properties
    private lazy var functions: Functions = {
        return Functions.functions(region: "us-central1")
    }()

    private var items: [ChatItem] = [
        .system(LocalizationKey.View.AIChat.welcomeMessage.localize)
    ]

    private var lastBugDescription: String?
    private var pendingProposals: [ProposedChange] = []
    /// `---TEKNİK---` ayracının altındaki teknik açıklama; "Kodu Düzenle" tıklanınca
    /// system mesajı olarak gösterilir.
    fileprivate var lastTechnicalDetail: String?

    private lazy var db = Firestore.firestore()
    /// Aktif bug-analizi job'ının Firestore dökümanını dinleyen listener.
    private var jobListener: ListenerRegistration?
    /// Job çalışırken gösterilen geçici "analiz ediliyor…" satırının index'i.
    /// Yalnızca job başlangıcı ile terminal durum arasında geçerlidir — bu aralıkta
    /// gönder butonu pasif olduğu için başka satır eklenmez, index sabit kalır.
    private var progressItemIndex: Int?
    /// Worker sessizce ölürse (OOM / hard timeout → job 'running'de takılı kalır)
    /// spinner'ı sonsuza dek dönmekten kurtaran watchdog.
    private var jobTimeoutWorkItem: DispatchWorkItem?
    /// Sunucu worker'ının hard timeout'u 540s; watchdog'u onun biraz üstüne (600s)
    /// koyuyoruz ki gerçekten tamamlanan bir analiz asla erken kesilmesin.
    private let jobTimeoutSeconds: TimeInterval = 600

    // MARK: UI
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseId)
        tv.register(ProposedChangeCell.self, forCellReuseIdentifier: ProposedChangeCell.reuseId)
        tv.register(ActionPromptCell.self, forCellReuseIdentifier: ActionPromptCell.reuseId)
        tv.register(JiraTicketCell.self, forCellReuseIdentifier: JiraTicketCell.reuseId)
        tv.dataSource = self
        tv.estimatedRowHeight = 120
        tv.rowHeight = UITableView.automaticDimension
        tv.separatorStyle = .none
        tv.keyboardDismissMode = .interactive
        return tv
    }()

    private lazy var inputContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        return v
    }()

    // ── BUG FIX: UITextField → UITextView ──────────────────────────────────
    // UITextField tek satır gösterir; uzun metinler kesilir.
    // UITextView çok satırlı metin girişini destekler.
    private lazy var inputField: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = .systemFont(ofSize: 16)
        tv.textColor = .label
        tv.backgroundColor = .systemBackground
        tv.layer.cornerRadius = 8
        tv.layer.borderWidth = 0.5
        tv.layer.borderColor = UIColor.separator.cgColor
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        tv.isScrollEnabled = true
        tv.returnKeyType = .send
        tv.delegate = self
        return tv
    }()

    // Placeholder etiketi (UITextView'ın built-in placeholder'ı yok)
    private lazy var placeholderLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = LocalizationKey.View.AIChat.inputPlaceholder.localize
        lbl.font = .systemFont(ofSize: 16)
        lbl.textColor = .placeholderText
        lbl.isUserInteractionEnabled = false
        return lbl
    }()
    // ───────────────────────────────────────────────────────────────────────

    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(LocalizationKey.View.AIChat.sendButton.localize, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var loadingView: UIActivityIndicatorView = {
        let av = UIActivityIndicatorView(style: .large)
        av.translatesAutoresizingMaskIntoConstraints = false
        av.hidesWhenStopped = true
        av.color = .systemBlue
        return av
    }()

    private lazy var createPRButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = LocalizationKey.View.AIChat.createPRButton.localize
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.2
        btn.layer.shadowRadius = 8
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.isHidden = true
        btn.addTarget(self, action: #selector(createPRTapped), for: .touchUpInside)
        return btn
    }()

    private var inputBottomConstraint: NSLayoutConstraint?
    // inputField'ın yüksekliğini dinamik tutmak için
    private var inputFieldHeightConstraint: NSLayoutConstraint?

    // MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = LocalizationKey.View.AIChat.navigationTitle.localize
        view.backgroundColor = .systemBackground
        setupViews()
        setupKeyboardObservers()
        demoNetworkManager()
    }

    /// Demo: NetworkManager üzerinden TMDB'ye gerçek bir istek atar ve
    /// sonucu console'a yazar. ApiConstant.bearerToken'ı kendi TMDB v4
    /// token'ınla değiştirdikten sonra çalışır.
    private func demoNetworkManager() {
        guard ApiConstant.bearerToken != "YOUR_TMDB_V4_TOKEN_HERE" else {
            print("⚠️  TMDB token not configured — set ApiConstant.bearerToken to run the NetworkManager demo.")
            return
        }
        NetworkManager.shared.request(service: MovieService.popular(page: 1)) {
            (result: Result<PagedResponse<Movie>, AFError>) in
            switch result {
            case .success(let response):
                print("✅ TMDB popular page \(response.page): \(response.results.count) movies, total \(response.totalResults)")
                if let first = response.results.first {
                    NetworkManager.shared.request(service: MovieService.detail(id: first.id)) {
                        (detailResult: Result<MovieDetail, AFError>) in
                        switch detailResult {
                        case .success(let detail):
                            print("🎬 Detail for \(detail.title): runtime=\(detail.runtime ?? 0)m, cast=\(detail.credits?.cast.count ?? 0)")
                        case .failure(let error):
                            print("❌ TMDB detail error: \(error.localizedDescription)")
                        }
                    }
                }
            case .failure(let error):
                print("❌ TMDB list error: \(error.localizedDescription)")
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        jobListener?.remove()
        jobTimeoutWorkItem?.cancel()
    }

    // MARK: Setup
    private func setupViews() {
        view.addSubview(tableView)
        view.addSubview(inputContainer)
        inputContainer.addSubview(inputField)
        inputContainer.addSubview(placeholderLabel)   // placeholder ekle
        inputContainer.addSubview(sendButton)
        view.addSubview(loadingView)
        view.addSubview(createPRButton)

        let bottomConstraint = inputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )
        inputBottomConstraint = bottomConstraint

        // inputField başlangıç yüksekliği: 1 satır (~40 pt)
        let heightConstraint = inputField.heightAnchor.constraint(equalToConstant: 40)
        inputFieldHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,

            inputField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputField.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 10),
            inputField.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -10),
            heightConstraint,

            // Placeholder: textContainerInset ile hizalı
            placeholderLabel.leadingAnchor.constraint(equalTo: inputField.leadingAnchor, constant: 10),
            placeholderLabel.topAnchor.constraint(equalTo: inputField.topAnchor, constant: 8),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 70),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            createPRButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            createPRButton.bottomAnchor.constraint(equalTo: inputContainer.topAnchor, constant: -12),
        ])
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let bottomInset = view.frame.height - frame.origin.y - view.safeAreaInsets.bottom
        inputBottomConstraint?.constant = -max(0, bottomInset)
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: Actions
    @objc private func sendTapped() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        ActivityRecorder.shared.recordTap("sendButton", context: "bugDescription")

        // Reset pending proposals on a new question.
        pendingProposals.removeAll()
        lastTechnicalDetail = nil
        updatePRButtonVisibility()
        lastBugDescription = text

        append(.user(text))
        inputField.text = ""
        updateInputFieldHeight()
        placeholderLabel.isHidden = false
        inputField.resignFirstResponder()
        sendButton.isEnabled = false
        loadingView.startAnimating()

        callAskClaude(bugDescription: text)
    }

    @objc private func createPRTapped() {
        ActivityRecorder.shared.recordTap("createPRButton")
        let accepted = pendingProposals.filter { $0.decision == .accepted }
        guard !accepted.isEmpty else {
            append(.system(LocalizationKey.View.AIChat.noChangesApproved.localize))
            return
        }
        guard let bugTitle = lastBugDescription else {
            append(.system(LocalizationKey.View.AIChat.describeBugFirst.localize))
            return
        }

        createPRButton.isEnabled = false
        loadingView.startAnimating()
        callCreatePR(bugTitle: bugTitle, accepted: accepted)
    }

    // MARK: inputField yükseklik güncelleme
    private func updateInputFieldHeight() {
        let maxHeight: CGFloat = 120   // ~4 satır
        let minHeight: CGFloat = 40    // 1 satır
        let fittingSize = inputField.sizeThatFits(
            CGSize(width: inputField.bounds.width, height: .greatestFiniteMagnitude)
        )
        let newHeight = min(max(fittingSize.height, minHeight), maxHeight)
        inputField.isScrollEnabled = fittingSize.height > maxHeight
        inputFieldHeightConstraint?.constant = newHeight
        UIView.animate(withDuration: 0.15) { self.view.layoutIfNeeded() }
    }

    // MARK: Network
    /// Bug analizini ASENKRON başlatır: `startBugAnalysis` anında bir jobId döner,
    /// ağır agentic iş sunucuda arka planda çalışır ve sonucu Firestore'a yazar.
    /// Böylece uzun analizlerde client tarafı DEADLINE_EXCEEDED'a takılmaz — sonucu
    /// `bugJobs/{jobId}` dökümanını realtime dinleyerek alırız.
    private func callAskClaude(bugDescription: String) {
        // Önceki job dinleyicisini ve watchdog'u bırak (yeni soru eskisinin yerini alır).
        jobListener?.remove()
        jobListener = nil
        cancelJobTimeout()

        var payload: [String: Any] = ["bugDescription": bugDescription]
        if let timeline = ActivityRecorder.shared.exportTimeline() {
            payload["activityLog"] = timeline
        }

        // Job'ı başlat — anında döner, kısa timeout yeterli.
        let callable = functions.httpsCallable("startBugAnalysis")
        callable.timeoutInterval = 30
        callable.call(payload) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                self.finishLoadingWithError(error)
                return
            }
            guard let data = result?.data as? [String: Any],
                  let jobId = data["jobId"] as? String else {
                self.loadingView.stopAnimating()
                self.sendButton.isEnabled = true
                self.append(.system(LocalizationKey.View.AIChat.unexpectedResponse.localize))
                return
            }

            self.observeJob(jobId: jobId, bugDescription: bugDescription)
        }
    }

    /// `bugJobs/{jobId}` dökümanını dinler; status geçişlerine göre ilerleme/sonuç/hata gösterir.
    private func observeJob(jobId: String, bugDescription: String) {
        var lastReportedIteration = 0
        jobListener = db.collection("bugJobs").document(jobId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.jobListener?.remove()
                    self.jobListener = nil
                    self.finishLoadingWithError(error)
                    return
                }

                guard let data = snapshot?.data(),
                      let status = data["status"] as? String else { return }

                switch status {
                case "pending":
                    break   // worker henüz işi almadı; merkezdeki spinner yeterli
                case "running":
                    let iterations = (data["iterations"] as? NSNumber)?.intValue ?? 0
                    if iterations > lastReportedIteration {
                        lastReportedIteration = iterations
                        self.showProgress(iterations: iterations)
                    }
                case "done":
                    self.jobListener?.remove()
                    self.jobListener = nil
                    self.cancelJobTimeout()
                    self.handleJobDone(jobId: jobId, data: data, bugDescription: bugDescription)
                case "error":
                    self.jobListener?.remove()
                    self.jobListener = nil
                    self.cancelJobTimeout()
                    self.loadingView.stopAnimating()
                    self.sendButton.isEnabled = true
                    self.removeProgress()
                    let message = (data["error"] as? String) ?? "bilinmeyen hata"
                    self.append(.system(
                        LocalizationKey.View.AIChat.errorFormat.localize
                            .replacing("message", with: message)
                            .replacing("code", with: "—")
                            .replacing("domain", with: "processBugAnalysis")
                    ))
                default:
                    break
                }
            }

        // Sonuç hiç gelmezse (worker sessizce öldüyse) spinner'ı kurtaran watchdog.
        scheduleJobTimeout()
    }

    /// Job bitince proposal'ları alt-koleksiyondan çekip sonucu render eder.
    private func handleJobDone(jobId: String, data: [String: Any], bugDescription: String) {
        db.collection("bugJobs").document(jobId).collection("proposals")
            .order(by: "order")
            .getDocuments { [weak self] snapshot, _ in
                guard let self = self else { return }

                self.loadingView.stopAnimating()
                self.sendButton.isEnabled = true
                self.removeProgress()

                var proposals: [ProposedChange] = []
                for doc in snapshot?.documents ?? [] {
                    let d = doc.data()
                    guard let id = d["id"] as? String,
                          let filePath = d["filePath"] as? String,
                          let desc = d["description"] as? String,
                          let oldC = d["oldContent"] as? String,
                          let newC = d["newContent"] as? String else { continue }
                    proposals.append(ProposedChange(
                        id: id,
                        filePath: filePath,
                        changeDescription: desc,
                        oldContent: oldC,
                        newContent: newC
                    ))
                }

                self.renderAnalysisResult(data: data, proposals: proposals, bugDescription: bugDescription)
            }
    }

    /// Job dökümanı + proposal'lardan kullanıcı dostu cevap + aksiyon kartını basar.
    private func renderAnalysisResult(data: [String: Any], proposals: [ProposedChange], bugDescription: String) {
        let rawAnswer = (data["answer"] as? String) ?? LocalizationKey.View.AIChat.noResponse.localize
        let iterations = (data["iterations"] as? NSNumber)?.intValue ?? 0
        let cost = (data["estimatedCostUsd"] as? NSNumber)?.doubleValue ?? 0.0
        let inputTokens = (data["inputTokens"] as? NSNumber)?.intValue ?? 0
        let outputTokens = (data["outputTokens"] as? NSNumber)?.intValue ?? 0
        let cacheRead = (data["cacheReadTokens"] as? NSNumber)?.intValue ?? 0
        let cacheCreated = (data["cacheCreationTokens"] as? NSNumber)?.intValue ?? 0

        // Cevabı kullanıcı dostu (üst) + teknik (alt) olarak böl.
        let (friendly, technical) = splitAnswer(rawAnswer)

        let metadataLine = LocalizationKey.View.AIChat.metadataFormat.localize
            .replacing("iterations", with: iterations)
            .replacing("inputTokens", with: inputTokens)
            .replacing("outputTokens", with: outputTokens)
            .replacing("cost", with: String(format: "%.4f", cost))
        var metadata = "\n\n— — — — —\n" + metadataLine
        if cacheRead > 0 || cacheCreated > 0 {
            let cacheLine = LocalizationKey.View.AIChat.cacheMetadata.localize
                .replacing("read", with: cacheRead)
                .replacing("write", with: cacheCreated)
            metadata += "\n" + cacheLine
        }

        append(.claude(friendly + metadata))

        // İki butonlu aksiyon kartı. Teknik detay buton arkasında saklı kalır.
        let prompt = ActionPrompt(
            bugDescription: bugDescription,
            pendingProposals: proposals
        )
        lastTechnicalDetail = technical
        append(.actionPrompt(prompt))
    }

    /// Job başlatma / dinleme hatasında spinner'ı durdurup hatayı gösterir.
    private func finishLoadingWithError(_ error: Error) {
        loadingView.stopAnimating()
        sendButton.isEnabled = true
        removeProgress()
        cancelJobTimeout()
        let nsError = error as NSError
        let msg = LocalizationKey.View.AIChat.errorFormat.localize
            .replacing("message", with: nsError.localizedDescription)
            .replacing("code", with: nsError.code)
            .replacing("domain", with: nsError.domain)
        append(.system(msg))
    }

    /// "🔄 Analiz ediliyor… (N. adım)" satırını oluşturur veya yerinde günceller.
    private func showProgress(iterations: Int) {
        let text = LocalizationKey.View.AIChat.analyzing.localize
            .replacing("iterations", with: iterations)
        if let idx = progressItemIndex, idx < items.count {
            items[idx] = .system(text)
            tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
        } else {
            items.append(.system(text))
            let idx = items.count - 1
            progressItemIndex = idx
            tableView.insertRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
            tableView.scrollToRow(at: IndexPath(row: idx, section: 0), at: .bottom, animated: true)
        }
    }

    /// İlerleme satırını kaldırır (terminal durumda, cevap basılmadan önce).
    private func removeProgress() {
        guard let idx = progressItemIndex, idx < items.count else {
            progressItemIndex = nil
            return
        }
        progressItemIndex = nil
        items.remove(at: idx)
        tableView.deleteRows(at: [IndexPath(row: idx, section: 0)], with: .automatic)
    }

    /// Sonuç `jobTimeoutSeconds` içinde gelmezse spinner'ı durdurup zaman aşımı gösterir.
    private func scheduleJobTimeout() {
        cancelJobTimeout()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.jobTimeoutWorkItem = nil
            self.jobListener?.remove()
            self.jobListener = nil
            self.loadingView.stopAnimating()
            self.sendButton.isEnabled = true
            self.removeProgress()
            self.append(.system(LocalizationKey.View.AIChat.jobTimeout.localize))
        }
        jobTimeoutWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + jobTimeoutSeconds, execute: work)
    }

    private func cancelJobTimeout() {
        jobTimeoutWorkItem?.cancel()
        jobTimeoutWorkItem = nil
    }

    /// `---TEKNİK---` ayracını arar; bulamazsa cevabın tamamını friendly say.
    private func splitAnswer(_ answer: String) -> (friendly: String, technical: String?) {
        let separator = LocalizationKey.View.AIChat.technicalSeparator.localize
        guard let range = answer.range(of: separator) else {
            return (answer.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }
        let friendly = String(answer[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let technical = String(answer[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (friendly, technical.isEmpty ? nil : technical)
    }

    // MARK: ActionPrompt actions

    fileprivate func actionPromptDidTapBug(_ prompt: ActionPrompt) {
        ActivityRecorder.shared.recordTap("bugOpenButton")
        guard prompt.state == .pending else { return }
        prompt.state = .bugLoading
        reloadActionPrompt(prompt)
        callCreateBugTicket(bugDescription: prompt.bugDescription, prompt: prompt)
    }

    fileprivate func actionPromptDidTapCode(_ prompt: ActionPrompt) {
        ActivityRecorder.shared.recordTap("codeEditButton")
        guard prompt.state == .pending else { return }
        prompt.state = .codeRevealed
        reloadActionPrompt(prompt)

        // Sakladığımız proposal'ları akışa şimdi ekle.
        pendingProposals = prompt.pendingProposals
        for change in prompt.pendingProposals {
            append(.proposal(change))
        }

        if prompt.pendingProposals.isEmpty {
            append(.system(LocalizationKey.View.AIChat.noCodeChange.localize))
        } else if let technical = lastTechnicalDetail, !technical.isEmpty {
            append(.system(
                LocalizationKey.View.AIChat.technicalDetailFormat.localize.replacing("detail", with: technical)
            ))
        }
        updatePRButtonVisibility()
    }

    private func reloadActionPrompt(_ prompt: ActionPrompt) {
        if let row = items.firstIndex(where: {
            if case let .actionPrompt(p) = $0 { return p === prompt }
            return false
        }) {
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        }
    }

    private func callCreateBugTicket(bugDescription: String, prompt: ActionPrompt) {
        var payload: [String: Any] = ["bugDescription": bugDescription]
        if let timeline = ActivityRecorder.shared.exportTimeline() {
            payload["activityLog"] = timeline
        }
        let callable = functions.httpsCallable("createBugTicket")
        callable.timeoutInterval = 60
        callable.call(payload) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                let nsError = error as NSError
                prompt.state = .pending
                self.reloadActionPrompt(prompt)
                self.append(.system(
                    LocalizationKey.View.AIChat.jiraError.localize.replacing("message", with: nsError.localizedDescription)
                ))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let key = data["ticketKey"] as? String,
                  let url = data["ticketUrl"] as? String,
                  let summary = data["summary"] as? String else {
                prompt.state = .pending
                self.reloadActionPrompt(prompt)
                self.append(.system(LocalizationKey.View.AIChat.jiraInvalidResponse.localize))
                return
            }

            prompt.state = .bugOpened
            self.reloadActionPrompt(prompt)
            self.append(.jiraTicket(key: key, url: url, summary: summary))

            if let sprintAdded = data["sprintAdded"] as? Bool, sprintAdded,
               let sprintName = data["sprintName"] as? String {
                self.append(.system(
                    LocalizationKey.View.AIChat.sprintAdded.localize.replacing("sprintName", with: sprintName)
                ))
            }
        }
    }

    fileprivate func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func callCreatePR(bugTitle: String, accepted: [ProposedChange]) {
        let changesPayload: [[String: Any]] = accepted.map {
            [
                "filePath": $0.filePath,
                "newContent": $0.newContent,
                "description": $0.changeDescription,
            ]
        }

        let payload: [String: Any] = [
            "bugTitle": String(bugTitle.prefix(80)),
            "bugDescription": bugTitle,
            "changes": changesPayload,
        ]

        let callable = functions.httpsCallable("createPR")
        callable.timeoutInterval = 120
        callable.call(payload) { [weak self] result, error in
            guard let self = self else { return }

            self.loadingView.stopAnimating()
            self.createPRButton.isEnabled = true

            if let error = error {
                let nsError = error as NSError
                self.append(.system(
                    LocalizationKey.View.AIChat.prError.localize.replacing("message", with: nsError.localizedDescription)
                ))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let prUrl = data["prUrl"] as? String,
                  let prNumber = data["prNumber"] as? Int,
                  let branch = data["branch"] as? String else {
                self.append(.system(LocalizationKey.View.AIChat.prInvalidResponse.localize))
                return
            }

            self.append(.system(
                LocalizationKey.View.AIChat.prOpened.localize
                    .replacing("number", with: prNumber)
                    .replacing("branch", with: branch)
                    .replacing("url", with: prUrl)
            ))

            // Lock in proposals — new PR requires a new analysis.
            self.pendingProposals.removeAll()
            self.updatePRButtonVisibility()
        }
    }

    // MARK: Helpers
    private func append(_ item: ChatItem) {
        // Kullanıcıya hata gösteren system mesajlarını ALERT olarak kaydet.
        if case .system(let text) = item, text.hasPrefix("❌") {
            let firstLine = text
                .split(separator: "\n", maxSplits: 1)
                .first
                .map(String.init) ?? text
            ActivityRecorder.shared.recordAlert(title: firstLine)
        }

        items.append(item)
        let indexPath = IndexPath(row: items.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }

    fileprivate func proposalDecided(_ change: ProposedChange) {
        // Find the row that holds this proposal and refresh it.
        if let row = items.firstIndex(where: {
            if case let .proposal(p) = $0 { return p.id == change.id }
            return false
        }) {
            tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
        }
        updatePRButtonVisibility()
    }

    private func updatePRButtonVisibility() {
        let anyDecided = pendingProposals.contains { $0.decision != .pending }
        createPRButton.isHidden = !anyDecided
    }
}

// MARK: - TableView DataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        switch item {
        case .user(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseId, for: indexPath) as! ChatMessageCell
            cell.configure(role: .user, content: text)
            return cell
        case .claude(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseId, for: indexPath) as! ChatMessageCell
            cell.configure(role: .claude, content: text)
            return cell
        case .system(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatMessageCell.reuseId, for: indexPath) as! ChatMessageCell
            cell.configure(role: .system, content: text)
            return cell
        case .proposal(let change):
            let cell = tableView.dequeueReusableCell(withIdentifier: ProposedChangeCell.reuseId, for: indexPath) as! ProposedChangeCell
            cell.configure(with: change) { [weak self] in
                self?.proposalDecided(change)
            }
            return cell
        case .actionPrompt(let prompt):
            let cell = tableView.dequeueReusableCell(withIdentifier: ActionPromptCell.reuseId, for: indexPath) as! ActionPromptCell
            cell.configure(
                with: prompt,
                onBug: { [weak self] in self?.actionPromptDidTapBug(prompt) },
                onCode: { [weak self] in self?.actionPromptDidTapCode(prompt) }
            )
            return cell
        case .jiraTicket(let key, let url, let summary):
            let cell = tableView.dequeueReusableCell(withIdentifier: JiraTicketCell.reuseId, for: indexPath) as! JiraTicketCell
            cell.configure(key: key, url: url, summary: summary) { [weak self] in
                self?.openURL(url)
            }
            return cell
        }
    }
}

// MARK: - TextViewDelegate (eski TextFieldDelegate'in yerini alır)
extension ViewController: UITextViewDelegate {

    // Return tuşuna basılınca gönder
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            sendTapped()
            return false   // yeni satır ekleme
        }
        return true
    }

    // Her değişiklikte yüksekliği ve placeholder'ı güncelle
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateInputFieldHeight()
    }
}

// MARK: - Chat Message Cell

final class ChatMessageCell: UITableViewCell {

    enum Role { case user, claude, system }

    static let reuseId = "ChatMessageCell"

    private let roleLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 13, weight: .bold)
        return lbl
    }()

    private let contentLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 14)
        lbl.numberOfLines = 0
        return lbl
    }()

    private let bubble: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.layer.cornerRadius = 8
        return v
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.addSubview(bubble)
        bubble.addSubview(roleLabel)
        bubble.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            roleLabel.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            roleLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            roleLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),

            contentLabel.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            contentLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),
            contentLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
        ])
    }

    func configure(role: Role, content: String) {
        contentLabel.text = content
        switch role {
        case .user:
            roleLabel.text = LocalizationKey.View.AIChat.roleUser.localize
            roleLabel.textColor = .systemBlue
            bubble.backgroundColor = .systemBlue.withAlphaComponent(0.1)
            contentLabel.textColor = .label
        case .claude:
            roleLabel.text = LocalizationKey.View.AIChat.roleAssistant.localize
            roleLabel.textColor = .systemGreen
            bubble.backgroundColor = .systemGreen.withAlphaComponent(0.1)
            contentLabel.textColor = .label
        case .system:
            roleLabel.text = LocalizationKey.View.AIChat.roleSystem.localize
            roleLabel.textColor = .secondaryLabel
            bubble.backgroundColor = .systemGray6
            contentLabel.textColor = .secondaryLabel
        }
    }
}

// MARK: - Proposed Change Cell

final class ProposedChangeCell: UITableViewCell {

    static let reuseId = "ProposedChangeCell"

    private var change: ProposedChange?
    private var onDecisionChanged: (() -> Void)?

    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .systemBackground
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.separator.cgColor
        return v
    }()

    private let headerLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .systemOrange
        lbl.text = LocalizationKey.View.AIChat.proposedChangeHeader.localize
        return lbl
    }()

    private let filePathLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        lbl.textColor = .label
        lbl.numberOfLines = 1
        lbl.lineBreakMode = .byTruncatingMiddle
        return lbl
    }()

    private let descriptionLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = .label
        lbl.numberOfLines = 0
        return lbl
    }()

    private let codeView: UITextView = {
        let tv = UITextView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        tv.backgroundColor = UIColor.systemGray6
        tv.layer.cornerRadius = 6
        tv.isEditable = false
        tv.isScrollEnabled = true
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        return tv
    }()

    private let acceptButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = LocalizationKey.View.AIChat.acceptChange.localize
        config.baseForegroundColor = .systemGreen
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return btn
    }()

    private let rejectButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = LocalizationKey.View.AIChat.rejectChange.localize
        config.baseForegroundColor = .systemRed
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return btn
    }()

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 12, weight: .semibold)
        lbl.textAlignment = .right
        return lbl
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(container)
        container.addSubview(headerLabel)
        container.addSubview(filePathLabel)
        container.addSubview(descriptionLabel)
        container.addSubview(codeView)
        container.addSubview(acceptButton)
        container.addSubview(rejectButton)
        container.addSubview(statusLabel)

        acceptButton.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        rejectButton.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),

            statusLabel.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: headerLabel.trailingAnchor, constant: 8),

            filePathLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            filePathLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            filePathLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            descriptionLabel.topAnchor.constraint(equalTo: filePathLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            codeView.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 8),
            codeView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            codeView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            codeView.heightAnchor.constraint(equalToConstant: 180),

            acceptButton.topAnchor.constraint(equalTo: codeView.bottomAnchor, constant: 10),
            acceptButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            acceptButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            acceptButton.heightAnchor.constraint(equalToConstant: 38),

            rejectButton.topAnchor.constraint(equalTo: acceptButton.topAnchor),
            rejectButton.leadingAnchor.constraint(equalTo: acceptButton.trailingAnchor, constant: 10),
            rejectButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            rejectButton.heightAnchor.constraint(equalToConstant: 38),
            rejectButton.widthAnchor.constraint(equalTo: acceptButton.widthAnchor),
        ])
    }

    func configure(with change: ProposedChange, onDecision: @escaping () -> Void) {
        self.change = change
        self.onDecisionChanged = onDecision
        filePathLabel.text = change.filePath
        descriptionLabel.text = change.changeDescription
        let diff = computeUnifiedDiff(
            old: change.oldContent,
            new: change.newContent,
            contextLines: 2
        )
        codeView.attributedText = renderDiff(diff)
        applyDecisionStyle(change.decision)
    }

    private func applyDecisionStyle(_ decision: ProposedChange.Decision) {
        switch decision {
        case .pending:
            statusLabel.text = ""
            container.layer.borderColor = UIColor.separator.cgColor
            container.layer.borderWidth = 1
            acceptButton.isEnabled = true
            rejectButton.isEnabled = true
            acceptButton.alpha = 1
            rejectButton.alpha = 1
        case .accepted:
            statusLabel.text = LocalizationKey.View.AIChat.acceptedChange.localize
            statusLabel.textColor = .systemGreen
            container.layer.borderColor = UIColor.systemGreen.cgColor
            container.layer.borderWidth = 2
            acceptButton.alpha = 1
            rejectButton.alpha = 0.4
        case .rejected:
            statusLabel.text = LocalizationKey.View.AIChat.rejectedChange.localize
            statusLabel.textColor = .systemRed
            container.layer.borderColor = UIColor.systemRed.cgColor
            container.layer.borderWidth = 2
            acceptButton.alpha = 0.4
            rejectButton.alpha = 1
        }
    }

    @objc private func acceptTapped() {
        guard let change = change else { return }
        change.decision = .accepted
        applyDecisionStyle(.accepted)
        onDecisionChanged?()
    }

    @objc private func rejectTapped() {
        guard let change = change else { return }
        change.decision = .rejected
        applyDecisionStyle(.rejected)
        onDecisionChanged?()
    }
}

// MARK: - Action Prompt Cell

final class ActionPromptCell: UITableViewCell {

    static let reuseId = "ActionPromptCell"

    private var onBug: (() -> Void)?
    private var onCode: (() -> Void)?

    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        v.layer.cornerRadius = 12
        return v
    }()

    private let promptLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.text = LocalizationKey.View.AIChat.actionPrompt.localize
        lbl.font = .systemFont(ofSize: 14, weight: .semibold)
        lbl.textColor = .label
        lbl.numberOfLines = 0
        return lbl
    }()

    private let bugButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = LocalizationKey.View.AIChat.bugActionTitle.localize
        config.subtitle = LocalizationKey.View.AIChat.bugActionSubtitle.localize
        config.baseBackgroundColor = .systemOrange
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleAlignment = .leading
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.contentHorizontalAlignment = .leading
        return btn
    }()

    private let codeButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = LocalizationKey.View.AIChat.codeActionTitle.localize
        config.subtitle = LocalizationKey.View.AIChat.codeActionSubtitle.localize
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.titleAlignment = .leading
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.contentHorizontalAlignment = .leading
        return btn
    }()

    private let statusLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 13, weight: .medium)
        lbl.textColor = .secondaryLabel
        lbl.numberOfLines = 0
        lbl.isHidden = true
        return lbl
    }()

    private let spinner: UIActivityIndicatorView = {
        let av = UIActivityIndicatorView(style: .medium)
        av.translatesAutoresizingMaskIntoConstraints = false
        av.hidesWhenStopped = true
        return av
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(container)
        container.addSubview(promptLabel)
        container.addSubview(bugButton)
        container.addSubview(codeButton)
        container.addSubview(statusLabel)
        container.addSubview(spinner)

        bugButton.addTarget(self, action: #selector(bugTapped), for: .touchUpInside)
        codeButton.addTarget(self, action: #selector(codeTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            promptLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            promptLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            promptLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            bugButton.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 12),
            bugButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            bugButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            codeButton.topAnchor.constraint(equalTo: bugButton.bottomAnchor, constant: 10),
            codeButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            codeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            statusLabel.topAnchor.constraint(equalTo: codeButton.bottomAnchor, constant: 12),
            statusLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: spinner.leadingAnchor, constant: -8),
            statusLabel.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -14),

            spinner.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            codeButton.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -14),
        ])
    }

    func configure(with prompt: ActionPrompt, onBug: @escaping () -> Void, onCode: @escaping () -> Void) {
        self.onBug = onBug
        self.onCode = onCode

        switch prompt.state {
        case .pending:
            bugButton.isEnabled = true
            codeButton.isEnabled = true
            bugButton.alpha = 1
            codeButton.alpha = 1
            statusLabel.isHidden = true
            spinner.stopAnimating()
        case .bugLoading:
            bugButton.isEnabled = false
            codeButton.isEnabled = false
            bugButton.alpha = 0.5
            codeButton.alpha = 0.5
            statusLabel.text = LocalizationKey.View.AIChat.jiraCreating.localize
            statusLabel.textColor = .secondaryLabel
            statusLabel.isHidden = false
            spinner.startAnimating()
        case .bugOpened:
            bugButton.isEnabled = false
            codeButton.isEnabled = true
            bugButton.alpha = 0.5
            codeButton.alpha = 1
            statusLabel.text = LocalizationKey.View.AIChat.jiraCreated.localize
            statusLabel.textColor = .systemGreen
            statusLabel.isHidden = false
            spinner.stopAnimating()
        case .codeRevealed:
            bugButton.isEnabled = true
            codeButton.isEnabled = false
            bugButton.alpha = 1
            codeButton.alpha = 0.5
            let suffix = prompt.pendingProposals.isEmpty
                ? LocalizationKey.View.AIChat.jiraNoChangeSuffix.localize
                : LocalizationKey.View.AIChat.jiraChangesBelowSuffix.localize
            statusLabel.text = "🛠️ \(suffix)"
            statusLabel.textColor = .systemBlue
            statusLabel.isHidden = false
            spinner.stopAnimating()
        }
    }

    @objc private func bugTapped() { onBug?() }
    @objc private func codeTapped() { onCode?() }
}

// MARK: - Jira Ticket Cell

final class JiraTicketCell: UITableViewCell {

    static let reuseId = "JiraTicketCell"

    private var onOpenURL: (() -> Void)?

    private let container: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.08)
        v.layer.cornerRadius = 10
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.4).cgColor
        return v
    }()

    private let headerLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 12, weight: .bold)
        lbl.textColor = .systemGreen
        lbl.text = LocalizationKey.View.AIChat.jiraTicketHeader.localize
        return lbl
    }()

    private let keyLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        lbl.textColor = .label
        return lbl
    }()

    private let summaryLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 14)
        lbl.textColor = .label
        lbl.numberOfLines = 0
        return lbl
    }()

    private let openButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = LocalizationKey.View.AIChat.openJira.localize
        config.baseForegroundColor = .systemGreen
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(container)
        container.addSubview(headerLabel)
        container.addSubview(keyLabel)
        container.addSubview(summaryLabel)
        container.addSubview(openButton)

        openButton.addTarget(self, action: #selector(openTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            headerLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            keyLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 6),
            keyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            keyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            summaryLabel.topAnchor.constraint(equalTo: keyLabel.bottomAnchor, constant: 4),
            summaryLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            summaryLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),

            openButton.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 10),
            openButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            openButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
    }

    func configure(key: String, url: String, summary: String, onOpen: @escaping () -> Void) {
        keyLabel.text = key
        summaryLabel.text = summary
        self.onOpenURL = onOpen
    }

    @objc private func openTapped() { onOpenURL?() }
}
