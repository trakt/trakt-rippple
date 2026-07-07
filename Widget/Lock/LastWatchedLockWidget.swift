//
//  LastWatchedLockWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 20/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Intents
import SwiftUI
import WidgetKit

#if !targetEnvironment(macCatalyst)

struct RectangularLockProvider: TimelineProvider {
    typealias Entry = RectangularLockEntry

    var widgetType: WidgetType

    var placeholderProgress = WidgetModel(label: "Widget Preview",
                                          title: "Stranger Things",
                                          subtitle: "S04E07",
                                          image: nil,
                                          behind: nil,
                                          redacted: false)

    func placeholder(in context: Context) -> Entry {
        if let entry = decodeEntry(for: widgetType) {
            return entry
        }
        return Entry(date: Date(), progress: placeholderProgress)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        if let entry = decodeEntry(for: widgetType) {
            completion(entry)
            return
        }
        completion(Entry(date: Date(), progress: placeholderProgress))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        var entries = [Entry]()

        if var entry = decodeEntry(for: widgetType) {
            if let runtime = entry.progress.runtime, let endDate = entry.progress.endDate, endDate > Date.now {
                let now = Date.now.timeIntervalSinceReferenceDate
                let end = endDate.timeIntervalSinceReferenceDate
                let start = end - (Double(runtime) * 60.0)

                let currentProgress = (now - start) / (end - start)
                entry.date = Date.now
                entry.progress.label = "Now Watching"
                entry.progress.progress = currentProgress

                entries.append(entry)

                for i in stride(from: 2.5, to: 100, by: 2.5) {
                    let futureProgress = Double(i) / 100.0
                    let futureNow = start + ((end - start) * futureProgress)
                    entry.date = Date(timeIntervalSinceReferenceDate: futureNow)
                    entry.progress.label = "Now Watching"
                    entry.progress.progress = futureProgress
                    entries.append(entry)
                }

                entry.progress.label = "Last Watched"
                entry.date = endDate
                entry.progress.progress = nil
                entries.append(entry)
            } else {
                entries.append(entry)
            }
        } else {
            let errorProgress = WidgetModel(title: "Nothing Found",
                                            subtitle: "Nothing found for this kind of Widget right now.",
                                            image: nil,
                                            behind: nil)
            let entry = Entry(date: Date(),
                              progress: errorProgress)
            entries.append(entry)
        }

        completion(Timeline(entries: entries, policy: .after(Date.now.advanced(by: 60 * 60))))
    }

    private func decodeEntry(for type: WidgetType) -> Entry? {
        if let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple")!.object(forKey: type.rawValue) as? Data {
            if let progress = try? JSONDecoder().decode(WidgetModel.self, from: encodedData) {
                return Entry(date: Date(), progress: progress)
            }
        }
        return nil
    }
}

struct RectangularLockEntry: TimelineEntry {
    var date: Date
    var progress: WidgetModel
}

struct LastWatchedLockWidget: Widget {
    let kind: String = "LastWatchedLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .lastWatched)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Last Watched")
            .description("See the last watched or currently watching movie or episode.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct LastWatchedMovieLockWidget: Widget {
    let kind: String = "LastWatchedMovieLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .lastWatchedMovie)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Last Watched Movie")
            .description("See the last watched movie.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct LastWatchedShowLockWidget: Widget {
    let kind: String = "LastWatchedShowLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .lastWatchedShow)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Last Watched TV Show")
            .description("See the last watched TV show.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct ShowToWatchLockWidget: Widget {
    let kind: String = "ShowToWatchLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .showsToWatch)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Episode To Watch")
            .description("See the next episode to watch.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct MovieToWatchLockWidget: Widget {
    let kind: String = "MovieToWatchLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .moviesToWatch)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Movie To Watch")
            .description("See the next movie to watch.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct UpcomingShowLockWidget: Widget {
    let kind: String = "UpcomingShowLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .showsComing)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Hot & Upcoming TV Show")
            .description("See the next hot & upcoming TV show.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct UpcomingMovieLockWidget: Widget {
    let kind: String = "UpcomingMovieLock"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RectangularLockProvider(widgetType: .moviesComing)) { entry in
            RectangularLockEntryView(entry: entry)
        }.configurationDisplayName("Hot & Upcoming Movie")
            .description("See the next hot & upcoming movie.")
            .supportedFamilies([.accessoryRectangular])
    }
}

struct RectangularLockEntryView: View {
    var entry: RectangularLockProvider.Entry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                if let label = entry.progress.label {
                    Text(label)
                        .font(.caption2.uppercaseSmallCaps())
                        .foregroundColor(.white)
                }
                if let title = entry.progress.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                if let subtitle = entry.progress.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.init(white: 0.8))
                }
            }
            Spacer()
            if let progress = entry.progress.progress {
                VStack {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 3.0)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }.frame(maxWidth: 20, maxHeight: 20).padding(.trailing, 5)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .widgetURL(entry.progress.deeplink)
            .containerBackground(for: .widget) {}
    }
}

struct RectangularLockWidget_Previews: PreviewProvider {
    static var previews: some View {
        let progress = WidgetModel(label: "Now Watching",
                                   title: "The Room",
                                   subtitle: "S04E08",
                                   image: nil,
                                   behind: "2 behind",
                                   redacted: true,
                                   progress: 0.5)

        RectangularLockEntryView(entry: RectangularLockEntry(date: Date.now, progress: progress)).previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}

#endif
