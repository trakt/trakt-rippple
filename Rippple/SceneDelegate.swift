//
//  SceneDelegate.swift
//  Rippple
//
//  Created by Kevin Cador on 06/05/2020.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    enum WindowMode: String {
        case main = "Default Configuration"
        case profile = "Profile Configuration"
        case media = "Media Configuration"

        init(configurationName: String?) {
            self = WindowMode(rawValue: configurationName ?? "") ?? .main
        }

        var activityType: String? {
            switch self {
            case .main: return nil
            case .profile: return "tv.trakt.rippple.profile-window"
            case .media: return "tv.trakt.rippple.media-window"
            }
        }
    }

    static let mediaUserInfoKey = "media"

    private(set) var standaloneMedia: MediaModel?

    private var inactiveTimestamp = Date()

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        guard let windowScene = (scene as? UIWindowScene) else { return }

        switch WindowMode(configurationName: session.configuration.name) {
        case .main:
            break
        case .profile:
            scene.title = "Your Profile"
        case .media:
            if let activity = connectionOptions.userActivities.first(where: { $0.activityType == WindowMode.media.activityType }),
               let data = activity.userInfo?[SceneDelegate.mediaUserInfoKey] as? Data,
               let media = try? JSONDecoder().decode(MediaModel.self, from: data) {
                standaloneMedia = media
                do {
                    let url = SceneDelegate.mediaWindowURL(for: session)
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                } catch {
                    print("Unable to save media window: \(error.localizedDescription)")
                }
            } else if let data = try? Data(contentsOf: SceneDelegate.mediaWindowURL(for: session)) {
                standaloneMedia = try? JSONDecoder().decode(MediaModel.self, from: data)
            }
            scene.title = standaloneMedia?.mediaTitle ?? "Media"
        }

        #if targetEnvironment(macCatalyst)
        if let titlebar = windowScene.titlebar {
            titlebar.titleVisibility = .visible
        }
        windowScene.sizeRestrictions?.minimumSize = CGSize(width: 480, height: 550)
        #endif

        handleURLContexts(URLContexts: connectionOptions.urlContexts)

        #if !targetEnvironment(macCatalyst)
        if let shortcutItem = connectionOptions.shortcutItem {
            ShortcutManager.shared.shouldHandle(shortcut: shortcutItem)
        }
        #endif

        for window in windowScene.windows {
            window.tintColor = UIColor(asset: .globalTint)
        }

        if let userActivity = connectionOptions.userActivities.first {
            handleUserActivity(userActivity)
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handleUserActivity(userActivity)
    }

    static func discardMediaWindow(for session: UISceneSession) {
        guard WindowMode(configurationName: session.configuration.name) == .media else { return }
        try? FileManager.default.removeItem(at: SceneDelegate.mediaWindowURL(for: session))
    }

    private static func mediaWindowURL(for session: UISceneSession) -> URL {
        return URL.applicationSupportDirectory
            .appending(path: "media-windows", directoryHint: .isDirectory)
            .appending(path: session.persistentIdentifier)
            .appendingPathExtension("json")
    }

    static func openWindow(_ mode: WindowMode, title: String, userInfo: [String: Any]? = nil, from window: UIWindow?) {
        guard UIApplication.shared.supportsMultipleScenes, let activityType = mode.activityType else { return }
        let activity = NSUserActivity(activityType: activityType)
        activity.title = title
        activity.userInfo = userInfo
        let options = UIScene.ActivationRequestOptions()
        options.requestingScene = window?.windowScene
        UIApplication.shared.activateSceneSession(for: UISceneSessionActivationRequest(userActivity: activity, options: options)) { [weak window] error in
            DispatchQueue.main.async { [weak window] in
                guard let window = window else { return }
                let alert = UIAlertController(title: "Unable to Open Window", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                var presenter = window.rootViewController
                while let presented = presenter?.presentedViewController {
                    presenter = presented
                }
                presenter?.present(alert, animated: true)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        SessionManager.shared.wakeUp { _ in
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        if SessionManager.shared.isLoggedIn,
           DeeplinkManager.shared.shouldOpenDeeplink() {
            UIApplication.shared.switchToDeeplink()
        }

        let timeSinceInactive = Date().timeIntervalSince(inactiveTimestamp)
        print("Time since the app is inactive: \(timeSinceInactive)")
        applicationLifecycleTransmitter.broadcast(.didBecomeActive(timeSinceInactive))
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        inactiveTimestamp = Date()

        let appIconShortcutItem = ShortcutManager.shared.appIconShortcutItem
        let searchAndKeyboard = ShortcutManager.shared.searchAndKeyboardShortcutItem

        UIApplication.shared.shortcutItems = [searchAndKeyboard, appIconShortcutItem]
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        AppManager.shared.scheduleNewBackgroundRefresh()

        applicationLifecycleTransmitter.broadcast(.didEnterBackground)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        handleURLContexts(URLContexts: URLContexts)
    }

    private func handleURLContexts(URLContexts: Set<UIOpenURLContext>) {
        for URLContext in URLContexts {
            // we take the first deeplink that looks like a deeplink or continue
            print("register in SceneDelegate")
            handleDeeplink(URLContext.url)
        }
    }

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        let incomingURL: URL?
        switch userActivity.activityType {
        case NSUserActivityTypeBrowsingWeb:
            incomingURL = userActivity.webpageURL
        case viewingMediaUserActivityType:
            incomingURL = (userActivity.userInfo?[viewingMediaUserActivityURLKey] as? String).flatMap(URL.init(string:))
                ?? userActivity.targetContentIdentifier.flatMap(URL.init(string:))
        default:
            return
        }

        guard let incomingURL = incomingURL else { return }
        handleDeeplink(incomingURL)
    }

    private func handleDeeplink(_ url: URL) {
        if DeeplinkManager.shared.registerDeeplink(url: url),
           SessionManager.shared.isLoggedIn,
           DeeplinkManager.shared.shouldOpenDeeplink() {
            UIApplication.shared.switchToDeeplink()
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        ShortcutManager.shared.shouldHandle(shortcut: shortcutItem)
    }
}
