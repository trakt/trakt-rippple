//
//  SmartListAssistant.swift
//  Rippple
//
//  Created by Kevin Cador on 01/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import FoundationModels
import LRUCache

/// Turns a typed request into a smart list definition with the on-device model, in two steps the small model handles
/// reliably: it first quotes the words of each condition, then turns each quote into a value. Quotes must appear in the
/// request and values must exist on Trakt, so nothing is invented.
enum SmartListAssistant {
    struct Definition {
        let source: SmartListSource
        let mediaType: SmartListMediaType
        let filters: SmartListFilters
    }

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Reuses conversions when a prompt is submitted again or rephrased.
    private static let quotesCache = LRUCache<String, AskQuotes>(countLimit: 100)
    private static let valuesCache = LRUCache<String, [String]>(countLimit: 500)

    private static let quotesInstructions = "Quote the exact words of a request for movies or TV shows, for each kind of condition. Leave a kind empty when the request doesn't mention it."

    /// Loads the model ahead of the first request.
    static func prewarm() {
        LanguageModelSession(instructions: quotesInstructions).prewarm()
    }

    static func definition(from request: String) async -> Definition? {
        guard isAvailable, Task.isCancelled == false else { return nil }
        let quotes: AskQuotes
        if let cached = quotesCache.value(forKey: request) {
            quotes = cached
        } else {
            guard let generated = await ask(AskQuotes.self, about: request, instructions: quotesInstructions) else { return nil }
            quotesCache.setValue(generated, forKey: request)
            quotes = generated
        }
        guard Task.isCancelled == false else { return nil }

        let words = verifiedWords(of: quotes, in: request)
        let said = { (kind: Kind) in words[kind] }
        let mediaType: SmartListMediaType
        switch quotes.mediaType {
        case .movies: mediaType = .movies
        case .shows: mediaType = .shows
        case .both: mediaType = .media
        }
        // Each condition is a separate, short request, run side by side.
        async let genres = genres(for: said(.genres), mediaType: mediaType)
        // A period the model didn't quote, such as "the eighties", is still read when written a usual way.
        async let years = years(for: said(.period) ?? (typedYears(in: request) != nil ? request : nil))
        async let runtimes = runtimes(for: said(.runtime))
        async let ratings = ratings(for: said(.rating), in: request)
        async let languages = languages(for: said(.language), mediaType: mediaType)
        async let countries = countries(for: said(.country), mediaType: mediaType)
        async let services = services(for: said(.services))
        async let certifications = certifications(for: said(.audience), typed: typedCertifications(in: request), mediaType: mediaType)
        let statuses = await statuses(for: said(.status), mediaType: mediaType)

        let excludesWatchlist = said(.notOnWatchlist) != nil || excludes(["watchlist", "watchlisted"], in: request)
        let resolvedSource = source(in: request, excludingWatchlist: excludesWatchlist)
        var filters = SmartListFilters()
        filters.genres = await genres
        filters.years = await years
        filters.runtimes = await runtimes
        filters.ratings = await ratings
        filters.languages = await languages
        filters.countries = await countries
        let resolvedServices = await services
        filters.watchnow = resolvedServices ?? availability(in: request)
        filters.statuses = statuses
        filters.certifications = await certifications
        // A failed conversion must not silently broaden the list, especially for audience or streaming requests.
        let resolved: [(Kind, Bool)] = [
            (.genres, filters.genres != nil), (.period, filters.years != nil), (.runtime, filters.runtimes != nil),
            (.rating, filters.ratings != nil), (.language, filters.languages != nil), (.country, filters.countries != nil),
            (.services, resolvedServices != nil), (.audience, filters.certifications != nil), (.status, filters.statuses != nil)
        ]
        guard resolved.allSatisfy({ said($0.0) == nil || $0.1 }),
              typedCertifications(in: request).isEmpty || filters.certifications != nil else { return nil }
        var limits = parentalLimits(in: request)
        // Titles for children leave out every Parents Guide topic, and titles for teenagers keep them mild, unless some
        // were asked for. Only for who the titles are for: "PG-13 movies" asks for a rating, not for limits.
        if limits.isEmpty, typedCertifications(in: request).isEmpty, let certifications = filters.certifications.map(Set.init) {
            if certifications.isSubset(of: childrenCertifications) {
                limits = parentalTopics.map { ($0, 0) }
            } else if certifications.isSubset(of: childrenCertifications.union(teenCertifications)) {
                limits = parentalTopics.map { ($0, 1) }
            }
        }
        for (keyPath, level) in limits {
            filters[keyPath: keyPath] = [0, Double(level)]
        }
        filters.ignoreWatched = said(.unwatched) != nil || excludesWatched(in: request) ? true : nil
        filters.ignoreWatchlisted = excludesWatchlist ? true : nil
        guard Task.isCancelled == false else { return nil }
        return Definition(source: resolvedSource, mediaType: mediaType, filters: filters)
    }

    // MARK: - Quotes

    /// Kinds of conditions, the most specific first: when two quote the same words, the first one keeps them.
    private enum Kind: CaseIterable {
        case status
        case audience
        case services
        case country
        case language
        case genres
        case runtime
        case rating
        case period
        case unwatched
        case notOnWatchlist
    }

    /// The quotes actually typed. The model sometimes quotes words of its own, or the same words for
    /// two kinds, such as "from Japan" for a country and a period.
    private static func verifiedWords(of quotes: AskQuotes, in request: String) -> [Kind: String] {
        let typed = Set(words(in: request).filter { fillerWords.contains($0) == false })
        // Words matched directly can't also be quoted for another kind: "upcoming" isn't a period, nor "free" an audience.
        var used = typed.filter { word in
            sourceKeywords.contains { $0.words.contains(word) } || priceKeywords.contains(word) || parentalKeywords.contains { $0.key.contains(word) }
        }
        if typedCertifications(in: request).isEmpty == false {
            used.formUnion(typed.filter { certificationNames.contains($0) || $0 == "rated" })
        }
        var verified = [Kind: String]()
        for kind in Kind.allCases {
            let quote: String
            switch kind {
            case .status: quote = quotes.status
            case .audience: quote = quotes.audience
            case .services: quote = quotes.services
            case .country: quote = quotes.country
            case .language: quote = quotes.language
            case .genres: quote = quotes.genres
            case .runtime: quote = quotes.runtime
            case .rating: quote = quotes.rating
            case .period: quote = quotes.period
            case .unwatched: quote = quotes.unwatched
            case .notOnWatchlist: quote = quotes.notOnWatchlist
            }
            // Seasonal occasions describe the theme, not a release year.
            if kind == .period, typedYears(in: quote) == nil, quote.contains(where: \.isNumber) == false,
               Set(words(in: quote)).isDisjoint(with: ["year", "years", "decade", "decades", "century", "era"]) {
                continue
            }
            // Words such as "for" or "the" don't tell kinds apart, nor show the quote was typed.
            let significant = Set(words(in: quote).filter { fillerWords.contains($0) == false })
            // A quote of the whole request says nothing about which kind it is.
            guard significant.isEmpty == false, containsPhrase(quote, in: request), significant.isSubset(of: used) == false,
                  typed.count < 3 || significant != typed else { continue }
            used.formUnion(significant)
            verified[kind] = quote.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return verified
    }

    /// Lowercased words, with curly and straight apostrophes treated alike, as in "haven’t" and "haven't".
    private static func words(in text: String) -> [String] {
        text.lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'+-")).inverted)
            .filter { $0.isEmpty == false }
    }

    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        let phrase = words(in: phrase)
        let typed = words(in: text)
        guard phrase.isEmpty == false, phrase.count <= typed.count else { return false }
        return (0...typed.count - phrase.count).contains { index in
            typed[index..<index + phrase.count].elementsEqual(phrase)
        }
    }

    private static let fillerWords: Set<String> = [
        "a", "an", "the", "i", "me", "my", "we", "our", "to", "of", "in", "on", "at", "by", "for", "with", "from", "and", "or",
        "that", "which", "who", "is", "are", "was", "has", "have", "can", "it", "its", "some", "any", "all"
    ]

    private static let childrenCertifications: Set<String> = ["g", "tv-y", "tv-y7", "tv-g"]
    private static let teenCertifications: Set<String> = ["pg", "pg-13", "tv-pg", "tv-14"]

    private static let parentalTopics: [WritableKeyPath<SmartListFilters, [Double]?>] = [
        \.parentalNudity, \.parentalViolence, \.parentalProfanity, \.parentalAlcohol, \.parentalFrightening
    ]

    // MARK: - Conditions

    /// Where titles come from is named with a few plain words, so they're matched directly rather than asked.
    /// Popular suits most requests: trending is for what's watched right now, when asked for.
    private static func source(in request: String, excludingWatchlist: Bool) -> SmartListSource {
        let typed = Set(words(in: request))
        return sourceKeywords.first {
            (excludingWatchlist == false || $0.source != .watchlist) && $0.words.isDisjoint(with: typed) == false
        }?.source ?? .popular
    }

    /// Explicit priority keeps prompts mentioning several sources consistent across launches.
    private static let sourceKeywords: [(words: Set<String>, source: SmartListSource)] = [
        (["watchlist", "watchlisted"], .watchlist),
        (["recommended", "recommendations", "recommend"], .recommendations),
        (["upcoming", "anticipated", "coming", "unreleased"], .anticipated),
        (["trending"], .trending),
        (["popular"], .popular)
    ]

    /// Negation must belong to the watched/watchlist phrase, rather than another condition earlier in the request.
    private static func excludes(_ keywords: Set<String>, in request: String) -> Bool {
        let typed = words(in: request)
        let connectingWords = fillerWords.union(["already", "yet", "ever", "been", "added", "put"])
        let negatives: Set = ["not", "no", "never", "without", "haven't", "hasn't", "isn't", "aren't", "wasn't", "weren't"]
        return typed.indices.contains { index in
            guard keywords.contains(typed[index]) else { return false }
            let preceding = typed[..<index].reversed().first { connectingWords.contains($0) == false }
            return preceding.map { negatives.contains($0) } ?? false
        }
    }

    private static func excludesWatched(in request: String) -> Bool {
        words(in: request).contains("unwatched") || excludes(["watched", "seen"], in: request)
    }

    private static func genres(for words: String?, mediaType: SmartListMediaType) async -> [String]? {
        guard let words = words, let choices = try? await SmartListChoices.genres(for: mediaType) else { return nil }
        let allowed = choices.map(\.value).joined(separator: ", ")
        return await cachedValues("genres-\(mediaType.rawValue)", words) {
            await ask(AskCodes.self, about: words, instructions: "Map these words to genre slugs. Allowed slugs: \(allowed).").map(\.codes)
        }.flatMap { allowedValues($0, in: choices) }
    }

    private static func years(for words: String?) async -> [Int]? {
        let currentYear = SmartListConditions.currentYear
        guard let words = words else { return nil }
        if let years = typedYears(in: words) {
            return years
        }
        // Without a number or a word about time, such as "for Halloween", the words aren't a release period.
        let typed = Set(self.words(in: words))
        guard words.contains(where: \.isNumber) || typed.isDisjoint(with: ["year", "years", "decade", "decades", "century", "era"]) == false,
              let values = await cachedValues("years-\(currentYear)", words, {
                  await ask(AskPeriod.self, about: words, instructions: "Turn these words into a range of release years. The current year is \(currentYear).")
                      .map { ["\($0.fromYear)", "\($0.toYear)"] }
              }), let from = values.first.flatMap(Int.init), let to = values.last.flatMap(Int.init) else { return nil }
        let latest = currentYear + 2
        let lower = min(max(from, 1900), latest)
        return [lower, max(lower, min(to, latest))]
    }

    /// Release periods are mostly written the same few ways, read directly: "80s", "the 2010s", "eighties", "2026",
    /// "since 2020", "before 1990", "between 2000 and 2010" or "this year".
    private static func typedYears(in words: String) -> [Int]? {
        let currentYear = SmartListConditions.currentYear
        let typed = self.words(in: words.replacingOccurrences(of: #"(?<=\d)[–—-](?=\d)"#, with: " ", options: .regularExpression))
        let text = typed.joined(separator: " ")
        let years = typed.compactMap { word -> Int? in
            guard word.count == 4, let year = Int(word), (1900...currentYear + 2).contains(year) else { return nil }
            return year
        }
        if text.contains("this year") {
            return [currentYear, currentYear]
        }
        if text.contains("last year") {
            return [currentYear - 1, currentYear - 1]
        }
        if years.count == 2, Set(typed).isDisjoint(with: ["before", "after", "since", "until"]) {
            return [years.min() ?? years[0], years.max() ?? years[1]]
        }
        if years.isEmpty == false {
            var lower = 1900
            var upper = currentYear + 2
            var hasBound = false
            for index in typed.indices {
                guard let year = Int(typed[index]), years.contains(year) else { continue }
                let modifier = index > 0 ? typed[index - 1] : ""
                switch modifier {
                case "after": lower = max(lower, year + 1)
                case "since": lower = max(lower, year)
                case "from" where years.count > 1: lower = max(lower, year)
                case "before": upper = min(upper, year - 1)
                case "until", "through": upper = min(upper, year)
                default: continue
                }
                hasBound = true
            }
            if hasBound {
                return lower <= upper ? [lower, upper] : nil
            }
            return [years.min() ?? lower, years.max() ?? upper]
        }
        for word in typed {
            // "2010s", or "80s" for the 1980s, and "00s" or "20s" for this century.
            if word.hasSuffix("s"), let number = Int(word.dropLast()) {
                if word.count == 5, number % 10 == 0 {
                    return [number, number + 9]
                }
                if word.count == 3, number % 10 == 0 {
                    let decade = number <= (currentYear % 100) ? 2000 + number : 1900 + number
                    return [decade, decade + 9]
                }
            }
        }
        let decades = ["fifties": 1950, "sixties": 1960, "seventies": 1970, "eighties": 1980, "nineties": 1990]
        if let decade = typed.lazy.compactMap({ decades[$0] }).first {
            return [decade, decade + 9]
        }
        return nil
    }

    private static func runtimes(for words: String?) async -> [Int]? {
        guard let words = words, let values = await cachedValues("runtimes", words, {
            await ask(AskRuntime.self, about: words, instructions: "Turn these words into a runtime range in minutes.")
                .map { ["\($0.minimum)", "\($0.maximum)"] }
        }), let minimum = values.first.flatMap(Int.init), let maximum = values.last.flatMap(Int.init) else { return nil }
        let lower = min(max(minimum, 0), 300)
        return [lower, max(lower, min(maximum, 300))]
    }

    /// Ratings are mostly described with a few set phrases, read directly: the model often leaves them out.
    private static let ratingPhrases = [
        ("highly rated", 80), ("top rated", 80), ("best rated", 80), ("great rating", 80), ("great ratings", 80), ("acclaimed", 80),
        ("well rated", 70), ("good rating", 70), ("good ratings", 70), ("rated well", 70)
    ]

    private static func ratings(for words: String?, in request: String) async -> [Int]? {
        let text = " " + self.words(in: request).joined(separator: " ") + " "
        if let minimum = ratingPhrases.first(where: { text.contains(" \($0.0) ") })?.1 {
            return [minimum, 100]
        }
        guard let words = words, let minimum = await cachedValues("ratings", words, {
            await ask(AskRating.self, about: words, instructions: "Turn these words into a minimum rating.").map { ["\($0.minimum)"] }
        })?.first.flatMap(Int.init) else { return nil }
        return [min(max(minimum, 0), 100), 100]
    }

    private static func languages(for words: String?, mediaType: SmartListMediaType) async -> [String]? {
        guard let words = words, let choices = try? await SmartListChoices.languages(for: mediaType) else { return nil }
        return await cachedValues("languages", words) {
            await ask(AskCodes.self, about: words, instructions: "Turn these words into ISO 639-1 codes of original languages, such as ko for Korean.").map(\.codes)
        }.flatMap { allowedValues($0, in: choices) }
    }

    private static func countries(for words: String?, mediaType: SmartListMediaType) async -> [String]? {
        guard let words = words, let choices = try? await SmartListChoices.countries(for: mediaType) else { return nil }
        return await cachedValues("countries", words) {
            await ask(AskCodes.self, about: words, instructions: "Turn these words into ISO 3166-1 alpha-2 country codes, such as jp for Japan.").map(\.codes)
        }.flatMap { allowedValues($0, in: choices) }
    }

    private static func services(for words: String?) async -> [String]? {
        guard let words = words, let names = await cachedValues("services", words, {
            await ask(AskCodes.self, about: words, instructions: "List the streaming services named.").map(\.codes)
        }) else { return nil }
        // Matched by name, the way people type them: "Disney Plus" is Disney+.
        let typed = Set(names.map(serviceKey))
        let services = await SmartListChoices.watchNowChoices().filter { $0.group != nil && typed.contains(serviceKey($0.title)) }
        return services.isEmpty ? nil : services.map(\.value).removingDuplicates()
    }

    private static let priceKeywords: Set<String> = ["free", "subscription", "subscriptions", "anywhere"]

    /// Price words are few and plain, so they're matched directly rather than asked.
    private static func availability(in request: String) -> [String]? {
        let words = words(in: request)
        let text = " " + words.joined(separator: " ") + " "
        if words.contains("free") {
            return ["free"]
        }
        if words.contains("subscription") || words.contains("subscriptions") {
            return ["subscriptions"]
        }
        if text.contains(" my services ") || text.contains(" favorite services ") || text.contains(" my streaming services ") {
            return ["favorites"]
        }
        if words.contains("anywhere") || text.contains(" any service ") {
            return ["any"]
        }
        return nil
    }

    private static let certificationNames: Set<String> = ["g", "pg", "pg-13", "r", "nc-17", "tv-y", "tv-y7", "tv-g", "tv-pg", "tv-14", "tv-ma"]

    /// Certifications typed by name, such as "PG-13", or "R rated": a lone "g" or "r" is too ambiguous.
    private static func typedCertifications(in request: String) -> [String] {
        let words = words(in: request)
        return words.indices.compactMap { index in
            let word = words[index]
            guard certificationNames.contains(word) else { return nil }
            let isRated = index + 1 < words.count && words[index + 1] == "rated"
            return word.count > 1 || isRated ? word : nil
        }
    }

    /// Who the titles are for, such as "with my kids", becomes the certifications suitable for that audience.
    /// Certifications typed by name are used as they are.
    private static func certifications(for words: String?, typed: [String], mediaType: SmartListMediaType) async -> [String]? {
        guard words != nil || typed.isEmpty == false else { return nil }
        guard let choices = try? await SmartListChoices.certifications(for: mediaType) else { return nil }
        if typed.isEmpty == false {
            return allowedValues(typed, in: choices)
        }
        guard let words = words else { return nil }
        // Descriptions such as "All Ages" let the model reason from an audience to certifications.
        let allowed = choices.map { "\($0.value) (\($0.subtitle ?? $0.title))" }.joined(separator: ", ")
        return await cachedValues("certifications-\(mediaType.rawValue)", words) {
            await ask(AskCodes.self, about: words, instructions: "Map these words to every certification suitable for that audience. Allowed certifications: \(allowed).").map(\.codes)
        }.flatMap { allowedValues($0, in: choices) }
    }

    private static func statuses(for words: String?, mediaType: SmartListMediaType) async -> [String]? {
        guard let words = words else { return nil }
        let choices = SmartListChoices.statuses(for: mediaType)
        let allowed = choices.map(\.value).joined(separator: ", ")
        return await cachedValues("statuses-\(mediaType.rawValue)", words) {
            await ask(AskCodes.self, about: words, instructions: "Map these words to statuses. Allowed statuses: \(allowed).").map(\.codes)
        }.flatMap { allowedValues($0, in: choices) }
    }

    /// Parents Guide topics named with a limit just before them: "too scary" or "mild language" allow up to mild,
    /// "no violence" or "without nudity" none. Matched directly: given a whole request, the model invents limits.
    private static func parentalLimits(in request: String) -> [(WritableKeyPath<SmartListFilters, [Double]?>, Int)] {
        let words = words(in: request)
        var limits = [WritableKeyPath<SmartListFilters, [Double]?>: Int]()
        for (index, word) in words.enumerated() {
            guard let topics = parentalKeywords.first(where: { $0.key.contains(word) })?.value else { continue }
            let before = words[max(0, index - 3)..<index]
            let level: Int
            if before.contains(where: { ["too", "mild", "little", "bit", "much"].contains($0) }) {
                level = 1
            } else if before.contains(where: { ["no", "not", "without", "aren't", "isn't", "nothing"].contains($0) }) {
                level = 0
            } else {
                continue
            }
            for topic in topics {
                limits[topic] = min(limits[topic] ?? level, level)
            }
        }
        return parentalTopics.compactMap { topic in limits[topic].map { (topic, $0) } }
    }

    /// Scary scenes usually come with violence: "too scary" limits both.
    private static let parentalKeywords: [Set<String>: [WritableKeyPath<SmartListFilters, [Double]?>]] = [
        ["nudity", "nude", "sex", "sexual"]: [\.parentalNudity],
        ["violence", "violent", "gore", "gory", "bloody"]: [\.parentalViolence],
        ["swearing", "swear", "profanity", "language", "cursing"]: [\.parentalProfanity],
        ["alcohol", "drugs", "drug", "drinking", "smoking"]: [\.parentalAlcohol],
        ["scary", "frightening", "intense", "creepy"]: [\.parentalFrightening, \.parentalViolence]
    ]

    // MARK: - Helpers

    private static func ask<Value: Generable>(_ type: Value.Type, about words: String, instructions: String) async -> Value? {
        guard Task.isCancelled == false else { return nil }
        // Greedy sampling is a little faster and gives the same answer for the same words.
        let response = try? await LanguageModelSession(instructions: instructions).respond(to: words, generating: type, options: GenerationOptions(samplingMode: .greedy))
        guard Task.isCancelled == false else { return nil }
        return response?.content
    }

    private static func cachedValues(_ kind: String, _ words: String, _ generate: () async -> [String]?) async -> [String]? {
        let key = "\(kind)|\(words.lowercased())"
        if let cached = valuesCache.value(forKey: key) {
            return cached
        }
        guard Task.isCancelled == false, let values = await generate(), values.isEmpty == false,
              Task.isCancelled == false else { return nil }
        valuesCache.setValue(values, forKey: key)
        return values
    }

    private static func allowedValues(_ values: [String], in choices: [SmartListChoice]) -> [String]? {
        let allowed = Set(choices.map(\.value))
        let values = values.map { $0.lowercased() }.filter { allowed.contains($0) }.removingDuplicates()
        return values.isEmpty ? nil : values
    }

    private static func serviceKey(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " plus", with: "+")
            .filter { $0.isLetter || $0.isNumber || $0 == "+" }
    }
}

// MARK: - Generated values

@Generable
private struct AskQuotes {
    @Generable
    enum MediaType {
        case movies
        case shows
        case both
    }

    @Guide(description: "movies for movies or films, shows for shows, series or dramas, otherwise both.")
    var mediaType: MediaType
    /// Example words only help: quotes that weren't typed are dropped, so a copied example never becomes a condition.
    @Guide(description: "Words naming genres or kinds of titles, such as horror, comedies, dramas, sci-fi or anime. Empty if none.")
    var genres: String
    @Guide(description: "Words naming a release year, decade or period, such as 80s or 2020. Empty if none.")
    var period: String
    @Guide(description: "Words about runtime or length, such as under 90 minutes or short. Empty if none.")
    var runtime: String
    @Guide(description: "Words about ratings or quality, such as well rated or a good rating. Empty if none.")
    var rating: String
    @Guide(description: "Words naming a language or nationality, such as Korean or French. Empty if none.")
    var language: String
    @Guide(description: "Words naming a production country, such as from Japan. Empty if none.")
    var country: String
    @Guide(description: "Words naming streaming services, such as Netflix. Empty if none.")
    var services: String
    @Guide(description: "The words of the request saying who the titles are suitable for, or naming an age certification. Empty if none.")
    var audience: String
    @Guide(description: "Words about whether titles are released, still running, ended or canceled. Empty if none.")
    var status: String
    @Guide(description: "Words about titles not watched yet, such as haven't watched. Empty if none.")
    var unwatched: String
    @Guide(description: "Words about titles not on the watchlist yet. Empty if none.")
    var notOnWatchlist: String
}

@Generable
private struct AskCodes {
    var codes: [String]
}

@Generable
private struct AskPeriod {
    var fromYear: Int
    var toYear: Int
}

@Generable
private struct AskRuntime {
    @Guide(description: "Shortest runtime in minutes, 0 if none.")
    var minimum: Int
    @Guide(description: "Longest runtime in minutes, 300 if none.")
    var maximum: Int
}

@Generable
private struct AskRating {
    @Guide(description: "Lowest Trakt rating from 0 to 100: 70 for good, 80 for great.")
    var minimum: Int
}
