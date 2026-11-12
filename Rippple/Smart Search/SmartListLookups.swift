//
//  SmartListLookups.swift
//  Rippple
//
//  Created by Kevin Cador on 25/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import LRUCache

/// What Trakt has, as the smart list assistant checks it: the lists of genres, countries, languages and services, and
/// people, themes and studios looked up by name.
extension SmartListAssistant {
    /// Trakt lookups by name, also those finding nothing, for an hour: Trakt adds keywords and people over time.
    static let lookupCache = LRUCache<String, Lookup>(countLimit: 1000)

    struct Lookup {
        let values: [String]
        let date: Date
    }

    /// `nil` when Trakt can't be reached, which isn't cached.
    static func lookedUp(_ key: String, _ search: () async throws -> [String]) async -> [String]? {
        if let cached = lookupCache.value(forKey: key), Date().timeIntervalSince(cached.date) < 3600 {
            return cached.values
        }
        guard Task.isCancelled == false, let values = try? await search() else { return nil }
        lookupCache.setValue(Lookup(values: values, date: Date()), forKey: key)
        return values
    }

    /// Compares names without case, accents or punctuation: "Bong Joon-ho" is "Bong Joon Ho".
    static func nameKey(_ name: String) -> String {
        name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .filter { $0.isLetter || $0.isNumber }
    }

    /// What Trakt offers for the media type, loaded side by side.
    struct Lists {
        let genres: [SmartListChoice]
        let languages: [SmartListChoice]
        let countries: [SmartListChoice]
        let services: [SmartListChoice]

        static func load(for mediaType: SmartListMediaType) async -> Lists {
            async let genres = SmartListChoices.genres(for: mediaType)
            async let languages = SmartListChoices.languages(for: mediaType)
            async let countries = SmartListChoices.countries(for: mediaType)
            async let services = SmartListChoices.watchNowServices()
            return Lists(genres: (try? await genres) ?? [], languages: (try? await languages) ?? [], countries: (try? await countries) ?? [],
                         services: await services)
        }
    }

    // MARK: - Names

    /// The Trakt keyword named exactly by this phrase, also as a plural or without the dates Trakt adds to some, as
    /// "korean war (1950-53)".
    static func themeName(for phrase: String) async -> String? {
        let phrase = phrase.lowercased()
        let undated = { (name: String) in name.lowercased().replacingOccurrences(of: #" \([^)]*\)$"#, with: "", options: .regularExpression) }
        // Titles are tagged with the singular far more often, "zombie" over "zombies", and Trakt searches names starting
        // with the query, so "vampires" only finds "vampire" from its singular. "Politics" and "news" aren't plurals.
        var singulars = [String]()
        if phrase.hasSuffix("s"), phrase.hasSuffix("ss") == false, phrase.hasSuffix("ics") == false,
           ["news", "series", "species"].contains(phrase) == false {
            let isEsPlural = ["ches", "shes", "xes", "zes", "sses", "oes"].contains { phrase.hasSuffix($0) }
            singulars = phrase.hasSuffix("ies") ? [String(phrase.dropLast(3)) + "y", String(phrase.dropLast())]
                : isEsPlural ? [String(phrase.dropLast(2)), String(phrase.dropLast())] : [String(phrase.dropLast())]
        }
        var found = [String]()
        for query in singulars + [phrase] {
            guard let names = await lookedUp("keywords|\(query)", { try await SmartListChoices.search(.keywords, query: query).map(\.value) })
            else { return nil }
            if let name = names.first(where: { undated($0) == query }) {
                return name
            }
            found = names
        }
        return found.first { isSame(phrase, $0.lowercased()) }
    }

    static let broadServiceValues = Set(SmartListChoices.watchNow.map(\.value))

    static func serviceKey(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " plus", with: "+")
            .filter { $0.isLetter || $0.isNumber || $0 == "+" }
    }

    /// Country names Trakt doesn't use: "the UK", "Korea".
    static let countryNames = [
        "uk": "gb", "britain": "gb", "great britain": "gb", "england": "gb", "us": "us", "usa": "us", "america": "us", "korea": "kr",
        "holland": "nl"
    ]

    /// Where titles are from, typed as an adjective: "French movies" are from France, while "movies in French" are spoken
    /// in French.
    static let nationalities = [
        "french": "fr", "korean": "kr", "japanese": "jp", "spanish": "es", "german": "de", "italian": "it", "chinese": "cn",
        "english": "gb", "british": "gb", "scottish": "gb", "american": "us", "mexican": "mx", "indian": "in", "canadian": "ca",
        "australian": "au", "brazilian": "br", "irish": "ie", "argentinian": "ar", "argentine": "ar", "colombian": "co",
        "belgian": "be", "swiss": "ch", "austrian": "at", "taiwanese": "tw", "chilean": "cl", "egyptian": "eg", "nigerian": "ng",
        "israeli": "il", "iranian": "ir", "danish": "dk", "swedish": "se", "norwegian": "no", "finnish": "fi", "dutch": "nl",
        "polish": "pl", "russian": "ru", "turkish": "tr", "greek": "gr", "portuguese": "pt", "thai": "th", "vietnamese": "vn",
        "indonesian": "id", "czech": "cz", "hungarian": "hu", "ukrainian": "ua", "icelandic": "is"
    ]

    /// A Trakt person named exactly so, as a misread name isn't guessed.
    static func person(named name: String) async -> (slug: String, name: String)? {
        guard let found = await lookedUp("people|\(nameKey(name))", {
            try await SmartListChoices.search(.people, query: name).filter { nameKey($0.title) == nameKey(name) }.map(cachedPerson)
        })?.first else { return nil }
        return person(cached: found, or: name)
    }

    /// People are cached as "slug<tab>name", so the log shows Trakt's spelling: "tom hanks" is Tom Hanks.
    static func cachedPerson(_ choice: SmartListChoice) -> String {
        "\(choice.value)\t\(choice.title)"
    }

    static func person(cached: String, or name: String) -> (slug: String, name: String) {
        let parts = cached.split(separator: "\t", maxSplits: 1).map(String.init)
        return (parts[0], parts.count > 1 ? parts[1] : name)
    }

    /// The people on Trakt with this last name, as "Shyamalan". Only one is a match: "Nolan" could be Christopher or Lloyd
    /// Nolan, which isn't guessed.
    static func people(withSurname surname: String) async -> [(slug: String, name: String)]? {
        let key = nameKey(surname)
        guard let found = await lookedUp("surname|\(key)", {
            try await SmartListChoices.search(.people, query: surname)
                .filter { $0.title.split(separator: " ").last.map { nameKey(String($0)) == key } == true }
                .map(cachedPerson)
        }) else { return nil }
        return found.map { person(cached: $0, or: surname) }
    }

    static func searchedStudioSlug(named name: String) async -> String? {
        await lookedUp("studios|\(nameKey(name))") {
            try await SmartListChoices.search(.studios, query: name).filter { nameKey($0.title) == nameKey(name) }.map(\.value)
        }?.first
    }

    static let genericStudioWords: Set<String> = ["studio", "studios", "animation", "animations", "productions", "walt", "the",
                                                  "films", "pictures"]

    /// The well-known studio named by these words, whole or by a distinctive part of its name: "Ghibli" is Studio
    /// Ghibli, "studio" alone isn't.
    static func knownStudio(named typed: [String], byPart: Bool) -> SmartListChoice? {
        SmartListChoices.studios.first { studio in
            let name = words(in: studio.title)
            guard typed.isEmpty == false, typed.count <= name.count,
                  (0...name.count - typed.count).contains(where: { Array(name[$0..<$0 + typed.count]) == typed }) else { return false }
            return typed.count == name.count || (byPart && typed.contains { genericStudioWords.contains($0) == false })
        }
    }

    static let genreAliases = ["sci-fi": "science-fiction", "scifi": "science-fiction"]
}
