//
//  UpcomingWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 06/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

struct UpcomingWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Upcoming"
    static let description = IntentDescription("Choose whether to show upcoming episodes or movies.")

    @Parameter(title: "Content", default: ToWatchWidgetContent.episodes)
    var content: ToWatchWidgetContent

    init() {}
}

struct UpcomingWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: UpcomingWidgetConfigurationIntent
    let items: [UpcomingWidgetItem]
    let posters: [String: UIImage]
}

struct UpcomingWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UpcomingWidgetEntry {
        let configuration = UpcomingWidgetConfigurationIntent()
        return UpcomingWidgetEntry(date: .now,
                                   configuration: configuration,
                                   items: items(from: storedItems(for: configuration.content), at: .now),
                                   posters: [:])
    }

    func snapshot(for configuration: UpcomingWidgetConfigurationIntent,
                  in context: Context) async -> UpcomingWidgetEntry {
        return await entry(for: configuration, at: .now)
    }

    func timeline(for configuration: UpcomingWidgetConfigurationIntent,
                  in context: Context) async -> Timeline<UpcomingWidgetEntry> {
        let now = Date.now
        let allItems = storedItems(for: configuration.content)
            .sorted { ($0.releaseDate, $0.title) < ($1.releaseDate, $1.title) }
        let releaseDates = Set(allItems.lazy.filter { $0.releaseDate > now }.map(\.releaseDate)).sorted()
        let entryDates = [now] + releaseDates
        let visibleItems = entryDates.map { items(from: allItems, at: $0) }
        let posters = await loadPosters(for: Array(visibleItems.joined()))
        let entries = zip(entryDates, visibleItems).map { date, items in
            UpcomingWidgetEntry(date: date,
                                configuration: configuration,
                                items: items,
                                posters: posters)
        }
        let refreshDate = (releaseDates.last ?? now).addingTimeInterval(upcomingWidgetFallbackRefreshInterval)
        return Timeline(entries: entries, policy: .after(refreshDate))
    }

    private func entry(for configuration: UpcomingWidgetConfigurationIntent,
                       at date: Date) async -> UpcomingWidgetEntry {
        let items = items(from: storedItems(for: configuration.content), at: date)
        let posters = await loadPosters(for: items)
        return UpcomingWidgetEntry(date: date,
                                   configuration: configuration,
                                   items: items,
                                   posters: posters)
    }

    private func storedItems(for content: ToWatchWidgetContent) -> [UpcomingWidgetItem] {
        switch content {
        case .episodes:
            return UpcomingWidgetStorage.episodes()
        case .movies:
            return UpcomingWidgetStorage.movies()
        }
    }

    private func items(from allItems: [UpcomingWidgetItem], at date: Date) -> [UpcomingWidgetItem] {
        Array(allItems.lazy.filter { $0.releaseDate > date }
            .sorted { ($0.releaseDate, $0.title) < ($1.releaseDate, $1.title) }
            .prefix(upcomingWidgetItemCount))
    }

    private func loadPosters(for items: [UpcomingWidgetItem]) async -> [String: UIImage] {
        let uniqueItems = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        return await loadWidgetPosters(for: Array(uniqueItems),
                                       identifier: \UpcomingWidgetItem.id,
                                       tmdbIdentifier: \UpcomingWidgetItem.tmdbIdentifier,
                                       mediaType: \UpcomingWidgetItem.tmdbMediaType)
    }
}

struct UpcomingWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: UpcomingWidgetStorage.kind,
                               intent: UpcomingWidgetConfigurationIntent.self,
                               provider: UpcomingWidgetProvider()) { entry in
            UpcomingWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Upcoming")
        .description("See the next episodes or movies coming your way.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct UpcomingWidgetEntryView: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: UpcomingWidgetEntry

    var body: some View {
        Group {
            if entry.items.isEmpty {
                emptyState
            } else {
                HStack(alignment: .top, spacing: upcomingWidgetItemSpacing) {
                    items
                }
            }
        }
        .padding([.trailing, .leading, .top], upcomingWidgetContentPadding)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.background, for: .widget)
    }

    private var items: some View {
        ForEach(0..<upcomingWidgetItemCount, id: \.self) { index in
            Group {
                if entry.items.indices.contains(index) {
                    let item = entry.items[index]
                    UpcomingWidgetPoster(item: item,
                                         poster: entry.posters[item.id],
                                         isFirst: index == 0,
                                         isLast: index == upcomingWidgetItemCount - 1)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3)
                .foregroundStyle(widgetRenderingMode == .fullColor ? Color.purple : Color.primary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Nothing upcoming")
                    .font(.headline)
                Text(entry.configuration.content == .episodes ? "No upcoming episodes were found." : "No upcoming movies were found.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct UpcomingWidgetPoster: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let item: UpcomingWidgetItem
    let poster: UIImage?
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            Link(destination: item.deeplink) {
                posterView
            }
            .layoutPriority(1)
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(item.title)")

            Link(destination: item.deeplink) {
                VStack(spacing: 0) {
                    Spacer(minLength: 2)
                    label
                    Spacer(minLength: 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Open \(item.title), \(item.metadata), in \(item.releaseDate, style: .relative)"))
        }
        .frame(maxHeight: .infinity)
    }

    private var posterView: some View {
        Group {
            if let poster {
                Image(uiImage: poster)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                posterShape
                    .fill(widgetRenderingMode == .fullColor ? Color(uiColor: .quaternarySystemFill) : Color.primary.opacity(0.12))
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .clipShape(posterShape)
        .overlay {
            posterShape.strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
        }
    }

    private var label: some View {
        VStack(spacing: 0) {
            Text(item.metadata)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
            Text(item.releaseDate, style: .relative)
                .font(.caption2)
                .foregroundStyle(.primary.opacity(0.9))
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .multilineTextAlignment(.center)
        .frame(height: upcomingWidgetLabelHeight)
    }

    private var posterShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: isFirst ? upcomingWidgetOuterPosterCornerRadius : upcomingWidgetPosterCornerRadius,
                               bottomLeadingRadius: upcomingWidgetPosterCornerRadius,
                               bottomTrailingRadius: upcomingWidgetPosterCornerRadius,
                               topTrailingRadius: isLast ? upcomingWidgetOuterPosterCornerRadius : upcomingWidgetPosterCornerRadius,
                               style: .continuous)
    }
}

private let upcomingWidgetItemCount = 4
private let upcomingWidgetContentPadding: CGFloat = 10
private let upcomingWidgetItemSpacing: CGFloat = 8
private let upcomingWidgetPosterCornerRadius: CGFloat = 12
private let upcomingWidgetOuterPosterCornerRadius: CGFloat = 20
private let upcomingWidgetLabelHeight: CGFloat = 24
private let upcomingWidgetFallbackRefreshInterval: TimeInterval = 60 * 60 * 2
