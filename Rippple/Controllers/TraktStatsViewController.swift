//
//  TraktStatsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 21/05/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit
import WebKit

final class TraktStatsViewController: UIViewController {
    private let webView = WKWebView()

    enum StatsMode {
        case mir(user: User, month: Int, year: Int)
        case yir(user: User, year: Int)
        case all(user: User)
    }

    var mode: StatsMode!
    private var user: User {
        switch mode! {
        case .all(let user):
            return user
        case .mir(let user, _, _):
            return user
        case .yir(let user, _):
            return user
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupLoadingNavigationBar()
        loadRequestedURL()
    }

    private func setupWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.isHidden = true
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func getLastDaysOfPreviousMonths(from date: Date, monthsBack: Int) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        var dates: [Date] = []

        for monthOffset in 0...(monthsBack - 1) {
            if let targetMonth = calendar.date(byAdding: .month, value: -monthOffset, to: date) {
                let components = calendar.dateComponents([.year, .month], from: targetMonth)
                if let firstDayOfMonth = calendar.date(from: components),
                   let firstDayOfNextMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth),
                   let lastMoment = calendar.date(byAdding: .second, value: -1, to: firstDayOfNextMonth) {
                    dates.append(lastMoment)
                }
            }
        }

        return dates
    }

    private func getCurrentAndPreviousYears(from date: Date, yearsBack: Int) -> [Int] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        let currentYear = calendar.component(.year, from: date)
        var years: [Int] = []

        for offset in 0...yearsBack {
            years.append(currentYear - offset)
        }

        return years
    }

    private func setupNavigationBar() {
        let closeButton = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(handler: { _ in
            self.dismiss(animated: true)
        }))
        closeButton.style = .plain

        var children = [UIAction]()

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")

        let allTime = UIAction(title: "All Time Stats") { _ in
            self.mode = .all(user: self.user)
            self.loadRequestedURL()
        }
        children.append(allTime)

        for year in getCurrentAndPreviousYears(from: .now, yearsBack: 5) {
            let pastYears = UIAction(title: "\(year) in Review") { _ in
                self.mode = .yir(user: self.user, year: year)
                self.loadRequestedURL()
            }
            children.append(pastYears)
        }

        for date in getLastDaysOfPreviousMonths(from: .now, monthsBack: 6) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            let pastMonth = UIAction(title: "\(formatter.string(from: date)) in Review") { _ in
                self.mode = .mir(user: self.user,
                                 month: calendar.component(.month, from: date),
                                 year: calendar.component(.year, from: date))
                self.loadRequestedURL()
            }
            children.append(pastMonth)
        }

        let moreButton = UIBarButtonItem(image: UIImage(systemName: "line.horizontal.3.decrease"),
                                         menu: UIMenu(children: children))

        navigationItem.leftBarButtonItems = [closeButton]
        navigationItem.rightBarButtonItems = [moreButton]
    }

    private func setupLoadingNavigationBar() {
        let closeButton = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(handler: { _ in
            self.dismiss(animated: true)
        }))

        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        let loading = UIBarButtonItem(customView: activityIndicator)

        navigationItem.leftBarButtonItems = [closeButton]
        navigationItem.rightBarButtonItems = [loading]
    }

    private func loadRequestedURL() {
        guard let mode = mode else { fatalError("Stats need a mode!") }

        var url: URL?
        switch mode {
        case .mir(let user, let month, let year):
            url = URL(string: "https://trakt.tv/users/\(user.slug)/mir/\(String(year))/\(String(month))?standalone_mode=true")
        case .yir(let user, let year):
            url = URL(string: "https://trakt.tv/users/\(user.slug)/year/\(String(year))?standalone_mode=true")
        case .all(let user):
            url = URL(string: "https://trakt.tv/users/\(user.slug)/year/all?standalone_mode=true")
        }

        guard let url = url else { fatalError("Couldn't get a valid URL") }
        if user.isCurrentUser {
            webView.load(URLRequest(url: url.slurmified()))
        } else {
            webView.load(URLRequest(url: url))
        }
    }
}

extension TraktStatsViewController: WKNavigationDelegate {
    private func openURL(url: URL) {
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: { success in
                if success {
                    print("Opened URL \(url) successfully")
                } else {
                    print("Failed to open URL \(url)")
                }
            })
        } else {
            print("Can't open the URL: \(url)")
        }
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            guard let url = navigationAction.request.url else { return }
            let urlString = url.absoluteString
            if urlString.hasPrefix("https://trakt.tv/shows") ||
                urlString.hasPrefix("https://trakt.tv/movies"),
                let ripppleUrl = URL(string: urlString.replacingOccurrences(of: "https://trakt.tv/", with: "ripl://")) {
                openURL(url: ripppleUrl)
            } else {
                openURL(url: url)
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setupLoadingNavigationBar()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.isHidden = false
        setupNavigationBar()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.isHidden = false
        setupNavigationBar()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.isHidden = false
        setupNavigationBar()
    }
}
