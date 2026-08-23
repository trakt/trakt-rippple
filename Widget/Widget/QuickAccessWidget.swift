//
//  QuickAccessWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 07/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import WidgetKit

struct QuickAccessWidgetEntry: TimelineEntry {
    let date: Date
    let items: [QuickAccessWidgetItem]
    let posters: [String: UIImage]
}

struct QuickAccessWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAccessWidgetEntry {
        entry(items: Array(QuickAccessWidgetStorage.items().prefix(itemCount(for: context.family))))
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAccessWidgetEntry) -> Void) {
        Task {
            completion(await entry(for: context.family))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAccessWidgetEntry>) -> Void) {
        Task {
            completion(Timeline(entries: [await entry(for: context.family)], policy: .never))
        }
    }

    private func entry(for family: WidgetFamily) async -> QuickAccessWidgetEntry {
        let items = Array(QuickAccessWidgetStorage.items().prefix(itemCount(for: family)))
        let posters = await loadPosters(for: items)
        return entry(items: items, posters: posters)
    }

    private func entry(items: [QuickAccessWidgetItem], posters: [String: UIImage] = [:]) -> QuickAccessWidgetEntry {
        QuickAccessWidgetEntry(date: .now, items: items, posters: posters)
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
        StaticConfiguration(kind: QuickAccessWidgetStorage.kind,
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
        GeometryReader { proxy in
            let controlSize = controlSize(for: proxy.size)

            if family == .systemSmall {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        searchIconButton(controlSize: controlSize)
                        trendingItemButton(at: 0, controlSize: controlSize)
                    }
                    HStack(spacing: 10) {
                        trendingItemButton(at: 1, controlSize: controlSize)
                        trendingItemButton(at: 2, controlSize: controlSize)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Link(destination: URL(string: "ripl://search")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.title3.weight(.medium))
                            Text("Search")
                                .font(.title3.weight(.medium))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.primary.opacity(0.72))
                        .padding(.leading, 18)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.primary.opacity(0.2), in: Capsule())
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(height: controlSize)
                    .accessibilityLabel("Search with Rippple")

                    HStack(spacing: 10) {
                        ForEach(0..<itemCount(for: family), id: \.self) { index in
                            trendingItemButton(at: index, controlSize: controlSize)
                        }
                    }
                    .frame(height: controlSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    private func controlSize(for availableSize: CGSize) -> CGFloat {
        let controlCount = family == .systemSmall ? 2 : CGFloat(itemCount(for: family))
        let width = (availableSize.width - 10 * (controlCount - 1)) / controlCount
        let height = (availableSize.height - 10) / 2
        return min(width, height)
    }

    private func searchIconButton(controlSize: CGFloat) -> some View {
        Link(destination: URL(string: "ripl://search")!) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary.opacity(0.72))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.2), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: controlSize, height: controlSize)
        .accessibilityLabel("Search with Rippple")
    }

    @ViewBuilder
    private func trendingItemButton(at index: Int, controlSize: CGFloat) -> some View {
        if entry.items.indices.contains(index) {
            let item = entry.items[index]
            Link(destination: item.deeplink) {
                poster(for: item)
            }
            .buttonStyle(.plain)
            .frame(width: controlSize, height: controlSize)
            .accessibilityLabel("Open \(item.title)")
        } else {
            emptyPoster
                .frame(width: controlSize, height: controlSize)
                .overlay {
                    posterBorder
                }
        }
    }

    private func poster(for item: QuickAccessWidgetItem) -> some View {
        Group {
            if let poster = entry.posters[item.id] {
                Image(uiImage: poster)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                emptyPoster
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Circle())
        .overlay {
            posterBorder
        }
        .contentShape(Circle())
    }

    private var posterBorder: some View {
        Circle()
            .strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
    }

    private var emptyPoster: some View {
        Image(systemName: "film")
            .font(.title2)
            .foregroundStyle(.primary.opacity(0.5))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.primary.opacity(0.12), in: Circle())
    }
}

private func itemCount(for family: WidgetFamily) -> Int {
    family == .systemMedium ? 5 : 3
}
