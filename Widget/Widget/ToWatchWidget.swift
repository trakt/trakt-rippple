//
//  ToWatchWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 01/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct ToWatchWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "To Watch"
    static let description = IntentDescription("Configures whether the widget shows episodes or movies and which action appears beside each item.")

    @Parameter(title: "Content",
               description: "The type of items to show in the widget.",
               default: ToWatchWidgetContent.episodes)
    var content: ToWatchWidgetContent

    @Parameter(title: "Action",
               description: "The button action shown beside each movie or episode.",
               default: ToWatchWidgetAction.checkIn)
    var action: ToWatchWidgetAction

    init() {}
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
enum ToWatchWidgetItem: Identifiable {
    case episode(ToWatchWidgetEpisode)
    case movie(ToWatchWidgetMovie)

    var id: String {
        switch self {
        case .episode(let episode):
            return "episode:\(episode.id)"
        case .movie(let movie):
            return "movie:\(movie.id)"
        }
    }

    var tmdbIdentifier: Int? {
        switch self {
        case .episode(let episode):
            return episode.showTMDbIdentifier
        case .movie(let movie):
            return movie.movieTMDbIdentifier
        }
    }

    var tmdbMediaType: String {
        switch self {
        case .episode:
            return "tv"
        case .movie:
            return "movie"
        }
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct ToWatchWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: ToWatchWidgetConfigurationIntent
    let items: [ToWatchWidgetItem]
    let posters: [String: UIImage]
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct ToWatchWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ToWatchWidgetEntry {
        let configuration = ToWatchWidgetConfigurationIntent()
        return placeholderEntry(for: configuration, family: context.family)
    }

    func snapshot(for configuration: ToWatchWidgetConfigurationIntent,
                  in context: Context) async -> ToWatchWidgetEntry {
        return await entry(for: configuration, family: context.family)
    }

    func timeline(for configuration: ToWatchWidgetConfigurationIntent,
                  in context: Context) async -> Timeline<ToWatchWidgetEntry> {
        let entry = await entry(for: configuration, family: context.family)
        return Timeline(entries: [entry], policy: .never)
    }

    private func placeholderEntry(for configuration: ToWatchWidgetConfigurationIntent,
                                  family: WidgetFamily) -> ToWatchWidgetEntry {
        ToWatchWidgetEntry(date: .now,
                           configuration: configuration,
                           items: Array(storedItems(for: configuration.content).prefix(rowCount(for: family))),
                           posters: [:])
    }

    private func entry(for configuration: ToWatchWidgetConfigurationIntent,
                       family: WidgetFamily) async -> ToWatchWidgetEntry {
        let items = Array(storedItems(for: configuration.content).prefix(rowCount(for: family)))
        let posters = await loadPosters(for: items)
        return ToWatchWidgetEntry(date: .now,
                                  configuration: configuration,
                                  items: items,
                                  posters: posters)
    }

    private func storedItems(for content: ToWatchWidgetContent) -> [ToWatchWidgetItem] {
        switch content {
        case .episodes:
            return ToWatchWidgetStorage.episodes().map(ToWatchWidgetItem.episode)
        case .movies:
            return ToWatchWidgetStorage.movies().map(ToWatchWidgetItem.movie)
        }
    }

    private func loadPosters(for items: [ToWatchWidgetItem]) async -> [String: UIImage] {
        await loadWidgetPosters(for: items,
                                identifier: \ToWatchWidgetItem.id,
                                tmdbIdentifier: \ToWatchWidgetItem.tmdbIdentifier,
                                mediaType: \ToWatchWidgetItem.tmdbMediaType)
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct ToWatchWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: ToWatchWidgetStorage.kind,
                               intent: ToWatchWidgetConfigurationIntent.self,
                               provider: ToWatchWidgetProvider()) { entry in
            ToWatchWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("To Watch")
        .description("See your next episodes or movies and quickly check in or mark them watched.")
        .supportedFamilies(toWatchWidgetSupportedFamilies)
        .contentMarginsDisabled()
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private struct ToWatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let entry: ToWatchWidgetEntry

    var body: some View {
        Group {
            if entry.items.isEmpty {
                emptyState
            } else {
                VStack(spacing: rowSpacing) {
                    rows
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(contentPadding)
        .containerBackground(.background, for: .widget)
    }

    private var rows: some View {
        ForEach(0..<rowCount(for: family), id: \.self) { index in
            Group {
                if entry.items.indices.contains(index) {
                    let item = entry.items[index]
                    ToWatchWidgetRow(item: item,
                                     poster: entry.posters[item.id],
                                     action: entry.configuration.action,
                                     isFirst: index == entry.items.startIndex,
                                     isLast: index == entry.items.index(before: entry.items.endIndex))
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(usesSystemRendering ? Color.primary : WidgetTint.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("You’re all caught up")
                    .font(.headline)
                Text(entry.configuration.content == .episodes ? "No episodes are waiting to be watched." : "No movies are waiting to be watched.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var usesSystemRendering: Bool {
        widgetRenderingMode != .fullColor
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private struct ToWatchWidgetRow: View {
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    let item: ToWatchWidgetItem
    let poster: UIImage?
    let action: ToWatchWidgetAction
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: itemSpacing) {
            Link(destination: posterDestination) {
                posterView
            }
            .accessibilityLabel("Open \(title)")

            Link(destination: contentDestination) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let primaryDetails {
                        Text(primaryDetails)
                            .font(.caption.bold())
                            .foregroundStyle(Color.primary.opacity(0.9))
                    }
                    if let secondaryDetails {
                        Text(secondaryDetails)
                            .font(.caption)
                            .foregroundStyle(Color.primary.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(contentAccessibilityLabel)

            actionButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .fill(usesSystemRendering ? Color.primary.opacity(0.12) : Color(uiColor: .quaternarySystemFill))
            }
        }
        .aspectRatio(2.0 / 3.0, contentMode: .fit)
        .frame(maxHeight: .infinity)
        .clipShape(posterShape)
        .overlay {
            posterShape.strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
        }
    }

    private var usesSystemRendering: Bool {
        widgetRenderingMode != .fullColor
    }

    private var actionColor: Color {
        usesSystemRendering ? .primary : WidgetTint.color
    }

    private var actionAccessibilityLabel: String {
        let mediaDescription: String
        switch item {
        case .episode(let episode):
            mediaDescription = "\(episode.showTitle) \(episode.localizedEpisodeNumber)"
        case .movie(let movie):
            mediaDescription = movie.title
        }

        switch action {
        case .none:
            return ""
        case .checkIn:
            return "Check in to \(mediaDescription)"
        case .markWatched:
            return "Mark \(mediaDescription) watched"
        }
    }

    private var contentAccessibilityLabel: String {
        var components = ["Open \(title)"]
        if let primaryDetails {
            components.append(primaryDetails)
        }
        if let secondaryDetails {
            components.append(secondaryDetails)
        }
        return components.joined(separator: ", ")
    }

    private var title: String {
        switch item {
        case .episode(let episode):
            return episode.showTitle
        case .movie(let movie):
            return movie.title
        }
    }

    private var primaryDetails: String? {
        switch item {
        case .episode(let episode):
            return episode.localizedEpisodeDetails
        case .movie(let movie):
            return movie.localizedDetails
        }
    }

    private var secondaryDetails: String? {
        guard case .episode(let episode) = item else { return nil }
        return episode.behind
    }

    private var posterDestination: URL {
        switch item {
        case .episode(let episode):
            return episode.showDeeplink
        case .movie(let movie):
            return movie.deeplink
        }
    }

    private var contentDestination: URL {
        switch item {
        case .episode(let episode):
            return episode.episodeDeeplink
        case .movie(let movie):
            return movie.deeplink
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if let systemImage = action.systemImage {
            switch item {
            case .episode(let episode):
                Button(intent: EpisodesToWatchRefreshWidgetActionIntent(action: action, episode: episode)) {
                    actionButtonLabel(systemImage: systemImage)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionAccessibilityLabel)
            case .movie(let movie):
                Button(intent: MoviesToWatchRefreshWidgetActionIntent(action: action, movie: movie)) {
                    actionButtonLabel(systemImage: systemImage)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(actionAccessibilityLabel)
            }
        }
    }

    private func actionButtonLabel(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(actionColor)
            .frame(width: actionCircleSize, height: actionCircleSize)
            .background(actionColor.opacity(usesSystemRendering ? 0.12 : 0.16), in: Circle())
            .frame(width: actionTargetSize, height: actionTargetSize)
            .contentShape(Rectangle())
    }

    private var posterShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: isFirst ? outerPosterCornerRadius : posterCornerRadius,
                               bottomLeadingRadius: isLast ? outerPosterCornerRadius : posterCornerRadius,
                               bottomTrailingRadius: posterCornerRadius,
                               topTrailingRadius: posterCornerRadius,
                               style: .continuous)
    }
}

private let contentPadding: CGFloat = 10
private let rowSpacing: CGFloat = 8
private let itemSpacing: CGFloat = 8
private let posterCornerRadius: CGFloat = 12
private let outerPosterCornerRadius: CGFloat = 20
private let actionCircleSize: CGFloat = 36
private let actionTargetSize: CGFloat = 44

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private let toWatchWidgetSupportedFamilies: [WidgetFamily] = [.systemMedium, .systemLarge, .systemExtraLargePortrait]

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
private func rowCount(for family: WidgetFamily) -> Int {
    if family == .systemExtraLargePortrait {
        return 6
    }
    return family == .systemLarge ? 4 : 2
}
