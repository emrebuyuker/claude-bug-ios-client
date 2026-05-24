import UIKit
import FirebaseFunctions

// MARK: - Message Model
struct ChatMessage {
    enum Role { case user, claude, system }
    let role: Role
    let content: String
}

final class ViewController: UIViewController {

    // MARK: - Properties
    private lazy var functions: Functions = {
        return Functions.functions(region: "us-central1")
    }()

    private var messages: [ChatMessage] = [
        ChatMessage(
            role: .system,
            content: "👋 Test repo: emrebuyuker/claude-bug-test\n\n"
                + "Aşağıdan bir bug tarif et, Claude GitHub'dan kodu okuyup analiz eder.\n\n"
                + "Örnek sorular:\n"
                + "• Feed ekranında array index out of bounds crash alıyorum\n"
                + "• Login butonuna basınca unexpectedly found nil\n"
                + "• TimerViewController deinit log basmıyor, memory leak şüphesi\n"
                + "• Cüzdan bakiyesi yanlış görünüyor (örn 1936030245 USD)"
        )
    ]

    // MARK: - UI
    private lazy var tableView: UITableView = {
        let tv = UITableView()
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(ChatMessageCell.self, forCellReuseIdentifier: ChatMessageCell.reuseId)
        tv.dataSource = self
        tv.estimatedRowHeight = 100
        tv.rowHeight = UITableView.automaticDimension
        tv.separatorStyle = .singleLine
        tv.keyboardDismissMode = .interactive
        return tv
    }()

    private lazy var inputContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .secondarySystemBackground
        return v
    }()

    private lazy var inputField: UITextField = {
        let tf = UITextField()
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.borderStyle = .roundedRect
        tf.placeholder = "Bug'ı tarif et..."
        tf.returnKeyType = .send
        tf.delegate = self
        tf.backgroundColor = .systemBackground
        return tf
    }()

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

    private var inputBottomConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle
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

    // MARK: - Setup
    private func setupViews() {
        view.addSubview(tableView)
        view.addSubview(inputContainer)
        inputContainer.addSubview(inputField)
        inputContainer.addSubview(sendButton)
        view.addSubview(loadingView)

        let bottomConstraint = inputContainer.bottomAnchor.constraint(
            equalTo: view.safeAreaLayoutGuide.bottomAnchor
        )
        inputBottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomConstraint,
            inputContainer.heightAnchor.constraint(equalToConstant: 60),

            inputField.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputField.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 40),

            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.centerYAnchor.constraint(equalTo: inputContainer.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 70),

            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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

    // MARK: - Actions
    @objc private func sendTapped() {
        guard let text = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return }

        appendMessage(ChatMessage(role: .user, content: text))
        inputField.text = ""
        inputField.resignFirstResponder()
        sendButton.isEnabled = false
        loadingView.startAnimating()

        callCloudFunction(bugDescription: text)
    }

    private func callCloudFunction(bugDescription: String) {
        let payload: [String: Any] = ["bugDescription": bugDescription]

        functions.httpsCallable("askClaude").call(payload) { [weak self] result, error in
            guard let self = self else { return }

            self.loadingView.stopAnimating()
            self.sendButton.isEnabled = true

            if let error = error {
                let nsError = error as NSError
                let msg = "❌ Hata: \(nsError.localizedDescription)\n"
                    + "Code: \(nsError.code)\n"
                    + "Domain: \(nsError.domain)"
                self.appendMessage(ChatMessage(role: .system, content: msg))
                return
            }

            guard let data = result?.data as? [String: Any] else {
                self.appendMessage(ChatMessage(role: .system, content: "❌ Beklenmedik response formatı"))
                return
            }

            let answer = (data["answer"] as? String) ?? "(Claude bir cevap üretemedi)"
            let iterations = data["iterations"] as? Int ?? 0
            let cost = data["estimatedCostUsd"] as? Double ?? 0.0
            let inputTokens = data["inputTokens"] as? Int ?? 0
            let outputTokens = data["outputTokens"] as? Int ?? 0

            let metadata = "\n\n— — — — —\n"
                + "📊 \(iterations) iterasyon\n"
                + "🪙 \(inputTokens) input + \(outputTokens) output token\n"
                + "💵 Tahmini maliyet: $\(String(format: "%.4f", cost))"

            self.appendMessage(ChatMessage(role: .claude, content: answer + metadata))
        }
    }

    private func appendMessage(_ message: ChatMessage) {
        messages.append(message)
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
    }
}

// MARK: - TableView DataSource
extension ViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: ChatMessageCell.reuseId,
            for: indexPath
        ) as? ChatMessageCell else {
            return UITableViewCell()
        }
        cell.configure(with: messages[indexPath.row])
        return cell
    }
}

// MARK: - TextField Delegate
extension ViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

// MARK: - Chat Message Cell
final class ChatMessageCell: UITableViewCell {

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

    func configure(with message: ChatMessage) {
        contentLabel.text = message.content
        switch message.role {
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
