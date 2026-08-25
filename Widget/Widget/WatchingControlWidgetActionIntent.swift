//
//  WatchingControlWidgetActionIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 10/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import Foundation
import WidgetKit

struct WatchingControlWidgetActionHandler {
    let refresh: @Sendable () async throws -> Void
    let cancelCheckIn: @Sendable () async throws -> Void
}

private func performWatchingControlWidgetAction(description: String,
                                                actionDescription: String,
                                                progress: Progress,
                                                action: @Sendable () async throws -> Void) async throws {
    progress.totalUnitCount = 2
    progress.localizedDescription = description
    progress.localizedAdditionalDescription = actionDescription

    try Task.checkCancellation()
    try await action()
    progress.completedUnitCount = 1
    progress.localizedAdditionalDescription = "Updating widget"

    try Task.checkCancellation()
    WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
    progress.completedUnitCount = 2
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct RefreshWatchingControlWidgetIntent: LongRunningIntent, CancellableIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Refresh Currently Watching"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    func perform() async throws -> some IntentResult {
        try await performBackgroundTask {
            try await performWatchingControlWidgetAction(description: "Refreshing currently watching",
                                                         actionDescription: "Refreshing activity",
                                                         progress: progress,
                                                         action: actionHandler.refresh)
        } onCancel: { _ in }
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct CancelWatchingControlWidgetIntent: LongRunningIntent, CancellableIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Current Check-In"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    func perform() async throws -> some IntentResult {
        try await performBackgroundTask {
            try await performWatchingControlWidgetAction(description: "Cancelling current check-in",
                                                         actionDescription: "Cancelling check-in",
                                                         progress: progress,
                                                         action: actionHandler.cancelCheckIn)
        } onCancel: { _ in }
        return .result()
    }
}
