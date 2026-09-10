import UIKit

/// One screen: a column of buttons that drive the SDK, and a scrolling log
/// that mirrors every payload / event.
final class TPAPTestViewController: UIViewController {

    private let logView = UITextView()

    /// (button title, action). Each maps to a `HyperSDKManager` call below.
    private let rows: [(title: String, action: String)] = [
        ("1 · Initiate SDK", "initiate"),
        ("2 · UPI Management — Signature", "management_signature"),
        ("3 · UPI Management — Auth Token", "management_token"),
        ("Terminate", "terminate")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UPI TPAP Test"
        view.backgroundColor = .systemBackground
        buildUI()
        Log.sink = { [weak self] message in
            DispatchQueue.main.async { self?.append(message) }
        }
    }

    // MARK: - Actions

    @objc private func handleTap(_ sender: UIButton) {
        let action = rows[sender.tag].action
        switch action {
        case "initiate":
            HyperSDKManager.shared.initiate(from: self) { [weak self] event, _ in
                self?.append("↳ handled event: \(event)")
            }
        case "management_signature":
            HyperSDKManager.shared.openUPIManagementSignature()
        case "management_token":
            HyperSDKManager.shared.openUPIManagementToken()
        case "terminate":
            HyperSDKManager.shared.terminate()
        default:
            break
        }
    }

    // MARK: - UI

    private func buildUI() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (index, row) in rows.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(row.title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = .systemBlue
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            button.tag = index
            button.addTarget(self, action: #selector(handleTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = .secondarySystemBackground
        logView.layer.cornerRadius = 8
        logView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(logView)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),

            logView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16),
            logView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            logView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            logView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)
        ])
    }

    private func append(_ message: String) {
        logView.text += (logView.text.isEmpty ? "" : "\n") + message + "\n"
        let end = NSRange(location: logView.text.count, length: 0)
        logView.scrollRangeToVisible(end)
    }
}
