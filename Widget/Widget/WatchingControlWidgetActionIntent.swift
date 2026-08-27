//
//  WatchingControlWidgetActionIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 10/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import WidgetKit

struct WatchingControlWidgetActionHandler {
    let refresh: @Sendable () async throws -> Void
    let cancelCheckIn: @Sendable () async throws -> Void
}

private func performWatchingControlWidgetAction(notificationAction: WidgetIntentNotificationsManager.Action,
                                                action: @Sendable () async throws -> Void) async throws {
    let notification = WidgetIntentNotificationsManager.shared.start(action: notificationAction)
    do {
        try Task.checkCancellation()
        try await action()

        try Task.checkCancellation()
        WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
        WidgetIntentNotificationsManager.shared.succeed(notification)
    } catch {
        WidgetIntentNotificationsManager.shared.fail(notification, error: error)
        throw error
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct RefreshWatchingControlWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Refresh Currently Watching"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    func perform() async throws -> some IntentResult {
        try await performWatchingControlWidgetAction(notificationAction: .refreshCurrentlyWatching,
                                                     action: actionHandler.refresh)
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct CancelWatchingControlWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Current Check-In"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    @Parameter(title: "Media Title")
    var mediaTitle: String?

    @Parameter(title: "Media Subtitle")
    var mediaSubtitle: String?

    @Parameter(title: "Media Link")
    var mediaDeeplink: URL?

    init() {}

    init(media: WatchingControlWidgetItem?) {
        mediaTitle = media?.title
        mediaSubtitle = media?.subtitle
        mediaDeeplink = media?.deeplink
    }

    func perform() async throws -> some IntentResult {
        let media: WidgetIntentNotificationsManager.Media?
        if let mediaTitle = mediaTitle, let mediaDeeplink = mediaDeeplink {
            let description = [mediaTitle, mediaSubtitle].compactMap { $0 }.joined(separator: " · ")
            media = WidgetIntentNotificationsManager.Media(description: description,
                                                           deeplink: mediaDeeplink)
        } else {
            media = nil
        }
        try await performWatchingControlWidgetAction(notificationAction: .cancelCheckIn(media),
                                                     action: actionHandler.cancelCheckIn)
        return .result()
    }
}
