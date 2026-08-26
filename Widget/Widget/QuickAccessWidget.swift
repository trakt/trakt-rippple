//
//  QuickAccessWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 07/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

enum QuickAccessWidgetContent: String, AppEnum {
    case trendingMedia
    case trendingMovies
    case trendingShows

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content")
    static let typeDisplayName: LocalizedStringResource = "Content"
    static let caseDisplayRepresentations: [QuickAccessWidgetContent: DisplayRepresentation] = [
        .trendingMedia: "Trending Media",
        .trendingMovies: "Trending Movies",
        .trendingShows: "Trending Shows"
    ]
}

struct QuickAccessWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Search"
    static let description = IntentDescription("Choose the media shown below the search field.")

    @Parameter(title: "Content", default: QuickAccessWidgetContent.trendingMedia)
    var content: QuickAccessWidgetContent

    init() {}
}

struct QuickAccessWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: QuickAccessWidgetConfigurationIntent
    let items: [QuickAccessWidgetItem]
    let posters: [String: UIImage]
}

struct QuickAccessWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuickAccessWidgetEntry {
        let configuration = QuickAccessWidgetConfigurationIntent()
        return entry(configuration: configuration,
                     items: Array(storedItems(for: configuration.content).prefix(itemCount(for: context.family))))
    }

    func snapshot(for configuration: QuickAccessWidgetConfigurationIntent,
                  in context: Context) async -> QuickAccessWidgetEntry {
        await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: QuickAccessWidgetConfigurationIntent,
                  in context: Context) async -> Timeline<QuickAccessWidgetEntry> {
        Timeline(entries: [await entry(for: configuration, family: context.family)], policy: .never)
    }

    private func entry(for configuration: QuickAccessWidgetConfigurationIntent,
                       family: WidgetFamily) async -> QuickAccessWidgetEntry {
        let items = Array(storedItems(for: configuration.content).prefix(itemCount(for: family)))
        let posters = await loadPosters(for: items)
        return entry(configuration: configuration, items: items, posters: posters)
    }

    private func entry(configuration: QuickAccessWidgetConfigurationIntent,
                       items: [QuickAccessWidgetItem],
                       posters: [String: UIImage] = [:]) -> QuickAccessWidgetEntry {
        QuickAccessWidgetEntry(date: .now,
                               configuration: configuration,
                               items: items,
                               posters: posters)
    }

    private func storedItems(for content: QuickAccessWidgetContent) -> [QuickAccessWidgetItem] {
        switch content {
        case .trendingMedia:
            return QuickAccessWidgetStorage.trendingMedia()
        case .trendingMovies:
            return QuickAccessWidgetStorage.trendingMovies()
        case .trendingShows:
            return QuickAccessWidgetStorage.trendingShows()
        }
    }

    private func loadPosters(for items: [QuickAccessWidgetItem]) async -> [String: UIImage] {
        await loadWidgetPosters(for: items,
                                identifier: \QuickAccessWidgetItem.id,
                                tmdbIdentifier: \QuickAccessWidgetItem.tmdbIdentifier,
                                mediaType: \QuickAccessWidgetItem.tmdbMediaType)
    }
}

struct QuickAccessWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: QuickAccessWidgetStorage.kind,
                               intent: QuickAccessWidgetConfigurationIntent.self,
                               provider: QuickAccessWidgetProvider()) { entry in
            QuickAccessWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Search")
        .description("Search Rippple or discover trending movies and shows.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

private struct QuickAccessWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickAccessWidgetEntry

    var body: some View {
        VStack(spacing: quickAccessWidgetItemSpacing) {
            searchButton

            HStack(spacing: quickAccessWidgetItemSpacing) {
                ForEach(0..<itemCount(for: family), id: \.self) { index in
                    trendingItemButton(at: index)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
        }
        .padding(quickAccessWidgetContentPadding)
        .containerBackground(.background, for: .widget)
    }

    private var searchButton: some View {
        Link(destination: URL(string: "ripl://search")!) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                Text("Search")
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary.opacity(0.7))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.primary.opacity(0.04), in: searchShape)
            .overlay {
                searchShape
                    .strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
            }
            .contentShape(searchShape)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: quickAccessWidgetSearchHeight)
        .accessibilityLabel("Search with Rippple")
    }

    private func trendingItemButton(at index: Int) -> some View {
        Group {
            if entry.items.indices.contains(index) {
                let item = entry.items[index]
                Link(destination: item.deeplink) {
                    poster(for: item, at: index)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(item.title)")
            } else {
                emptyPoster(at: index)
                    .overlay {
                        posterShape(at: index)
                            .strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
                    }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private func poster(for item: QuickAccessWidgetItem, at index: Int) -> some View {
        Group {
            if let poster = entry.posters[item.id] {
                Image(uiImage: poster)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                emptyPoster(at: index)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipShape(posterShape(at: index))
        .overlay {
            posterShape(at: index)
                .strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
        }
        .contentShape(posterShape(at: index))
    }

    private func emptyPoster(at index: Int) -> some View {
        Image(systemName: "film")
            .font(.title2)
            .foregroundStyle(.primary.opacity(0.5))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(.primary.opacity(0.12), in: posterShape(at: index))
    }

    private var searchShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: quickAccessWidgetOuterCornerRadius,
                               bottomLeadingRadius: quickAccessWidgetCornerRadius,
                               bottomTrailingRadius: quickAccessWidgetCornerRadius,
                               topTrailingRadius: quickAccessWidgetOuterCornerRadius,
                               style: .continuous)
    }

    private func posterShape(at index: Int) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: quickAccessWidgetCornerRadius,
                               bottomLeadingRadius: index == 0 ? quickAccessWidgetOuterCornerRadius : quickAccessWidgetCornerRadius,
                               bottomTrailingRadius: index == itemCount(for: family) - 1 ? quickAccessWidgetOuterCornerRadius : quickAccessWidgetCornerRadius,
                               topTrailingRadius: quickAccessWidgetCornerRadius,
                               style: .continuous)
    }
}

private func itemCount(for family: WidgetFamily) -> Int {
    family == .systemMedium ? 4 : 2
}

private let quickAccessWidgetContentPadding: CGFloat = 10
private let quickAccessWidgetItemSpacing: CGFloat = 8
private let quickAccessWidgetSearchHeight: CGFloat = 32
private let quickAccessWidgetCornerRadius: CGFloat = 12
private let quickAccessWidgetOuterCornerRadius: CGFloat = 20
