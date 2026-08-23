//
//  WatchingControlWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 10/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import SwiftUI
import WidgetKit

#if !targetEnvironment(macCatalyst)
@available(iOS 27.0, *)
enum WatchingControlWidgetButtonAction: String, AppEnum {
    case episodesToWatch
    case moviesToWatch
    case runShortcut

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static let typeDisplayName: LocalizedStringResource = "Action"
    static let caseDisplayRepresentations: [WatchingControlWidgetButtonAction: DisplayRepresentation] = [
        .episodesToWatch: "Open Episodes To Watch",
        .moviesToWatch: "Open Movies To Watch",
        .runShortcut: "Run a Shortcut"
    ]
}

@available(iOS 27.0, *)
struct WatchingControlWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Watching Controls"
    static let description = IntentDescription("Choose what the bottom-right button does.")

    @Parameter(title: "Action", default: WatchingControlWidgetButtonAction.episodesToWatch)
    var action: WatchingControlWidgetButtonAction

    @Parameter(title: "Shortcut")
    var shortcut: SystemShortcut?

    static var parameterSummary: some ParameterSummary {
        Switch(\.$action) {
            Case(.runShortcut) {
                Summary("\(\.$action): \(\.$shortcut)")
            }
            DefaultCase {
                Summary("\(\.$action)")
            }
        }
    }

    init() {}
}

@available(iOS 27.0, *)
struct WatchingControlWidgetEntry: TimelineEntry {
    let date: Date
    let configuration: WatchingControlWidgetConfigurationIntent
    let item: WatchingControlWidgetItem?
    let poster: UIImage?
}

@available(iOS 27.0, *)
struct WatchingControlWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WatchingControlWidgetEntry {
        WatchingControlWidgetEntry(date: .now,
                                   configuration: WatchingControlWidgetConfigurationIntent(),
                                   item: .placeholder,
                                   poster: nil)
    }

    func snapshot(for configuration: WatchingControlWidgetConfigurationIntent,
                  in context: Context) async -> WatchingControlWidgetEntry {
        await entry(for: configuration)
    }

    func timeline(for configuration: WatchingControlWidgetConfigurationIntent,
                  in context: Context) async -> Timeline<WatchingControlWidgetEntry> {
        let entry = await entry(for: configuration)
        guard let item = entry.item,
              item.isCheckInActive,
              let startDate = item.checkInStartDate,
              let endDate = item.checkInEndDate,
              endDate > entry.date else {
            return Timeline(entries: [entry], policy: .never)
        }

        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0 else {
            return Timeline(entries: [entry], policy: .never)
        }
        let entryDates = stride(from: 0.0, through: 1.0, by: 0.025).map { progress in
            max(entry.date, startDate.addingTimeInterval(duration * progress))
        }
        let entries = Array(Set(entryDates)).sorted().map { date in
            WatchingControlWidgetEntry(date: date,
                                       configuration: configuration,
                                       item: item,
                                       poster: entry.poster)
        }
        return Timeline(entries: entries, policy: .after(endDate))
    }

    private func entry(for configuration: WatchingControlWidgetConfigurationIntent) async -> WatchingControlWidgetEntry {
        let item = WatchingControlWidgetStorage.item()
        let posters = await loadWidgetPosters(for: item.map { [$0] } ?? [],
                                              identifier: \WatchingControlWidgetItem.id,
                                              tmdbIdentifier: \WatchingControlWidgetItem.tmdbIdentifier,
                                              mediaType: \WatchingControlWidgetItem.tmdbMediaType)
        return WatchingControlWidgetEntry(date: .now,
                                          configuration: configuration,
                                          item: item,
                                          poster: item.flatMap { posters[$0.id] })
    }
}

@available(iOS 27.0, *)
struct WatchingControlWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WatchingControlWidgetStorage.kind,
                               intent: WatchingControlWidgetConfigurationIntent.self,
                               provider: WatchingControlWidgetProvider()) { entry in
            WatchingControlWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Watching Controls")
        .description("See what you're watching, refresh or cancel your check-in, and run a shortcut.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

@available(iOS 27.0, *)
private struct WatchingControlWidgetEntryView: View {
    let entry: WatchingControlWidgetEntry

    var body: some View {
        GeometryReader { proxy in
            let controlSize = min((proxy.size.width - 10) / 2,
                                  (proxy.size.height - 10) / 2)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    mediaButton(controlSize: controlSize)
                    actionButton(systemImage: "arrow.clockwise",
                                 accessibilityLabel: "Refresh currently watching",
                                 controlSize: controlSize,
                                 intent: RefreshWatchingControlWidgetIntent())
                }
                HStack(spacing: 10) {
                    cancelButton(controlSize: controlSize)
                    configuredActionButton(controlSize: controlSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(12)
        .containerBackground(.background, for: .widget)
    }

    @ViewBuilder
    private func mediaButton(controlSize: CGFloat) -> some View {
        if let item = entry.item {
            Link(destination: item.deeplink) {
                poster
            }
            .buttonStyle(.plain)
            .frame(width: controlSize, height: controlSize)
            .accessibilityLabel(accessibilityLabel(for: item))
        } else {
            Link(destination: WatchingControlWidgetStorage.toWatchDeeplink) {
                emptyMedia
            }
            .buttonStyle(.plain)
            .frame(width: controlSize, height: controlSize)
            .accessibilityLabel("Open To Watch")
        }
    }

    private var poster: some View {
        Group {
            if let poster = entry.poster {
                Image(uiImage: poster)
                    .resizable()
                    .widgetAccentedRenderingMode(.fullColor)
                    .scaledToFill()
            } else {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.primary.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.primary.opacity(0.12))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(Circle())
        .overlay {
            Circle().strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
        }
        .contentShape(Circle())
    }

    private var emptyMedia: some View {
        Image(systemName: "film")
            .font(.title2)
            .foregroundStyle(.primary.opacity(0.5))
            .background(.primary.opacity(0.12))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(Circle())
            .overlay {
                Circle().strokeBorder(Color(uiColor: .tertiarySystemFill), lineWidth: 1)
            }
            .contentShape(Circle())
    }

    @ViewBuilder
    private func configuredActionButton(controlSize: CGFloat) -> some View {
        switch entry.configuration.action {
        case .episodesToWatch:
            deeplinkButton(systemImage: "checklist",
                           accessibilityLabel: "Open Episodes To Watch",
                           destination: WatchingControlWidgetStorage.episodesToWatchDeeplink,
                           controlSize: controlSize)
        case .moviesToWatch:
            deeplinkButton(systemImage: "checklist",
                           accessibilityLabel: "Open Movies To Watch",
                           destination: WatchingControlWidgetStorage.moviesToWatchDeeplink,
                           controlSize: controlSize)
        case .runShortcut:
            if let shortcut = entry.configuration.shortcut {
                actionButton(systemImage: "circle",
                             accessibilityLabel: "Run selected shortcut",
                             controlSize: controlSize,
                             foregroundStyle: .primary.opacity(0.9),
                             backgroundStyle: .primary.opacity(0.2),
                             intent: RunSystemShortcutIntent(shortcut: shortcut))
            } else {
                Image(systemName: "circle")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.primary.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.primary.opacity(0.08), in: Circle())
                    .contentShape(Circle())
                    .frame(width: controlSize, height: controlSize)
                    .accessibilityLabel("No shortcut selected")
            }
        }
    }

    private func deeplinkButton(systemImage: String,
                                accessibilityLabel: String,
                                destination: URL,
                                controlSize: CGFloat) -> some View {
        Link(destination: destination) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(.primary.opacity(0.8))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.primary.opacity(0.2), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: controlSize, height: controlSize)
        .accessibilityLabel(accessibilityLabel)
    }

    private func cancelButton(controlSize: CGFloat) -> some View {
        actionButton(systemImage: "xmark",
                     accessibilityLabel: "Cancel current check-in",
                     controlSize: controlSize,
                     foregroundStyle: .red.opacity(cancelIsEnabled ? 0.9 : 0.35),
                     backgroundStyle: .red.opacity(cancelIsEnabled ? 0.2 : 0.08),
                     intent: CancelWatchingControlWidgetIntent())
            .disabled(!cancelIsEnabled)
            .overlay {
                if let checkInProgress {
                    ZStack {
                        Circle()
                            .stroke(.primary.opacity(0.3), lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: checkInProgress)
                            .stroke(.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .padding(2)
                    .allowsHitTesting(false)
                }
            }
    }

    private func actionButton<Intent: AppIntent>(systemImage: String,
                                                 accessibilityLabel: String,
                                                 controlSize: CGFloat,
                                                 foregroundStyle: Color = .primary.opacity(0.8),
                                                 backgroundStyle: Color = .primary.opacity(0.2),
                                                 intent: Intent) -> some View {
        Button(intent: intent) {
            Image(systemName: systemImage)
                .font(.title3.weight(.medium))
                .foregroundStyle(foregroundStyle)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(backgroundStyle, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: controlSize, height: controlSize)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cancelIsEnabled: Bool {
        entry.item?.isCheckInActive == true
    }

    private var checkInProgress: Double? {
        guard let item = entry.item,
              item.isCheckInActive,
              let startDate = item.checkInStartDate,
              let endDate = item.checkInEndDate else { return nil }
        let duration = endDate.timeIntervalSince(startDate)
        guard duration > 0 else { return nil }
        return min(max(entry.date.timeIntervalSince(startDate) / duration, 0), 1)
    }

    private func accessibilityLabel(for item: WatchingControlWidgetItem) -> String {
        let details = item.subtitle.map { " \($0)" } ?? ""
        switch item.state {
        case .currentlyWatching:
            return "Currently watching \(item.title)\(details)"
        case .lastWatched:
            return "Last watched \(item.title)\(details)"
        case .nextEpisode:
            return "Next episode \(item.title)\(details)"
        }
    }
}

private extension WatchingControlWidgetItem {
    static let placeholder = WatchingControlWidgetItem(state: .currentlyWatching,
                                                       traktIdentifier: 0,
                                                       tmdbIdentifier: nil,
                                                       tmdbMediaType: "tv",
                                                       title: "Currently Watching",
                                                       subtitle: "S01E01",
                                                       deeplink: URL(string: "ripl://")!,
                                                       showTraktIdentifier: 0,
                                                       isCheckInActive: true,
                                                       checkInStartDate: .now.addingTimeInterval(-1800),
                                                       checkInEndDate: .now.addingTimeInterval(1800))
}
#endif
