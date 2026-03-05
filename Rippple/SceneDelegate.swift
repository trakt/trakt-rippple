//
//  SceneDelegate.swift
//  Rippple
//
//  Created by Kevin Cador on 06/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    private var inactiveTimestamp = Date()

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        guard let windowScene = (scene as? UIWindowScene) else { return }

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

        // Get URL components from the incoming user activity.
        guard let userActivity = connectionOptions.userActivities.first,
            userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return
        }

        if DeeplinkManager.shared.registerDeeplink(url: incomingURL) {
            if SessionManager.shared.isLoggedIn,
                DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
            }
        }
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Get URL components from the incoming user activity.
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let incomingURL = userActivity.webpageURL else {
            return
        }

        if DeeplinkManager.shared.registerDeeplink(url: incomingURL) {
            if SessionManager.shared.isLoggedIn,
                DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
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
            if DeeplinkManager.shared.registerDeeplink(url: URLContext.url) {
                if SessionManager.shared.isLoggedIn,
                    DeeplinkManager.shared.shouldOpenDeeplink() {
                    UIApplication.shared.switchToDeeplink()
                }
            }
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        ShortcutManager.shared.shouldHandle(shortcut: shortcutItem)
    }
}
