//
//  SmartListSentence.swift
//  Rippple
//
//  Created by Kevin Cador on 30/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import LRUCache
import Moya
import UIKit

/// The plain English sentence describing a smart list everywhere in the app, e.g. "A smart list with Movies that are
/// currently Trending and released in 2026." The builder turns its words into menus; list cards show them in bold.
struct SmartListSentence {
    /// What a highlighted word of the sentence stands for.
    enum Token {
        case mediaType
        case source
        case value(SmartListConditions.ValueCondition, String)
        case matchOperator(WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>)
        case singleValue(SmartListConditions.RangeCondition, Double)
        case lowerBound(SmartListConditions.RangeCondition, lower: Double, upper: Double)
        case upperBound(SmartListConditions.RangeCondition, lower: Double, upper: Double)
        case parental(SmartListConditions.ParentalCondition, level: Int)
        case includeUnrated
        case hidden(SmartListConditions.HideCondition)
    }

    enum Segment {
        case text(String)
        case token(String, Token)
    }

    private(set) var segments = [Segment]()

    init(source: SmartListSource, mediaType: SmartListMediaType, filters: SmartListFilters) {
        text("A smart list with ")
        token(mediaType.title, .mediaType)
        appendSource(source)

        let clauses = SmartListSentence.clauses(for: filters)
        for (index, clause) in clauses.enumerated() {
            text(index == clauses.count - 1 ? " and" : ",")
            segments += clause
        }
        text(".")
    }

    init(smartList: SmartList) {
        self.init(source: smartList.source, mediaType: smartList.mediaType, filters: smartList.filters)
    }

    /// The sentence without formatting, for subtitles and other plain text.
    var string: String {
        segments.map { segment in
            switch segment {
            case .text(let text), .token(let text, _):
                return text
            }
        }.joined()
    }

    /// Renders the sentence with regular words and highlighted conditions.
    func attributedString(regular: [NSAttributedString.Key: Any], highlighted: [NSAttributedString.Key: Any]) -> NSMutableAttributedString {
        let string = NSMutableAttributedString()
        for segment in segments {
            switch segment {
            case .text(let text):
                string.append(NSAttributedString(string: text, attributes: regular))
            case .token(let text, _):
                string.append(NSAttributedString(string: text, attributes: highlighted))
            }
        }
        return string
    }

    private mutating func text(_ string: String) {
        segments.append(.text(string))
    }

    private mutating func token(_ string: String, _ token: Token) {
        segments.append(.token(string, token))
    }

    private mutating func appendSource(_ source: SmartListSource) {
        switch source {
        case .trending:
            text(" that are currently ")
            token("Trending", .source)
        case .popular:
            text(" that are ")
            token("Popular", .source)
        case .anticipated:
            text(" that are the most ")
            token("Anticipated", .source)
        case .recommendations:
            text(" that are ")
            token("Recommended", .source)
        case .discover, .unknown:
            // Not offered by the builder: shown for lists created elsewhere so their source can be changed.
            text(" from ")
            token(source == .discover ? "Discover" : "an unknown source", .source)
        case .watchlist:
            text(" from the ")
            token("Watchlist", .source)
        case .library:
            text(" from the ")
            token("Library", .source)
        }
    }

    private static func clauses(for filters: SmartListFilters) -> [[Segment]] {
        var clauses = [[Segment]]()

        for condition in SmartListConditions.values {
            guard let values = filters[keyPath: condition.keyPath], values.isEmpty == false else { continue }
            let matchesAll = condition.operatorKeyPath.map { filters[keyPath: $0] == .and } ?? false
            var clause: [Segment] = [.text(condition.prefix)]
            for (index, value) in values.enumerated() {
                if index > 0 {
                    if let operatorKeyPath = condition.operatorKeyPath {
                        clause += [.text(" "), .token(matchesAll ? "and" : "or", .matchOperator(operatorKeyPath)), .text(" ")]
                    } else {
                        clause.append(.text(" or "))
                    }
                }
                clause.append(.token(condition.format(value), .value(condition, value)))
            }
            clause.append(.text(values.count > 1 ? condition.pluralSuffix : condition.suffix))
            clauses.append(clause)
        }

        for condition in SmartListConditions.ranges {
            guard let range = condition.get(filters), let lower = range.first else { continue }
            let upper = range.count > 1 ? range[1] : lower
            if lower == upper {
                clauses.append([.text(condition.singlePrefix),
                                .token(condition.format(lower), .singleValue(condition, lower)),
                                .text(condition.suffix)])
            } else {
                clauses.append([.text(condition.rangePrefix),
                                .token(condition.format(lower), .lowerBound(condition, lower: lower, upper: upper)),
                                .text(" and "),
                                .token(condition.format(upper), .upperBound(condition, lower: lower, upper: upper)),
                                .text(condition.suffix)])
            }
        }

        for condition in SmartListConditions.parental {
            guard let range = filters[keyPath: condition.keyPath], let last = range.last else { continue }
            let level = Int(last)
            let severities = SmartListConditions.severities
            let severity = severities.indices.contains(level) ? severities[level] : "severe"
            clauses.append([.text(level == 0 ? " with " : " with at most "),
                            .token(level == 0 ? "no" : severity, .parental(condition, level: level)),
                            .text(" \(condition.noun)")])
        }

        if filters.parentalIncludeUnrated == true {
            clauses.append([.text(" including titles "), .token("without a parents guide", .includeUnrated)])
        }

        for condition in SmartListConditions.hidden where filters[keyPath: condition.keyPath] == true {
            clauses.append([.text(condition.prefix), .token(condition.token, .hidden(condition))])
        }
        return clauses
    }
}

// MARK: - Conditions

/// The conditions a smart list sentence can contain, in the order they read.
enum SmartListConditions {
    static let currentYear = Calendar.current.component(.year, from: Date())

    struct ValueCondition {
        let title: String
        let symbol: String
        let keyPath: WritableKeyPath<SmartListFilters, [String]?>
        var operatorKeyPath: WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>?
        let prefix: String
        var suffix = ""
        var pluralSuffix = ""
        let format: (String) -> String
        /// `nil` for values that can be kept or removed but not picked, such as subgenres and keywords.
        let load: ((SmartListMediaType) async throws -> [SmartListChoice])?
        var isAvailable: (SmartListMediaType) -> Bool = { _ in true }
    }

    struct RangeCondition {
        let title: String
        let get: (SmartListFilters) -> [Double]?
        let set: (inout SmartListFilters, [Double]?) -> Void
        let singlePrefix: String
        let rangePrefix: String
        var suffix = ""
        let values: [Double]
        let initial: [Double]
        let format: (Double) -> String
    }

    struct ParentalCondition {
        let title: String
        let noun: String
        let keyPath: WritableKeyPath<SmartListFilters, [Double]?>
    }

    struct HideCondition {
        let title: String
        let prefix: String
        let token: String
        let keyPath: WritableKeyPath<SmartListFilters, Bool?>
        var isAvailable: (SmartListMediaType) -> Bool = { _ in true }
    }

    static let severities = ["none", "mild", "moderate", "severe"]

    static let values: [ValueCondition] = [
        ValueCondition(title: "Genres", symbol: "theatermasks", keyPath: \.genres, operatorKeyPath: \.genresOperator,
                       prefix: " in the ", suffix: " genre", pluralSuffix: " genres",
                       format: { $0.smartListTitle }, load: SmartListChoices.genres),
        ValueCondition(title: "Subgenres", symbol: "theatermasks", keyPath: \.subgenres,
                       prefix: " in the ", suffix: " subgenre", pluralSuffix: " subgenres",
                       format: { $0.smartListTitle }, load: nil),
        ValueCondition(title: "Keywords", symbol: "tag", keyPath: \.keywords, operatorKeyPath: \.keywordsOperator,
                       prefix: " about ", format: { $0 }, load: nil),
        ValueCondition(title: "Certifications", symbol: "checkmark.seal", keyPath: \.certifications,
                       prefix: " with a ", suffix: " certification", pluralSuffix: " certification",
                       format: { $0 == "nr" ? "No Certification" : $0.uppercased() }, load: SmartListChoices.certifications),
        ValueCondition(title: "Status", symbol: "antenna.radiowaves.left.and.right", keyPath: \.statuses,
                       prefix: " with a ", suffix: " status", pluralSuffix: " status",
                       format: { $0.smartListTitle }, load: { SmartListChoices.statuses(for: $0) }),
        ValueCondition(title: "Networks", symbol: "tv", keyPath: \.networks,
                       prefix: " released on ", format: { $0 }, load: SmartListChoices.networks,
                       isAvailable: { $0.includesShows }),
        ValueCondition(title: "Countries", symbol: "globe", keyPath: \.countries,
                       prefix: " released in ",
                       format: { SmartListChoices.locale.localizedString(forRegionCode: $0) ?? $0.uppercased() }, load: SmartListChoices.countries),
        ValueCondition(title: "Languages", symbol: "character.bubble", keyPath: \.languages,
                       prefix: " where the original language is ",
                       format: { SmartListChoices.locale.localizedString(forLanguageCode: $0) ?? $0 }, load: SmartListChoices.languages),
        ValueCondition(title: "Where to Watch", symbol: "play.tv", keyPath: \.watchnow,
                       prefix: " streaming ", format: SmartListChoices.watchNowTitle, load: { _ in await SmartListChoices.watchNowChoices() })
    ]

    static let ranges: [RangeCondition] = {
        let percent = { (value: Double) in "\(Int(value))%" }
        let decimal = { (value: Double) in value.formatted(.number.precision(.fractionLength(1))) }
        let integers = { (keyPath: WritableKeyPath<SmartListFilters, [Int]?>) -> ((SmartListFilters) -> [Double]?, (inout SmartListFilters, [Double]?) -> Void) in
            ({ $0[keyPath: keyPath]?.map(Double.init) },
             { $0[keyPath: keyPath] = ($1?.isEmpty ?? true) ? nil : $1?.map { Int($0.rounded()) } })
        }
        let decimals = { (keyPath: WritableKeyPath<SmartListFilters, [Double]?>) -> ((SmartListFilters) -> [Double]?, (inout SmartListFilters, [Double]?) -> Void) in
            ({ $0[keyPath: keyPath] }, { $0[keyPath: keyPath] = ($1?.isEmpty ?? true) ? nil : $1 })
        }
        let year = Double(currentYear)
        let years = integers(\.years)
        let runtimes = integers(\.runtimes)
        let ratings = integers(\.ratings)
        let rtMeters = integers(\.rtMeters)
        let rtUserMeters = integers(\.rtUserMeters)
        let imdb = decimals(\.imdbRatings)
        let letterboxd = decimals(\.letterboxdRatings)
        let mal = decimals(\.malRatings)
        return [
            // Release years stay first: the Release Date menu edits them.
            RangeCondition(title: "Release Year", get: years.0, set: years.1,
                           singlePrefix: " released in ", rangePrefix: " released between ",
                           values: Array(stride(from: 1900, through: year + 2, by: 1)), initial: [year - 10, year],
                           format: { "\(Int($0))" }),
            RangeCondition(title: "Runtime", get: runtimes.0, set: runtimes.1,
                           singlePrefix: " with a runtime of ", rangePrefix: " with a runtime between ",
                           values: Array(stride(from: 0, through: 300, by: 10)), initial: [60, 150],
                           format: { "\(Int($0))‘" }),
            RangeCondition(title: "Trakt Rating", get: ratings.0, set: ratings.1,
                           singlePrefix: " with a Trakt rating of ", rangePrefix: " with a Trakt rating between ",
                           values: Array(stride(from: 0, through: 100, by: 5)), initial: [75, 100], format: percent),
            RangeCondition(title: "IMDb Rating", get: imdb.0, set: imdb.1,
                           singlePrefix: " with an IMDb rating of ", rangePrefix: " with an IMDb rating between ",
                           values: Array(stride(from: 0, through: 10, by: 0.5)), initial: [7, 10], format: decimal),
            RangeCondition(title: "Rotten Tomatoes Critics", get: rtMeters.0, set: rtMeters.1,
                           singlePrefix: " with a Rotten Tomatoes score of ", rangePrefix: " with a Rotten Tomatoes score between ",
                           values: Array(stride(from: 0, through: 100, by: 5)), initial: [75, 100], format: percent),
            RangeCondition(title: "Rotten Tomatoes Audience", get: rtUserMeters.0, set: rtUserMeters.1,
                           singlePrefix: " with a Rotten Tomatoes audience score of ", rangePrefix: " with a Rotten Tomatoes audience score between ",
                           values: Array(stride(from: 0, through: 100, by: 5)), initial: [75, 100], format: percent),
            RangeCondition(title: "Letterboxd Rating", get: letterboxd.0, set: letterboxd.1,
                           singlePrefix: " with a Letterboxd rating of ", rangePrefix: " with a Letterboxd rating between ",
                           values: Array(stride(from: 0, through: 5, by: 0.5)), initial: [3.5, 5], format: decimal),
            RangeCondition(title: "MyAnimeList Rating", get: mal.0, set: mal.1,
                           singlePrefix: " with a MyAnimeList rating of ", rangePrefix: " with a MyAnimeList rating between ",
                           values: Array(stride(from: 0, through: 10, by: 0.5)), initial: [7, 10], format: decimal)
        ]
    }()

    static let parental = [
        ParentalCondition(title: "Sex & Nudity", noun: "sex & nudity", keyPath: \.parentalNudity),
        ParentalCondition(title: "Violence & Gore", noun: "violence & gore", keyPath: \.parentalViolence),
        ParentalCondition(title: "Profanity", noun: "profanity", keyPath: \.parentalProfanity),
        ParentalCondition(title: "Alcohol, Drugs & Smoking", noun: "alcohol, drugs & smoking", keyPath: \.parentalAlcohol),
        ParentalCondition(title: "Frightening & Intense Scenes", noun: "frightening & intense scenes", keyPath: \.parentalFrightening)
    ]

    static let hidden = [
        HideCondition(title: "Watched", prefix: " that ", token: "aren't already watched", keyPath: \.ignoreWatched),
        HideCondition(title: "Watchlisted", prefix: " that ", token: "aren't watchlisted", keyPath: \.ignoreWatchlisted),
        HideCondition(title: "Currently Watching", prefix: " that ", token: "aren't currently being watched", keyPath: \.ignoreWatching,
                      isAvailable: { $0.includesShows }),
        HideCondition(title: "Unreleased", prefix: " that are ", token: "already released", keyPath: \.ignoreUnreleased),
        HideCondition(title: "Released", prefix: " that are ", token: "not released yet", keyPath: \.ignoreReleased),
        HideCondition(title: "Ended Shows", prefix: " that ", token: "haven't ended", keyPath: \.ignoreEnded,
                      isAvailable: { $0.includesShows }),
        HideCondition(title: "Airing Shows", prefix: " that ", token: "aren't airing", keyPath: \.ignoreAiring,
                      isAvailable: { $0.includesShows }),
        HideCondition(title: "Without a Release Date", prefix: " that ", token: "have a release date", keyPath: \.ignoreNoReleaseDate)
    ]
}

// MARK: - Choices

struct SmartListChoice: Hashable {
    struct Group: Hashable {
        let title: String
        /// Long groups such as every country read better split by letter. Short or ranked ones stay a plain list.
        var groupsByLetter = false
    }

    let value: String
    let title: String
    var subtitle: String?
    /// Quick picks are offered in their own section, after the other ungrouped choices.
    var isQuickPick = false
    /// Grouped choices are offered in a submenu, after the ungrouped ones.
    var group: Group?
}

enum SmartListChoices {
    static let locale = Locale(identifier: "en_US")

    static let watchNow = [SmartListChoice(value: "favorites", title: "On Favorite Services", subtitle: "Your favorite streaming services"),
                           SmartListChoice(value: "subscriptions", title: "With a Subscription", subtitle: "Any subscription service in your country"),
                           SmartListChoice(value: "free", title: "For Free", subtitle: "Free services in your country"),
                           SmartListChoice(value: "any", title: "Anywhere", subtitle: "Any service in your country")]

    /// Service names by source, filled when services load so the sentence reads "on Disney+" rather than "on Disney Plus".
    private static let watchNowServiceNames = LRUCache<String, String>(countLimit: 1000)

    /// Reads within the sentence, e.g. "streaming with a subscription" or "streaming on Netflix".
    static func watchNowTitle(for value: String) -> String {
        watchNow.first { $0.value == value }?.title.lowercased() ?? "on \(watchNowServiceNames.value(forKey: value) ?? value.smartListTitle)"
    }

    /// The broad options, then the services available in the user's watch now country. Services are optional:
    /// the broad options are still offered when they cannot be loaded.
    static func watchNowChoices() async -> [SmartListChoice] {
        guard let country = (UserManager.shared.currentUserWatchNowCountry ?? Locale.current.region?.identifier)?.lowercased(),
              let sources = try? await request(.watchNowSources(country: country), decode: { response in
                  try response.map([[String: [WatchNowSource]]].self, using: TraktAPIProvider.decoder)
                      .flatMap { $0[country] ?? [] }
              }) else { return watchNow }

        var seen = Set<String>()
        let services = sources.filter { seen.insert($0.source).inserted }
        for service in services {
            watchNowServiceNames.setValue(service.name, forKey: service.source)
        }
        // The largest catalogs are offered first, then every service by letter, in the order Trakt returns them.
        let quickPicks = services
            .sorted { ($0.linkCount ?? 0) > ($1.linkCount ?? 0) }
            .prefix(5)
            .map { SmartListChoice(value: $0.source, title: $0.name, isQuickPick: true) }
        let group = SmartListChoice.Group(title: "All Services in \(locale.localizedString(forRegionCode: country) ?? country.uppercased())",
                                          groupsByLetter: true)
        return watchNow + quickPicks + services.map { SmartListChoice(value: $0.source, title: $0.name, group: group) }
    }

    /// Popular values are offered first, without duplicates, then every choice split by letter.
    private static func withQuickPicks(_ values: [String], allTitle: String, in choices: [SmartListChoice]) -> [SmartListChoice] {
        let quickPicks = values.removingDuplicates().compactMap { value in choices.first { $0.value == value } }.map { choice -> SmartListChoice in
            var quickPick = choice
            quickPick.isQuickPick = true
            return quickPick
        }
        let group = SmartListChoice.Group(title: allTitle, groupsByLetter: true)
        return quickPicks + choices.map { choice -> SmartListChoice in
            var grouped = choice
            grouped.group = group
            return grouped
        }
    }

    static func genres(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        try await choices(for: mediaType, movies: .movieGenres, shows: .tvGenres) { response in
            try response.map([Genre].self, using: TraktAPIProvider.decoder).map { SmartListChoice(value: $0.slug, title: $0.name) }
        }
    }

    static func certifications(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        try await choices(for: mediaType, movies: .movieCertifications, shows: .tvCertifications) { response in
            try response.map(CertificationsCounties.self, using: TraktAPIProvider.decoder).us.map {
                SmartListChoice(value: $0.slug, title: $0.name, subtitle: $0.description)
            }
        }
    }

    static func languages(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        let languages = try await choices(for: mediaType, movies: .movieLanguages, shows: .tvLanguages) { response in
            try response.map([Language].self, using: TraktAPIProvider.decoder).compactMap { language in
                SmartListChoices.locale.localizedString(forLanguageCode: language.code).map { SmartListChoice(value: language.code, title: $0) }
            }
        }
        // The device languages, then among the most common original languages of movies and shows.
        let deviceLanguages = Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier.lowercased() }
        return withQuickPicks(deviceLanguages + ["en", "es", "fr", "ja", "ko"], allTitle: "All Languages", in: languages)
    }

    static func countries(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        // Countries share the language payload shape.
        let countries = try await choices(for: mediaType, movies: .movieCountries, shows: .tvCountries) { response in
            try response.map([Language].self, using: TraktAPIProvider.decoder).compactMap { country in
                SmartListChoices.locale.localizedString(forRegionCode: country.code).map { SmartListChoice(value: country.code, title: $0) }
            }
        }
        // The device region, then among the countries producing the most movies and shows.
        let deviceCountries = [Locale.current.region?.identifier.lowercased()].compactMap { $0 }
        return withQuickPicks(deviceCountries + ["us", "gb", "fr", "jp", "kr"], allTitle: "All Countries", in: countries)
    }

    static func networks(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        try await choices(for: mediaType, movies: nil, shows: .networks) { response in
            try response.map([Network].self, using: TraktAPIProvider.decoder).map { SmartListChoice(value: $0.name, title: $0.name) }
        }
    }

    static func statuses(for mediaType: SmartListMediaType) -> [SmartListChoice] {
        var values = [String]()
        if mediaType.includesShows {
            values += ["returning series", "continuing", "in production", "planned", "upcoming", "canceled", "ended"]
        }
        if mediaType.includesMovies {
            values += ["released", "in production", "post production", "planned", "rumored", "canceled"]
        }
        return values.removingDuplicates().map { SmartListChoice(value: $0, title: $0.smartListTitle) }
    }

    /// Loads the choices for the selected media types, without duplicates, sorted by title.
    private static func choices(for mediaType: SmartListMediaType,
                                movies: TraktAPIService?,
                                shows: TraktAPIService?,
                                decode: @escaping @Sendable (Response) throws -> [SmartListChoice]) async throws -> [SmartListChoice] {
        var services = [TraktAPIService]()
        if mediaType.includesMovies, let movies = movies {
            services.append(movies)
        }
        if mediaType.includesShows, let shows = shows {
            services.append(shows)
        }

        var seen = Set<String>()
        var choices = [SmartListChoice]()
        for service in services {
            choices += try await request(service, decode: decode).filter { seen.insert($0.value).inserted }
        }
        return choices.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Decodes off the main thread, on the request callback queue.
    private static func request<Value: Sendable>(_ service: TraktAPIService,
                                                 decode: @escaping @Sendable (Response) throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                continuation.resume(with: Result { try decode(result.get().filterSuccessfulStatusCodes()) })
            }
        }
    }
}
