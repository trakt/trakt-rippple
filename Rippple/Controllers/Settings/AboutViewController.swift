//
//  AboutViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 22/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import StoreKit

import MessageUI

import Receiver

import SafariServices

import SwiftUI

final class AboutViewController: UITableViewController {

    enum AboutSection: Int {
        case premium
        case account
        case settings
        case knowledge
        case touch
        case follow
        case love
        case about
        case data
    }

    enum SettingsSection: Int, CaseIterable {
        case general
        case spoilers
        case notifications
        case appearance
        case appIcon
        case appIconBadge
        case whereToWatch
        case swipeOptions
        case automations
        case deeplinks
    }

    @IBOutlet var barButtonItem: UIBarButtonItem!

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()
        reloadData()

        PurchaseManager.shared.onPurchasedChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.reloadData()
            }
        }.disposed(by: disposeBag)

        onSettingsRefreshedReceiver.listen { _ in
            DispatchQueue.main.async {
                SwiftMessages.show(message: "✅ Settings refreshed")
            }
        }.disposed(by: disposeBag)

        if navigationController!.viewControllers.first! == self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                               target: self,
                                                               action: #selector(done))
        }

        let redeem = UIAction(title: "Redeem a Code", image: UIImage(systemName: "app.gift")) { _ in
            #if targetEnvironment(macCatalyst)
            if let url = URL(string: "macappstore://apps.apple.com/redeem/"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else if let url = URL(string: "https://apps.apple.com/redeem/"), UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
            #else
            Task.init {
                await AppManager.shared.presentOfferCodeRedeemSheet()
            }
            #endif
        }

        let restore = UIAction(title: "Restore Purchases", image: UIImage(systemName: "arrow.trianglehead.counterclockwise.rotate.90")) { [weak self] _ in
            Task { [weak self] in
                do {
                    try await AppStore.sync()
                    PurchaseManager.shared.refresh()
                } catch {
                    guard let self = self else { return }
                    let alert = UIAlertController(title: "Restore Failed",
                                                  message: error.localizedDescription,
                                                  preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Okay",
                                                  style: .default))
                    self.present(alert, animated: true)
                }
            }
        }

        let history = UIAction(title: "Transactions History", image: UIImage(systemName: "list.bullet.rectangle.portrait")) { [weak self] _ in
            guard let self = self else { return }
            let hosting = UIHostingController(rootView: TransactionsView())
            hosting.modalPresentationStyle = .formSheet
            self.present(hosting, animated: true)
        }

        let refreshTraktSettings = UIAction(title: "Refresh Trakt Settings", image: UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90")) { _ in
            UserManager.shared.reloadSettings(transmitRefreshed: true)
        }

        barButtonItem.primaryAction = nil
        barButtonItem.menu = UIMenu(children: [refreshTraktSettings, redeem, restore, history])
    }

    deinit {
        print("deiniting AboutViewController")
    }

    @objc private func done() {
        dismiss(animated: true, completion: nil)
    }

    private func reloadData() {
        tableView.reloadData()
    }

    private func logoutFromTrakt() {
        UIApplication.shared.switchToLogin()
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch AboutSection(rawValue: section)! {
        case .settings:
            return nil
        case .account:
            return nil
        case .premium:
            return nil
        case .about:
            return "Version \(Bundle.main.releaseVersionNumber!) (\(Bundle.main.buildVersionNumber!))"
        case .data:
            return "Rippple uses the Trakt.tv API and the TMDb API. Rippple is not endorsed or certified by TMDb."
        case .knowledge:
            return nil
        case .follow:
            return nil
        case .touch:
            return nil
        case .love:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch AboutSection(rawValue: section)! {
        case .settings:
            return "Settings"
        case .account:
            return "Trakt"
        case .premium:
            return nil
        case .about:
            return "About"
        case .data:
            return "Data Providers"
        case .knowledge:
            return "Knowledge Base"
        case .touch:
            return "Get in Touch"
        case .love:
            return "Show Your Love"
        case .follow:
            return "Follow & Community"
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch AboutSection(rawValue: section)! {
        case .settings:
            return SettingsSection.allCases.count
        case .account:
            return 3
        case .premium:
            return 1
        case .data:
            return 2
        case .knowledge:
            return 3
        case .touch:
            return 3
        case .follow:
            return 3
        case .love:
            return 2
        case .about:
            return 3
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch AboutSection(rawValue: indexPath.section)! {
        case .settings:
            if indexPath.row == SettingsSection.notifications.rawValue {
                performSegue(withIdentifier: "notifications", sender: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == SettingsSection.appIconBadge.rawValue {
                performSegue(withIdentifier: "badge", sender: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .account:
            if indexPath.row == 0 {
                logoutFromTrakt()
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                present(SFSafariViewController(url: URL(string: "https://status.trakt.tv")!),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else {
                if let url = URL(string: "https://trakt.tv/settings/advanced"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .premium:
            if PurchaseManager.shared.purchased == false {
                 performSegue(withIdentifier: "subscribe", sender: nil)
            } else {
                AppManager.shared.emitEmoji(emoji: "👑")
            }
            tableView.deselectRow(at: indexPath, animated: true)
        case .follow:
            if indexPath.row == 0 {
                if let url = URL(string: "https://mastodon.social/@ripppleapp"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                if let url = URL(string: "https://bsky.app/profile/rippple.app"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 2 {
                if let url = URL(string: "https://discord.gg/wZZqhMWSVS"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .love:
            if indexPath.row == 0 {
                if let url = URL(string: "macappstore://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: "itms-apps://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                } else if let url = URL(string: "https://apps.apple.com/app/id6758765611?action=write-review"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            } else {
                if let url = URL(string: "https://ko-fi.com/kcador/tip"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
            }
            tableView.deselectRow(at: indexPath, animated: true)
        case .about:
            if indexPath.row == 0 {
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true

                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/blob/main/PRIVACY.md")!,
                                               configuration: config),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true

                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/blob/main/TERMS.md")!,
                                              configuration: config),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 2 {
                if let url = URL(string: "https://github.com/trakt/trakt-rippple"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .knowledge:
            if indexPath.row == 0 {
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true
                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/blob/main/docs/RIPPPLE_101.md")!,
                                               configuration: config),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                present(SFSafariViewController(url: URL(string: "https://headwayapp.co/rippple-updates")!),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 2 {
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true
                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/blob/main/docs/GET_HELP.md")!,
                                               configuration: config),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .touch:
            if indexPath.row == 0 {
                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/issues/new/choose")!),
                animated: true,
                completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/issues/new/choose")!),
                animated: true,
                completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 2 {
                let config = SFSafariViewController.Configuration()
                config.entersReaderIfAvailable = true
                present(SFSafariViewController(url: URL(string: "https://github.com/trakt/trakt-rippple/blob/main/docs/GET_HELP.md")!,
                                               configuration: config),
                        animated: true,
                        completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .data:
            if indexPath.row == 0 {
                present(SFSafariViewController(url: URL(string: "https://trakt.tv")!),
                animated: true,
                completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            } else if indexPath.row == 1 {
                present(SFSafariViewController(url: URL(string: "https://www.themoviedb.org")!),
                animated: true,
                completion: nil)
                tableView.deselectRow(at: indexPath, animated: true)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        if case .premium = AboutSection(rawValue: indexPath.section) {
            cell.contentConfiguration = UIHostingConfiguration {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading) {
                            if UserManager.shared.isCurrentVIP {
                                Text("Sweet, you're VIP!")
                                    .font(.title3.bold())
                                Spacer(minLength: 4)
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                    Text("Trakt VIP")
                                }
                            } else if PurchaseManager.shared.purchased {
                                Text("VIP pending...")
                                    .font(.title3.bold())
                                Spacer(minLength: 4)
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .foregroundStyle(.secondary)
                                    Text("Trakt VIP")
                                }
                            } else {
                                Text("Unlock more with Trakt VIP!")
                                    .font(.title3.bold())
                                Spacer(minLength: 4)
                                HStack(spacing: 4) {
                                    Image(systemName: "xmark.circle").foregroundStyle(.secondary)
                                    Text("Trakt VIP")
                                }
                            }

                            if PurchaseManager.shared.isSandboxed {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.tint)
                                    Text("Beta Tester")
                                }
                                Text("You can test in-app purchases in sandbox mode but it won't give you Trakt VIP because you are not charged as a Beta Tester.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if PurchaseManager.shared.isSandboxed {
                            Text("🧪").font(.largeTitle)
                        } else if PurchaseManager.shared.purchased {
                            Text("👑").font(.largeTitle)
                        } else {
                            Text("").font(.title)
                        }
                    }

                    if UserManager.shared.isCurrentVIP == false {
                        if PurchaseManager.shared.traktVIPIAP {
                            Button("Refresh Trakt VIP Status") {
                                UserManager.shared.reloadSettings(transmitRefreshed: true)
                            }.bold()
                        } else {
                            Button("Upgrade to VIP →") { [weak self] in
                                guard let self = self else { return }
                                self.performSegue(withIdentifier: "subscribe", sender: nil)
                            }.bold()
                        }
                    } else {
                        if PurchaseManager.shared.traktVIPIAP {
                            Button("Manage your Subscription") { [weak self] in
                                guard let self = self else { return }
#if targetEnvironment(macCatalyst)
                                self.appStoreManageSubscription()
#else
                                Task { [weak self] in
                                    guard let self = self else { return }
                                    await self.manageSubscriptions()
                                }
#endif
                            }.bold()
                        } else {
                            Button("Manage Trakt VIP →") {
                                if let url = URL(string: "https://trakt.tv/vip"), UIApplication.shared.canOpenURL(url) {
                                    UIApplication.shared.open(url)
                                }
                            }.bold()
                        }
                    }
                }.buttonStyle(.borderless)
#if targetEnvironment(macCatalyst)
                    .padding(8)
#endif
            }
            cell.accessoryType = .none
        }
        return cell
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if case .premium = AboutSection(rawValue: indexPath.section) {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
        if case .account = AboutSection(rawValue: indexPath.section) {
            if indexPath.row == 2 {
                return super.tableView(tableView, heightForRowAt: indexPath)
            }
        }
        return 44.0
    }
    #endif

    @MainActor
    func manageSubscriptions() async {
        if let windowScene = UIApplication.shared.connectedScenes.first {
            do {
                try await AppStore.showManageSubscriptions(in: windowScene as! UIWindowScene)
            } catch {
                appStoreManageSubscription()
            }
        } else {
            appStoreManageSubscription()
        }
    }

    private func appStoreManageSubscription() {
        if let url = URL(string: "macappstore://apps.apple.com/account/subscriptions"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else if let url = URL(string: "https://apps.apple.com/account/subscriptions"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

extension AboutViewController: SKStoreProductViewControllerDelegate {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
        dismiss(animated: true, completion: nil)
    }
}

extension AboutViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        dismiss(animated: true, completion: nil)
    }
}
