//
//  NotificationCenterManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/04/2023.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit
import UserNotifications

let (onNotificationCenterChangedTransmitter, onNotificationCenterChangedReceiver) = Receiver<[RipppleNotification]>.make(with: .hot)

final class NotificationCenterManager: NSObject {
    static let shared = NotificationCenterManager()

    var notifications: [RipppleNotification]? {
        didSet {
            if notifications == oldValue { return }
            if let encoded = try? JSONEncoder().encode(notifications) {
                UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.set(encoded, forKey: "NotificationCenterManager.notifications")
                UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.set(true, forKey: "NotificationCenterManager.notificationsReceived")
                UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.synchronize()

                onNotificationCenterChangedTransmitter.broadcast(notifications ?? [RipppleNotification]())
            }
        }
    }

    private let disposeBag = DisposeBag()

    func update() {
        getNotifications()
    }

    var newNotificationReceived: Bool {
        if notifications == nil || notifications!.isEmpty { return false }
        return UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.bool(forKey: "NotificationCenterManager.notificationsReceived")
    }

    func notificationsRead() {
        UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.set(false, forKey: "NotificationCenterManager.notificationsReceived")
        UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.synchronize()
        // This is to update the bell with or without dot
        onNotificationCenterChangedTransmitter.broadcast(notifications ?? [RipppleNotification]())
    }

    override init() {
        super.init()

        if let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!.object(forKey: "NotificationCenterManager.notifications") as? Data {
            if let notifications = try? JSONDecoder().decode([RipppleNotification].self, from: encodedData) {
                self.notifications = notifications
            }
        }
    }

    func setup() {
        UNUserNotificationCenter.current().delegate = self
        getNotifications()

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.notifications = []
            let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")!
            defaults.removeObject(forKey: "NotificationCenterManager.notifications")
            defaults.set(false, forKey: "NotificationCenterManager.notificationsReceived")
            defaults.synchronize()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60 * 60 * 4 {
                    self.getNotifications()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)
    }

    func delete(notification: RipppleNotification) {
        notifications = notifications?.filter { $0.identifier != notification.identifier }
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notification.identifier])
    }

    private func getNotifications() {
        UNUserNotificationCenter.current().getDeliveredNotifications { deliveredNotifications in
            self.save(latestNotifications: deliveredNotifications)
        }
    }

    private func save(latestNotifications: [UNNotification]) {
        let newNotifications = latestNotifications.map { RipppleNotification(identifier: $0.request.identifier,
                                                                             title: $0.request.content.title,
                                                                             subtitle: $0.request.content.subtitle,
                                                                             body: $0.request.content.body,
                                                                             date: $0.date,
                                                                             link: ($0.request.content.userInfo["link"] as? String) ?? nil,
                                                                             versionToCheck: ($0.request.content.userInfo["version-check"] as? Int) ?? nil) }
        guard var notifications = notifications else {
            notifications = newNotifications
            return
        }
        for notification in newNotifications.sorted(by: { $0.date > $1.date }) {
            if notifications.contains(notification) {
                notifications.removeAll { $0.identifier == notification.identifier }
                notifications.append(notification)
            } else {
                notifications.append(notification)
            }
        }
        let oneMonthsAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date.now)!
        notifications.removeAll { $0.date < oneMonthsAgo }
        self.notifications = notifications
    }
}

extension NotificationCenterManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        save(latestNotifications: [notification])

        // print("User Info = \(notification.request.content.userInfo)")
        if notification.request.identifier == "TestNotification" {
            testPushTransmitter.broadcast("TestNotification")
        }

        let userInfo = notification.request.content.userInfo
        if let versionToCheck = userInfo["version-check"] as? Int {
            UIApplication.shared.checkVersionNow(version: versionToCheck)
        }

        completionHandler([.list, .banner, .badge, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        save(latestNotifications: [response.notification])

        if response.notification.request.identifier == "TestNotification" {
            testPushTransmitter.broadcast("TestNotification")
        }

        let userInfo = response.notification.request.content.userInfo
        if let link = userInfo["link"] as? String, let url = URL(string: link) {
            DeeplinkManager.shared.registerDeeplink(url: url)
            if SessionManager.shared.isLoggedIn,
               DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
            }
        }
        if let versionToCheck = userInfo["version-check"] as? Int {
            UIApplication.shared.checkVersionNow(version: versionToCheck)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://settings/notifications")!)
        if SessionManager.shared.isLoggedIn,
           DeeplinkManager.shared.shouldOpenDeeplink() {
            UIApplication.shared.switchToDeeplink()
        }
    }
}
