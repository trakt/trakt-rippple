//
//  WeeklyTrackerViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit
import WebKit

final class WeeklyTrackerViewController: UIViewController {
    private let webView: WKWebView = {
        // The weekly pages use viewport-fit=cover without padding for safe areas, so the bar buttons would cover them.
        // Rails stretch back out to the edges so they scroll under the buttons instead of being clipped by the body padding.
        // The app sets the --app-inset-* values because WebKit doesn't always update env() when the safe area changes.
        let appStyle = """
        const style = document.createElement('style');
        style.textContent = `
            :root {
                --app-inset-top: env(safe-area-inset-top);
                --app-inset-right: env(safe-area-inset-right);
                --app-inset-bottom: env(safe-area-inset-bottom);
                --app-inset-left: env(safe-area-inset-left);
            }
            footer { display: none !important; }
            body {
                padding: var(--app-inset-top) var(--app-inset-right) var(--app-inset-bottom) var(--app-inset-left);
            }
            .rail, .carousel {
                margin-left: calc(-1 * var(--app-inset-left));
                margin-right: calc(-1 * var(--app-inset-right));
            }
            .rail > li, .carousel > li {
                scroll-margin-left: var(--app-inset-left);
                scroll-margin-right: var(--app-inset-right);
            }
            .rail > li:first-child, .carousel > li:first-child { margin-left: var(--app-inset-left); }
            .rail > li:last-child, .carousel > li:last-child { margin-right: var(--app-inset-right); }
            .slide { max-width: calc(95% - var(--app-inset-left) - var(--app-inset-right)); }
        `;
        document.documentElement.appendChild(style);
        """
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.addUserScript(WKUserScript(source: appStyle,
                                                                       injectionTime: .atDocumentStart,
                                                                       forMainFrameOnly: true))
        return WKWebView(frame: .zero, configuration: configuration)
    }()

    private let rippplePageHosts = ["rippple.app", "www.rippple.app"]

    private lazy var doneButton = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
        guard let self = self else { return }
        self.dismiss(animated: true)
    })

    private lazy var backButton = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), primaryAction: UIAction { [weak self] _ in
        guard let self = self else { return }
        self.webView.goBack()
    })

    override func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true
        navigationController?.overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        updateNavigationButtons()

        if let url = URL(string: "https://rippple.app/weeks/") {
            webView.load(URLRequest(url: url))
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePageInsets()
    }

    private func updatePageInsets() {
        let insets = view.safeAreaInsets
        let script = """
        (() => {
            const style = document.documentElement.style;
            style.setProperty('--app-inset-top', '\(insets.top)px');
            style.setProperty('--app-inset-right', '\(insets.right)px');
            style.setProperty('--app-inset-bottom', '\(insets.bottom)px');
            style.setProperty('--app-inset-left', '\(insets.left)px');
        })();
        """
        webView.evaluateJavaScript(script)
    }

    private func updateNavigationButtons() {
        navigationItem.leftBarButtonItems = webView.canGoBack ? [doneButton, backButton] : [doneButton]
    }
}

// MARK: - WKNavigationDelegate

extension WeeklyTrackerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard navigationAction.navigationType == .linkActivated,
              let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if DeeplinkManager.shared.openInApp(url) {
            decisionHandler(.cancel)
            return
        }

        if let host = url.host?.lowercased(), rippplePageHosts.contains(host) {
            decisionHandler(.allow)
            return
        }

        UIApplication.shared.open(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        updatePageInsets()
        updateNavigationButtons()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateNavigationButtons()
    }
}
