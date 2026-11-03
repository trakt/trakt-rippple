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
        /// The "not" of a condition's excluded values.
        case negation(SmartListConditions.ValueCondition)
        case matchOperator(WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>)
        case personRole
        case watchNowCountry
        case singleValue(SmartListConditions.RangeCondition, Double)
        case lowerBound(SmartListConditions.RangeCondition, lower: Double, upper: Double)
        case upperBound(SmartListConditions.RangeCondition, lower: Double, upper: Double)
        case minimum(SmartListConditions.MinimumCondition, Int)
        case releasedWithin(days: Int)
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
        case .discover:
            text(" from ")
            token(source.title, .source)
        case .unknown:
            // Shown for lists created elsewhere so their source can be changed.
            text(" from ")
            token("an unknown source", .source)
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
            let included = values.filter { SmartListConditions.isExcluded($0) == false }
            let excluded = values.filter(SmartListConditions.isExcluded)
            let role: [Segment] = [.token(SmartListConditions.rolePhrase(filters.peopleRole), .personRole), .text(" ")]
            let isPeople = condition.keyPath == \SmartListFilters.people

            if included.isEmpty == false {
                let matchesAll = condition.operatorKeyPath.map { filters[keyPath: $0] == .and } ?? false
                var clause: [Segment] = isPeople ? [.text(" ")] + role : [.text(condition.prefix)]
                for (index, value) in included.enumerated() {
                    if index > 0 {
                        if let operatorKeyPath = condition.operatorKeyPath {
                            clause += [.text(" "), .token(matchesAll ? "and" : "or", .matchOperator(operatorKeyPath)), .text(" ")]
                        } else {
                            clause.append(.text(" or "))
                        }
                    }
                    clause.append(.token(condition.format(value), .value(condition, value)))
                }
                clause.append(.text(included.count > 1 ? condition.pluralSuffix : condition.suffix))
                clauses.append(clause)
            }

            // Excluded values read "not in the Thriller or Horror genres": titles with any of them are left out.
            if excluded.isEmpty == false {
                let negation = condition.negation
                var clause: [Segment] = [.text(negation.lead), .token(negation.word, .negation(condition))]
                clause += isPeople ? [.text(" ")] + role : [.text(negation.trail)]
                for (index, value) in excluded.enumerated() {
                    if index > 0 {
                        clause.append(.text(" or "))
                    }
                    clause.append(.token(condition.format(value), .value(condition, value)))
                }
                clause.append(.text(excluded.count > 1 ? condition.pluralSuffix : condition.suffix))
                clauses.append(clause)
            }

            // Only set on trakt-web: shown so it isn't saved unseen, and can be reset to the user's country. It applies to
            // excluded services too, so it ends the condition's last clause.
            if condition.keyPath == \SmartListFilters.watchnow, let country = filters.watchnowCountry, clauses.isEmpty == false {
                clauses[clauses.count - 1] += [.text(" in "), .token(SmartListChoices.countryName(country), .watchNowCountry)]
            }
        }

        if let days = filters.releasedWithinDays {
            clauses.append([.text(" released in the last "), .token(SmartListConditions.releaseWindow(days), .releasedWithin(days: days))])
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

        for condition in SmartListConditions.minimums {
            guard let range = filters[keyPath: condition.keyPath], let lower = range.first else { continue }
            let upper = range.count > 1 ? range[1] : SmartListConditions.votesCeiling
            if upper < SmartListConditions.votesCeiling {
                clauses.append([.text(" with between "), .token(lower.formatted(.number.locale(SmartListChoices.locale)), .minimum(condition, lower)),
                                .text(" and \(upper.formatted(.number.locale(SmartListChoices.locale))) \(condition.noun)")])
            } else {
                clauses.append([.text(" with at least "), .token(lower.formatted(.number.locale(SmartListChoices.locale)), .minimum(condition, lower)), .text(" \(condition.noun)")])
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
        let operatorKeyPath: WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>?
        let prefix: String
        let suffix: String
        let pluralSuffix: String
        /// Reads values without their exclusion mark: use `format` for display.
        private let formatValue: (String) -> String
        /// The menu's choices: every value of short lists, a few quick picks of long ones. `nil` for values that can be
        /// kept or removed but not picked, such as subgenres.
        let load: ((SmartListMediaType) async throws -> [SmartListChoice])?
        /// Long lists are searched in a sheet for values beyond their quick picks.
        let search: Search?
        /// What the search sheet looks for, when it isn't the condition's title.
        let searchTitle: String?
        /// How the search sheet lists values, when the sentence's wording doesn't read as a name.
        let choiceFormat: ((String) -> String)?
        let isAvailable: (SmartListMediaType) -> Bool

        /// How excluded values are introduced, around the tappable negation word, e.g. " not in the ".
        let negation: (lead: String, word: String, trail: String)

        init(title: String, symbol: String, keyPath: WritableKeyPath<SmartListFilters, [String]?>,
             operatorKeyPath: WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>? = nil,
             prefix: String, suffix: String = "", pluralSuffix: String = "",
             negation: (lead: String, word: String, trail: String)? = nil,
             format: @escaping (String) -> String,
             load: ((SmartListMediaType) async throws -> [SmartListChoice])?,
             search: Search? = nil, searchTitle: String? = nil, choiceFormat: ((String) -> String)? = nil,
             isAvailable: @escaping (SmartListMediaType) -> Bool = { _ in true }) {
            self.title = title
            self.symbol = symbol
            self.keyPath = keyPath
            self.operatorKeyPath = operatorKeyPath
            self.prefix = prefix
            self.suffix = suffix
            self.pluralSuffix = pluralSuffix
            self.negation = negation ?? (" ", "not", prefix)
            formatValue = format
            self.load = load
            self.search = search
            self.searchTitle = searchTitle
            self.choiceFormat = choiceFormat
            self.isAvailable = isAvailable
        }

        func format(_ value: String) -> String {
            formatValue(SmartListConditions.includedValue(value))
        }

        var isPickable: Bool {
            load != nil || search != nil
        }
    }

    /// Trakt reads list values starting with a minus as excluded, like trakt-web's filters: `genres: ["action", "-thriller"]`.
    private static let exclusionPrefix = "-"

    static func isExcluded(_ value: String) -> Bool {
        value.hasPrefix(exclusionPrefix)
    }

    static func includedValue(_ value: String) -> String {
        isExcluded(value) ? String(value.dropFirst(exclusionPrefix.count)) : value
    }

    static func excludedValue(_ value: String) -> String {
        exclusionPrefix + includedValue(value)
    }

    enum Search {
        /// Trakt searches the values as the user types, like trakt-web.
        case trakt(SmartListFilterOptionKind)
        /// Every value loads once, then is filtered as the user types.
        case all((SmartListMediaType) async throws -> [SmartListChoice])
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

    /// A minimum number of votes, saved as a range up to `votesCeiling` like trakt-web does.
    struct MinimumCondition {
        let title: String
        let noun: String
        let keyPath: WritableKeyPath<SmartListFilters, [Int]?>
        let steps: [Int]
        let initial: Int
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

    static let votesCeiling = 999999999

    static let releaseWindows = [30, 90, 180, 365]

    static func releaseWindow(_ days: Int) -> String {
        switch days {
        case 365: return "year"
        case 180: return "6 months"
        case 1: return "day"
        default: return "\(days) days"
        }
    }

    fileprivate static func rolePhrase(_ role: SmartListFilters.PersonRole?) -> String {
        switch role {
        case .cast: return "starring"
        case .directing: return "directed by"
        case .writing: return "written by"
        case .producing: return "produced by"
        case .any, .unknown, .none: return "featuring"
        }
    }

    static let values: [ValueCondition] = [
        ValueCondition(title: "Genres", symbol: "theatermasks", keyPath: \.genres, operatorKeyPath: \.genresOperator,
                       prefix: " in the ", suffix: " genre", pluralSuffix: " genres",
                       format: { $0.smartListTitle }, load: SmartListChoices.genres),
        ValueCondition(title: "Subgenres", symbol: "theatermasks", keyPath: \.subgenres,
                       prefix: " in the ", suffix: " subgenre", pluralSuffix: " subgenres",
                       format: { $0.smartListTitle }, load: nil),
        ValueCondition(title: "Keywords", symbol: "tag", keyPath: \.keywords, operatorKeyPath: \.keywordsOperator,
                       prefix: " about ", format: { $0 }, load: { _ in SmartListChoices.keywords }, search: .trakt(.keywords)),
        ValueCondition(title: "People", symbol: "person.2", keyPath: \.people, operatorKeyPath: \.peopleOperator,
                       prefix: "", format: { SmartListChoices.title(of: $0, kind: .people) }, load: nil, search: .trakt(.people)),
        ValueCondition(title: "Studios", symbol: "building.2", keyPath: \.studios,
                       prefix: " made by ", format: { SmartListChoices.title(of: $0, kind: .studios) },
                       load: { _ in SmartListChoices.studios }, search: .trakt(.studios)),
        ValueCondition(title: "Certifications", symbol: "checkmark.seal", keyPath: \.certifications,
                       prefix: " with a ", suffix: " certification", pluralSuffix: " certification", negation: (" ", "without", " a "),
                       format: { $0 == "nr" ? "No Certification" : $0.uppercased() }, load: SmartListChoices.certifications),
        ValueCondition(title: "Status", symbol: "antenna.radiowaves.left.and.right", keyPath: \.statuses,
                       prefix: " with a ", suffix: " status", pluralSuffix: " status", negation: (" ", "without", " a "),
                       format: { $0.smartListTitle }, load: { SmartListChoices.statuses(for: $0) }),
        ValueCondition(title: "Networks", symbol: "tv", keyPath: \.networks,
                       prefix: " released on ", format: { $0 }, load: { _ in SmartListChoices.networks }, search: .trakt(.networks),
                       isAvailable: { $0.includesShows }),
        ValueCondition(title: "Countries", symbol: "globe", keyPath: \.countries,
                       prefix: " released in ", format: SmartListChoices.countryName,
                       load: { _ in SmartListChoices.countryQuickPicks }, search: .all(SmartListChoices.countries)),
        ValueCondition(title: "Languages", symbol: "character.bubble", keyPath: \.languages,
                       prefix: " where the original language is ", negation: (" where the original language ", "isn’t", " "),
                       format: SmartListChoices.languageName,
                       load: { _ in SmartListChoices.languageQuickPicks }, search: .all(SmartListChoices.languages)),
        ValueCondition(title: "Where to Watch", symbol: "play.tv", keyPath: \.watchnow,
                       prefix: " streaming ", format: SmartListChoices.watchNowTitle,
                       load: { _ in await SmartListChoices.watchNowChoices() }, search: .all { _ in await SmartListChoices.watchNowServices() },
                       searchTitle: "Services", choiceFormat: SmartListChoices.watchNowName)
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
        let tmdb = decimals(\.tmdbRatings)
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
                           values: Array(stride(from: 0, through: 10, by: 0.5)), initial: [7, 10], format: decimal),
            RangeCondition(title: "TMDB Rating", get: tmdb.0, set: tmdb.1,
                           singlePrefix: " with a TMDB rating of ", rangePrefix: " with a TMDB rating between ",
                           values: Array(stride(from: 0, through: 10, by: 0.5)), initial: [7, 10], format: decimal)
        ]
    }()

    static let minimums = [
        MinimumCondition(title: "Trakt Votes", noun: "Trakt votes", keyPath: \.votes, steps: [100, 1000, 10000, 100000], initial: 1000),
        MinimumCondition(title: "IMDb Votes", noun: "IMDb votes", keyPath: \.imdbVotes, steps: [100, 1000, 10000, 100000], initial: 1000)
    ]

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
    let value: String
    let title: String
    var subtitle: String?
    /// Quick picks are offered in their own section, after the other choices.
    var isQuickPick = false
}

enum SmartListChoices {
    static let locale = Locale(identifier: "en_US")

    static let watchNow = [SmartListChoice(value: "favorites", title: "On Favorite Services", subtitle: "Your favorite streaming services"),
                           SmartListChoice(value: "subscriptions", title: "With a Subscription", subtitle: "Any subscription service in your country"),
                           SmartListChoice(value: "free", title: "For Free", subtitle: "Free services in your country"),
                           SmartListChoice(value: "any", title: "Anywhere", subtitle: "Any service in your country")]

    /// Service names by source, filled when services load so the sentence reads "on Disney+" rather than "on Disney Plus".
    private static let watchNowServiceNames = LRUCache<String, String>(countLimit: 1000)

    /// The option or service name, e.g. "With a Subscription" or "Netflix".
    static func watchNowName(for value: String) -> String {
        watchNow.first { $0.value == value }?.title ?? watchNowServiceNames.value(forKey: value) ?? value.smartListTitle
    }

    /// Reads within the sentence, e.g. "streaming with a subscription" or "streaming on Netflix".
    static func watchNowTitle(for value: String) -> String {
        watchNow.first { $0.value == value }?.title.lowercased() ?? "on \(watchNowServiceNames.value(forKey: value) ?? value.smartListTitle)"
    }

    /// The broad options, then the largest services in the user's watch now country as quick picks. Services are
    /// optional: the broad options are still offered when they cannot be loaded.
    static func watchNowChoices() async -> [SmartListChoice] {
        let quickPicks = (await watchNowSources() ?? [])
            .sorted { ($0.linkCount ?? 0) > ($1.linkCount ?? 0) }
            .prefix(5)
            .map { SmartListChoice(value: $0.source, title: $0.name, isQuickPick: true) }
        return watchNow + quickPicks
    }

    /// Every service in the user's watch now country, by name.
    static func watchNowServices() async -> [SmartListChoice] {
        (await watchNowSources() ?? [])
            .map { SmartListChoice(value: $0.source, title: $0.name) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    /// Replaces the user's watch now country. Only the smart list assistant's tests set it, so its test cases read as in
    /// the US whatever account the test host is signed in with.
    static var testingWatchNowCountry: String?

    private static func watchNowSources() async -> [WatchNowSource]? {
        guard let country = (testingWatchNowCountry ?? UserManager.shared.currentUserWatchNowCountry ?? Locale.current.region?.identifier)?.lowercased(),
              let sources = try? await request(.watchNowSources(country: country), decode: { response in
                  try response.map([[String: [WatchNowSource]]].self, using: TraktAPIProvider.decoder)
                      .flatMap { $0[country] ?? [] }
              }) else { return nil }
        var seen = Set<String>()
        let services = sources.filter { seen.insert($0.source).inserted }
        for service in services {
            watchNowServiceNames.setValue(service.name, forKey: service.source)
        }
        return services
    }

    static func countryName(_ code: String) -> String {
        locale.localizedString(forRegionCode: code) ?? code.uppercased()
    }

    static func languageName(_ code: String) -> String {
        locale.localizedString(forLanguageCode: code) ?? code
    }

    /// The device region, then among the countries producing the most movies and shows.
    fileprivate static let countryQuickPicks = ([Locale.current.region?.identifier.lowercased()].compactMap { $0 } + ["us", "gb", "fr", "jp", "kr"])
        .removingDuplicates()
        .map { SmartListChoice(value: $0, title: countryName($0)) }

    /// The device languages, then among the most common original languages of movies and shows.
    fileprivate static let languageQuickPicks = (Locale.preferredLanguages.compactMap { Locale(identifier: $0).language.languageCode?.identifier.lowercased() }
        + ["en", "es", "fr", "ja", "ko"])
        .removingDuplicates()
        .prefix(6)
        .map { SmartListChoice(value: $0, title: languageName($0)) }

    /// Well-known networks, as Trakt names them. Any other network is searched.
    fileprivate static let networks = ["Netflix", "HBO", "HBO Max", "Apple TV+", "Disney+", "Amazon", "Hulu", "AMC", "FX", "BBC One"]
        .map { SmartListChoice(value: $0, title: $0) }

    /// Common keywords, as Trakt names them. Any other keyword is searched.
    static let keywords = ["based on novel or book", "based on true story", "time travel", "superhero", "dystopia",
                           "coming of age", "serial killer", "heist", "zombie", "christmas"]
        .map { SmartListChoice(value: $0, title: $0.prefix(1).uppercased() + $0.dropFirst()) }

    /// Well-known studios. Any other studio is searched.
    static let studios = [("a24", "A24"), ("pixar", "Pixar"), ("studio-ghibli", "Studio Ghibli"), ("marvel-studios", "Marvel Studios"),
                          ("lucasfilm", "Lucasfilm"), ("walt-disney-animation-studios", "Walt Disney Animation Studios"),
                          ("dreamworks-animation", "DreamWorks Animation"), ("blumhouse-productions", "Blumhouse Productions"),
                          ("neon", "Neon"), ("aardman-animations", "Aardman Animations")]
        .map { SmartListChoice(value: $0.0, title: $0.1) }

    /// Names of searched values saved as slugs, so the sentence reads "Christopher Nolan" for `christopher-nolan`.
    private static let searchedTitles = LRUCache<String, String>(countLimit: 1000)

    static func title(of value: String, kind: SmartListFilterOptionKind) -> String {
        if let title = searchedTitles.value(forKey: "\(kind.rawValue)|\(value)") ?? (kind == .studios ? studios.first { $0.value == value }?.title : nil) {
            return title
        }
        // People slugs end with a number or an identifier when names are shared, as in "john-smith-2" or
        // "tom-holland-b16234ab-6f75-4d41-91f6-e115ebbbc7df".
        let name = kind == .people
            ? value.replacingOccurrences(of: #"-([0-9]+|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$"#, with: "", options: .regularExpression)
            : value
        return name.smartListTitle
    }

    fileprivate static func remember(_ choices: [SmartListChoice], kind: SmartListFilterOptionKind) {
        for choice in choices {
            searchedTitles.setValue(choice.title, forKey: "\(kind.rawValue)|\(choice.value)")
        }
    }

    /// Searches values by name, like trakt-web: keywords, studios and networks by their own endpoints, people by name.
    static func search(_ kind: SmartListFilterOptionKind, query: String) async throws -> [SmartListChoice] {
        let choices = try await request(.smartListFilterOptions(kind: kind, query: query)) { response -> [SmartListChoice] in
            switch kind {
            case .keywords, .networks:
                return try response.map([NamedOption].self, using: TraktAPIProvider.decoder).map {
                    SmartListChoice(value: $0.name, title: $0.name, subtitle: $0.country.map(countryName))
                }
            case .studios:
                return try response.map([StudioOption].self, using: TraktAPIProvider.decoder).map { SmartListChoice(value: $0.slug, title: $0.name) }
            case .people:
                return try response.map([PersonResult].self, using: TraktAPIProvider.decoder).compactMap { result in
                    result.person.ids.slug.map { SmartListChoice(value: $0, title: result.person.name) }
                }
            }
        }
        remember(choices, kind: kind)
        return choices
    }

    private struct NamedOption: Decodable {
        let name: String
        let country: String?
    }

    private struct StudioOption: Decodable {
        let slug: String
        let name: String
    }

    private struct PersonResult: Decodable {
        struct Person: Decodable {
            struct Ids: Decodable {
                let slug: String?
            }

            let name: String
            let ids: Ids
        }

        let person: Person
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
        try await choices(for: mediaType, movies: .movieLanguages, shows: .tvLanguages) { response in
            try response.map([Language].self, using: TraktAPIProvider.decoder).compactMap { language in
                SmartListChoices.locale.localizedString(forLanguageCode: language.code).map { SmartListChoice(value: language.code, title: $0) }
            }
        }
    }

    static func countries(for mediaType: SmartListMediaType) async throws -> [SmartListChoice] {
        // Countries share the language payload shape.
        try await choices(for: mediaType, movies: .movieCountries, shows: .tvCountries) { response in
            try response.map([Language].self, using: TraktAPIProvider.decoder).compactMap { country in
                SmartListChoices.locale.localizedString(forRegionCode: country.code).map { SmartListChoice(value: country.code, title: $0) }
            }
        }
    }

    static func statuses(for mediaType: SmartListMediaType) -> [SmartListChoice] {
        var values = [String]()
        if mediaType.includesShows {
            // "Continuing" is left out: Trakt matches nothing with it, see `SmartListFilters.foldingContinuing`.
            values += ["returning series", "in production", "planned", "upcoming", "canceled", "ended"]
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
