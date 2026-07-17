//
//  IconWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 19/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Intents
import SwiftUI
import WidgetKit

struct IconProvider: IntentTimelineProvider {
    typealias Intent = IconTypeIntent
    typealias Entry = IconEntry

    func placeholder(in context: Context) -> IconEntry {
        let configuration = Intent()
        return IconEntry(date: Date(), configuration: configuration)
    }

    func getSnapshot(for configuration: Intent, in context: Context, completion: @escaping (IconEntry) -> Void) {
        let entry = IconEntry(date: Date(), configuration: configuration)
        completion(entry)
    }

    func getTimeline(for configuration: Intent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [IconEntry] = []

        let entryDate = Date.now
        let entry = IconEntry(date: entryDate, configuration: configuration)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct IconEntry: TimelineEntry {
    let date: Date
    let configuration: IconTypeIntent
}

struct RipppleIcon: Widget {
    let kind: String = "RipppleIcon"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: IconTypeIntent.self, provider: IconProvider()) { _ in
            IconView()
        }.configurationDisplayName("Splash")
            .description("Enjoy a bigger version of Rippple's ripple effect.")
            .supportedFamilies([.systemSmall])
            .contentMarginsDisabled()
            .containerBackgroundRemovable(false)
    }
}

struct IconView: View {
    var body: some View {
        if let appIcon = UserDefaults(suiteName: "group.tv.trakt.rippple")!.object(forKey: "WidgetManager.appIcon") as? String, let identifier = AppIconIdentifier(rawValue: appIcon) {
            AppIconGeneratorView(appIconIdentifier: identifier)
                .containerBackground(.background, for: .widget)
        } else {
            AppIconGeneratorView(appIconIdentifier: .original)
                .containerBackground(.background, for: .widget)
        }
    }
}

struct IconWidget_Previews: PreviewProvider {
    static var previews: some View {
        IconView()
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
