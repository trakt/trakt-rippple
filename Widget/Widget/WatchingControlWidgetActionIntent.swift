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

struct RefreshWatchingControlWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Refresh Currently Watching"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    func perform() async throws -> some IntentResult {
        try await actionHandler.refresh()
        WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
        return .result()
    }
}

struct CancelWatchingControlWidgetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Current Check-In"
    static let isDiscoverable = false
    static let supportedModes: IntentModes = [.background, .foreground(.dynamic)]

    @Dependency
    private var actionHandler: WatchingControlWidgetActionHandler

    func perform() async throws -> some IntentResult {
        try await actionHandler.cancelCheckIn()
        WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
        return .result()
    }
}
