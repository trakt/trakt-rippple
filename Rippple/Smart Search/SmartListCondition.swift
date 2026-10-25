//
//  SmartListCondition.swift
//  Rippple
//
//  Created by Kevin Cador on 25/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

/// What the smart list assistant reads, as conditions of the composer: what each means, whether the composer can search
/// it, its filters and how it's said. Nothing here reads the request.
extension SmartListAssistant {
    // MARK: - Conditions

    enum Score: Hashable {
        case trakt
        case imdb
        case rottenTomatoes
        /// Rotten Tomatoes' audience score, rather than critics'.
        case rottenTomatoesAudience
        case metacritic
        /// A site or score with no filter, as Letterboxd, read so it's left out with its reason.
        case unsupported(String)
    }

    enum Condition: Equatable {
        case genres([String])
        case countries([String])
        case languages([String])
        case services([String])
        case people([String], role: SmartListFilters.PersonRole?)
        case studios([String])
        case themes([String])
        /// Periods as typed, read together: "between 2000 and 2010", "the 80s and 90s".
        case years([String])
        case runtimes([Int])
        /// The lowest score, in percent, and the highest if typed, which the composer can't search.
        case rating(Score, minimum: Int, maximum: Int? = nil)
        case unwatched
        case notStarted
        case notOnWatchlist
        /// Already released, or not yet when negated.
        case released
        case statuses([String])
        case certifications([String])
        /// The most of a parents guide category titles may show: "nudity" at 0 is none. A least, as in "at least moderate
        /// violence", can't be searched.
        case parental(String, most: Int, least: Int? = nil)
    }

    /// A parents guide category's filter and how it's said.
    static let parentalGuide: [String: (keyPath: WritableKeyPath<SmartListFilters, [Double]?>, noun: String)] = [
        "nudity": (\.parentalNudity, "sex & nudity"), "violence": (\.parentalViolence, "violence & gore"), "profanity": (\.parentalProfanity, "profanity"),
        "alcohol": (\.parentalAlcohol, "alcohol, drugs & smoking"), "frightening": (\.parentalFrightening, "frightening & intense scenes")
    ]

    /// Parents guide levels, as the composer has them.
    static let severities = ["none", "mild", "moderate", "severe"]

    struct Match {
        var range: Range<Int>
        var condition: Condition
        /// The values as the log names them, as "France" or "Tom Hanks".
        var titles: [String]
        /// Typed with "and": titles must have every value.
        var requiresAll = false
        var isNegated = false
        /// The words saying so, as "not" in "not on Netflix".
        var negation: Range<Int>?
        /// Words read with the condition past others, as "on IMDb" in "highly rated movies on IMDb".
        var alsoRead: Range<Int>?
        /// The condition this one is joined to and shares a negation with, as "violence" for "profanity" in "without mild
        /// violence or profanity".
        var joinedTo: Range<Int>?
    }

    // MARK: - What the composer can search

    /// The longest runtime the composer searches, in minutes.
    static let longestRuntime = 300

    /// Why the composer can't search a reading, as the end of "I'm leaving out …", or nil when it can. Every reading is
    /// checked here, the rules' and Apple Intelligence's, so matchers read what's typed rather than skip what can't be
    /// searched.
    static func unsearchable(_ match: Match) -> String? {
        switch match.condition {
        case .years where match.isNegated: return "as release years can't be excluded"
        case .runtimes where match.isNegated: return "as runtimes can't be excluded"
        case .rating where match.isNegated: return "as ratings can't be excluded"
        case .parental where match.isNegated: return "as a parents guide level can't be excluded"
        case .parental(_, _, .some): return "as a parents guide level can only be a highest one"
        case .unwatched where match.isNegated, .notStarted where match.isNegated, .notOnWatchlist where match.isNegated:
            return "as what you've watched can't be excluded"
        case .services(let values) where match.isNegated && values.contains(where: broadServiceValues.contains):
            return "as a way to stream can't be excluded"
        case .runtimes(let range) where range[0] >= longestRuntime || range[1] > longestRuntime:
            return "as I can only search runtimes up to 5 hours"
        case .rating(.unsupported(let site), _, _): return "as I can't search by \(site) ratings"
        case .rating(_, _, .some): return "as a list can only have a lowest rating"
        default: return nil
        }
    }

    /// Runtimes or release years no title can have all of, as "under 90 minutes" and "over 120 minutes", are left out
    /// and told, rather than dropped quietly from the filters. Returns what was left out, as sentences.
    static func conflicting(_ matches: inout [Match], in tokens: [Token]) -> [String] {
        var notes = [String]()
        let filters = filters(of: matches).0
        let isRuntime = { (match: Match) -> Bool in
            guard case .runtimes = match.condition else { return false }
            return true
        }
        let isYears = { (match: Match) -> Bool in
            guard case .years = match.condition else { return false }
            return true
        }
        // "For kids and adults" is every audience: no certification narrows it.
        let isCertification = { (match: Match) -> Bool in
            guard case .certifications = match.condition, match.isNegated == false else { return false }
            return true
        }
        let certified = Set(filters.certifications ?? [])
        let isEveryone = matches.filter(isCertification).count > 1 && certified.isDisjoint(with: Audience.kids.movies + Audience.kids.shows) == false
            && certified.isDisjoint(with: Audience.adults.movies + Audience.adults.shows) == false
        if isEveryone {
            let typed = listed(matches.filter(isCertification).map { "“\(quote($0.range, in: tokens))”" })
            matches.removeAll(where: isCertification)
            notes.append("I'll have to skip \(typed), as together they mean any audience.")
        }
        for (isKind, isLost) in [(isRuntime, filters.runtimes == nil), (isYears, filters.years == nil)] where isLost {
            let lost = matches.filter(isKind)
            guard lost.isEmpty == false else { continue }
            matches.removeAll(where: isKind)
            let typed = listed(lost.map { "“\(quote($0.range, in: tokens))”" })
            // "Before 1980 and after 2000" is one condition of two periods.
            let isSeveral = lost.count > 1 || lost.contains {
                guard case .years(let periods) = $0.condition else { return false }
                return periods.count > 1
            }
            notes.append(isSeveral ? "I'll have to skip \(typed), as no title can be all of them." : "I'll have to skip \(typed), as I can't search for it.")
        }
        return notes
    }

    // MARK: - Filters

    /// The filters of every kept condition, and whether they narrow the catalog rather than a chart.
    static func filters(of matches: [Match]) -> (SmartListFilters, Bool) {
        var filters = SmartListFilters()
        var periods = [String]()
        var runtimes = [[Int]]()
        var isCatalog = false
        let add = { (values: [String], keyPath: WritableKeyPath<SmartListFilters, [String]?>, match: Match) in
            let marked = match.isNegated ? values.map(SmartListConditions.excludedValue) : values
            filters[keyPath: keyPath] = ((filters[keyPath: keyPath] ?? []) + marked).removingDuplicates()
        }
        let requiresAll = { (match: Match) in match.requiresAll && match.isNegated == false }
        for match in matches {
            switch match.condition {
            case .genres(let values):
                add(values, \.genres, match)
                if requiresAll(match) {
                    filters.genresOperator = .and
                }
            case .countries(let values): add(values, \.countries, match)
            case .languages(let values): add(values, \.languages, match)
            case .services(let values): add(values, \.watchnow, match)
            case .people(let values, let role):
                add(values, \.people, match)
                filters.peopleRole = filters.peopleRole ?? role
                if requiresAll(match) {
                    filters.peopleOperator = .and
                }
                isCatalog = isCatalog || match.isNegated == false
            case .studios(let values):
                add(values, \.studios, match)
                isCatalog = isCatalog || match.isNegated == false
            case .themes(let values):
                add(values, \.keywords, match)
                if requiresAll(match) {
                    filters.keywordsOperator = .and
                }
                isCatalog = isCatalog || match.isNegated == false
            case .statuses(let values): add(values, \.statuses, match)
            case .certifications(let values): add(values, \.certifications, match)
            case .years(let typed): periods += typed
            case .runtimes(let range): runtimes.append(range)
            case .rating(let score, let minimum, _):
                switch score {
                case .unsupported: break
                case .trakt: filters.ratings = [max(minimum, filters.ratings?.first ?? 0), 100]
                case .imdb: filters.imdbRatings = [max(Double(minimum) / 10, filters.imdbRatings?.first ?? 0), 10]
                case .rottenTomatoes: filters.rtMeters = [max(minimum, filters.rtMeters?.first ?? 0), 100]
                case .rottenTomatoesAudience: filters.rtUserMeters = [max(minimum, filters.rtUserMeters?.first ?? 0), 100]
                case .metacritic: filters.metascores = [max(minimum, filters.metascores?.first ?? 0), 100]
                }
            case .parental(let category, let most, _):
                guard let guide = parentalGuide[category] else { break }
                filters[keyPath: guide.keyPath] = [0, Double(min(most, Int(filters[keyPath: guide.keyPath]?.last ?? Double(most))))]
            case .unwatched: filters.ignoreWatched = true
            case .notStarted:
                filters.ignoreWatched = true
                filters.ignoreWatching = true
            case .notOnWatchlist: filters.ignoreWatchlisted = true
            case .released:
                if match.isNegated {
                    filters.ignoreReleased = true
                } else {
                    filters.ignoreUnreleased = true
                }
            }
        }
        if periods.isEmpty == false {
            filters.years = years(of: periods)
        }
        if let lower = runtimes.map({ $0[0] }).max(), let upper = runtimes.map({ $0[1] }).min(), lower <= upper {
            filters.runtimes = [lower, upper]
        }
        return (filters, isCatalog)
    }

    // MARK: - Values

    static func ratingTitle(_ score: Score, _ minimum: Int, maximum: Int? = nil) -> String {
        let name: String
        let shown: (Int) -> String
        switch score {
        case .trakt: (name, shown) = ("Trakt rating", { "\($0)%" })
        case .imdb: (name, shown) = ("IMDb rating", { String(format: "%.1f", Double($0) / 10) })
        case .rottenTomatoes: (name, shown) = ("Rotten Tomatoes score", { "\($0)%" })
        case .rottenTomatoesAudience: (name, shown) = ("Rotten Tomatoes audience score", { "\($0)%" })
        case .metacritic: (name, shown) = ("Metascore", { "\($0)" })
        case .unsupported(let site): return "\(site) rating"
        }
        return maximum.map { "\(name) of \(shown($0)) or lower" } ?? "\(name) of \(shown(minimum)) or higher"
    }

    static func runtimeTitle(_ range: [Int]) -> String {
        if range[0] == 0 {
            return "under \(range[1]) minutes"
        }
        return range[1] >= 300 ? "over \(range[0]) minutes" : "\(range[0]) to \(range[1]) minutes"
    }

    /// The years of all typed periods. Periods add up, as "the 80s and 90s" or "between 2000 and 2010", and bounds narrow
    /// them, as "after the 80s and before 2000". Nil when no year is all of them.
    static func years(of periods: [String]) -> [Int]? {
        var spans = [[Int]]()
        var lower = 1900
        var upper = SmartListConditions.currentYear + 2
        var index = 0
        while index < periods.count {
            guard let range = typedYears(in: periods[index]) else { return nil }
            let typed = Set(words(in: periods[index]))
            let isUpper = typed.isDisjoint(with: ["before", "until", "through"]) == false
            let isLower = typed.isDisjoint(with: ["after", "since"]) == false
            // "Between 2000 and 2010" is read as two periods.
            if typed.contains("between"), index + 1 < periods.count, let end = typedYears(in: periods[index + 1]) {
                spans.append([min(range[0], end[0]), max(range[1], end[1])])
                index += 2
                continue
            }
            if isUpper, isLower == false {
                upper = min(upper, range[1])
            } else if isLower, isUpper == false {
                lower = max(lower, range[0])
            } else {
                spans.append(range)
            }
            index += 1
        }
        if let first = spans.compactMap(\.first).min(), let last = spans.compactMap(\.last).max() {
            lower = max(lower, first)
            upper = min(upper, last)
        }
        return lower <= upper ? [lower, upper] : nil
    }

    static func typedYears(in text: String) -> [Int]? {
        let currentYear = SmartListConditions.currentYear
        let typed = words(in: text)
        let joined = typed.joined(separator: " ")
        if joined == "this year" {
            return [currentYear, currentYear]
        }
        if joined == "last year" {
            return [currentYear - 1, currentYear - 1]
        }
        let years = typed.compactMap { word -> Int? in
            guard word.count == 4, let year = Int(word), (1900...currentYear + 2).contains(year) else { return nil }
            return year
        }
        if years.count == 2, Set(typed).isDisjoint(with: ["before", "after", "since", "until"]) {
            return [years.min() ?? years[0], years.max() ?? years[1]]
        }
        if years.isEmpty == false {
            var lower = 1900
            var upper = currentYear + 2
            for index in typed.indices {
                guard let year = Int(typed[index]), years.contains(year) else { continue }
                switch index > 0 ? typed[index - 1] : "" {
                case "after": lower = max(lower, year + 1)
                case "since": lower = max(lower, year)
                case "before": upper = min(upper, year - 1)
                case "until", "through": upper = min(upper, year)
                default:
                    lower = max(lower, years.min() ?? year)
                    upper = min(upper, years.max() ?? year)
                }
            }
            return lower <= upper ? [lower, upper] : nil
        }
        var decade: Int?
        for word in typed where word.hasSuffix("s") {
            // "2010s", or "80s" for the 1980s, and "00s" or "20s" for this century.
            guard let number = Int(word.dropLast()), number % 10 == 0 else { continue }
            if word.count == 5 {
                decade = number
            } else if word.count == 3 {
                decade = number <= (currentYear % 100) ? 2000 + number : 1900 + number
            }
            break
        }
        guard let start = decade ?? typed.lazy.compactMap({ decades[$0] }).first else { return nil }
        let latest = currentYear + 2
        switch typed.first(where: decadeModifiers.contains) {
        case "early": return [start, start + 4]
        case "mid": return [start + 3, start + 6]
        case "late": return [start + 5, start + 9]
        case "before", "until": return [1900, start - 1]
        case "after": return [start + 10, latest]
        case "since": return [start, latest]
        default: return [start, start + 9]
        }
    }

    static let decades = ["fifties": 1950, "sixties": 1960, "seventies": 1970, "eighties": 1980, "nineties": 1990]

    static let decadeModifiers: Set<String> = ["early", "mid", "late", "before", "until", "after", "since"]

    /// Trakt's show statuses.
    static let showStatuses: Set = ["returning series", "in production", "planned", "upcoming", "canceled", "ended"]

    /// Trakt's US certifications, typed as they are: "PG-13", "TV-MA", or "R" after "rated".
    static let certificationCodes: Set = ["g", "pg", "pg-13", "r", "tv-y", "tv-y7", "tv-g", "tv-pg", "tv-14", "tv-ma"]

    /// Who titles are for, as certifications: "for adults" is R for movies and TV-MA for shows.
    enum Audience: String, CaseIterable {
        case kids
        case teens
        case adults

        var movies: [String] {
            switch self {
            case .kids: return ["g", "pg"]
            case .teens: return ["pg-13"]
            case .adults: return ["r"]
            }
        }

        var shows: [String] {
            switch self {
            case .kids: return ["tv-y", "tv-y7", "tv-g"]
            case .teens: return ["tv-14"]
            case .adults: return ["tv-ma"]
            }
        }

        /// The certifications for the media the request names.
        func certifications(in words: [String]) -> [String] {
            switch mediaType(named: words) {
            case .movies: return movies
            case .shows: return shows
            default: return movies + shows
            }
        }
    }

    // MARK: - Wording

    /// A list said as a sentence: "popular horror movies about halloween, starring Tom Hanks, that you haven't watched".
    static func sentence(mediaType: SmartListMediaType, source: SmartListSource?, matches: [Match]) -> String {
        let isLead = { (match: Match) -> Bool in
            switch match.condition {
            case .genres: return match.isNegated == false
            // "R-rated horror movies".
            case .certifications(let codes): return match.isNegated == false && codes.count == 1
            default: return false
            }
        }
        let isTail = { (match: Match) -> Bool in
            switch match.condition {
            case .unwatched, .notStarted, .notOnWatchlist, .statuses, .released: return true
            default: return false
            }
        }
        var lead = [String]()
        switch source {
        case .trending: lead.append("trending")
        case .popular: lead.append("popular")
        case .anticipated: lead.append("upcoming")
        case .recommendations: lead.append("recommended")
        default: break
        }
        // The certification first: "R-rated animation movies".
        let isCertification = { (match: Match) -> Bool in
            guard case .certifications = match.condition else { return false }
            return true
        }
        let leads = matches.filter(isLead)
        // "R-rated or PG-13-rated", as certifications typed apart are either.
        let certified = leads.filter(isCertification).map(spoken).removingDuplicates()
        lead += (certified.isEmpty ? [] : [listed(certified, or: true)]) + leads.filter { isCertification($0) == false }.map(spoken).removingDuplicates()
        lead.append(mediaType == .movies ? "movies" : mediaType == .shows ? "shows" : "movies and shows")
        var said = lead.joined(separator: " ")
        switch source {
        case .watchlist: said += " on your watchlist"
        case .library: said += " in your library"
        default: break
        }
        let rest = matches.filter { isLead($0) == false && isTail($0) == false }.map(spoken).removingDuplicates()
        if let first = rest.first {
            said += " " + ([first] + rest.dropFirst()).joined(separator: ", ")
        }
        // Not started already says not watched.
        let isNotStarted = matches.contains { $0.condition == .notStarted }
        let tail = matches.filter { isTail($0) && (isNotStarted == false || $0.condition != .unwatched) }.map(spoken).removingDuplicates()
        if tail.isEmpty == false {
            said += " that " + listed(tail)
        }
        return source == .discover ? said + ", across all of Trakt" : said
    }

    /// A condition as said in a sentence: "horror", "on Netflix", "starring Tom Hanks", "released since 2016".
    static func spoken(_ match: Match) -> String {
        let values = match.titles.joined(separator: match.requiresAll ? " and " : " or ")
        let not = match.isNegated ? "not " : ""
        switch match.condition {
        case .genres: return match.isNegated ? "without \(values.lowercased())" : values.lowercased()
        case .countries: return "\(not)from \(values)"
        case .languages: return "\(not)in \(values)"
        case .services(let slugs) where slugs.allSatisfy(broadServiceValues.contains): return "\(not)\(values)"
        case .services: return "\(not)on \(values)"
        case .people(_, let role):
            guard match.isNegated == false else { return "without \(values)" }
            switch role {
            case .cast: return "starring \(values)"
            case .directing: return "directed by \(values)"
            case .writing: return "written by \(values)"
            case .producing: return "produced by \(values)"
            default: return "with \(values)"
            }
        case .studios: return "\(not)by \(values)"
        // "Based on novel or book" says it all: not "about based on novel or book".
        case .themes where match.titles.allSatisfy { $0.hasPrefix("based on") }: return "\(not)\(values)"
        case .themes: return "\(not)about \(values)"
        case .years: return label(of: match).lowercased()
        case .runtimes(let range): return runtimeTitle(range)
        case .rating(let score, let minimum, let maximum):
            guard maximum == nil else { return ratingTitle(score, minimum, maximum: maximum) }
            switch score {
            case .unsupported: return ratingTitle(score, minimum)
            case .trakt: return "rated \(minimum)%+ on Trakt"
            case .imdb: return "rated \(String(format: "%.1f", Double(minimum) / 10))+ on IMDb"
            case .rottenTomatoes: return "at \(minimum)%+ on Rotten Tomatoes"
            case .rottenTomatoesAudience: return "at \(minimum)%+ with Rotten Tomatoes audiences"
            case .metacritic: return "with a Metascore of \(minimum)+"
            }
        case .parental(let category, let most, let least):
            let noun = parentalGuide[category]?.noun ?? category
            if let least = least {
                return "with at least \(severities[min(least, 3)]) \(noun)"
            }
            return most == 0 ? "with no \(noun)" : "with at most \(severities[min(most, 3)]) \(noun)"
        case .unwatched: return "you haven't watched"
        case .notStarted: return "you haven't started"
        case .notOnWatchlist: return "aren't on your watchlist"
        case .released: return match.isNegated ? "aren't released yet" : "are already released"
        case .certifications(let codes):
            guard match.isNegated == false else { return "not rated \(values)" }
            if codes.count == 1 {
                return "\(values)-rated"
            }
            let audience = Audience.allCases.first { Set($0.movies + $0.shows).isSuperset(of: codes) }
            return audience.map { "for \($0.rawValue)" } ?? "rated \(values)"
        case .statuses(let statuses):
            let said = statuses.map { status -> String in
                switch status {
                case "ended": return match.isNegated ? "haven't ended" : "have ended"
                case "returning series": return match.isNegated ? "aren't still running" : "are still running"
                default: return "\(match.isNegated ? "aren't" : "are") \(status)"
                }
            }
            return listed(said, or: match.isNegated == false)
        }
    }

    /// One of a few ways to say something, the same for the same words: hash values change from one launch to the next.
    static func variety(of text: String, among count: Int) -> Int {
        text.unicodeScalars.reduce(0) { $0 + Int($1.value) } % count
    }

    /// A source as said in a sentence: "your watchlist", "trending titles".
    static func phrase(of source: SmartListSource) -> String {
        switch source {
        case .watchlist: return "your watchlist"
        case .library: return "your library"
        case .recommendations: return "your recommendations"
        case .discover: return "all of Trakt"
        default: return "\(source.title.lowercased()) titles"
        }
    }

    /// "a, b and c", or "a, b or c".
    static func listed(_ items: [String], or isAlternative: Bool = false) -> String {
        guard items.count > 1, let last = items.last else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + (isAlternative ? " or " : " and ") + last
    }

    /// Conditions of one kind, wanted or not: a specialist's finding of a kind the rules already read isn't added, so
    /// "horror" read by the rules isn't joined by a guessed "without horror".
    static func kind(of match: Match) -> String {
        switch match.condition {
        case .genres: return "genres"
        case .countries: return "countries"
        case .languages: return "languages"
        case .services: return "services"
        case .people: return "people"
        case .studios: return "studios"
        case .themes: return "themes"
        case .statuses: return "statuses"
        case .certifications: return "certifications"
        case .years: return "years"
        case .runtimes: return "runtimes"
        case .rating(let score, _, _): return "rating-\(score)"
        case .unwatched: return "unwatched"
        case .notStarted: return "not started"
        case .notOnWatchlist: return "watchlist"
        case .released: return "released"
        case .parental(let category, _, _): return "parental-\(category)"
        }
    }

    static func mediaTitle(_ mediaType: SmartListMediaType) -> String {
        switch mediaType {
        case .movies: return "Movies"
        case .shows: return "Shows"
        default: return "Movies and shows"
        }
    }

    /// A condition as the log names it, excluded or not.
    static func describe(_ match: Match) -> String {
        match.isNegated ? "Excluding \(match.titles.joined(separator: " or "))" : label(of: match)
    }

    static func label(of match: Match) -> String {
        let values = match.titles.joined(separator: match.requiresAll ? " and " : " or ")
        switch match.condition {
        case .genres: return "Genre: \(values)"
        case .countries: return "Country: \(values)"
        case .languages: return "Language: \(values)"
        case .services(let slugs) where slugs.allSatisfy(broadServiceValues.contains): return "Streaming \(values)"
        case .services: return "Streaming on \(values)"
        case .people(_, let role):
            switch role {
            case .cast: return "Starring \(values)"
            case .directing: return "Directed by \(values)"
            case .writing: return "Written by \(values)"
            case .producing: return "Produced by \(values)"
            default: return "With \(values)"
            }
        case .studios: return "Studio: \(values)"
        case .themes: return "Theme: \(values)"
        case .statuses: return "Status: \(values)"
        case .certifications: return "Certification: \(values)"
        case .years(let typed):
            guard let years = years(of: typed) else { return "Release years" }
            if years[0] == years[1] {
                return "Released in \(years[0])"
            }
            if years[0] == 1900 {
                return "Released until \(years[1])"
            }
            return years[1] >= SmartListConditions.currentYear ? "Released since \(years[0])" : "Released from \(years[0]) to \(years[1])"
        case .runtimes(let range): return "Runtime \(runtimeTitle(range))"
        case .parental:
            let said = spoken(match)
            return said.prefix(1).uppercased() + said.dropFirst()
        case .released: return match.isNegated ? "Not released yet" : "Already released"
        case .rating, .unwatched, .notStarted, .notOnWatchlist: return values
        }
    }
}
