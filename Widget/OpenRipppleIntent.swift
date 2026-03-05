//
//  OpenRipppleIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 18/01/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import AppIntents

struct OpenRipppleIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Rippple"
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct OpenRipppleSearchIntent: AppIntent {
    static var title: LocalizedStringResource = "Rippple Search"
    static var isDiscoverable: Bool = true

    @MainActor
    func perform() async throws -> some OpensIntent {
        return .result(opensIntent: OpenURLIntent(URL(string: "https://rippple.app/search")!))
    }
}
