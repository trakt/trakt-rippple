//
//  WidgetIntentNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import UserNotifications

enum WidgetIntentNotificationMetadata {
    static let identifierPrefix = "WidgetIntentAction."

    static func matches(identifier: String) -> Bool {
        identifier.hasPrefix(WidgetIntentNotificationMetadata.identifierPrefix)
    }
}

enum RipppleNotificationUserInfoKey {
    static let isTransient = "is-transient-notification"
}

protocol WidgetIntentNotificationFailureProviding {
    var widgetIntentNotificationFailure: WidgetIntentNotificationsManager.Failure { get }
}

final class WidgetIntentNotificationsManager {
    struct Media {
        let description: String
        let deeplink: URL
    }

    enum Action {
        case checkIn(Media)
        case markWatched(Media)
        case refreshCurrentlyWatching
        case cancelCheckIn(Media?)
    }

    enum Failure {
        case generic
        case checkInAlreadyInProgress
    }

    struct Notification {
        fileprivate let identifier: String
        fileprivate let action: Action
    }

    static let shared = WidgetIntentNotificationsManager()

    private static let widgetReloadDeliveryDelay: TimeInterval = 1.0

    private enum State {
        case loading
        case success
        case failure(Failure)
    }

    private init() {}

    func start(action: Action) -> Notification {
        let notification = Notification(identifier: "\(WidgetIntentNotificationMetadata.identifierPrefix)\(UUID().uuidString)",
                                        action: action)
        update(notification, state: .loading)
        return notification
    }

    func succeed(_ notification: Notification) {
        // Interactive widgets render after the intent returns, so deliver confirmation just after that handoff.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: WidgetIntentNotificationsManager.widgetReloadDeliveryDelay,
                                                        repeats: false)
        update(notification, state: .success, trigger: trigger)
    }

    func fail(_ notification: Notification, error: Error) {
        let failure = (error as? WidgetIntentNotificationFailureProviding)?.widgetIntentNotificationFailure ?? .generic
        update(notification, state: .failure(failure))
    }

    private func update(_ notification: Notification,
                        state: State,
                        trigger: UNNotificationTrigger? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title(for: notification.action, state: state)
        content.body = body(for: notification.action, state: state)
        content.interruptionLevel = .active

        var userInfo: [AnyHashable: Any] = [RipppleNotificationUserInfoKey.isTransient: true]
        if let media = media(for: notification.action) {
            userInfo["link"] = media.deeplink.absoluteString
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(identifier: notification.identifier,
                                            content: content,
                                            trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Unable to update widget intent notification: \(error)")
            }
        }
    }

    private func title(for action: Action, state: State) -> String {
        switch (action, state) {
        case (.checkIn, .loading):
            return "Checking in…"
        case (.checkIn, .success):
            return "Now watching"
        case (.checkIn, .failure(.checkInAlreadyInProgress)):
            return "You’re already checked in"
        case (.checkIn, .failure(.generic)):
            return "Check-in failed"
        case (.markWatched, .loading):
            return "Updating history…"
        case (.markWatched, .success):
            return "Added to history"
        case (.markWatched, .failure):
            return "History update failed"
        case (.refreshCurrentlyWatching, .loading):
            return "Refreshing…"
        case (.refreshCurrentlyWatching, .success):
            return "Up to date"
        case (.refreshCurrentlyWatching, .failure):
            return "Couldn’t refresh"
        case (.cancelCheckIn, .loading):
            return "Ending check-in…"
        case (.cancelCheckIn, .success):
            return "Check-in ended"
        case (.cancelCheckIn, .failure):
            return "Couldn’t end check-in"
        }
    }

    private func body(for action: Action, state: State) -> String {
        switch (action, state) {
        case (.checkIn(let media), .loading):
            return media.description
        case (.checkIn(let media), .success):
            return "You’re checked in to \(media.description)."
        case (.checkIn(let media), .failure(.checkInAlreadyInProgress)):
            return "End your current check-in before starting \(media.description)."
        case (.checkIn(let media), .failure(.generic)):
            return "Something went wrong while checking in to \(media.description). Please try again."
        case (.markWatched(let media), .loading):
            return "Marking \(media.description) as watched."
        case (.markWatched(let media), .success):
            return "\(media.description) is now in your watched history."
        case (.markWatched(let media), .failure):
            return "Something went wrong while adding \(media.description) to your watched history. Please try again."
        case (.refreshCurrentlyWatching, .loading):
            return "Checking for your latest activity."
        case (.refreshCurrentlyWatching, .success):
            return "Currently Watching now matches your latest activity."
        case (.refreshCurrentlyWatching, .failure):
            return "Something went wrong while updating Currently Watching. Please try again."
        case (.cancelCheckIn(let media), .loading):
            return media.map { "Ending your check-in to \($0.description)." } ?? "Ending your current check-in."
        case (.cancelCheckIn(let media), .success):
            return media.map { "Your check-in to \($0.description) has ended." } ?? "Your current check-in has ended."
        case (.cancelCheckIn(let media), .failure):
            return media.map { "Something went wrong while ending your check-in to \($0.description). Please try again." }
                ?? "Something went wrong while ending your current check-in. Please try again."
        }
    }

    private func media(for action: Action) -> Media? {
        switch action {
        case .checkIn(let media), .markWatched(let media):
            return media
        case .cancelCheckIn(let media):
            return media
        case .refreshCurrentlyWatching:
            return nil
        }
    }
}
