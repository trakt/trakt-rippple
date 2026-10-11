#if targetEnvironment(macCatalyst)
import Receiver
import UIKit

final class MCPConsoleViewController: UIViewController {
    private let console = UITextView()
    private let disposeBag = DisposeBag()
    private var toggleButton: UIBarButtonItem?
    private var reloadButton: UIBarButtonItem?
    private var verbosityButton: UIBarButtonItem?
    private var followsTail = true
    private var showsVerboseLogs = true

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Console"
        view.backgroundColor = .ripppleViewBackground
        console.translatesAutoresizingMaskIntoConstraints = false
        console.isEditable = false
        console.alwaysBounceVertical = true
        console.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .monospacedSystemFont(ofSize: 12, weight: .regular))
        console.adjustsFontForContentSizeCategory = true
        console.backgroundColor = .ripppleViewBackground
        console.textColor = .label
        console.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 88, right: 16)
        console.verticalScrollIndicatorInsets.bottom = 88
        console.accessibilityLabel = "MCP console"
        console.delegate = self
        view.addSubview(console)
        NSLayoutConstraint.activate([
            console.topAnchor.constraint(equalTo: view.topAnchor),
            console.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            console.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            console.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let clear = UIBarButtonItem(title: "Clear", primaryAction: UIAction { _ in
            MCPServerManager.shared.clearLogs()
        })
        let copy = UIBarButtonItem(title: "Copy", primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            let snapshot = MCPServerManager.shared.snapshot
            let console = self.showsVerboseLogs ? snapshot.verboseConsole : snapshot.console
            UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: console]], options: [.localOnly: true])
        })
        let toggle = UIBarButtonItem(title: "Start", primaryAction: UIAction { _ in
            let snapshot = MCPServerManager.shared.snapshot
            MCPServerManager.shared.setEnabled(!snapshot.enabled || snapshot.state == .failed)
        })
        let reload = UIBarButtonItem(title: "Reload", primaryAction: UIAction { _ in
            MCPServerManager.shared.reload()
        })
        toggleButton = toggle
        reloadButton = reload

        let verbosity = UIBarButtonItem(title: "Verbose (Y)", primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.showsVerboseLogs.toggle()
            self.update(MCPServerManager.shared.snapshot)
        })
        verbosityButton = verbosity

        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.isTranslucent = true
        toolbar.items = [
            .flexibleSpace(),
            clear,
            .fixedSpace(8),
            copy,
            .fixedSpace(8),
            toggle,
            .fixedSpace(8),
            reload,
            .fixedSpace(12),
            verbosity,
            .flexibleSpace()
        ]
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.scrollView = console
        interaction.edge = .bottom
        toolbar.addInteraction(interaction)
        console.topEdgeEffect.style = .soft
        console.topEdgeEffect.isHidden = false
        console.bottomEdgeEffect.style = .soft
        console.bottomEdgeEffect.isHidden = false
        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        update(MCPServerManager.shared.snapshot)
        MCPServerManager.shared.onChangeReceiver.listen { [weak self] snapshot in
            guard let self = self else { return }
            self.update(snapshot)
        }.disposed(by: disposeBag)
    }

    private func update(_ snapshot: MCPServerManager.Snapshot) {
        let active = snapshot.activeConnectionCount
        title = "Console · \(active) active connection\(active == 1 ? "" : "s")"
        let text = showsVerboseLogs ? snapshot.verboseConsole : snapshot.console
        if console.text != text {
            console.text = text
            if followsTail {
                scrollToBottom()
            }
        }
        toggleButton?.title = snapshot.enabled && snapshot.state != .failed ? "Stop" : "Start"
        reloadButton?.isEnabled = snapshot.enabled
        verbosityButton?.title = showsVerboseLogs ? "Verbose (Y)" : "Verbose (N)"
    }

    private func scrollToBottom() {
        console.layoutIfNeeded()
        let bottomOffset = max(
            -console.adjustedContentInset.top,
            console.contentSize.height - console.bounds.height + console.adjustedContentInset.bottom
        )
        console.setContentOffset(CGPoint(x: console.contentOffset.x, y: bottomOffset), animated: false)
    }

    private var isAtBottom: Bool {
        let bottomOffset = console.contentSize.height - console.bounds.height + console.adjustedContentInset.bottom
        return console.contentOffset.y >= bottomOffset - 1
    }
}

extension MCPConsoleViewController: UITextViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        followsTail = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating else { return }
        followsTail = isAtBottom
    }
}
#endif
