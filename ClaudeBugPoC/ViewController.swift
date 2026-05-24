import UIKit
import FirebaseFunctions

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
            string: "(değişiklik yok)",
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
        .system(
            "👋 Bu uygulamanın kendi Swift kodunu analiz edebilirsin.\n\n"
            + "Aşağıdan bir bug ya da şüpheli davranış tarif et — Claude, "
            + "GitHub'daki iOS kaynaklarını (ClaudeBugPoC/) okuyup root cause + fix önerir.\n\n"
            + "Önerilen her değişiklikte ✓ veya ✗ ile karar ver. Herhangi bir kararı verdiğinde "
            + "altta 'PR Oluştur' butonu görünür."
        )
    ]

    private var lastBugDescription: String?
    private var pendingProposals: [ProposedChange] = []

    // MARK: UI
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseId)
        tv.register(ProposedChangeCell.self, forCellReuseIdentifier: ProposedChangeCell.reuseId)
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
        lbl.text = "Bug'ı tarif et..."
        lbl.font = .systemFont(ofSize: 16)
        lbl.textColor = .placeholderText
        lbl.isUserInteractionEnabled = false
        return lbl
    }()
    // ───────────────────────────────────────────────────────────────────────

    private lazy var sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("Gönder", for: .normal)
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
        config.title = "🚀 PR Oluştur"
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
        title = "Claude Bug Analyzer"
        view.backgroundColor = .systemBackground
        setupViews()
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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

        // Reset pending proposals on a new question.
        pendingProposals.removeAll()
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
        let accepted = pendingProposals.filter { $0.decision == .accepted }
        guard !accepted.isEmpty else {
            append(.system("ℹ️ Hiçbir değişiklik ✓ ile onaylanmadı. PR açılmadı."))
            return
        }
        guard let bugTitle = lastBugDescription else {
            append(.system("❌ Önce bir bug tarif etmelisin."))
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
    private func callAskClaude(bugDescription: String) {
        let payload: [String: Any] = ["bugDescription": bugDescription]
        let callable = functions.httpsCallable("askClaude")
        callable.timeoutInterval = 180   // match server-side timeout; default is 70s
        callable.call(payload) { [weak self] result, error in
            guard let self = self else { return }

            self.loadingView.stopAnimating()
            self.sendButton.isEnabled = true

            if let error = error {
                let nsError = error as NSError
                let msg = "❌ Hata: \(nsError.localizedDescription)\n"
                    + "Code: \(nsError.code)\nDomain: \(nsError.domain)"
                self.append(.system(msg))
                return
            }

            guard let data = result?.data as? [String: Any] else {
                self.append(.system("❌ Beklenmedik response formatı"))
                return
            }

            let answer = (data["answer"] as? String) ?? "(Claude bir cevap üretemedi)"
            let iterations = data["iterations"] as? Int ?? 0
            let cost = data["estimatedCostUsd"] as? Double ?? 0.0
            let inputTokens = data["inputTokens"] as? Int ?? 0
            let outputTokens = data["outputTokens"] as? Int ?? 0
            let cacheRead = data["cacheReadTokens"] as? Int ?? 0
            let cacheCreated = data["cacheCreationTokens"] as? Int ?? 0

            var metadata = "\n\n— — — — —\n"
                + "📊 \(iterations) iterasyon · 🪙 \(inputTokens)+\(outputTokens) token · "
                + "💵 $\(String(format: "%.4f", cost))"
            if cacheRead > 0 || cacheCreated > 0 {
                metadata += "\n♻️ cache: \(cacheRead) read · \(cacheCreated) write"
            }

            self.append(.claude(answer + metadata))

            if let rawChanges = data["proposedChanges"] as? [[String: Any]] {
                for raw in rawChanges {
                    guard let id = raw["id"] as? String,
                          let filePath = raw["filePath"] as? String,
                          let desc = raw["description"] as? String,
                          let oldC = raw["oldContent"] as? String,
                          let newC = raw["newContent"] as? String else { continue }
                    let change = ProposedChange(
                        id: id,
                        filePath: filePath,
                        changeDescription: desc,
                        oldContent: oldC,
                        newContent: newC
                    )
                    self.pendingProposals.append(change)
                    self.append(.proposal(change))
                }
            }
        }
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
                self.append(.system("❌ PR oluşturulamadı: \(nsError.localizedDescription)"))
                return
            }

            guard let data = result?.data as? [String: Any],
                  let prUrl = data["prUrl"] as? String,
                  let prNumber = data["prNumber"] as? Int,
                  let branch = data["branch"] as? String else {
                self.append(.system("❌ PR yanıtı beklenen formatta değil"))
                return
            }

            self.append(.system(
                "✅ PR #\(prNumber) açıldı\n"
                + "🌿 branch: \(branch)\n"
                + "🔗 \(prUrl)"
            ))

            // Lock in proposals — new PR requires a new analysis.
            self.pendingProposals.removeAll()
            self.updatePRButtonVisibility()
        }
    }

    // MARK: Helpers
    private func append(_ item: ChatItem) {
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
            roleLabel.text = "🧑 SEN"
            roleLabel.textColor = .systemBlue
            bubble.backgroundColor = .systemBlue.withAlphaComponent(0.1)
            contentLabel.textColor = .label
        case .claude:
            roleLabel.text = "🤖 CLAUDE"
            roleLabel.textColor = .systemGreen
            bubble.backgroundColor = .systemGreen.withAlphaComponent(0.1)
            contentLabel.textColor = .label
        case .system:
            roleLabel.text = "ℹ️  SYSTEM"
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
        lbl.text = "📝 ÖNERİLEN DEĞİŞİKLİK"
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
        config.title = "✓ Ekle"
        config.baseForegroundColor = .systemGreen
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        return btn
    }()

    private let rejectButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "✗ Atla"
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
            statusLabel.text = "✓ EKLENECEK"
            statusLabel.textColor = .systemGreen
            container.layer.borderColor = UIColor.systemGreen.cgColor
            container.layer.borderWidth = 2
            acceptButton.alpha = 1
            rejectButton.alpha = 0.4
        case .rejected:
            statusLabel.text = "✗ ATLANDI"
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
