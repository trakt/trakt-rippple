//
//  OpenRipppleIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 18/01/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents

struct OpenRipppleIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Rippple"
    static let description = IntentDescription("Opens Rippple. This action has no input and does not return a value.",
                                               categoryName: "Navigation")
    static let openAppWhenRun = true
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct OpenRipppleSearchIntent: AppIntent {
    static let title: LocalizedStringResource = "Rippple Search"
    static let description = IntentDescription("Opens the search screen in Rippple. This action has no input and does not return a value.",
                                               categoryName: "Navigation")
    static let isDiscoverable = true

    @MainActor
    func perform() async throws -> some OpensIntent {
        .result(opensIntent: OpenURLIntent(URL(string: "https://rippple.app/search")!))
    }
}
