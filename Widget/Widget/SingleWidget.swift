//
//  SingleWidget.swift
//  WidgetExtension
//
//  Created by Kevin Cador on 18/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import WidgetKit

import SwiftUI
import Intents

struct SingleWidgetProvider: IntentTimelineProvider {
    typealias Entry = SingleEntry

    var placeholderProgress = WidgetModel(label: "Widget Preview",
                                                title: "Stranger Things",
                            subtitle: "S04E08",
                            image: nil,
                            behind: "2 behind",
                            redacted: false)

    func placeholder(in context: Context) -> Entry {
        let uiImage = UIImage(named: "WidgetPreview")

        return Entry(date: Date(),
                     configuration: Intent(),
                     progress: placeholderProgress,
                     uiImage: uiImage)
    }

    func getSnapshot(for configuration: MediaWidgetIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        let uiImage = UIImage(named: "WidgetPreview")

        let entry = Entry(date: Date(),
                          configuration: configuration,
                          progress: placeholderProgress,
                          uiImage: uiImage)

        completion(entry)
    }

    private func decodeEntry(for type: WidgetType, configuration: MediaWidgetIntent, in context: Context) -> Entry? {
        if let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple")!.object(forKey: type.rawValue) as? Data {
            if let progress = try? JSONDecoder().decode(WidgetModel.self, from: encodedData) {
                guard let imageURL = progress.image else {
                    let entry = Entry(date: Date(),
                                      configuration: configuration,
                                      progress: progress,
                                      uiImage: nil)
                    return entry
                }
                guard let data = try? Data(contentsOf: imageURL) else {
                    let entry = Entry(date: Date(),
                                      configuration: configuration,
                                      progress: progress,
                                      uiImage: nil)
                    return entry
                }
                guard let uiImage = UIImage(data: data) else {
                    let entry = Entry(date: Date(),
                                      configuration: configuration,
                                      progress: progress,
                                      uiImage: nil)
                    return entry
                }

                let entry = Entry(date: Date(),
                                  configuration: configuration,
                                  progress: progress,
                                  uiImage: image(source: uiImage, in: context))
                return entry
            }
        }
        return nil
    }

    func getTimeline(for configuration: MediaWidgetIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        print("Getting Widget Timeline for configuration: \(configuration)")
        if configuration.type?.identifier == WidgetType.custom.rawValue {
            Task {
                let data = await TraktItemLoader().loadCachedMediaItem(from: URL(string: "\(TraktAPIConfiguration.baseURL)/search/tmdb/\(configuration.type!.tmdbId!)?extended=full&type=\(configuration.type!.tmdbType! == "tv" ? "show" : "movie")")!)

                let entries = await entries(for: data,
                                            and: configuration,
                                            in: context,
                                            adding: nil)
                
                var refreshDate = Date.now.advanced(by: data == nil ? 60 * 5 : 60 * 60)
                
                for entry in entries {
                    if let date = entry.progress.endDate, date < refreshDate {
                        refreshDate = date
                    }
                }
                completion(Timeline(entries: entries,
                                    policy: .after(refreshDate)))
            }
        } else if configuration.type?.identifier == WidgetType.trendingShow.rawValue {
            Task {
                let data = await TraktItemLoader().loadMediaItem(from: URL(string: "\(TraktAPIConfiguration.baseURL)/shows/trending?extended=full&page=1&limit=1")!)

                let entries = await entries(for: data,
                                            and: configuration,
                                            in: context,
                                            adding: "Trending Show")
                var refreshDate = Date.now.advanced(by: 60*60*3)
                for entry in entries {
                    if let date = entry.progress.endDate, date < refreshDate {
                        refreshDate = date
                    }
                }
                completion(Timeline(entries: entries,
                                    policy: .after(refreshDate)))
            }
        } else if configuration.type?.identifier == WidgetType.trendingMovie.rawValue {
            Task {
                let data = await TraktItemLoader().loadMediaItem(from: URL(string: "\(TraktAPIConfiguration.baseURL)/movies/trending?extended=full&page=1&limit=1")!)

                let entries = await entries(for: data,
                                            and: configuration,
                                            in: context,
                                            adding: "Trending Movie")
                var refreshDate = Date.now.advanced(by: 60*60*3)
                for entry in entries {
                    if let date = entry.progress.endDate, date < refreshDate {
                        refreshDate = date
                    }
                }
                completion(Timeline(entries: entries,
                                    policy: .after(refreshDate)))
            }
        } else if configuration.type?.identifier == WidgetType.recommendedShow.rawValue {
            Task {
                let data = await TraktItemLoader().loadMediaItem(from: URL(string: "\(TraktAPIConfiguration.baseURL)/shows/favorited/weekly/?extended=full&page=1&limit=1")!)

                let entries = await entries(for: data,
                                            and: configuration,
                                            in: context,
                                            adding: "Most Favorited Show")
                var refreshDate = Date.now.advanced(by: 60*60*3)
                for entry in entries {
                    if let date = entry.progress.endDate, date < refreshDate {
                        refreshDate = date
                    }
                }
                completion(Timeline(entries: entries,
                                    policy: .after(refreshDate)))
            }
        } else if configuration.type?.identifier == WidgetType.recommendedMovie.rawValue {
            Task {
                let data = await TraktItemLoader().loadMediaItem(from: URL(string: "\(TraktAPIConfiguration.baseURL)/movies/favorited/weekly/?extended=full&page=1&limit=1")!)

                let entries = await entries(for: data,
                                            and: configuration,
                                            in: context,
                                            adding: "Most Favorited Movie")
                var refreshDate = Date.now.advanced(by: 60*60*3)
                for entry in entries {
                    if let date = entry.progress.endDate, date < refreshDate {
                        refreshDate = date
                    }
                }
                completion(Timeline(entries: entries,
                                    policy: .after(refreshDate)))
            }
        } else {
            var entries = [Entry]()

            if let identifier = configuration.type?.identifier, let type = WidgetType(rawValue: identifier) {
                if var entry = decodeEntry(for: type, configuration: configuration, in: context) {
                    if let runtime = entry.progress.runtime, let endDate = entry.progress.endDate, endDate > Date.now {
                        let now = Date.now.timeIntervalSinceReferenceDate
                        let end = endDate.timeIntervalSinceReferenceDate
                        let start = end - (Double(runtime)*60.0)

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
                                      configuration: configuration,
                                      progress: errorProgress,
                                      uiImage: nil)
                    entries.append(entry)
                }
            } else {
                let errorProgress = WidgetModel(title: "Error",
                                                subtitle: "An unexpected error occurred.",
                                                image: nil,
                                                behind: nil)

                let entry = Entry(date: Date(),
                                  configuration: configuration,
                                  progress: errorProgress,
                                  uiImage: nil)
                entries.append(entry)
            }

            completion(Timeline(entries: entries, policy: .after(Date.now.advanced(by: 60*60))))
        }
    }

    private func imageWidthToGet(for context: Context) -> CGFloat {
        if context.displaySize.width > 900 {
            return 1280.0
        }
        return 780.0
    }

    private func image(source: UIImage, in context: Context) -> UIImage {
        if context.displaySize.width / context.displaySize.height < 1.2 {
            // Square-ish
            print("Squarish with scale \(UIImage(named: "WidgetPreview")!.scale)")
            return source.squared.scale(newWidth: context.displaySize.width)
        } else {
            // Rectangle
            print("Rectangle with scale \(UIImage(named: "WidgetPreview")!.scale)")
            return source.rected.scale(newWidth: context.displaySize.width)
        }
    }

    private func entries(for data: TraktItem?, and configuration: MediaWidgetIntent, in context: Context, adding title: String?) async -> [Entry] {
        var entries = [Entry]()

        var refreshDate: Date?

        if let movie = data?.movie {

            let loadedImage = await TMDbImageLoader().loadImage(for: movie.ids.tmdb,
                                                                type: "movie",
                                                                with: imageWidthToGet(for: context))

            if let released = movie.released {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                refreshDate = dateFormatter.date(from: released)
            }

            let widgetModel = WidgetModel(label: title,
                                          title: movie.title,
                                          subtitle: "\(movie.year ?? 1900)",
                                          image: nil,
                                          behind: (refreshDate != nil) ? "Coming..." : nil,
                                          deeplink: URL(string: "ripl://movies/\(movie.ids.trakt)"),
                                          endDate: refreshDate)

            let entry = Entry(date: Date(),
                              configuration: configuration,
                              progress: widgetModel,
                              uiImage: image(source: loadedImage ?? UIImage(), in: context))
            entries.append(entry)
        } else if let show = data?.show {
            let loadedImage = await TMDbImageLoader().loadImage(for: show.ids.tmdb,
                                                                type: "tv",
                                                                with: imageWidthToGet(for: context))

            let progress = await TraktItemLoader().loadProgress(from: URL(string: "\(TraktAPIConfiguration.baseURL)/shows/\(show.ids.trakt)/progress/watched?last_activity=watched")!)

            var behind: String?
            var subtitle: String?
            var deeplink = URL(string: "ripl://shows/\(show.ids.trakt)")
            if let progress = progress {
                let behindCount = progress.behind
                let toRewatchCount = progress.toRewatchCount
                let nextEpisodeToWatch = progress.nextEpisodeToWatch
                let nextEpisodeToRewtach = progress.nextEpisodeToRewtach
                if behindCount == 0 {
                    if nextEpisodeToWatch == nil {
                        if let status = show.status {
                            subtitle = "\(status.capitalized)"
                        }
                    }
                } else {
                    behind = "\(behindCount) behind"
                }
                if toRewatchCount > 0 {
                    behind = "\(toRewatchCount) to rewatch"
                }

                if let episodeToWatch = nextEpisodeToWatch {
                    if behindCount == 0 {
                        if let firstAirDate = await TraktItemLoader().loadEpisodeFirstAirDate(from: URL(string: "\(TraktAPIConfiguration.baseURL)/shows/\(show.ids.trakt)/seasons/\(episodeToWatch.season)/episodes/\(episodeToWatch.number)?extended=full")!) {
                            behind = "Coming..."
                            refreshDate = firstAirDate
                        }
                    }

                    subtitle = episodeToWatch.localizedEpisodeNumber
                    deeplink = URL(string: "ripl://shows/\(show.ids.trakt)/seasons/\(episodeToWatch.season)/episodes/\(episodeToWatch.number)")
                }
                if toRewatchCount > 0, let nextEpisodeToWatch = nextEpisodeToRewtach {
                    subtitle = nextEpisodeToWatch.localizedEpisodeNumber
                    deeplink = URL(string: "ripl://shows/\(show.ids.trakt)/seasons/\(nextEpisodeToWatch.season)/episodes/\(nextEpisodeToWatch.number)")
                }
                if nextEpisodeToWatch == nil, nextEpisodeToRewtach == nil, progress.completed == 0 {
                    if let firstEpisode = await TraktItemLoader().loadFirstEpisode(from: URL(string: "\(TraktAPIConfiguration.baseURL)/shows/\(show.ids.trakt)/seasons/1/episodes/1?extended=full")!) {
                        behind = "Coming..."
                        refreshDate = firstEpisode.firstAired
                        subtitle = firstEpisode.localizedEpisodeNumber
                        deeplink = URL(string: "ripl://shows/\(show.ids.trakt)/seasons/1/episodes/1")
                    }
                }
            }

            let widgetModel = WidgetModel(label: title,
                                          title: show.title,
                                          subtitle: subtitle,
                                          image: nil,
                                          behind: behind,
                                          deeplink: deeplink,
                                          endDate: refreshDate)

            let entry = Entry(date: Date(),
                              configuration: configuration,
                              progress: widgetModel,
                              uiImage: image(source: loadedImage ?? UIImage(), in: context))
            entries.append(entry)
        } else {
            if configuration.type?.identifier == WidgetType.custom.rawValue {
                let errorProgress = WidgetModel(title: "Nothing Found",
                                                subtitle: "Nothing found for this search. Try another one.",
                                                image: nil,
                                                behind: nil)

                let entry = Entry(date: Date(),
                                  configuration: configuration,
                                  progress: errorProgress,
                                  uiImage: nil)
                entries.append(entry)
            } else {
                let errorProgress = WidgetModel(title: title,
                                                subtitle: "Nothing found right now...",
                                                image: nil,
                                                behind: nil)

                let entry = Entry(date: Date(),
                                  configuration: configuration,
                                  progress: errorProgress,
                                  uiImage: nil)
                entries.append(entry)
            }
        }
        return entries
    }
}

struct SingleEntry: TimelineEntry {
    var date: Date
    let configuration: MediaWidgetIntent

    var progress: WidgetModel
    let uiImage: UIImage?
}

struct SingleWidget: Widget {
    let kind: String = "SingleWidget"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: MediaWidgetIntent.self, provider: SingleWidgetProvider()) { entry in
            SingleWidgetEntryView(progress: entry.progress, uiImage: entry.uiImage, configuration: entry.configuration)
        }.configurationDisplayName("Peek")
            .description("Get a peek at your last or currently watching, next or upcoming movie or TV show.")
            // .containerBackgroundRemovable(false)
            .contentMarginsDisabled()
    }
}

struct SingleWidgetEntryView: View {
    var progress: WidgetModel
    var uiImage: UIImage?
    var configuration: MediaWidgetIntent?

    @Environment(\.widgetRenderingMode) var widgetRenderingMode

    var body: some View {
        ZStack {
            if let uiImage = uiImage {
                if widgetRenderingMode == .fullColor {
                    Rectangle()
                        .foregroundStyle(.black)
                }
                VStack { Spacer() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(progress.redacted ? 0 : 1)
                    .background(
                        Image(uiImage: uiImage)
                            .resizable()
                            .widgetAccentedRenderingMode(.fullColor)
                            .grayscale(widgetRenderingMode == .fullColor ? 0 : 1)
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .opacity(widgetRenderingMode == .fullColor ? 1 : 0.45)
                            .mask {
                                if (configuration?.header?.boolValue ?? true && progress.label != nil) || configuration?.info?.boolValue ?? true || configuration?.title?.boolValue ?? true {
                                    Rectangle()
                                        .foregroundStyle(.linearGradient(colors: [.black.opacity(0.4), .black],
                                                                         startPoint: .bottomLeading,
                                                                         endPoint: .top))
                                } else {
                                    Rectangle()
                                        .foregroundStyle(.black)
                                }
                            }
                            .mask {
                                if progress.progress != nil {
                                    Rectangle()
                                        .foregroundStyle(.linearGradient(colors: [.black.opacity(0.4), .black, .black],
                                                                         startPoint: .bottomTrailing,
                                                                         endPoint: .top))
                                } else {
                                    Rectangle()
                                        .foregroundStyle(.black)
                                }
                            }
                    )
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading) {
                    Spacer()
                    if let label = progress.label, configuration?.header?.boolValue ?? true {
                        Text(label)
                            .font(.caption2.uppercaseSmallCaps().bold())
                            .foregroundColor(.white)
                            .opacity(0.8)
                            .shadow(radius: 0.5)
                            .redacted(reason: progress.redacted ? .placeholder : [])
                    }
                    if let title = progress.title, configuration?.title?.boolValue ?? true {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(radius: 0.5)
                            .redacted(reason: progress.redacted ? .placeholder : [])
                    }
                    if let subtitle = progress.subtitle, configuration?.info?.boolValue ?? true {
                        Text(subtitle)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .opacity(0.9)
                            .shadow(radius: 0.5)
                            .redacted(reason: progress.redacted ? .placeholder : [])
                    }
                    if let behind = progress.behind, configuration?.info?.boolValue ?? true {
                        if behind == "Coming...", let firstAirDate = progress.endDate {
                            if firstAirDate > Date.now {
                                Text("→ \(firstAirDate, style: .relative)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .opacity(0.9)
                                    .shadow(radius: 0.5)
                                    .redacted(reason: progress.redacted ? .placeholder : [])
                            }
                        } else {
                            Text(behind)
                                .font(.caption)
                                .foregroundColor(.white)
                                .opacity(0.9)
                                .shadow(radius: 0.5)
                                .redacted(reason: progress.redacted ? .placeholder : [])
                        }
                    }
                }
                Spacer()
                if let progress = progress.progress {
                    if configuration?.header?.boolValue ?? true || configuration?.title?.boolValue ?? true || configuration?.info?.boolValue ?? true {
                    }
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 3.0)
                            .opacity(0.3)
                            .widgetAccentable()
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }.frame(maxWidth: 20, maxHeight: 20)
                        .padding(.bottom, 3)
                }
            }.padding(14)
        }.widgetURL(progress.deeplink)
            .containerBackground(LinearGradient(colors: [Color(uiColor: .darkGray.darker(amount: 0.4)),
                                                         Color(uiColor: .darkGray.darker(amount: 0.6))],
                                                startPoint: .top,
                                                endPoint: .bottom),
                                 for: .widget)
    }
}

struct SingleWidget_Previews: PreviewProvider {
    static var previews: some View {
        let progress = WidgetModel(label: "Widget Preview",
                                title: "Stranger Things",
                                subtitle: "S04E08",
                                image: nil,
                                behind: "2 behind",
                                redacted: false,
                                   progress: 0.4)
        let uiImage: UIImage? = UIImage(named: "WidgetPreview")

        SingleWidgetEntryView(progress: progress, uiImage: uiImage)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}

struct TraktItemLoader {
    var session = URLSession.shared

    private static let cacheSuiteName = "group.tv.trakt.rippple"
    private static let tmdbSearchCacheKeyPrefix = "widget.search.tmdb.cache."
    private static let tmdbSearchCacheLifetime: TimeInterval = 60 * 60 * 3
    private static let tmdbSearchCleanupThreshold: TimeInterval = 60 * 60 * 24 * 30
    private static let tmdbSearchLastCleanupKey = "widget.search.tmdb.cache.lastCleanupAt"
    private static let tmdbSearchCleanupInterval: TimeInterval = 60 * 60 * 24

    private struct CachedTraktItem: Codable {
        let item: TraktItem
        let cachedAt: Date
    }

    private var userAgent: String {
        let bundle = Bundle.main
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Rippple"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(name)/\(version) (\(build))"
    }

    private func searchTMDbCacheKey(for url: URL) -> String {
        TraktItemLoader.tmdbSearchCacheKeyPrefix + url.absoluteString
    }

    private func cleanupOldTMDbSearchCacheEntries() {
        guard let defaults = UserDefaults(suiteName: TraktItemLoader.cacheSuiteName) else { return }

        let now = Date()
        if let lastCleanup = defaults.object(forKey: TraktItemLoader.tmdbSearchLastCleanupKey) as? Date,
           now.timeIntervalSince(lastCleanup) < TraktItemLoader.tmdbSearchCleanupInterval {
            return
        }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(TraktItemLoader.tmdbSearchCacheKeyPrefix) {
            guard let data = defaults.data(forKey: key),
                  let cached = try? JSONDecoder().decode(CachedTraktItem.self, from: data) else {
                defaults.removeObject(forKey: key)
                continue
            }

            if now.timeIntervalSince(cached.cachedAt) > TraktItemLoader.tmdbSearchCleanupThreshold {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(now, forKey: TraktItemLoader.tmdbSearchLastCleanupKey)
    }

    private func cachedMediaItem(for url: URL) -> CachedTraktItem? {
        guard let defaults = UserDefaults(suiteName: TraktItemLoader.cacheSuiteName),
              let data = defaults.data(forKey: searchTMDbCacheKey(for: url)),
              let cached = try? JSONDecoder().decode(CachedTraktItem.self, from: data) else {
            return nil
        }
        return cached
    }

    private func storeMediaItemInCache(_ item: TraktItem, for url: URL) {
        guard let defaults = UserDefaults(suiteName: TraktItemLoader.cacheSuiteName) else { return }
        let cached = CachedTraktItem(item: item, cachedAt: Date())
        guard let data = try? JSONEncoder().encode(cached) else { return }
        defaults.removeObject(forKey: searchTMDbCacheKey(for: url))
        defaults.set(data, forKey: searchTMDbCacheKey(for: url))
    }

    func loadCachedMediaItem(from url: URL) async -> TraktItem? {
        cleanupOldTMDbSearchCacheEntries()

        let cached = cachedMediaItem(for: url)

        if let cached, Date().timeIntervalSince(cached.cachedAt) <= TraktItemLoader.tmdbSearchCacheLifetime {
            return cached.item
        }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            let mediaItem = try decoder.decode([TraktItem].self, from: data).first

            if let mediaItem, mediaItem.movie != nil || mediaItem.show != nil {
                storeMediaItemInCache(mediaItem, for: url)
                return mediaItem
            }

            // Network succeeded but wasn't usable: keep stale/invalid cache as fallback.
            return cached?.item ?? mediaItem
        } catch {
            // Network failed: keep stale/invalid cache as fallback.
            return cached?.item
        }
    }

    func loadMediaItem(from url: URL) async -> TraktItem? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            return try decoder.decode([TraktItem].self, from: data).first
        } catch {
            return nil
        }
    }

    func loadProgress(from url: URL) async -> TraktShowProgress? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            guard let accessToken = KeychainStore.accessToken() else {
                return nil
            }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            return try decoder.decode(TraktShowProgress.self, from: data)
        } catch {
            return nil
        }
    }

    func loadEpisodeFirstAirDate(from url: URL) async -> Date? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            return try decoder.decode(TraktEpisode.self, from: data).firstAired
        } catch {
            return nil
        }
    }

    func loadFirstEpisode(from url: URL) async -> TraktEpisode? {
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

            let (data, _) = try await session.data(for: request)
            let decoder = JSONDecoder()
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            decoder.dateDecodingStrategy = .formatted(formatter)
            return try decoder.decode(TraktEpisode.self, from: data)
        } catch {
            return nil
        }
    }
}

struct TraktShowProgress: Codable {
    let aired: Int
    let completed: Int
    let lastWatchedAt: Date?
    let nextEpisodeToWatch: TraktEpisode?
    let resetAt: Date?
    let seasons: [TraktSeasonProgress]
    let lastEpisode: TraktEpisode?

    enum CodingKeys: String, CodingKey {
        case lastWatchedAt = "last_watched_at"
        case nextEpisodeToWatch = "next_episode"
        case resetAt = "reset_at"
        case aired
        case seasons
        case completed
        case lastEpisode = "last_episode"
    }

    var toRewatchCount: Int {
        guard let resetDate = resetAt else { return 0 }
        var index = 0
        for season in seasons {
            for episode in season.episodes {
                if let lastWatchedDate = episode.lastWatchedAt {
                    if lastWatchedDate < resetDate {
                        index += 1
                    }
                }
            }
        }
        return index
    }

    var nextToRewtach: (TraktSeasonProgress, TraktEpisodeProgress)? {
        guard let resetDate = resetAt else { return nil }
        for season in seasons {
            for episode in season.episodes {
                if let lastWatchedDate = episode.lastWatchedAt {
                    if lastWatchedDate < resetDate {
                        return (season, episode)
                    }
                }
            }
        }
        return nil
    }

    var nextEpisodeToRewtach: TraktEpisode? {
        guard let nextToRewtach = nextToRewtach else {
            return nil
        }
        return TraktEpisode(season: nextToRewtach.0.number,
                            number: nextToRewtach.1.number,
                            firstAired: nil)
    }

    var behind: Int {
        let toRawatchCount = toRewatchCount
        if toRawatchCount > 0 { return toRawatchCount }

        var behind = 0
        for season in seasons {
            for episode in season.episodes {
                if !episode.completed {
                    behind += 1
                }
                if let nextEpisodeToWatch = nextEpisodeToWatch, episode.number == nextEpisodeToWatch.number, season.number == nextEpisodeToWatch.season {
                    // this is the next episode to watch (we restart counting from 1)
                    behind = 1
                }
            }
        }
        return behind
    }
}

struct TraktSeasonProgress: Codable, Hashable {
    let number: Int
    let aired: Int
    let completed: Int
    let episodes: [TraktEpisodeProgress]
}

struct TraktEpisodeProgress: Codable, Hashable {
    let number: Int
    let completed: Bool
    let lastWatchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case lastWatchedAt = "last_watched_at"
        case number
        case completed
    }
}

struct TraktEpisode: Codable {
    private static let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 2
        return numberFormatter
    }()

    let season: Int
    let number: Int

    let firstAired: Date?

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case number
        case season
    }

    var localizedEpisodeNumber: String {
        return "S\(TraktEpisode.numberFormatter.string(from: NSNumber(value: season))!)E\(TraktEpisode.numberFormatter.string(from: NSNumber(value: number))!)"
    }
}

struct TraktItem: Codable {
    let movie: TraktMovie?
    let show: TraktShow?
}

struct TraktMovie: Codable {
    let title: String?
    let year: Int?
    let ids: TraktIdentifier
    let released: String?
}

struct TraktIdentifier: Codable {
    let trakt: Int64
    let tmdb: Int64
}

struct TraktShow: Codable {
    let title: String?
    let ids: TraktIdentifier
    let status: String?
}

struct TMDbConfiguration: Codable {
    let images: TMDbImagesConfiguration
}

struct TMDbImagesConfiguration: Codable {
    let baseURL: String
    let backdropSizes: [String]
    let posterSizes: [String]

    enum CodingKeys: String, CodingKey {
        case baseURL = "secure_base_url"
        case backdropSizes = "backdrop_sizes"
        case posterSizes = "poster_sizes"
    }
}

struct TMDbPostersImages: Codable {
    let id: Int64
    let backdrops: [TMDbImage]
    let posters: [TMDbImage]
}

struct TMDbImage: Codable {
    let filePath: String
    let language: String?
    let voteAverage: Double?
    let voteCount: Int?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case language = "iso_639_1"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
    }
}

struct TMDbImageLoader {
    var session = URLSession.shared

    func loadImage(for tmdbId: Int64, type: String, with width: CGFloat) async -> UIImage? {
        do {
            let (configurationData, _) = try await session.data(from: URL(string: "https://api.themoviedb.org/3/configuration?api_key=\(TmdbAPIConfiguration.apiKey)")!)
            let decoder = JSONDecoder()
            let configuration = try decoder.decode(TMDbConfiguration.self, from: configurationData)

            let (imagesData, _) = try await session.data(from: URL(string: "https://api.themoviedb.org/3/\(type)/\(tmdbId)/images?api_key=\(TmdbAPIConfiguration.apiKey)")!)
            let images = try decoder.decode(TMDbPostersImages.self, from: imagesData)

            // first, we check for the first backdrop without a language because they are usually better
            for backdrop in images.backdrops where backdrop.language == nil {
                for posterSize in configuration.images.backdropSizes where posterSize.hasPrefix("w") {
                    if let posterWidth = Float(posterSize.dropFirst()) {
                        if posterWidth >= Float(width) {
                            let (image, _) = try await session.data(from: URL(string: "\(configuration.images.baseURL)\(posterSize)/\(backdrop.filePath)")!)
                            return UIImage(data: image)
                        }
                    }
                }
            }

            // then we try any language
            for backdrop in images.backdrops {
                for posterSize in configuration.images.backdropSizes where posterSize.hasPrefix("w") {
                    if let posterWidth = Float(posterSize.dropFirst()) {
                        if posterWidth >= Float(width) {
                            let (image, _) = try await session.data(from: URL(string: "\(configuration.images.baseURL)\(posterSize)/\(backdrop.filePath)")!)
                            return UIImage(data: image)
                        }
                    }
                }
            }

            // if we don't have a backdrop, we take the poster
            if let firstPoster = images.posters.first {
                for posterSize in configuration.images.posterSizes {
                    if let posterWidth = Float(posterSize.dropFirst()) {
                        if posterWidth >= Float(width) {
                            let (image, _) = try await session.data(from: URL(string: "\(configuration.images.baseURL)\(posterSize)/\(firstPoster.filePath)")!)
                            return UIImage(data: image)
                        }
                    } else {
                        let (image, _) = try await session.data(from: URL(string: "\(configuration.images.baseURL)\(posterSize)/\(firstPoster.filePath)")!)
                        return UIImage(data: image)
                    }
                }
            }

            return nil
        } catch {
            return nil
        }
    }
}

extension UIImage {
    func scale(newWidth: CGFloat) -> UIImage {
        if newWidth >= self.size.width { return self }

        let scaleFactor = newWidth / self.size.width

        let newHeight = self.size.height * scaleFactor
        let newSize = CGSize(width: newWidth, height: newHeight)

        UIGraphicsBeginImageContextWithOptions(newSize, true, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        let newImage: UIImage? = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }

    var squared: UIImage {
        guard let cgImage = cgImage else { return self }
        let length = cgImage.height
        let x = cgImage.width / 2 - length / 2
        let y = cgImage.height / 2 - length / 2
        let cropRect = CGRect(x: x, y: y, width: length, height: length)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {  return self }
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
    }

    var rected: UIImage {
        guard let cgImage = cgImage else { return self }
        let height = cgImage.width/2
        let cropRect = CGRect(x: 0,
                              y: cgImage.height/2 - height/2,
                              width: cgImage.width,
                              height: height)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {  return self }
        return UIImage(cgImage: croppedCGImage, scale: scale, orientation: imageOrientation)
    }
}
