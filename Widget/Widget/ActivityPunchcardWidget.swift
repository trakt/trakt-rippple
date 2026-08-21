//
//  ActivityPunchcardWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 07/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import WidgetKit

private struct ActivityPunchcardWidgetEntry: TimelineEntry {
    let date: Date
    let activityCounts: [Date: Int]
}

private struct ActivityPunchcardWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ActivityPunchcardWidgetEntry {
        entry(activityCounts: ActivityPunchcardWidgetStorage.activityCounts())
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (ActivityPunchcardWidgetEntry) -> Void) {
        completion(entry(activityCounts: ActivityPunchcardWidgetStorage.activityCounts()))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<ActivityPunchcardWidgetEntry>) -> Void) {
        completion(Timeline(entries: [entry(activityCounts: ActivityPunchcardWidgetStorage.activityCounts())],
                            policy: .never))
    }

    private func entry(activityCounts: [Date: Int]) -> ActivityPunchcardWidgetEntry {
        return ActivityPunchcardWidgetEntry(date: .now,
                                            activityCounts: activityCounts)
    }
}

struct ActivityPunchcardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ActivityPunchcardWidgetStorage.kind,
                            provider: ActivityPunchcardWidgetProvider()) { entry in
            ActivityPunchcardWidgetView(entry: entry)
        }
        .configurationDisplayName("Activity Punchcard")
        .description("See your recent watching activity at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct ActivityPunchcardWidgetView: View {
    let entry: ActivityPunchcardWidgetEntry

    var body: some View {
        ActivityPunchcardView(activityCounts: entry.activityCounts,
                              referenceDate: entry.date,
                              tint: tintColor,
                              punchSize: ActivityPunchcardMetrics.punchSize * 1.2,
                              fillsAvailableSpace: true,
                              outerCornerRadiusFactor: 0.8)
            .padding(14)
            .containerBackground(.background, for: .widget)
            .widgetURL(URL(string: "ripl://users/me"))
    }

    private var tintColor: UIColor {
        let colors: [UIColor] = [
            UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(red: 191 / 255, green: 90 / 255, blue: 242 / 255, alpha: 1)
                }
                return UIColor(red: 174 / 255, green: 82 / 255, blue: 222 / 255, alpha: 1)
            },
            .systemRed,
            .systemOrange,
            .systemYellow,
            .systemGreen,
            .systemMint,
            .systemTeal,
            .systemCyan,
            .systemBlue,
            .systemIndigo,
            .systemPink,
            .systemBrown,
            .label
        ]
        let index = UserDefaults(suiteName: "group.tv.trakt.rippple")!.integer(forKey: "AppManager.currentTint")
        return colors.indices.contains(index) ? colors[index] : .systemPurple
    }
}

struct ActivityPunchcardWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ActivityPunchcardWidgetView(entry: ActivityPunchcardWidgetEntry(date: .now,
                                                                            activityCounts: [:]))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Small")

            ActivityPunchcardWidgetView(entry: ActivityPunchcardWidgetEntry(date: .now,
                                                                            activityCounts: [:]))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Medium")
        }
    }
}
