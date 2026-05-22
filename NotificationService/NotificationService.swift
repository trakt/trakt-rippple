//
//  NotificationService.swift
//  NotificationService
//
//  Created by Kevin Cador on 28/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        guard let bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent else {
            return
        }

        do {
            if let link = bestAttemptContent.userInfo["image"] as? String,
               let url = URL(string: link),
               let data = NSData(contentsOf: url) as? Data,
               let image = UIImage(data: data),
               let pngData = image.pngData() {
                let localURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("png")

                try pngData.write(to: localURL)

                let attachment = try UNNotificationAttachment(identifier: "image", url: localURL, options: [:])
                bestAttemptContent.attachments = [attachment]
            }
        } catch {
            print(error)
        }

        guard let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")?.object(forKey: "NotificationCenterManager.notifications") as? Data else {
            contentHandler(bestAttemptContent)
            return
        }

        guard var notifications = try? JSONDecoder().decode([RipppleNotification].self, from: encodedData) else {
            contentHandler(bestAttemptContent)
            return
        }

        let newNotification = RipppleNotification(identifier: request.identifier,
                                                  title: bestAttemptContent.title,
                                                  subtitle: bestAttemptContent.subtitle,
                                                  body: bestAttemptContent.body,
                                                  date: Date.now,
                                                  link: (bestAttemptContent.userInfo["link"] as? String) ?? nil,
                                                  versionToCheck: (bestAttemptContent.userInfo["version-check"] as? Int) ?? nil)

        if notifications.contains(newNotification) {
            notifications.removeAll { $0.identifier == newNotification.identifier }
            notifications.append(newNotification)
        } else {
            notifications.append(newNotification)
        }

        if let encoded = try? JSONEncoder().encode(notifications) {
            UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")?.set(encoded, forKey: "NotificationCenterManager.notifications")
            UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")?.set(true, forKey: "NotificationCenterManager.notificationsReceived")
            UserDefaults(suiteName: "group.tv.trakt.rippple.notificationservice")?.synchronize()
        }

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        guard let bestAttemptContent = bestAttemptContent, let contentHandler = contentHandler else {
            return
        }
        contentHandler(bestAttemptContent)
    }
}
