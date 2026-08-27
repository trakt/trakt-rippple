//
//  WidgetModel.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

enum WidgetType: String {
    case lastWatched = "widget.lastWatched"
    case lastWatchedMovie = "widget.lastWatchedMovie"
    case lastWatchedShow = "widget.lastWatchedShow"
    case showsToWatch = "widget.showsToWatch"
    case moviesToWatch = "widget.moviesToWatch"
    case showsComing = "widget.showsComing"
    case moviesComing = "widget.moviesComing"

    case recommendedMovie = "widget.recommendedMovie"
    case trendingMovie = "widget.trendingMovie"
    case recommendedShow = "widget.recommendedShow"
    case trendingShow = "widget.trendingShow"

    case custom = "widget.custom"
}

struct WidgetModel: Identifiable, Codable, Equatable, Hashable {
    var label: String?
    var title: String?
    var subtitle: String?
    var image: URL?
    var behind: String?
    var redacted = false
    var deeplink: URL?

    var progress: Double?
    var runtime: Int?
    var endDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(image)
        hasher.combine(behind)
        hasher.combine(redacted)
        hasher.combine(deeplink)
        hasher.combine(label)

        hasher.combine(progress)
        hasher.combine(runtime)
        hasher.combine(endDate)
    }

    var id: Int {
        return hashValue
    }
}

struct ToWatchWidgetEpisode: Identifiable, Codable, Equatable {
    let episodeTraktIdentifier: Int
    let showTraktIdentifier: Int
    let showTMDbIdentifier: Int?
    let showTitle: String
    let seasonNumber: Int
    let episodeNumber: Int
    let runtime: Int?
    let behind: String?

    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 2
        return formatter
    }()

    var id: Int {
        episodeTraktIdentifier
    }

    var episodeDeeplink: URL {
        URL(string: "ripl://shows/\(showTraktIdentifier)/seasons/\(seasonNumber)/episodes/\(episodeNumber)")!
    }

    var showDeeplink: URL {
        URL(string: "ripl://shows/\(showTraktIdentifier)")!
    }

    var localizedEpisodeNumber: String {
        "S\(ToWatchWidgetEpisode.numberFormatter.string(from: NSNumber(value: seasonNumber))!)E\(ToWatchWidgetEpisode.numberFormatter.string(from: NSNumber(value: episodeNumber))!)"
    }

    var localizedEpisodeDetails: String {
        guard let runtime = runtime else { return localizedEpisodeNumber }
        return "\(localizedEpisodeNumber) · \(runtime)′"
    }
}

struct ToWatchWidgetMovie: Identifiable, Codable, Equatable {
    let movieTraktIdentifier: Int
    let movieTMDbIdentifier: Int?
    let title: String
    let releaseYear: Int?
    let runtime: Int?

    var id: Int {
        movieTraktIdentifier
    }

    var deeplink: URL {
        URL(string: "ripl://movies/\(movieTraktIdentifier)")!
    }

    var localizedDetails: String? {
        releaseYear.map(String.init)
    }
}

struct UpcomingWidgetItem: Identifiable, Codable, Equatable {
    let traktIdentifier: Int
    let tmdbIdentifier: Int?
    let tmdbMediaType: String
    let title: String
    let metadata: String
    let releaseDate: Date
    let deeplink: URL

    var id: String {
        "\(tmdbMediaType):\(traktIdentifier)"
    }
}

struct QuickAccessWidgetItem: Identifiable, Codable, Equatable {
    let traktIdentifier: Int
    let tmdbIdentifier: Int?
    let tmdbMediaType: String
    let title: String
    let deeplink: URL

    var id: String {
        "\(tmdbMediaType):\(traktIdentifier)"
    }
}

enum WatchingControlWidgetItemState: String, Codable {
    case currentlyWatching
    case lastWatched
    case nextEpisode
}

struct WatchingControlWidgetItem: Identifiable, Codable, Equatable {
    let state: WatchingControlWidgetItemState
    let traktIdentifier: Int
    let tmdbIdentifier: Int?
    let tmdbMediaType: String
    let title: String
    let subtitle: String?
    let deeplink: URL
    let showTraktIdentifier: Int?
    let isCheckInActive: Bool
    let checkInStartDate: Date?
    let checkInEndDate: Date?

    var id: String {
        "\(tmdbMediaType):\(traktIdentifier)"
    }
}

private enum WidgetCodableStorage {
    private static let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!

    static func items<Item: Decodable>(forKey key: String) -> [Item] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    static func publish<Item: Codable & Equatable>(_ items: [Item], forKey key: String) {
        guard items != self.items(forKey: key),
              let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }
}

enum ToWatchWidgetStorage {
    static let kind = "ToWatchWidget"
    static let episodeKey = "widget.episodesToWatch.list"
    static let movieKey = "widget.moviesToWatch.list"

    static func episodes() -> [ToWatchWidgetEpisode] {
        WidgetCodableStorage.items(forKey: episodeKey)
    }

    static func movies() -> [ToWatchWidgetMovie] {
        WidgetCodableStorage.items(forKey: movieKey)
    }

    static func publish(_ episodes: [ToWatchWidgetEpisode]) {
        WidgetCodableStorage.publish(episodes, forKey: episodeKey)
    }

    static func publish(_ movies: [ToWatchWidgetMovie]) {
        WidgetCodableStorage.publish(movies, forKey: movieKey)
    }
}

enum UpcomingWidgetStorage {
    static let kind = "UpcomingWidget"
    static let episodeKey = "widget.upcomingEpisodes.list"
    static let movieKey = "widget.upcomingMovies.list"

    static func episodes() -> [UpcomingWidgetItem] {
        WidgetCodableStorage.items(forKey: episodeKey)
    }

    static func movies() -> [UpcomingWidgetItem] {
        WidgetCodableStorage.items(forKey: movieKey)
    }

    static func publishEpisodes(_ items: [UpcomingWidgetItem]) {
        WidgetCodableStorage.publish(items, forKey: episodeKey)
    }

    static func publishMovies(_ items: [UpcomingWidgetItem]) {
        WidgetCodableStorage.publish(items, forKey: movieKey)
    }
}

enum QuickAccessWidgetStorage {
    static let kind = "QuickAccessWidget"
    static let trendingMediaKey = "widget.quickAccess.trending"
    static let trendingMoviesKey = "widget.quickAccess.trendingMovies"
    static let trendingShowsKey = "widget.quickAccess.trendingShows"

    static func trendingMedia() -> [QuickAccessWidgetItem] {
        WidgetCodableStorage.items(forKey: trendingMediaKey)
    }

    static func trendingMovies() -> [QuickAccessWidgetItem] {
        WidgetCodableStorage.items(forKey: trendingMoviesKey)
    }

    static func trendingShows() -> [QuickAccessWidgetItem] {
        WidgetCodableStorage.items(forKey: trendingShowsKey)
    }

    static func publishTrendingMedia(_ items: [QuickAccessWidgetItem]) {
        WidgetCodableStorage.publish(items, forKey: trendingMediaKey)
    }

    static func publishTrendingMovies(_ items: [QuickAccessWidgetItem]) {
        WidgetCodableStorage.publish(items, forKey: trendingMoviesKey)
    }

    static func publishTrendingShows(_ items: [QuickAccessWidgetItem]) {
        WidgetCodableStorage.publish(items, forKey: trendingShowsKey)
    }
}

enum WatchingControlWidgetStorage {
    static let kind = "WatchingControlWidget"
    static let dataKey = "widget.watchingControl.item"
    static let profileAvatarURLKey = "widget.watchingControl.profileAvatarURL"
    static let toWatchContainerDeeplink = URL(string: "ripl://towatch")!
    static let episodesToWatchDeeplink = URL(string: "ripl://towatch/episodes")!
    static let moviesToWatchDeeplink = URL(string: "ripl://towatch/movies")!
    static let profileDeeplink = URL(string: "ripl://users/me")!
    static let searchDeeplink = URL(string: "ripl://search")!

    static var profileAvatarURL: URL? {
        let urls: [URL] = WidgetCodableStorage.items(forKey: profileAvatarURLKey)
        return urls.first
    }

    static func item() -> WatchingControlWidgetItem? {
        let items: [WatchingControlWidgetItem] = WidgetCodableStorage.items(forKey: dataKey)
        return items.first
    }

    static func publish(_ item: WatchingControlWidgetItem?) {
        WidgetCodableStorage.publish(item.map { [$0] } ?? [], forKey: dataKey)
    }

    static func publishProfileAvatarURL(_ url: URL?) {
        WidgetCodableStorage.publish(url.map { [$0] } ?? [], forKey: profileAvatarURLKey)
    }
}

struct ActivityPunchcardWidgetDay: Codable, Equatable {
    let date: Date
    let activityCount: Int
}

enum ActivityPunchcardWidgetStorage {
    static let kind = "ActivityPunchcardWidget"
    static let dataKey = "widget.activityPunchcard.days"

    private static let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!
    private static let maximumStoredDayCount = 400

    static func activityCounts() -> [Date: Int] {
        guard let data = defaults.data(forKey: dataKey),
              let days = try? JSONDecoder().decode([ActivityPunchcardWidgetDay].self, from: data) else { return [:] }
        return Dictionary(days.map { ($0.date, $0.activityCount) }, uniquingKeysWith: +)
    }

    static func publish(_ activityCounts: [Date: Int], calendar: Calendar = .current) {
        guard let firstDate = calendar.date(byAdding: .day,
                                            value: -(maximumStoredDayCount - 1),
                                            to: calendar.startOfDay(for: .now)) else { return }
        let days = activityCounts.lazy
            .filter { $0.key >= firstDate && $0.value > 0 }
            .map { ActivityPunchcardWidgetDay(date: $0.key, activityCount: $0.value) }
            .sorted { $0.date < $1.date }
        guard let data = try? JSONEncoder().encode(days) else { return }
        defaults.set(data, forKey: dataKey)
    }
}

enum CalendarRelativeDateFormatter {
    static func string(for date: Date,
                       relativeTo referenceDate: Date = Date(),
                       unitsStyle: DateComponentsFormatter.UnitsStyle = .full,
                       uppercaseFirstLetter: Bool = false) -> String {
        let interval = date.timeIntervalSince(referenceDate)
        guard abs(interval) >= 1 else {
            return uppercaseFirstLetter ? "Now" : "now"
        }

        let component = completedComponent(for: date, relativeTo: referenceDate)
        let value = formattedValue(component.value, unit: component.unit, unitsStyle: unitsStyle)
        let formattedString = interval < 0 ? "\(value) ago" : "in \(value)"

        guard uppercaseFirstLetter else { return formattedString }
        return formattedString.prefix(1).uppercased() + String(formattedString.dropFirst())
    }

    private static func completedComponent(for date: Date, relativeTo referenceDate: Date) -> (value: Int, unit: NSCalendar.Unit) {
        let interval = date.timeIntervalSince(referenceDate)
        let absoluteInterval = abs(interval)

        let minute: TimeInterval = 60
        let hour = minute * 60
        let day = hour * 24

        if absoluteInterval < minute {
            return (max(1, Int(absoluteInterval)), .second)
        } else if absoluteInterval < hour * 2 {
            return (max(1, Int(absoluteInterval / minute)), .minute)
        } else if absoluteInterval < day * 2 {
            return (max(1, Int(absoluteInterval / hour)), .hour)
        } else if absoluteInterval < day * 14 {
            return (max(1, Int(absoluteInterval / day)), .day)
        }

        let earlierDate = interval < 0 ? date : referenceDate
        let laterDate = interval < 0 ? referenceDate : date
        let calendar = Calendar.current

        let years = calendar.dateComponents([.year], from: earlierDate, to: laterDate).year ?? 0
        if years >= 1 {
            return (years, .year)
        }

        let months = calendar.dateComponents([.month], from: earlierDate, to: laterDate).month ?? 0
        if months >= 1 {
            return (months, .month)
        }

        return (max(1, Int(absoluteInterval / (day * 7))), .weekOfMonth)
    }

    private static func formattedValue(_ value: Int,
                                       unit: NSCalendar.Unit,
                                       unitsStyle: DateComponentsFormatter.UnitsStyle) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = unit
        formatter.maximumUnitCount = 1
        formatter.unitsStyle = unitsStyle

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar

        var components = DateComponents()
        switch unit {
        case .second:
            components.second = value
        case .minute:
            components.minute = value
        case .hour:
            components.hour = value
        case .day:
            components.day = value
        case .weekOfMonth:
            components.weekOfMonth = value
        case .month:
            components.month = value
        case .year:
            components.year = value
        default:
            break
        }

        return formatter.string(from: components) ?? "\(value)"
    }
}
