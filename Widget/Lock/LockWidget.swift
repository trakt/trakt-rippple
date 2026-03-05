//
//  LockWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 18/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents

#if !targetEnvironment(macCatalyst)

struct LockProvider: TimelineProvider {
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries: [SimpleEntry] = []

        let entryDate = Date.now
        let entry = SimpleEntry(date: entryDate)
        entries.append(entry)

        let timeline = Timeline(entries: entries, policy: .never)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct RipppleLock: Widget {
    let kind: String = "RipppleLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockProvider()) { entry in
            RipppleLockEntryView(entry: entry)
        }.configurationDisplayName("Shortcut")
            .description("Jump in Rippple faster than ever.")
            .supportedFamilies([.accessoryCircular])
    }
}

struct RipppleLockEntryView: View {
    var entry: LockProvider.Entry

    let insideRipppleScale: CGFloat = 0.35
    let secondRipppleScale: CGFloat = 0.7

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: geometry.size.width / 2)
                    .fill(.white)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .opacity(0.4)

                RoundedRectangle(cornerRadius: (geometry.size.width * secondRipppleScale) / 2)
                    .fill(.white)
                    .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                    .shadow(radius: 20)
                    .opacity(0.6)

                RoundedRectangle(cornerRadius: (geometry.size.width * insideRipppleScale) / 2)
                    .fill(.white)
                    .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                    .shadow(radius: 20)
                    .opacity(1)
            }
        }.containerBackground(for: .widget) {}
    }
}

struct LockWidget_Previews: PreviewProvider {
    static var previews: some View {

        RipppleLockEntryView(entry: SimpleEntry(date: Date.now)).previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}

#endif
