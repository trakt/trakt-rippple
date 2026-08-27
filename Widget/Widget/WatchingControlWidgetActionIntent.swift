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

private func performWatchingControlWidgetAction(action: @Sendable () async throws -> Void) async throws {
    try Task.checkCancellation()
    try await action()

    try Task.checkCancellation()
    WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
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
        try await performWatchingControlWidgetAction(action: actionHandler.refresh)
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

    func perform() async throws -> some IntentResult {
        try await performWatchingControlWidgetAction(action: actionHandler.cancelCheckIn)
        return .result()
    }
}
