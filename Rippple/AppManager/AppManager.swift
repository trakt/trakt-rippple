//
//  AppManager.swift
//  Rippple
//
//  Created by Kevin Cador on 19/02/2018.
//  Copyright © Trakt. All rights reserved.
//

import AuthenticationServices
import BackgroundTasks
import Foundation
import SafariServices
import Toast
import UIKit
#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif

import StoreKit
import WidgetKit

final class AppManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return mainWindow!
    }

    static let shared = AppManager()
    func setup() {
        // Means setup has already been done!
        if mainWindow != nil { return }

        // This should only happen if something starts the AppManager too soon
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let window = sceneDelegate.window else { return }

        mainWindow = window

        currentUserInterfaceStyle = UIUserInterfaceStyle(rawValue: UserDefaults.standard.integer(forKey: "AppManager.currentUserInterfaceStyle"))
        if let currentUserInterfaceStyle = currentUserInterfaceStyle {
            for windowScene in UIApplication.shared.connectedScenes {
                if let sceneDelegate = windowScene.delegate as? SceneDelegate,
                   let window = sceneDelegate.window {
                    DispatchQueue.main.async {
                        #if targetEnvironment(macCatalyst)
                        window.overrideUserInterfaceStyle = .unspecified
                        #else
                        window.overrideUserInterfaceStyle = currentUserInterfaceStyle
                        #endif
                    }
                }
            }
        }

        currentTint = RipppleTintColor(rawValue: UserDefaults(suiteName: "group.tv.trakt.rippple")!.integer(forKey: "AppManager.currentTint"))
        isTintedAppearanceEnabled = UserDefaults.standard.bool(forKey: "AppManager.tintedAppearance")
        for windowScene in UIApplication.shared.connectedScenes {
            guard let windowScene = windowScene as? UIWindowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate,
                  let window = sceneDelegate.window else { continue }
            windowScene.traitOverrides.ripppleTintColor = currentTint ?? .original
            windowScene.traitOverrides.ripppleTintedAppearance = isTintedAppearanceEnabled
            window.backgroundColor = .ripppleViewBackground
            window.tintColor = (currentTint ?? .original).color
        }

        confettiWindow?.windowLevel = .statusBar + 1000
        confettiWindow?.backgroundColor = .clear
//        confettiWindow?.isHidden = false
//        confettiWindow?.isUserInteractionEnabled = false

        _ = NotificationCenter.default.addObserver(forName: UIWindow.didBecomeVisibleNotification,
                                                   object: nil,
                                                   queue: nil) { [weak self] notification in
            guard let self = self else { return }
            guard let window = notification.object as? UIWindow,
                  let sceneDelegate = window.windowScene?.delegate as? SceneDelegate,
                  window === sceneDelegate.window else { return }
            window.overrideUserInterfaceStyle = self.currentUserInterfaceStyle ?? .unspecified
            window.traitOverrides.ripppleTintColor = self.currentTint ?? .original
            window.traitOverrides.ripppleTintedAppearance = self.isTintedAppearanceEnabled
            window.backgroundColor = .ripppleViewBackground
            window.tintColor = (self.currentTint ?? .original).color
        }
    }

    fileprivate var mainWindow: UIWindow?

    fileprivate var confettiWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows
            .first ?? mainWindow
    }

    fileprivate var currentUserInterfaceStyle: UIUserInterfaceStyle? {
        didSet {
            if let currentUserInterfaceStyle = currentUserInterfaceStyle {
                UserDefaults.standard.set(currentUserInterfaceStyle.rawValue, forKey: "AppManager.currentUserInterfaceStyle")
                UserDefaults.standard.synchronize()
            }
        }
    }

    fileprivate var currentTint: RipppleTintColor? {
        didSet {
            if let currentTint = currentTint {
                UserDefaults(suiteName: "group.tv.trakt.rippple")!.set(currentTint.rawValue, forKey: "AppManager.currentTint")
                UserDefaults.standard.synchronize()
            }
        }
    }

    fileprivate var isTintedAppearanceEnabled = false {
        didSet {
            UserDefaults.standard.set(isTintedAppearanceEnabled, forKey: "AppManager.tintedAppearance")
            UserDefaults.standard.synchronize()
        }
    }

    var isUserInteractionEnabled: Bool = true {
        didSet {
            setup()
            mainWindow?.isUserInteractionEnabled = isUserInteractionEnabled
        }
    }

    var scale: CGFloat {
        return mainWindow?.screen.scale ?? 2.0
    }

    var isUserInteractionEnabledWithLayer: Bool = true {
        didSet {
            isUserInteractionEnabled = isUserInteractionEnabledWithLayer

            if !isUserInteractionEnabledWithLayer {
                let window = AppManager.shared.confettiWindow ?? AppManager.shared.mainWindow
                var containerView = UIView()
                if let window = window {
                    if let v = window.viewWithTag(6481548447) {
                        containerView = v
                    } else {
                        containerView = PassThroughView(frame: window.bounds)
                        containerView.tag = 6481548447
                        containerView.backgroundColor = .clear
                        containerView.isUserInteractionEnabled = true
                        containerView.layer.zPosition = 1000
                        containerView.translatesAutoresizingMaskIntoConstraints = false
                        window.addSubview(containerView)
                        NSLayoutConstraint.activate([
                            containerView.topAnchor.constraint(equalTo: window.topAnchor),
                            containerView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                            containerView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                            containerView.trailingAnchor.constraint(equalTo: window.trailingAnchor)
                        ])
                    }
                } else {
                    return // no window is a bad sign, abort
                }
                containerView.backgroundColor = .black.withAlphaComponent(0.7)
            } else {
                let window = AppManager.shared.confettiWindow ?? AppManager.shared.mainWindow
                if let window = window {
                    if let v = window.viewWithTag(6481548447) {
                        v.backgroundColor = .clear
                    }
                }
            }
        }
    }

    override private init() {
        super.init()
    }

    func present(viewController: UIViewController, animated: Bool) {
        DispatchQueue.main.async {
            self.setup()
            guard let rootViewController = AppManager.shared.mainWindow?.rootViewController else { return }
            var presentingViewController = rootViewController
            while presentingViewController.presentedViewController != nil {
                presentingViewController = presentingViewController.presentedViewController!
            }
            presentingViewController.present(viewController, animated: animated)
        }
    }

    func scheduleNewBackgroundRefresh() {
        do {
            // default earliestBeginDate = 1h
            var earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

            #if !targetEnvironment(macCatalyst)
            for activity in Activity<RipppleLiveActivityAttributes>.activities {
                if let endDate = activity.content.state.entry.endDate, endDate >= .now {
                    // take the first enddate (should be less than the default anyway
                    if endDate < earliestBeginDate {
                        earliestBeginDate = endDate
                    }
                }
            }
            #endif

            BGTaskScheduler.shared.cancelAllTaskRequests()

            let request = BGAppRefreshTaskRequest(identifier: "tv.trakt.towatch.refresh")
            request.earliestBeginDate = earliestBeginDate
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule app refresh: \(error)")
        }
    }

    func emitConfetti() {
        DispatchQueue.main.async {
            let confettiView = ConfettiView()
            self.confettiWindow?.addSubview(confettiView)
            confettiView.emit(with: [
                .shape(.square, #colorLiteral(red: 1, green: 0.5333333333, blue: 0.2235294118, alpha: 1)),
                .shape(.triangle, #colorLiteral(red: 0.2274509804, green: 0.7254901961, blue: 1, alpha: 1)),
                .shape(.circle, #colorLiteral(red: 0.1490196078, green: 0.8588235294, blue: 0.5568627451, alpha: 1)),
                .shape(.square, #colorLiteral(red: 0.9490196078, green: 0.2588235294, blue: 0.2588235294, alpha: 1)),
                .shape(.triangle, #colorLiteral(red: 1, green: 0.8235294118, blue: 0.2235294118, alpha: 1))
            ])
            Timer.scheduledTimer(withTimeInterval: 2.0,
                                 repeats: false) { _ in
                UIView.animate(withDuration: 0.5,
                               animations: {
                                   confettiView.alpha = 0
                               },
                               completion: { _ in
                                   confettiView.removeFromSuperview()
                               })
            }
        }
    }

    func emitEmoji(emoji: String) {
        DispatchQueue.main.async {
            let confettiView = ConfettiView()
            self.confettiWindow?.addSubview(confettiView)
            confettiView.emit(with: [.text(emoji), .text(emoji)])
            Timer.scheduledTimer(withTimeInterval: 2.0,
                                 repeats: false) { _ in
                UIView.animate(withDuration: 0.5,
                               animations: {
                                   confettiView.alpha = 0
                               },
                               completion: { _ in
                                   confettiView.removeFromSuperview()
                               })
            }
        }
    }

    var mainAppIsDisplayed: Bool {
        setup()
        return mainWindow?.rootViewController?.isKind(of: UISplitViewController.self) ?? false
    }

    func checkRating() {
        let minute: TimeInterval = 60.0
        let hour: TimeInterval = 60.0 * minute
        let day: TimeInterval = 24 * hour
        let month: TimeInterval = 30 * day
        let twoMonths: TimeInterval = 2 * month
        let sixMonths: TimeInterval = 6 * month
        let year: TimeInterval = 12 * month

        defer {
            UserDefaults.standard.synchronize()
        }

        // check the date, start with a 2 month ask, then 6, then every year
        let dateFirstChecked = UserDefaults.standard.object(forKey: "SKStoreReviewController.checkRating.dateFirstChecked") as? Date
        guard let dateFirstChecked else {
            print("⭐️ Checking if app needs to ask for rating for the first time...")
            UserDefaults.standard.set(Date.now, forKey: "SKStoreReviewController.checkRating.dateFirstChecked")
            UserDefaults.standard.set(twoMonths, forKey: "SKStoreReviewController.checkRating.nextCheckTimeInterval")
            return
        }
        let nextCheckTimeInterval = TimeInterval(UserDefaults.standard.integer(forKey: "SKStoreReviewController.checkRating.nextCheckTimeInterval"))
        if nextCheckTimeInterval == 0 { // just a failsafe
            UserDefaults.standard.set(twoMonths, forKey: "SKStoreReviewController.checkRating.nextCheckTimeInterval")
            return
        }
        if Date.now >= dateFirstChecked.addingTimeInterval(nextCheckTimeInterval) {
            print("⭐️ App asked for rating because \(Date.now) is >= to \(dateFirstChecked.addingTimeInterval(nextCheckTimeInterval))!")
            guard let windowScene = mainWindow?.windowScene else { return }
            AppStore.requestReview(in: windowScene)
            // reset the reference date
            UserDefaults.standard.set(Date.now, forKey: "SKStoreReviewController.checkRating.dateFirstChecked")
            // update the time interval to check
            if nextCheckTimeInterval == twoMonths {
                UserDefaults.standard.set(sixMonths, forKey: "SKStoreReviewController.checkRating.nextCheckTimeInterval")
            } else if nextCheckTimeInterval >= sixMonths {
                UserDefaults.standard.set(year, forKey: "SKStoreReviewController.checkRating.nextCheckTimeInterval")
            }
        } else {
            print("⭐️ App is not asking for rating because the conditions are not met!")
        }
    }

    func presentOfferCodeRedeemSheet() async {
        guard let windowScene = mainWindow?.windowScene else { return }
        try? await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
    }
}

public extension UIApplication {
    internal var currentUserInterfaceStyle: UIUserInterfaceStyle {
        AppManager.shared.setup()
        return AppManager.shared.mainWindow?.overrideUserInterfaceStyle ?? .unspecified
    }

    internal var currentTint: RipppleTintColor {
        return AppManager.shared.currentTint ?? .original
    }

    internal var isTintedAppearanceEnabled: Bool {
        AppManager.shared.setup()
        return AppManager.shared.isTintedAppearanceEnabled
    }

    func setTintColor(tint: RipppleTintColor) {
        AppManager.shared.currentTint = tint
        for windowScene in UIApplication.shared.connectedScenes {
            guard let windowScene = windowScene as? UIWindowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate,
                  let window = sceneDelegate.window else { continue }
            windowScene.traitOverrides.ripppleTintColor = tint
            window.traitOverrides.ripppleTintColor = tint
            window.tintColor = tint.color
        }
    }

    func setTintedAppearance(enabled: Bool) {
        AppManager.shared.isTintedAppearanceEnabled = enabled
        for windowScene in UIApplication.shared.connectedScenes {
            guard let windowScene = windowScene as? UIWindowScene,
                  let sceneDelegate = windowScene.delegate as? SceneDelegate,
                  let window = sceneDelegate.window else { continue }
            windowScene.traitOverrides.ripppleTintedAppearance = enabled
            window.traitOverrides.ripppleTintedAppearance = enabled
        }
        WidgetCenter.shared.reloadTimelines(ofKind: ToWatchWidgetStorage.kind)
        WidgetCenter.shared.reloadTimelines(ofKind: ActivityPunchcardWidgetStorage.kind)
    }

    func setDarkMode() {
        for windowScene in UIApplication.shared.connectedScenes {
            if let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.overrideUserInterfaceStyle = .dark
            }
        }
        AppManager.shared.currentUserInterfaceStyle = .dark
    }

    func setLightMode() {
        for windowScene in UIApplication.shared.connectedScenes {
            if let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.overrideUserInterfaceStyle = .light
            }
        }
        AppManager.shared.currentUserInterfaceStyle = .light
    }

    func setSystemMode() {
        for windowScene in UIApplication.shared.connectedScenes {
            if let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window {
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
        AppManager.shared.currentUserInterfaceStyle = .unspecified
    }

    func switchToMainApp() {
        if AppManager.shared.mainAppIsDisplayed == true {
            // we already are on the Main app
            return
        }

        let compactViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()!

        let splitViewController = SplitViewController(style: .doubleColumn)
        splitViewController.primaryBackgroundStyle = .sidebar
        splitViewController.minimumPrimaryColumnWidth = 200
        splitViewController.maximumPrimaryColumnWidth = 500

        #if targetEnvironment(macCatalyst)
        let lastWidth = UserDefaults.standard.float(forKey: "SplitViewController.preferredPrimaryColumnWidth")
        let initialWidth = lastWidth > 0 ? CGFloat(lastWidth) : 300
        splitViewController.preferredPrimaryColumnWidth = initialWidth

        #endif

        let primary = SidebarViewController()
        splitViewController.setViewController(primary, for: .primary)
        let browseViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateInitialViewController()!
        splitViewController.setViewController(browseViewController, for: .secondary)
        splitViewController.setViewController(compactViewController, for: .compact)

        let transitionOptions = TransitionOptions(direction: .fade, style: .easeInOut)
        AppManager.shared.setup()
        AppManager.shared.mainWindow?.setRootViewController(splitViewController, options: transitionOptions)

        if DeeplinkManager.shared.shouldOpenDeeplink() {
            switchToDeeplink()
        }
    }

    func switchToLogin() {
        SessionManager.shared.logout()
        UserManager.shared.logout()

        let login = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()!
        let transitionOptions = TransitionOptions(direction: .fade, style: .easeInOut)
        AppManager.shared.setup()
        AppManager.shared.mainWindow?.setRootViewController(login, options: transitionOptions)
    }

    func switchToLogin401() {
        SessionManager.shared.logout()
        UserManager.shared.logout()

        let login = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()!
        let transitionOptions = TransitionOptions(direction: .fade, style: .easeInOut)
        AppManager.shared.setup()
        AppManager.shared.mainWindow?.setRootViewController(login, options: transitionOptions)

        let alertController = UIAlertController(title: "Logged Out",
                                                message: "You have been automatically logged out of Trakt. You must sign in to Trakt again.\nRebooting your device may help if the problem persists.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Okay", style: .default, handler: { _ in
            onNeedsToShowLoginTransmitter.broadcast(true)
        }))

        login.present(alertController, animated: true)
    }

    func switchToLogin423() {
        SessionManager.shared.logout()
        UserManager.shared.logout()

        let login = UIStoryboard(name: "Login", bundle: nil).instantiateInitialViewController()!
        let transitionOptions = TransitionOptions(direction: .fade, style: .easeInOut)
        AppManager.shared.setup()
        AppManager.shared.mainWindow?.setRootViewController(login, options: transitionOptions)

        let alertController = UIAlertController(title: "Locked User Account",
                                                message: "Please contact Trakt support (forums.trakt.tv) so they can unlock your account.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Okay", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Trakt Support", style: .default, handler: { _ in
            UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://forums.trakt.tv")!))
        }))

        login.present(alertController, animated: true)
    }

    func vipOnly() {
        let alertController = UIAlertController(title: "Trakt VIP Only",
                                                message: "This feature is only available to Trakt VIP users.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Okay", style: .cancel))

        alertController.addAction(UIAlertAction(title: "Get Trakt VIP", style: .default, handler: { _ in
            if let url = URL(string: "https://app.trakt.tv/vip"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))

        AppManager.shared.setup()
        present(alertController)
    }

    func accountLimitExceeded() {
        let alertController = UIAlertController(title: "Trakt Limit Reached",
                                                message: "You have reach a limit imposed by Trakt. Upgrading to Track VIP may help. If you are VIP, you've just hit a hard limit.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Okay", style: .cancel))

        alertController.addAction(UIAlertAction(title: "Get Trakt VIP", style: .default, handler: { _ in
            if let url = URL(string: "https://app.trakt.tv/vip"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))

        AppManager.shared.setup()
        present(alertController)
    }

    func comeBackToMainApp() {
        AppManager.shared.setup()
        AppManager.shared.mainWindow?.rootViewController?.dismiss(animated: true, completion: nil)
    }

    func isModalDisplayed() -> Bool {
        guard let mainWindow = AppManager.shared.mainWindow else { return false }
        var presentingViewController = mainWindow.rootViewController
        while let presentedViewController = presentingViewController?.presentedViewController {
            presentingViewController = presentedViewController
        }
        return presentingViewController != mainWindow.rootViewController
    }

    func present(_ viewControllerToPresent: UIViewController) {
        guard var presentingViewController = AppManager.shared.mainWindow?.rootViewController else { return }
        while let presentedViewController = presentingViewController.presentedViewController {
            presentingViewController = presentedViewController
        }
        viewControllerToPresent.popoverPresentationController?.sourceView = presentingViewController.view
        viewControllerToPresent.popoverPresentationController?.permittedArrowDirections = []
        #if targetEnvironment(macCatalyst)
        viewControllerToPresent.popoverPresentationController?.sourceRect = CGRect(x: presentingViewController.view.bounds.midX - 100, y: presentingViewController.view.bounds.midY - 100, width: 1, height: 1)
        #endif
        presentingViewController.present(viewControllerToPresent, animated: true)
    }

    internal func openStats(mode: TraktStatsViewController.StatsMode) {
        if UserManager.shared.isCurrentVIP {
            let embed = TraktStatsViewController()
            embed.mode = mode
            let navigationController = StyledNavigationController(rootViewController: embed)
            navigationController.view.tintColor = UIColor.systemPurple
            present(navigationController)
        } else {
            vipOnly()
        }
    }

    func checkVersionNow(version: Int) {
        guard let buildNumber = Int(Bundle.main.buildVersionNumber ?? "") else { return }
        if version > buildNumber {
            if let url = URL(string: "https://apps.apple.com/app/id6758765611"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        } else {
            // do nothing
        }
    }

    func switchToDeeplink() {
        let main = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "deeplink")
        present(main)
    }

    func switchToPurchase() {
        if UserManager.shared.currentUser == nil {
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }
        let main = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "subscribe modal")
        present(main)
    }

    func switchToCurrentlyWatching(zoomSourceView: UIView?) {
        guard let watchingItem = WatchingManager.shared.watchingItem else { return }

        guard let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "watching") as? UINavigationController else { return }
        guard let mediaViewController = navigationController.viewControllers.first as? MediaViewController else { return }

        navigationController.modalPresentationStyle = .formSheet

        mediaViewController.isDeeplink = true
        mediaViewController.media = MediaModel(item: watchingItem)

        if let zoomSourceView = zoomSourceView {
            navigationController.preferredTransition = .zoom(sourceViewProvider: { _ in
                zoomSourceView
            })
        }

        present(navigationController)
    }
}

enum SwiftMessages {
    private static var toasts = [(Toast, Style)]()

    enum Style {
        case content
        case error(Error)
        case standout
        case loading
        case retry(Int)
    }

    static func show(message: String, style: Style? = .content) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async {
                show(message: message, style: style)
            }
            return
        }

        if UserManager.shared.currentUser == nil {
            return
        }

        let window = AppManager.shared.confettiWindow ?? AppManager.shared.mainWindow
        var containerView = UIView()
        if let window = window {
            if let v = window.viewWithTag(6481548447) {
                containerView = v
            } else {
                containerView = PassThroughView(frame: window.bounds)
                containerView.tag = 6481548447
                containerView.backgroundColor = .clear
                containerView.isUserInteractionEnabled = true
                containerView.layer.zPosition = 1000
                containerView.translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(containerView)
                NSLayoutConstraint.activate([
                    containerView.topAnchor.constraint(equalTo: window.topAnchor),
                    containerView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                    containerView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    containerView.trailingAnchor.constraint(equalTo: window.trailingAnchor)
                ])
            }
        } else {
            return // no window is a bad sign, abort
        }
        for toast in toasts {
            // if there's already a retry toast and this is currently a retry toast we are asking to display, we return
            if case .retry = toast.1, toast.0.view.superview != nil { return }
            toast.0.close()
        }
        toasts.removeAll()
        switch style! {
        case .content:
            let view = Bundle.main.loadNibNamed("RipppleMessage", owner: nil, options: nil)?.first as! RipppleBannerMessage

            view.pillView.backgroundColor = .darkGray
            view.message.textColor = .white
            view.message.text = message

            view.subtext.textColor = .white
            view.subtext.isHidden = true

            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()

            let appleToastView = AppleToastView(child: view, config: .init(darkBackgroundColor: .clear, lightBackgroundColor: .clear))
            let config = ToastConfiguration(
                dismissBy: [.time(time: TimeInterval(3))],
                animationTime: 0.2,
                attachTo: containerView
            )
            let toast = Toast.custom(view: appleToastView, config: config)

            toast.show(haptic: .success)

            toasts.append((toast, style!))
        case .error(let error):
            let view = Bundle.main.loadNibNamed("RipppleMessage", owner: nil, options: nil)?.first as! RipppleBannerMessage

            view.pillView.backgroundColor = .systemRed
            view.message.textColor = .white
            view.message.text = message

            view.subtext.textColor = .white
            view.subtext.text = error.localizedDescription
            view.subtext.isHidden = false

            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()

            let appleToastView = AppleToastView(child: view, config: .init(darkBackgroundColor: .clear, lightBackgroundColor: .clear))
            let config = ToastConfiguration(
                dismissBy: [.time(time: TimeInterval(5))],
                animationTime: 0.2,
                attachTo: containerView
            )
            let toast = Toast.custom(view: appleToastView, config: config)

            toast.show(haptic: .error)

            toasts.append((toast, style!))
        case .standout:
            let view = Bundle.main.loadNibNamed("RipppleMessage", owner: nil, options: nil)?.first as! RipppleBannerMessage

            view.pillView.backgroundColor = .systemRed
            view.message.textColor = .white
            view.message.text = message

            view.subtext.textColor = .white
            view.subtext.isHidden = true

            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()

            let appleToastView = AppleToastView(child: view, config: .init(darkBackgroundColor: .clear, lightBackgroundColor: .clear))
            let config = ToastConfiguration(
                dismissBy: [.time(time: TimeInterval(5))],
                animationTime: 0.2,
                attachTo: containerView
            )
            let toast = Toast.custom(view: appleToastView, config: config)

            toast.show(haptic: .error)

            toasts.append((toast, style!))
        case .loading:
            let view = Bundle.main.loadNibNamed("RipppleMessage", owner: nil, options: nil)?.first as! RipppleBannerMessage

            view.pillView.backgroundColor = .darkGray
            view.message.textColor = .white.withAlphaComponent(0.75)
            view.message.text = message

            view.subtext.textColor = .white.withAlphaComponent(0.75)
            view.subtext.isHidden = true

            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()

            let appleToastView = AppleToastView(child: view, config: .init(darkBackgroundColor: .clear, lightBackgroundColor: .clear))
            let config = ToastConfiguration(
                dismissBy: [.time(time: TimeInterval(3000))], // should be dismissed by the confirmation or error banner
                animationTime: 0.2,
                attachTo: containerView
            )
            let toast = Toast.custom(view: appleToastView, config: config)

            toast.show(haptic: .warning)

            toasts.append((toast, style!))
        case .retry(let retryAfter):
            let view = Bundle.main.loadNibNamed("RipppleMessage", owner: nil, options: nil)?.first as! RipppleBannerMessage

            view.pillView.backgroundColor = .darkGray
            view.message.textColor = .white.withAlphaComponent(0.75)
            view.message.text = message

            view.subtext.textColor = .white.withAlphaComponent(0.75)
            view.subtext.text = "Waiting for auto-retry..."
            view.subtext.isHidden = false

            view.date = Date.now.addingTimeInterval(TimeInterval(retryAfter))

            view.setNeedsUpdateConstraints()
            view.setNeedsLayout()

            let appleToastView = AppleToastView(child: view, config: .init(darkBackgroundColor: .clear, lightBackgroundColor: .clear))
            let config = ToastConfiguration(
                dismissBy: [.time(time: TimeInterval(retryAfter))],
                animationTime: 0.2,
                attachTo: containerView
            )
            let toast = Toast.custom(view: appleToastView, config: config)

            toast.show(haptic: .warning)

            toasts.append((toast, style!))
        }
    }
}

final class PassThroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in subviews {
            if !subview.isHidden && subview.isUserInteractionEnabled && subview.point(inside: convert(point, to: subview), with: event) {
                return true
            }
        }
        return false
    }
}
