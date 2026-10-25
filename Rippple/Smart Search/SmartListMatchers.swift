//
//  SmartListMatchers.swift
//  Rippple
//
//  Created by Kevin Cador on 23/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

/// The conditions pass of `SmartListAssistant`: one matcher per filter, each taking only the phrasings it reads exactly.
/// Values typed together with "and" or "or" make one condition.
extension SmartListAssistant {
    /// Every condition typed, each word in one condition at most. Themes come first, so "about war" is the theme rather
    /// than the War genre; the other matchers only take words no condition took before them.
    static func conditions(in tokens: [Token], claimed: Set<Int>, lists: Lists) async -> [Match] {
        let words = tokens.map(\.word)
        var taken = claimed
        var matches = [Match]()
        let take = { (found: [Match]) in
            for match in found.sorted(by: { $0.range.count > $1.range.count })
                where taken.isDisjoint(with: match.range) && taken.isDisjoint(with: match.alsoRead ?? 0..<0) {
                taken.formUnion(match.range)
                taken.formUnion(match.alsoRead ?? 0..<0)
                matches.append(match)
            }
        }
        take(await themeMatches(in: words, claimed: taken))
        take(await knownThemeMatches(in: tokens, genres: lists.genres))
        take(parentalMatches(in: words))
        take(watchedMatches(in: words))
        take(releasedMatches(in: words))
        take(statusMatches(in: words))
        take(certificationMatches(in: words))
        take(ratingMatches(in: words, claimed: taken))
        take(runtimeMatches(in: words))
        take(yearMatches(in: words))
        take(serviceMatches(in: tokens, services: lists.services))
        take(broadServiceMatches(in: words))
        take(languageMatches(in: words, lists: lists))
        take(countryMatches(in: tokens, lists: lists, claimed: taken))
        take(await peopleMatches(in: tokens, lists: lists, claimed: taken))
        take(await studioMatches(in: tokens, claimed: taken))
        // After names, so "Martin Short" stays a person.
        take(shortRuntimeMatches(in: words))
        take(genreMatches(in: words, lists: lists))
        return grouped(matches.sorted { $0.range.lowerBound < $1.range.lowerBound }, in: words)
    }

    // MARK: - Lists

    /// Values of one kind typed with "and" or "or" in between, as "on Netflix or Hulu", make one condition, and so do
    /// genres typed side by side. "And" means every value where Trakt can require them all: genres, themes and people. A value joined to excluded ones is
    /// excluded too unless it has a negation of its own, as "funny" in "not horror or funny"; a negated value doesn't join
    /// wanted ones.
    static func grouped(_ matches: [Match], in words: [String]) -> [Match] {
        var groups = [Match]()
        for match in matches {
            // "No nudity or mild nudity", "no nudity or with only mild nudity": limits on one category joined by "or" allow
            // the higher one.
            if var last = groups.last, case .parental(let category, let most, nil) = last.condition,
               case .parental(category, let other, nil) = match.condition, last.isNegated == false, match.isNegated == false,
               last.range.upperBound <= match.range.lowerBound,
               case let gap = Set(words[last.range.upperBound..<match.range.lowerBound]), gap.contains("or"),
               gap.subtracting(parentalAlternativeWords).isEmpty {
                last.range = last.range.lowerBound..<match.range.upperBound
                last.condition = .parental(category, most: max(most, other))
                last.titles = [label(of: last)]
                groups[groups.count - 1] = last
                continue
            }
            // Conditions read from the same words, as a genre and a theme written in for one phrase, stay apart.
            guard var last = groups.last, last.range.upperBound <= match.range.lowerBound,
                  last.isNegated == match.isNegated || (last.isNegated && match.negation == nil),
                  let merged = merging(last.condition, match.condition) else {
                groups.append(match)
                continue
            }
            let gap = Set(words[last.range.upperBound..<match.range.lowerBound])
            // Themes are read without their lead-in, as "zombies" in "with zombies and with time travel": typed again, it's
            // in the gap.
            let gapLeadIns: Set<String> = {
                guard case .themes = match.condition else { return [] }
                return gap.intersection(leadIns)
            }()
            // "Not on Netflix and on Disney+": a lead-in typed again after "and" starts a clause of its own, out of the
            // negation's reach. "Not on Netflix or on Hulu" is neither.
            let isNewClause = gap.contains("and") && gap.contains("or") == false
                && (leadIns.contains(words[match.range.lowerBound]) || gapLeadIns.isEmpty == false)
                && (last.isNegated || freeNegation(before: last.range.lowerBound, in: words, among: matches) != nil)
            // "Romantic comedies" or "action thriller": genres typed side by side are one kind of title, with both.
            let isStacked: Bool = {
                guard gap.isEmpty, case .genres = last.condition, case .genres = match.condition else { return false }
                return true
            }()
            guard isStacked || (gap.isEmpty == false && gap.subtracting(gapLeadIns).isSubset(of: ["and", "or", "the", "a", "an"])
                && gap.isDisjoint(with: ["and", "or"]) == false),
                isNewClause == false else {
                groups.append(match)
                continue
            }
            last.requiresAll = (last.titles.count == 1 || last.requiresAll) && gap.contains("or") == false
            last.range = last.range.lowerBound..<match.range.upperBound
            last.condition = merged
            last.titles += match.titles
            // "Horror and spooky" is Horror once.
            if let values = values(of: last.condition), values.count == last.titles.count {
                let titles = last.titles
                let unique = titles.indices.filter { titles.firstIndex(of: titles[$0]) == $0 }
                last.condition = condition(last.condition, with: unique.map { values[$0] })
                last.titles = unique.map { titles[$0] }
                last.requiresAll = last.requiresAll && unique.count > 1
            }
            groups[groups.count - 1] = last
        }
        return groups
    }

    /// The values of a list condition, in the order of its titles.
    private static func values(of condition: Condition) -> [String]? {
        switch condition {
        case .genres(let values), .countries(let values), .languages(let values), .services(let values), .people(let values, _),
             .studios(let values), .themes(let values), .statuses(let values), .certifications(let values):
            return values
        default: return nil
        }
    }

    private static func condition(_ condition: Condition, with values: [String]) -> Condition {
        switch condition {
        case .genres: return .genres(values)
        case .countries: return .countries(values)
        case .languages: return .languages(values)
        case .services: return .services(values)
        case .people(_, let role): return .people(values, role: role)
        case .studios: return .studios(values)
        case .themes: return .themes(values)
        case .statuses: return .statuses(values)
        case .certifications: return .certifications(values)
        default: return condition
        }
    }

    /// The match without the values another condition already has, as Comedy alone from "spooky and funny" after
    /// "horror". `nil` when none is left.
    static func dropping(_ titles: Set<String>, from match: Match) -> Match? {
        guard let values = values(of: match.condition), values.count == match.titles.count else {
            return titles.contains(where: match.titles.contains) ? nil : match
        }
        let kept = match.titles.indices.filter { titles.contains(match.titles[$0]) == false }
        guard kept.isEmpty == false else { return nil }
        var rest = match
        rest.condition = condition(match.condition, with: kept.map { values[$0] })
        rest.titles = kept.map { match.titles[$0] }
        // "Spooky and funny" after "horror" still needs both: the "and" holds for the value already there.
        rest.requiresAll = match.requiresAll
        return rest
    }

    /// Words a condition may start with, introducing its values: "on Netflix", "from France".
    private static let leadIns: Set<String> = ["on", "from", "in", "by", "with", "starring", "featuring", "about", "involving", "directed",
                                               "written"]

    private static func merging(_ first: Condition, _ second: Condition) -> Condition? {
        switch (first, second) {
        case (.genres(let a), .genres(let b)): return .genres(a + b)
        case (.countries(let a), .countries(let b)): return .countries(a + b)
        case (.languages(let a), .languages(let b)): return .languages(a + b)
        case (.services(let a), .services(let b)): return .services(a + b)
        case (.studios(let a), .studios(let b)): return .studios(a + b)
        case (.themes(let a), .themes(let b)): return .themes(a + b)
        case (.years(let a), .years(let b)): return .years(a + b)
        // "With Tom Hanks and Meg Ryan": a name after the first takes its role.
        case (.people(let a, let role), .people(let b, let other)) where other == nil || other == role: return .people(a + b, role: role)
        default: return nil
        }
    }

    // MARK: - Themes

    /// Words that end a theme typed after "about": "about war from the 90s".
    private static let themeEnds: Set<String> = [
        "from", "on", "in", "with", "by", "starring", "featuring", "directed", "written", "that", "which", "who", "released",
        "rated", "made", "set", "under", "over", "before", "after", "since", "between", "and", "or", "i", "my"
    ]

    /// Themes only where one was asked for, as "about war" or "involving time travel and zombies": Trakt has a keyword for
    /// nearly any word, as "high" or "rock", so a theme read anywhere would turn words into conditions they don't mean.
    private static func themeMatches(in words: [String], claimed: Set<Int>) async -> [Match] {
        var matches = [Match]()
        for index in words.indices where ["about", "involving"].contains(words[index]) && claimed.contains(index) == false {
            var start = index + 1
            var isFirst = true
            while true {
                while start < words.count, ["the", "a", "an"].contains(words[start]) {
                    start += 1
                }
                var end = start
                while end < words.count, end - start < 5, themeEnds.contains(words[end]) == false, negatives.contains(words[end]) == false,
                      claimed.contains(end) == false, words[end].first?.isNumber == false {
                    end += 1
                }
                guard end > start, let (length, name) = await keyword(startingAt: start, upTo: end, in: words) else { break }
                matches.append(Match(range: (isFirst ? index : start)..<start + length, condition: .themes([name]), titles: [name]))
                isFirst = false
                let next = start + length
                guard next + 1 < words.count, ["and", "or"].contains(words[next]) else { break }
                start = next + 1
            }
        }
        return matches
    }

    /// The longest Trakt keyword typed from `start`, with how many words it takes: "time travel", "war", or "korean war"
    /// for "korean war (1950-53)", which Trakt dates.
    private static func keyword(startingAt start: Int, upTo end: Int, in words: [String]) async -> (Int, String)? {
        for length in stride(from: end - start, through: 1, by: -1) {
            if let name = await themeName(for: words[start..<start + length].joined(separator: " ")) {
                return (length, name)
            }
        }
        return nil
    }

    /// Themes that mean one thing wherever they're typed, beside the composer's quick picks.
    static let commonThemes = [
        "christmas", "halloween", "thanksgiving", "valentine's day", "easter", "heist", "time travel", "zombie", "vampire", "werewolf",
        "alien", "robot", "dinosaur", "shark", "pirate", "space", "dystopia", "post-apocalyptic", "serial killer", "coming of age",
        "martial arts", "road trip", "high school", "kaiju", "cyberpunk", "witch", "ghost", "monster", "spy", "zombie apocalypse",
        "time loop", "haunted house", "survival", "artificial intelligence", "boxing", "basketball", "baseball", "football", "soccer"
    ]

    /// Other ways people say a theme: "based on a book" is Trakt's "based on novel or book".
    private static let themeAliases = [
        "based on a novel": "based on novel or book", "based on novels": "based on novel or book", "based on a book": "based on novel or book",
        "based on books": "based on novel or book", "based on the book": "based on novel or book", "based on the novel": "based on novel or book",
        "book adaptation": "based on novel or book", "adapted from a book": "based on novel or book", "adapted from a novel": "based on novel or book",
        "based on a true story": "based on true story", "based on true stories": "based on true story", "based on real events": "based on true story",
        "based on true events": "based on true story", "true story": "based on true story", "true stories": "based on true story",
        "superheroes": "superhero", "post apocalyptic": "post-apocalyptic", "coming-of-age": "coming of age", "time-travel": "time travel"
    ]

    /// The quick-pick keywords and common themes, once each.
    static let knownThemes = (SmartListChoices.keywords.map(\.value) + commonThemes).removingDuplicates()

    /// Every known theme and other way of saying one, split into words once, with the keyword it means.
    private static let knownThemePhrases: [(words: [String], keyword: String)] =
        (knownThemes.map { ($0, $0) } + themeAliases.map { ($0.key, $0.value) }).map { (SmartListAssistant.words(in: $0.0), $0.1) }

    /// The composer's quick-pick keywords and common themes, wherever they're typed, as "zombie shows" or "heist and time
    /// travel movies", and other ways of saying them. A theme that's also a genre, as "superhero", is the genre's.
    private static func knownThemeMatches(in tokens: [Token], genres: [SmartListChoice]) async -> [Match] {
        let words = tokens.map(\.word)
        let genreNames = Set(genres.map { $0.title.lowercased() })
        var matches = [Match]()
        for (phrase, keyword) in knownThemePhrases where genreNames.contains(keyword) == false {
            for range in ranges(of: phrase, in: words) {
                guard await isNameOrComparedTitle(range, in: tokens) == false, let name = await themeName(for: keyword) else { continue }
                matches.append(Match(range: range, condition: .themes([name]), titles: [name]))
            }
        }
        return matches
    }

    /// Words that end the titles a request compares with, where the rest of the request starts: "from" in "movies like
    /// Alien from the 80s".
    private static let comparisonEnds: Set<String> = [
        "from", "on", "with", "without", "that", "which", "who", "released", "in", "by", "rated", "under", "over", "before",
        "after", "since", "starring", "directed", "about", "set", "for", "but", "not", "are", "is"
    ]

    /// A theme within the titles a request compares with, as "Christmas" in "movies like A Christmas Story" or "Halloween"
    /// in "like Alien or Halloween", names a title rather than the theme. Comparing isn't searchable, so it's left unread.
    static func isCompared(_ range: Range<Int>, in tokens: [Token]) -> Bool {
        let words = tokens.map(\.word)
        // "Like Alien with a Christmas theme" asks for the theme after the title.
        if range.upperBound < words.count, ["theme", "themed", "themes", "vibe", "vibes", "feel", "feeling", "mood", "setting"].contains(words[range.upperBound]) {
            return false
        }
        var index = range.lowerBound
        while index > 0 {
            let word = words[index - 1]
            // "I'd like zombie movies" says what's wanted.
            if word == "like", index < 2 || ["i", "i'd", "we", "you", "they", "would", "really", "also", "might", "to"].contains(words[index - 2]) == false {
                return true
            }
            if index > 1, [["similar", "to"], ["such", "as"]].contains([words[index - 2], word]) {
                return true
            }
            // Inside a title, as "Before" in "The Nightmare Before Christmas" or "with" in "Interview with the Vampire", these
            // words don't end it: capitalized, between capitalized words, or followed by an article or a holiday's "before".
            let isInTitle = tokens[index - 1].isCapitalized
                || tokens[range.lowerBound].isCapitalized && index > 1 && tokens[index - 2].isCapitalized
                || index < words.count && ["the", "a", "an"].contains(words[index])
                || ["before", "after"].contains(word)
            guard comparisonEnds.contains(word) == false || isInTitle else { return false }
            index -= 1
        }
        return false
    }

    /// A theme typed as part of a person's name, as "Zombie" in "directed by Rob Zombie", is left to the person: a name
    /// typed capitalized, or right after a role word, found on Trakt as typed. A single word right after a role, as in
    /// "directed by Zombie", is a last name, left to the people matcher as it would read it.
    /// A theme typed where it names someone or a compared title is left to them, by the rules and Apple Intelligence alike.
    static func isNameOrComparedTitle(_ range: Range<Int>, in tokens: [Token]) async -> Bool {
        if isCompared(range, in: tokens) {
            return true
        }
        return await isInName(range, tokens: tokens)
    }

    static func isInName(_ range: Range<Int>, tokens: [Token]) async -> Bool {
        let words = tokens.map(\.word)
        if let role = role(before: range.lowerBound, in: words)?.words {
            // After "directed by", "starring" or "by", whatever follows is a person's or a studio's name, however it's typed:
            // "by zombie", "directed by Time Travel". After "with" or "featuring", only a capitalized last name one person
            // has: "with zombies" is the theme.
            if role.count > 1 || role == ["starring"] || role == ["by"] {
                return true
            }
            if range.count == 1, tokens[range.lowerBound].isCapitalized, let people = await people(withSurname: tokens[range.lowerBound].text),
               people.count == 1 {
                return true
            }
        }
        guard range.count < 3 else { return false }
        for start in max(0, range.upperBound - 3)...range.lowerBound {
            let isAfterRole = role(before: start, in: words) != nil
            for end in range.upperBound...min(tokens.count, start + 3) where end - start >= 2 {
                let span = tokens[start..<end]
                guard span.allSatisfy({ $0.word.allSatisfy(\.isLetter) }), span.allSatisfy(\.isCapitalized) || isAfterRole else { continue }
                if await person(named: span.map(\.text).joined(separator: " ")) != nil {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Show statuses

    /// Trakt's show statuses by the words people use: "canceled", "ended", "still airing".
    static let statusWords = [
        "canceled": "canceled", "cancelled": "canceled", "ended": "ended", "returning series": "returning series",
        "returning": "returning series", "renewed": "returning series", "ongoing": "returning series",
        "still airing": "returning series", "still running": "returning series", "currently airing": "returning series",
        "in production": "in production"
    ]

    /// Statuses joined by "or" are one condition, so "not canceled or ended" leaves both out. "Haven't been canceled"
    /// is negated here; other negations, as "not canceled", are read with every condition's.
    private static func statusMatches(in words: [String]) -> [Match] {
        // Longest first where phrases start together, so "returning series" wins over "returning" whatever the order.
        var found = [(range: Range<Int>, status: String)]()
        for (phrase, status) in statusWords {
            found += ranges(of: SmartListAssistant.words(in: phrase), in: words).map { ($0, status) }
        }
        found.sort { first, second in
            first.range.lowerBound == second.range.lowerBound ? first.range.count > second.range.count : first.range.lowerBound < second.range.lowerBound
        }
        var groups = [(range: Range<Int>, statuses: [String])]()
        for (range, status) in found {
            if let last = groups.last, last.range.upperBound + 1 == range.lowerBound,
               ["or", "and", "nor"].contains(words[last.range.upperBound]) {
                groups[groups.count - 1] = (last.range.lowerBound..<range.upperBound, (last.statuses + [status]).removingDuplicates())
            } else if groups.last?.range.overlaps(range) != true {
                groups.append((range, [status]))
            }
        }
        return groups.map { range, statuses in
            var match = Match(range: range, condition: .statuses(statuses), titles: statuses.map(\.smartListTitle))
            var start = range.lowerBound
            while start > 0, ["been", "yet", "ever", "got", "get", "gotten"].contains(words[start - 1]) {
                start -= 1
            }
            if start > 0, ["haven't", "hasn't", "didn't", "wasn't", "weren't", "never"].contains(words[start - 1]) {
                match.range = (start - 1)..<range.upperBound
                match.isNegated = true
                match.negation = (start - 1)..<start
            }
            return match
        }
    }

    // MARK: - Certifications

    static let audienceWords: [String: Audience] = [
        "for adults": .adults, "for grown-ups": .adults, "for grownups": .adults, "adult": .adults, "adults": .adults,
        "mature": .adults, "for kids": .kids, "for children": .kids, "kids": .kids, "children's": .kids, "kid-friendly": .kids,
        "for teens": .teens, "for teenagers": .teens
    ]

    /// An audience certification, as "for kids": "young adult" is a kind of story instead.
    static func certificationMatch(for audience: Audience, at range: Range<Int>, in words: [String]) -> Match? {
        guard range.lowerBound == 0 || words[range.lowerBound - 1] != "young" else { return nil }
        let codes = audience.certifications(in: words)
        return Match(range: range, condition: .certifications(codes), titles: codes.map { $0.uppercased() })
    }

    private static func certificationMatches(in words: [String]) -> [Match] {
        var matches = [Match]()
        for (index, word) in words.enumerated() {
            let rated = word.hasSuffix("-rated") ? String(word.dropLast(6)) : nil
            let isAfterRated = index > 0 && words[index - 1] == "rated"
            guard let code = rated ?? (certificationCodes.contains(word) ? word : nil), certificationCodes.contains(code),
                  code.contains("-") || rated != nil || isAfterRated else { continue }
            matches.append(Match(range: (isAfterRated ? index - 1 : index)..<index + 1, condition: .certifications([code]),
                                 titles: [code.uppercased()]))
        }
        for (phrase, audience) in audienceWords {
            matches += ranges(of: SmartListAssistant.words(in: phrase), in: words).compactMap { certificationMatch(for: audience, at: $0, in: words) }
        }
        return matches
    }

    // MARK: - Parents guide

    /// How the parents guide categories are named: "sex scenes", "gore", "swearing".
    private static let parentalNames: [String: [String]] = [
        "nudity": ["nudity", "nude", "sex", "sex scenes", "sexual content", "sexual", "sex scene"],
        "violence": ["violence", "violent", "gore", "gory", "blood", "bloody"],
        "profanity": ["profanity", "swearing", "swear words", "cursing", "curse words", "bad language", "foul language"],
        "alcohol": ["alcohol", "drinking", "drugs", "drug use", "smoking"],
        "frightening": ["frightening scenes", "intense scenes", "jump scares"]
    ]

    /// How much, said right before a category, as the composer's level: "no" is none, "mild" is mild.
    private static let parentalLevels: [(words: [String], most: Int)] = [
        (["not", "too", "much"], 1), (["not", "much"], 1), (["not", "too"], 1), (["a", "little"], 1), (["free", "of"], 0), (["not", "any"], 0),
        (["no"], 0), (["without"], 0), (["zero"], 0), (["not"], 0), (["mild"], 1), (["light"], 1), (["little"], 1),
        (["minimal"], 1), (["low"], 1), (["moderate"], 2), (["some"], 2), (["severe"], 3)
    ]

    /// Said between a comparison and its level, as "very" in "less than very moderate violence".
    private static let parentalModifiers: Set<String> = ["only", "very", "any", "really", "quite", "fairly", "pretty", "too"]

    /// Comparisons said before a level, with how they move it: "at most mild" is mild, "less than moderate" is mild too.
    private static let parentalMostComparisons: [(words: [String], offset: Int)] = [
        (["at", "most"], 0), (["up", "to"], 0), (["no", "more", "than"], 0), (["not", "more", "than"], 0), (["less", "than"], -1),
        (["fewer", "than"], -1), (["lower", "than"], -1), (["under"], -1), (["below"], -1)
    ]

    /// Comparisons that ask for at least a level, which the composer can't search: "at least moderate", "more than mild".
    private static let parentalLeastComparisons: [(words: [String], offset: Int)] = [
        (["at", "least"], 0), (["no", "less", "than"], 0), (["not", "less", "than"], 0), (["more", "than"], 1), (["higher", "than"], 1),
        (["greater", "than"], 1), (["over"], 1), (["above"], 1)
    ]

    /// Parents guide limits, only with a level: "mild violence", "without nudity", "no gore", "not too violent", "at most
    /// moderate violence". "Violent movies" asks for violence rather than limiting it, so a category alone isn't read. "At
    /// least moderate violence" is read whole, so it's skipped rather than taken as a highest level.
    private static func parentalMatches(in words: [String]) -> [Match] {
        var matches = [Match]()
        for category in parentalNames.keys {
            for name in parentalNameWords[category] ?? [] {
                for range in ranges(of: name, in: words) {
                    // "With only mild violence".
                    var end = range.lowerBound
                    while end > 0, ["only", "very", "any"].contains(words[end - 1]) {
                        end -= 1
                    }
                    guard let level = parentalLevels.first(where: { ends(words, at: end, with: $0.words) }) else { continue }
                    var start = end - level.words.count
                    // "Less than very moderate violence".
                    let compared = skippingModifiers(before: start, in: words)
                    var condition = Condition.parental(category, most: level.most)
                    if let comparison = parentalMostComparisons.first(where: { ends(words, at: compared, with: $0.words) }) {
                        guard level.most + comparison.offset >= 0 else { continue }
                        start = compared - comparison.words.count
                        condition = .parental(category, most: level.most + comparison.offset)
                        // "At least mild and at most moderate violence": a least said first is read with it.
                        if start > 0, ["and", "but"].contains(words[start - 1]), let least = parentalLeast(endingAt: start - 1, in: words) {
                            start = least.start
                            condition = .parental(category, most: level.most + comparison.offset, least: least.least)
                        }
                    } else if let comparison = parentalLeastComparisons.first(where: { ends(words, at: compared, with: $0.words) }) {
                        condition = .parental(category, most: severities.count - 1, least: level.most + comparison.offset)
                        start = compared - comparison.words.count
                    } else if compared > 1, ["and", "to", "through"].contains(words[compared - 1]),
                              let lower = parentalLevels.first(where: { $0.most > 0 && ends(words, at: compared - 1, with: $0.words) }) {
                        // "Mild to moderate violence", "between very mild and very moderate violence": a range with a least.
                        let from = skippingModifiers(before: compared - 1 - lower.words.count, in: words)
                        start = from > 0 && ["between", "from"].contains(words[from - 1]) ? from - 1 : from
                        condition = .parental(category, most: level.most, least: lower.most)
                    } else if level.most == severities.count - 1 {
                        // "Severe violence" asks for it rather than limiting it.
                        continue
                    }
                    var match = Match(range: start..<range.upperBound, condition: condition, titles: [])
                    match.titles = [label(of: match)]
                    matches.append(match)
                }
            }
        }
        return matches + parentalJoined(to: matches, in: words)
    }

    /// The parents guide names, split into words once.
    private static let parentalNameWords = parentalNames.mapValues { $0.map(SmartListAssistant.words(in:)) }

    /// Words that may come between a limit and another one on the same category: "no nudity or with only mild nudity".
    private static let parentalAlternativeWords = parentalModifiers.union(["or", "with"])

    /// Whether `phrase` is typed right before `end`.
    private static func ends(_ words: [String], at end: Int, with phrase: [String]) -> Bool {
        words[..<end].reversed().starts(with: phrase.reversed())
    }

    /// Where the modifiers typed right before `index` start, as "very" in "less than very moderate".
    private static func skippingModifiers(before index: Int, in words: [String]) -> Int {
        var index = index
        while index > 0, parentalModifiers.contains(words[index - 1]) {
            index -= 1
        }
        return index
    }

    /// A least said as "at least mild", ending right before `end`, with where it starts.
    private static func parentalLeast(endingAt end: Int, in words: [String]) -> (start: Int, least: Int)? {
        guard let level = parentalLevels.first(where: { $0.most > 0 && ends(words, at: end, with: $0.words) }) else { return nil }
        let compared = skippingModifiers(before: end - level.words.count, in: words)
        guard let comparison = parentalLeastComparisons.first(where: { ends(words, at: compared, with: $0.words) }) else { return nil }
        return (compared - comparison.words.count, level.most + comparison.offset)
    }

    /// Categories joined to a limited one share its limit, and its negation once read: "no nudity or violence", "mild
    /// violence, gore and swearing", and all of "without mild violence or profanity" excluded.
    private static func parentalJoined(to limited: [Match], in words: [String]) -> [Match] {
        var joined = [Match]()
        var previous = limited
        while previous.isEmpty == false {
            var found = [Match]()
            for source in previous {
                guard case .parental(_, let most, let least) = source.condition else { continue }
                var next = source.range.upperBound
                if next < words.count, ["or", "and", "nor"].contains(words[next]) {
                    next += 1
                }
                for category in parentalNames.keys {
                    guard let name = (parentalNameWords[category] ?? []).filter({ words.dropFirst(next).starts(with: $0) })
                        .max(by: { $0.count < $1.count }) else { continue }
                    var match = Match(range: next..<next + name.count, condition: .parental(category, most: most, least: least), titles: [],
                                      joinedTo: source.range)
                    match.titles = [label(of: match)]
                    found.append(match)
                }
            }
            joined += found
            previous = found
        }
        return joined
    }

    // MARK: - Released

    /// Released or not, as people say it: "already released", "out already". A negation before, as in "not released yet"
    /// or "haven't come out yet", means not released.
    private static let releasedPhrases = ["already released", "released already", "already out", "out already", "already came out",
                                          "already been released", "been released", "released yet", "out yet", "come out yet"]
        .map(SmartListAssistant.words(in:))

    /// The negation is read with the phrase: its words are ones a negation reaches past, so a condition after it, as "in
    /// English" in "not released yet in English", would take it too.
    private static func releasedMatches(in words: [String]) -> [Match] {
        releasedPhrases.flatMap { phrase in
            // "Checked out yet" is about watching, not release.
            ranges(of: phrase, in: words)
                .filter { $0.lowerBound == 0 || ["checked", "check", "found", "figured", "worked"].contains(words[$0.lowerBound - 1]) == false }
                .map { range in
                    guard let negation = negation(before: range.lowerBound, in: words) else {
                        return Match(range: range, condition: .released, titles: ["Released"])
                    }
                    return Match(range: negation..<range.upperBound, condition: .released, titles: ["Released"], isNegated: true,
                                 negation: negation..<range.lowerBound)
                }
        }
    }

    // MARK: - Watched

    private static let unwatchedPhrases = [
        "haven't watched", "have not watched", "haven't seen", "have not seen", "haven't yet watched", "haven't yet seen",
        "didn't watch", "did not watch", "didn't see", "did not see", "never watched", "never seen", "never saw", "not watched",
        "not seen", "not yet watched", "not yet seen", "unwatched", "unseen", "haven't checked out", "have not checked out",
        "haven't gotten to", "haven't got to", "still need to watch", "still need to see", "still haven't watched", "still haven't seen",
        "haven't finished", "have not finished", "haven't completed", "haven't completely watched", "haven't fully watched"
    ]

    /// Not started is neither watched nor being watched.
    private static let notStartedPhrases = [
        "haven't started", "have not started", "haven't yet started", "haven't begun", "have not begun", "didn't start",
        "did not start", "never started", "not started"
    ]

    /// Watch verbs that can follow a negated one with "or": "haven't watched or started".
    private static let watchVerbs: [String: Condition] = [
        "watched": .unwatched, "seen": .unwatched, "finished": .unwatched, "started": .notStarted, "begun": .notStarted
    ]

    private static let notOnWatchlistPhrases = [
        "not on my watchlist", "not in my watchlist", "aren't on my watchlist", "isn't on my watchlist", "aren't in my watchlist",
        "isn't in my watchlist", "not watchlisted"
    ]

    /// "That I haven't watched yet" or "not on my watchlist": the negation is part of the phrase.
    private static func watchedMatches(in words: [String]) -> [Match] {
        let phrases = unwatchedPhrases.map { ($0, Condition.unwatched, "Not watched") }
            + notStartedPhrases.map { ($0, Condition.notStarted, "Not started") }
            + notOnWatchlistPhrases.map { ($0, Condition.notOnWatchlist, "Not on my watchlist") }
        let typed = phrases.flatMap { phrase, condition, title in
            ranges(of: SmartListAssistant.words(in: phrase), in: words).map { range in
                var end = range.upperBound < words.count && words[range.upperBound] == "yet" ? range.upperBound + 1 : range.upperBound
                var condition = condition
                // The negation carries over: "haven't watched or started watching yet" is neither, so not started.
                // "Started airing" or "finished airing" is about the show, not watching it.
                let isAboutShow = end + 2 < words.count && ["airing", "broadcasting", "running", "production", "filming", "in"].contains(words[end + 2])
                if condition != .notOnWatchlist, end + 1 < words.count, ["or", "nor", "and"].contains(words[end]),
                   let verb = watchVerbs[words[end + 1]], isAboutShow == false {
                    end += 2
                    while end < words.count, ["watching", "it", "them", "yet"].contains(words[end]) {
                        end += 1
                    }
                    condition = verb == .notStarted || condition == .notStarted ? .notStarted : .unwatched
                }
                return Match(range: range.lowerBound..<end, condition: condition, titles: [condition == .notStarted ? "Not started" : title])
            }
        }
        // Any negated "my watchlist", as "not currently on my watchlist", whatever comes between.
        let negated = ranges(of: ["my", "watchlist"], in: words).compactMap { range in
            negation(before: range.lowerBound, in: words).map { Match(range: $0..<range.upperBound, condition: .notOnWatchlist, titles: ["Not on my watchlist"]) }
        }
        return typed + negated
    }

    // MARK: - Ratings

    private static let ratingPhrases = [
        ("highly rated", 80), ("highly-rated", 80), ("top rated", 80), ("top-rated", 80), ("high rating", 80), ("high rated", 80),
        ("great rating", 80), ("best rated", 80), ("best-rated", 80), ("well rated", 70), ("well-rated", 70), ("good rating", 70),
        ("loved", 80), ("acclaimed", 80), ("praised", 75)
    ]
    /// Praise that's a rating only with its site: "loved on Rotten Tomatoes", unlike "loved by kids".
    private static let sitePhrases: Set = ["loved", "acclaimed", "praised"]
    private static let ratingQualities = ["high": 80, "great": 80, "top": 80, "good": 70, "strong": 70, "solid": 70, "decent": 60]
    /// Who rated, between a site and its rating: "IMDb user rating", "Rotten Tomatoes audience score".
    static let audienceRatingWords: Set<String> = ["user", "users", "audience", "audiences", "viewer", "viewers", "fan", "fans"]
    private static let ratingWords: Set<String> = ["rating", "ratings", "rated", "score", "scores", "scored"]
    static let scoreNames: [String: Score] = [
        "imdb": .imdb, "rotten": .rottenTomatoes, "tomatoes": .rottenTomatoes, "tomatometer": .rottenTomatoes, "rt": .rottenTomatoes,
        "metacritic": .metacritic, "metascore": .metacritic, "metascores": .metacritic, "trakt": .trakt
    ]
    /// Rating sites Trakt can't filter by, by name: a rating of theirs is read, and left out rather than read as a
    /// Trakt rating.
    static let otherRatingSites = [
        "letterboxd": "Letterboxd", "tmdb": "TMDB", "themoviedb": "TMDB", "tvdb": "TVDB", "thetvdb": "TVDB", "douban": "Douban",
        "kinopoisk": "Kinopoisk", "allocine": "AlloCiné", "filmaffinity": "FilmAffinity", "mubi": "MUBI", "simkl": "Simkl",
        "anilist": "AniList", "myanimelist": "MyAnimeList", "senscritique": "SensCritique", "csfd": "ČSFD"
    ]
    private static let maximumWords: Set = ["under", "below", "less", "lower", "most", "max", "maximum", "beneath"]

    /// A rating the request names that no filter can search, as a Letterboxd rating or a Metacritic user score.
    static func namesOtherRating(_ words: [String]) -> Bool {
        let isMetacriticUsers = words.contains { scoreNames[$0] == .metacritic } && words.contains(where: audienceRatingWords.contains)
        return isMetacriticUsers || words.contains { otherRatingSites[$0] != nil }
    }

    /// A rating site typed at `index`, and where its name ends: "IMDb", "Rotten Tomatoes", "Letterboxd".
    private static func site(at index: Int, in words: [String]) -> (score: Score, end: Int)? {
        guard index < words.count else { return nil }
        if let other = otherRatingSites[words[index]] {
            return (.unsupported(other), index + 1)
        }
        guard let name = scoreNames[words[index]] else { return nil }
        let end = name == .rottenTomatoes && words[index] == "rotten" && index + 1 < words.count && words[index + 1] == "tomatoes" ? index + 2 : index + 1
        return (name, end)
    }

    /// A site's score by its audience: Rotten Tomatoes has its own, and Metacritic's users have no filter.
    private static func audience(of score: Score) -> Score {
        switch score {
        case .rottenTomatoes: return .rottenTomatoesAudience
        case .metacritic: return .unsupported("Metacritic user")
        default: return score
        }
    }

    /// Words that may come between a rating's name and its number: "an IMDb rating of at least 8".
    private static let ratingLinks: Set<String> = ["a", "an", "of", "at", "least", "above", "over", "more", "than", "higher", "greater",
                                                   "minimum", "is", "with", "on"]

    /// A rating, by phrase or by number: "highly rated", "a rating of 80% or higher", "IMDb rating of 8 or more",
    /// "Rotten Tomatoes score above 90%". A highest rating, as "rated under 50%", is read to be left out.
    private static func ratingMatches(in words: [String], claimed: Set<Int>) -> [Match] {
        var matches = ratingPhrases.flatMap { phrase, minimum in
            ranges(of: SmartListAssistant.words(in: phrase), in: words).compactMap { range -> Match? in
                // "Highly rated on IMDb", or past what's rated: "highly rated movies on IMDb".
                var after = range.upperBound
                while after < words.count, movieWords.contains(words[after]) || showWords.contains(words[after]) {
                    after += 1
                }
                let named = score(after: after, in: words)
                guard named != nil || sitePhrases.contains(phrase) == false else { return nil }
                let kind = named?.score ?? .trakt
                var match = Match(range: range, condition: .rating(kind, minimum: minimum), titles: [ratingTitle(kind, minimum)])
                if let named = named {
                    if after == range.upperBound {
                        match.range = range.lowerBound..<named.end
                    } else {
                        match.alsoRead = after..<named.end
                    }
                }
                return match
            }
        }
        // "a high IMDb rating", "good Rotten Tomatoes scores".
        for index in words.indices {
            guard let minimum = ratingQualities[words[index]], let site = site(at: index + 1, in: words),
                  site.score != .trakt || words[index + 1] == "trakt" else { continue }
            var end = site.end
            var kind = site.score
            if end < words.count, audienceRatingWords.contains(words[end]) {
                kind = audience(of: kind)
                end += 1
            }
            guard end < words.count, ratingWords.contains(words[end]) else { continue }
            matches.append(Match(range: index..<(end + 1), condition: .rating(kind, minimum: minimum), titles: [ratingTitle(kind, minimum)]))
        }
        let numbers = quantities(in: words)
        let upperEnds = Set(numbers.keys.compactMap { rangeEnd(from: $0, in: words, numbers: numbers) })
        for (index, number) in numbers.sorted(by: { $0.key < $1.key }) where claimed.contains(index) == false && upperEnds.contains(index) == false {
            guard case .score(let tenths, let typedPercent) = number.quantity else { continue }
            var end = number.end
            // "Between 6 and 8" is read whole, to be left out: either end alone would search outside it.
            var upper: (tenths: Int, percent: Int)?
            if let other = rangeEnd(from: index, in: words, numbers: numbers), let ending = numbers[other], case .score(let t, let p) = ending.quantity {
                upper = (t, p)
                end = ending.end
            }
            var start = upper != nil && index > 0 && ["between", "from"].contains(words[index - 1]) ? index - 1 : index
            var score: Score?
            var isRating = false
            var isAudience = false
            while start > 0, claimed.contains(start - 1) == false {
                let word = words[start - 1]
                if let other = otherRatingSites[word] {
                    score = score ?? .unsupported(other)
                    isRating = true
                } else if let name = scoreNames[word] {
                    score = score ?? name
                    isRating = true
                } else if audienceRatingWords.contains(word) {
                    isAudience = true
                } else if ratingWords.contains(word) {
                    isRating = true
                } else if ratingLinks.contains(word) == false {
                    break
                }
                start -= 1
            }
            // A highest rating, as "rated below 5" or "at most 6", is read with its words, to be left out.
            var isMaximum = start > 0 && (maximumWords.contains(words[start - 1]) || (words[start - 1] == "no" && words[start] == "more"))
            if isMaximum {
                start -= words[start - 1] == "most" && start > 1 && words[start - 2] == "at" ? 2 : 1
                while start > 0, claimed.contains(start - 1) == false, ratingWords.contains(words[start - 1]) || scoreNames[words[start - 1]] != nil {
                    score = score ?? scoreNames[words[start - 1]]
                    isRating = true
                    start -= 1
                }
            }
            while start < index, ["a", "an", "with", "is", "on"].contains(words[start]) {
                start += 1
            }
            let rest = Array(words[end...])
            if let suffix = [["or", "lower"], ["or", "less"], ["or", "below"], ["or", "under"], ["or", "worse"], ["and", "below"], ["and", "under"],
                             ["and", "lower"]].first(where: { rest.starts(with: $0) }) {
                isMaximum = true
                end += suffix.count
            } else if let suffix = [["or", "higher"], ["or", "more"], ["or", "above"], ["or", "better"], ["or", "over"], ["and", "up"], ["and", "above"],
                                    ["plus"]].first(where: { rest.starts(with: $0) }) {
                end += suffix.count
            }
            if let named = self.score(after: end, in: words) {
                score = named.score
                isRating = true
                end = named.end
            }
            guard isRating else { continue }
            // "IMDb user rating" is IMDb's, "Rotten Tomatoes audience score" its audience's. Scores up to 10 are out of 10
            // on Trakt and IMDb, but not on Metacritic or Rotten Tomatoes.
            let kind = isAudience ? audience(of: score ?? .trakt) : score ?? .trakt
            let isTenths = [.trakt, .imdb].contains(kind)
            let typed = isTenths ? tenths : typedPercent
            let highest = upper.map { isTenths ? $0.tenths : $0.percent } ?? (isMaximum ? typed : nil)
            let lowest = isMaximum && upper == nil ? 0 : typed
            matches.append(Match(range: start..<end, condition: .rating(kind, minimum: lowest, maximum: highest),
                                 titles: [ratingTitle(kind, lowest, maximum: highest)]))
        }
        return matches
    }

    // MARK: - Quantities

    /// A number as typed with its unit, read before any condition so every matcher agrees on what it is: "8", "80%" and
    /// "8 out of 10" are scores, "90 minutes" a duration.
    enum Quantity: Equatable {
        /// In percent: `tenths` reads a number up to 10 as out of 10, as IMDb's, and `percent` as typed, as Metascores.
        case score(tenths: Int, percent: Int)
        case duration(minutes: Int)
    }

    /// The quantities typed, by the index they start at, with where each ends.
    static func quantities(in words: [String]) -> [Int: (quantity: Quantity, end: Int)] {
        var found = [Int: (quantity: Quantity, end: Int)]()
        var index = 0
        while index < words.count {
            let next = index + 1 < words.count ? words[index + 1] : nil
            if let length = duration(at: index, in: words) {
                found[index] = (.duration(minutes: length.minutes), length.end)
                index = length.end
            } else if let tenths = percent(of: words[index], next: next), let typed = percent(of: words[index], next: next, isOutOfTen: false) {
                var end = index + 1 + tenths.extra
                var value = (tenths: tenths.percent, percent: typed.percent)
                // The scale is part of it: "10" in "8 out of 10" isn't another score.
                if words.dropFirst(end).starts(with: ["out", "of"]), end + 2 < words.count, let scale = Double(words[end + 2]), scale > 0,
                   let number = Double(words[index].replacingOccurrences(of: "+", with: "")), number <= scale {
                    let percent = Int((number / scale * 100).rounded())
                    value = (percent, percent)
                    end += 3
                }
                found[index] = (.score(tenths: value.tenths, percent: value.percent), end)
                index = end
            } else {
                index += 1
            }
        }
        return found
    }

    /// Where the second score of a range starting at `index` is: "8" in "between 6 and 8" or "6 to 8". A score and a
    /// duration, as "8 and 90 minutes", aren't a range.
    private static func rangeEnd(from index: Int, in words: [String], numbers: [Int: (quantity: Quantity, end: Int)]) -> Int? {
        guard let number = numbers[index], case .score = number.quantity, number.end + 1 < words.count,
              words[number.end] == "to" || (words[number.end] == "and" && index > 0 && words[index - 1] == "between"),
              let other = numbers[number.end + 1], case .score = other.quantity else { return nil }
        return number.end + 1
    }

    /// Whether the request has a range of scores, as "rated between 6 and 8".
    static func hasScoreRange(_ words: [String]) -> Bool {
        let numbers = quantities(in: words)
        return numbers.keys.contains { rangeEnd(from: $0, in: words, numbers: numbers) != nil }
    }

    /// The site named right after a rating: "8 or higher on IMDb", "well rated on Rotten Tomatoes", "by the Tomatometer",
    /// "on Rotten Tomatoes audience scores", "on Letterboxd".
    private static func score(after end: Int, in words: [String]) -> (score: Score, end: Int)? {
        var index = end
        guard index < words.count, ["on", "by", "at", "per"].contains(words[index]) else { return nil }
        index += 1
        if index < words.count, words[index] == "the" {
            index += 1
        }
        guard let site = site(at: index, in: words) else { return nil }
        index = site.end
        guard index < words.count, audienceRatingWords.contains(words[index]) else { return site }
        index += 1
        if index < words.count, ratingWords.contains(words[index]) {
            index += 1
        }
        return (audience(of: site.score), index)
    }

    /// "80%", "80", "8.5", "8/10" or "8+" as a percent, with how many words after it say "percent". A number up to 10 is
    /// out of 10 on scales people give that way, as IMDb's, but not on Metascores or Rotten Tomatoes scores.
    static func percent(of word: String, next: String?, isOutOfTen tenths: Bool = true) -> (percent: Int, extra: Int)? {
        var text = word.replacingOccurrences(of: "+", with: "")
        let isOutOfTen = text.hasSuffix("/10")
        text = text.replacingOccurrences(of: "/10", with: "")
        var isPercent = text.hasSuffix("%")
        text = text.replacingOccurrences(of: "%", with: "")
        guard let number = Double(text), number > 0 else { return nil }
        let extra = next == "percent" || next == "%" ? 1 : 0
        isPercent = isPercent || extra == 1
        let value = isPercent ? number : isOutOfTen || (tenths && number <= 10) ? number * 10 : number
        guard value <= 100 else { return nil }
        return (Int(value.rounded()), extra)
    }

    // MARK: - Runtimes

    private static let runtimeUnits = ["minute": 1, "minutes": 1, "min": 1, "mins": 1, "hour": 60, "hours": 60, "hr": 60, "hrs": 60, "h": 60]
    private static let runtimeMaximums = [["under"], ["below"], ["less", "than"], ["shorter", "than"], ["at", "most"], ["up", "to"],
                                          ["within"], ["no", "more", "than"], ["no", "longer", "than"], ["max"], ["maximum"]]
    private static let runtimeMinimums = [["over"], ["above"], ["more", "than"], ["longer", "than"], ["at", "least"], ["minimum"]]

    /// Runtimes with a bound: "under 90 minutes", "2 hours or more", "from 90 minutes to 2 hours". A length alone, as
    /// "90 minutes" or "about an hour", isn't read.
    private static func runtimeMatches(in words: [String]) -> [Match] {
        var matches = [Match]()
        for index in words.indices {
            guard let length = duration(at: index, in: words) else { continue }
            let minutes = length.minutes
            var end = length.end
            var start = index
            var bounds: [Int]?
            if let maximum = runtimeMaximums.first(where: { words[..<index].reversed().starts(with: $0.reversed()) }) {
                start -= maximum.count
                bounds = [0, minutes]
            } else if let minimum = runtimeMinimums.first(where: { words[..<index].reversed().starts(with: $0.reversed()) }) {
                start -= minimum.count
                bounds = [minutes, 300]
            }
            if [["or", "more"], ["or", "longer"]].contains(where: { words.dropFirst(end).starts(with: $0) }) {
                bounds = [minutes, 300]
                end += 2
            } else if [["or", "less"], ["or", "shorter"]].contains(where: { words.dropFirst(end).starts(with: $0) }) {
                bounds = [0, minutes]
                end += 2
            }
            guard let typed = bounds else { continue }
            // A runtime past the composer's 5 hours stays as typed, to be left out.
            let range = typed.map { max($0, 0) }
            matches.append(Match(range: start..<end, condition: .runtimes(range), titles: [runtimeTitle(range)]))
        }
        // "From 90 minutes to 2 hours" or "between 90 and 120 minutes": a number alone takes the unit after the second one.
        for index in words.indices where index > 0 && ["to", "and"].contains(words[index]) {
            guard let upper = duration(at: index + 1, in: words) else { continue }
            let typedLower = (max(0, index - 6)..<index).lazy.compactMap { start in
                duration(at: start, in: words).flatMap { $0.end == index ? (start, $0.minutes) : nil }
            }.first
            let unit = index + 2 < words.count ? runtimeUnits[words[index + 2]] ?? 1 : 1
            guard let lower = typedLower ?? amount(words[index - 1]).map({ (index - 1, $0 * unit) }) else { continue }
            let opener = words[index] == "to" ? "from" : "between"
            let hasOpener = lower.0 > 0 && words[lower.0 - 1] == opener
            guard hasOpener || words[index] == "to" else { continue }
            let range = [lower.1, upper.minutes].sorted().map { max($0, 0) }
            matches.append(Match(range: (hasOpener ? lower.0 - 1 : lower.0)..<upper.end, condition: .runtimes(range), titles: [runtimeTitle(range)]))
        }
        return matches
    }

    /// "Short" alone: episodes of half an hour at most for shows, otherwise under 90 minutes.
    private static func shortRuntimeMatches(in words: [String]) -> [Match] {
        let isShows = mediaType(named: words) == .shows
        return words.indices.filter { words[$0] == "short" && isShortFilm(at: $0..<($0 + 1), in: words) == false }.map { index in
            let range = [0, isShows ? 30 : 90]
            return Match(range: index..<(index + 1), condition: .runtimes(range), titles: [runtimeTitle(range)])
        }
    }

    /// A length in minutes and where its words end: "90 minutes", "2 hours", "an hour and a half", "1 hour 30 minutes"
    /// or "90-minute".
    private static func duration(at index: Int, in words: [String]) -> (minutes: Int, end: Int)? {
        guard words.indices.contains(index) else { return nil }
        let word = words[index]
        let amounts = ["a": 1, "an": 1, "one": 1, "two": 2, "three": 3]
        // "Two and a half hours", "half an hour".
        if let amount = amount(word) ?? amounts[word], words.dropFirst(index + 1).starts(with: ["and", "a", "half"]), index + 4 < words.count,
           runtimeUnits[words[index + 4]] == 60 {
            return (amount * 60 + 30, index + 5)
        }
        if word == "half", let unit = words.dropFirst(index + 1).first(where: { $0 != "a" && $0 != "an" }), runtimeUnits[unit] == 60 {
            return (30, words[index + 1] == unit ? index + 2 : index + 3)
        }
        // A count too large to search, as "200000000000000000 hours", is read as one, to be left out.
        let count = { (word: String) in amount(word) ?? (word.isEmpty == false && word.allSatisfy(\.isNumber) ? 10000 : nil) }
        if index + 1 < words.count, let unit = runtimeUnits[words[index + 1]], let amount = count(word) ?? (unit == 60 ? amounts[word] : nil) {
            let next = index + 2 < words.count && words[index + 2] == "and" ? index + 3 : index + 2
            if unit == 60, next + 1 < words.count, let minutes = self.amount(words[next]), runtimeUnits[words[next + 1]] == 1 {
                return (amount * unit + minutes, next + 2)
            }
            // "2 hours and a half", "an hour and a half".
            if unit == 60, words.dropFirst(index + 2).starts(with: ["and", "a", "half"]) {
                return (amount * unit + 30, index + 5)
            }
            return (amount * unit, index + 2)
        }
        let parts = word.split(separator: "-").map(String.init)
        if parts.count == 2, let amount = amount(parts[0]), let unit = runtimeUnits[parts[1]] {
            return (amount * unit, index + 1)
        }
        return nil
    }

    /// A typed count small enough to multiply safely, as minutes or hours: "200000000000000000 hours" isn't one.
    static func amount(_ word: String) -> Int? {
        Int(word).flatMap { (0...10000).contains($0) ? $0 : nil }
    }

    // MARK: - Years

    /// Years and decades: "2020", "the 90s", "1990s", "nineties", "before 1980", "this year".
    private static func yearMatches(in words: [String]) -> [Match] {
        let currentYear = SmartListConditions.currentYear
        let bounds: Set = ["before", "after", "since", "until", "through", "between"]
        var matches = [["this", "year"], ["last", "year"]].flatMap { phrase in
            ranges(of: phrase, in: words).map { Match(range: $0, condition: .years([phrase.joined(separator: " ")]), titles: []) }
        }
        for (index, word) in words.enumerated() {
            let isYear = word.count == 4 && Int(word).map { (1900...currentYear + 2).contains($0) } == true
            let isDecade = (word.hasSuffix("s") && typedYears(in: word) != nil) || decades[word] != nil
            guard isYear || isDecade else { continue }
            var start = index > 0 && isYear && bounds.contains(words[index - 1]) ? index - 1 : index
            // A decade is narrowed or bounded by the words before it: "the early 2000s", "before the 90s".
            if isDecade {
                var before = index - 1
                while before >= 0, words[before] == "the" {
                    before -= 1
                }
                if before >= 0, decadeModifiers.contains(words[before]) {
                    start = before
                }
            }
            let typed = words[start...index].filter { $0 != "the" }.joined(separator: " ")
            matches.append(Match(range: start..<index + 1, condition: .years([typed]), titles: []))
        }
        return matches + yearRangeMatches(in: words)
    }

    /// A range typed whole, so a negation applies to all of it: "1990-2000", "from 1990 to 2000", "between the 80s and
    /// the 90s".
    private static func yearRangeMatches(in words: [String]) -> [Match] {
        let period = { (word: String) -> [Int]? in
            let isYear = word.count == 4 && Int(word) != nil
            return isYear || word.hasSuffix("s") || decades[word] != nil ? typedYears(in: word) : nil
        }
        let opener = { (start: Int, connector: String) -> Int in
            var index = start
            if index > 0, words[index - 1] == "the" {
                index -= 1
            }
            let openers = connector == "and" ? ["between"] : ["from", "between"]
            return index > 0 && openers.contains(words[index - 1]) ? index - 1 : start
        }
        var matches = [Match]()
        for (index, word) in words.enumerated() {
            let parts = word.split(separator: "-").map(String.init)
            if parts.count == 2, parts.allSatisfy({ $0.count == 4 }), let lower = period(parts[0]), let upper = period(parts[1]) {
                let range = opener(index, "-")..<index + 1
                matches.append(Match(range: range, condition: .years(["\(min(lower[0], upper[0])) \(max(lower[1], upper[1]))"]), titles: []))
                continue
            }
            guard ["to", "through", "until", "and"].contains(word), index > 0, let lower = period(words[index - 1]) else { continue }
            var next = index + 1
            if next < words.count, words[next] == "the" {
                next += 1
            }
            guard next < words.count, let upper = period(words[next]) else { continue }
            let start = opener(index - 1, word)
            // "1990 and 2000" alone are two years; "between" makes them a range.
            guard word != "and" || start < index - 1 else { continue }
            matches.append(Match(range: start..<next + 1, condition: .years(["\(min(lower[0], upper[0])) \(max(lower[1], upper[1]))"]), titles: []))
        }
        return matches
    }

    // MARK: - Services

    /// Streaming services by name: "on Netflix", "Disney Plus". A lowercase short word, as "max", is a word rather than
    /// a service unless typed after "on".
    static func serviceMatches(in tokens: [Token], services: [SmartListChoice]) -> [Match] {
        let services = Dictionary(services.map { (serviceKey($0.title), $0) }) { first, _ in first }
        return tokens.indices.flatMap { start in
            (1...min(3, tokens.count - start)).compactMap { length -> Match? in
                let range = start..<start + length
                let key = serviceKey(tokens[range].map(\.word).joined(separator: " "))
                // "Apple TV+" is Trakt's "Apple TV", while "Disney+" stays itself when Trakt has it.
                guard let service = services[key] ?? (key.hasSuffix("+") ? services[String(key.dropLast())] : nil) else { return nil }
                let isAfterOn = start > 0 && tokens[start - 1].word == "on"
                guard length > 1 || isAfterOn || tokens[start].isCapitalized, linkingWords.contains(tokens[start].word) == false else { return nil }
                return Match(range: (isAfterOn ? start - 1 : start)..<range.upperBound, condition: .services([service.value]), titles: [service.title])
            }
        }
    }

    /// The composer's ways to stream without naming a service: "for free", "with a subscription", "on my services",
    /// "anywhere". Excluding one isn't something Trakt can search, so "not free" is read to be left out.
    static func broadServiceMatches(in words: [String]) -> [Match] {
        var found = [Match]()
        for start in words.indices {
            for (phrase, value) in broadServicePhrases {
                let end = start + phrase.count
                guard end <= words.count, Array(words[start..<end]) == phrase, isBroadService(phrase, at: start..<end, in: words) else { continue }
                // Read with its lead-in, so a negation before it applies: "aren't streaming for free", "not on my subscriptions".
                var head = start > 0 && ["on", "with", "through", "via"].contains(words[start - 1]) && phrase.first != "for" ? start - 1 : start
                while head > 0, ["streaming", "stream", "available", "watchable"].contains(words[head - 1]) {
                    head -= 1
                }
                found.append(Match(range: head..<end, condition: .services([value]), titles: [SmartListChoices.watchNowTitle(for: value)]))
            }
        }
        return found
    }

    private static let broadServicePhrases: [([String], String)] = [
        ("free", "free"), ("for free", "free"), ("free to stream", "free"), ("free to watch", "free"), ("streaming for free", "free"),
        ("subscription", "subscriptions"), ("subscriptions", "subscriptions"), ("a subscription", "subscriptions"),
        ("subscription service", "subscriptions"), ("subscription services", "subscriptions"), ("a subscription service", "subscriptions"),
        ("my services", "favorites"), ("my streaming services", "favorites"), ("my subscriptions", "favorites"), ("my apps", "favorites"),
        ("my streaming apps", "favorites"), ("favorite services", "favorites"), ("favourite services", "favorites"),
        ("my favorite services", "favorites"), ("my favourite services", "favorites"), ("favorite streaming services", "favorites"),
        ("my favorite streaming services", "favorites"), ("my favourite streaming services", "favorites"),
        ("anywhere", "any"), ("any service", "any"), ("any services", "any"), ("any streaming service", "any"),
        ("any streaming services", "any")
    ].map { (words(in: $0.0), $0.1) }

    /// "Free" is also part of other phrases: "feel free", "my free time", "Free Guy".
    private static func isBroadService(_ phrase: [String], at range: Range<Int>, in words: [String]) -> Bool {
        guard phrase == ["free"] else { return true }
        let before = range.lowerBound > 0 ? words[range.lowerBound - 1] : ""
        let after = range.upperBound < words.count ? words[range.upperBound] : ""
        return ["feel", "gluten", "sugar", "fat", "hands", "tax", "duty", "care", "stress", "worry", "spoiler", "ad", "commercial", "set",
                "break", "for"].contains(before) == false
            && ["will", "willy", "spirit", "solo", "guy", "time", "fall", "agent", "state", "love", "world", "of", "from", "to"].contains(after) == false
    }

    // MARK: - Places

    /// A language named as one: "in French", "speaks French", "French-language", "Korean speaking". A name listed after
    /// one, as "in English or French", is also a language.
    private static func languageMatches(in words: [String], lists: Lists) -> [Match] {
        var matches = [Match]()
        let named = lists.languages.flatMap { language in
            ranges(of: SmartListAssistant.words(in: language.title), in: words).map { ($0, language) }
        }.sorted { $0.0.lowerBound < $1.0.lowerBound }
        for (range, language) in named {
            let before = range.lowerBound > 0 ? words[range.lowerBound - 1] : ""
            let isListed = ["and", "or"].contains(before) && matches.contains { $0.range.upperBound == range.lowerBound - 1 }
            if ["in", "speak", "speaks", "spoken"].contains(before) {
                // "Spoken in French" is read whole, so "aren't spoken in French" is a negation of it.
                let start = before == "in" && range.lowerBound > 1 && ["spoken", "speaking"].contains(words[range.lowerBound - 2])
                    ? range.lowerBound - 2 : range.lowerBound - 1
                matches.append(Match(range: start..<range.upperBound, condition: .languages([language.value]), titles: [language.title]))
            } else if isListed {
                matches.append(Match(range: range, condition: .languages([language.value]), titles: [language.title]))
            } else if range.upperBound < words.count, ["language", "speaking"].contains(words[range.upperBound]) {
                matches.append(Match(range: range.lowerBound..<range.upperBound + 1, condition: .languages([language.value]), titles: [language.title]))
            }
        }
        for language in lists.languages {
            let name = SmartListAssistant.words(in: language.title)
            for index in words.indices where ["\(name.joined(separator: " "))-language", "\(name.joined(separator: " "))-speaking"].contains(words[index]) {
                matches.append(Match(range: index..<index + 1, condition: .languages([language.value]), titles: [language.title]))
            }
        }
        return matches
    }

    /// Whether the words before `index` say where a story happens rather than where it's from: "set in", "takes place
    /// in", "located in". A place typed so is a theme, not a country of production.
    static func isSetting(before index: Int, in words: [String]) -> Bool {
        var end = index
        while end > 0, words[end - 1] == "the" {
            end -= 1
        }
        let before = Array(words[..<end])
        return [["set", "in"], ["place", "in"], ["located", "in"], ["set"]].contains { before.reversed().starts(with: $0.reversed()) }
    }

    /// A country after "from" or "in", or by nationality: "from France", "from the UK", "French movies". "Set in Paris" is
    /// where a story happens, not where it's from. A name listed after one, as "from France or Italy", is also a country.
    private static func countryMatches(in tokens: [Token], lists: Lists, claimed: Set<Int>) -> [Match] {
        let words = tokens.map(\.word)
        let countries = Dictionary(lists.countries.map { ($0.value, $0.title) }) { first, _ in first }
        let named = lists.countries.map { (SmartListAssistant.words(in: $0.title), $0.value) }
            + countryNames.compactMap { countries[$0.value] == nil ? nil : (SmartListAssistant.words(in: $0.key), $0.value) }
        var matches = [Match]()
        for (name, code) in named {
            for range in ranges(of: name, in: words) {
                // "Us" is a country only when typed as one.
                guard name != ["us"] || tokens[range.lowerBound].text == "US", let title = countries[code] else { continue }
                var start = range.lowerBound
                while start > 0, words[start - 1] == "the" {
                    start -= 1
                }
                let before = start > 0 ? words[start - 1] : ""
                let isListed = ["and", "or"].contains(before) && matches.contains { $0.range.upperBound == start - 1 }
                guard (["from", "in"].contains(before) && isSetting(before: start, in: words) == false) || isListed else { continue }
                matches.append(Match(range: (isListed ? start : start - 1)..<range.upperBound, condition: .countries([code]), titles: [title]))
            }
        }
        for (index, word) in words.enumerated() where claimed.contains(index) == false {
            guard let code = nationalities[word], let title = countries[code] else { continue }
            matches.append(Match(range: index..<index + 1, condition: .countries([code]), titles: [title]))
        }
        return matches
    }

    // MARK: - People

    private static let roleWords: [[String]: SmartListFilters.PersonRole] = [
        ["starring"]: .cast, ["with"]: .cast, ["featuring"]: .cast, ["directed", "by"]: .directing, ["written", "by"]: .writing,
        ["produced", "by"]: .producing, ["executive", "produced", "by"]: .producing, ["by"]: .directing,
        // Other crew, which "by" alone would read as directing: "music composed by Hans Zimmer".
        ["composed", "by"]: .any, ["scored", "by"]: .any, ["edited", "by"]: .any, ["photographed", "by"]: .any, ["shot", "by"]: .any,
        ["created", "by"]: .any, ["music", "by"]: .any, ["music", "composed", "by"]: .any, ["score", "by"]: .any, ["voiced", "by"]: .cast,
        ["narrated", "by"]: .cast
    ]

    /// The role words typed right before `index`, the longest first: "directed by" rather than "by".
    private static func role(before index: Int, in words: [String]) -> (words: [String], role: SmartListFilters.PersonRole)? {
        roleWords.filter { words[..<index].reversed().starts(with: $0.key.reversed()) }.max { $0.key.count < $1.key.count }
            .map { ($0.key, $0.value) }
    }

    /// Full names typed capitalized and found on Trakt as typed: "with Tom Holland", "directed by Greta Gerwig", "Tom
    /// Hanks movies". A single name, as "Tarantino", isn't looked up.
    private static func peopleMatches(in tokens: [Token], lists: Lists, claimed: Set<Int>) async -> [Match] {
        let known = knownWords(lists)
        let isNamePart = { (index: Int) in
            claimed.contains(index) == false && tokens[index].isCapitalized && tokens[index].word.first?.isLetter == true
        }
        // Runs of capitalized words, up to three. A word the reader knows can start one, as "Popular" before "Tom Hanks"
        // or "Will" in "Will Smith", but not continue it.
        var runs = [Range<Int>]()
        var start = 0
        while start < tokens.count {
            guard isNamePart(start) else {
                start += 1
                continue
            }
            var end = start + 1
            while end < tokens.count, end - start < 3, isNamePart(end), known.contains(tokens[end].word) == false {
                end += 1
            }
            if end - start >= 2 {
                runs.append(start..<end)
            }
            // A known word may end a name, as "Short" in "Martin Short": the longer name is tried first.
            if end < tokens.count, end - start < 3, isNamePart(end) {
                runs.append(start..<end + 1)
            }
            start = end
        }
        // A last name alone right after a role word, as "directed by Shyamalan", when it's one person's on Trakt.
        let words = tokens.map(\.word)
        var surnames = [Range<Int>]()
        // Not after "by" alone, which also introduces studios: "by Marvel" isn't whoever is named Marvel.
        for (role, _) in roleWords where role != ["by"] {
            for range in ranges(of: role, in: words) where range.upperBound < tokens.count {
                let index = range.upperBound
                let isNext = index + 1 < tokens.count && isNamePart(index + 1) && known.contains(tokens[index + 1].word) == false
                // After "with" or "featuring", only a capitalized word: "with zombies" isn't a person.
                guard claimed.contains(index) == false, isNext == false, known.contains(tokens[index].word) == false,
                      tokens[index].word.allSatisfy(\.isLetter), tokens[index].isCapitalized || role.count > 1 || role == ["starring"],
                      runs.contains(where: { $0.contains(index) }) == false else { continue }
                surnames.append(index..<index + 1)
            }
        }
        // A name typed in lowercase or mixed case right after a role word, as "with tom hanks" or "with Omar sy", is
        // looked up too: the role word says a person follows.
        for (role, _) in roleWords {
            for range in ranges(of: role, in: words) where range.upperBound < tokens.count {
                let first = range.upperBound
                var end = first
                // The first name may be a word the reader knows, as "will" in "with will smith".
                while end < tokens.count, end - first < 3, claimed.contains(end) == false, tokens[end].word.allSatisfy(\.isLetter),
                      known.contains(tokens[end].word) == false || (end == first && ["a", "an", "the", "my", "some", "no"].contains(tokens[end].word) == false) {
                    end += 1
                }
                // As "short" in "with martin short", a known word may end the name.
                let isLonger = end < tokens.count && end - first < 3 && claimed.contains(end) == false && tokens[end].word.allSatisfy(\.isLetter)
                for name in [first..<end, first..<end + 1] where name.count >= 2 && (name.upperBound == end || isLonger)
                    && runs.contains(where: { $0.overlaps(name) }) == false {
                    runs.append(name)
                }
            }
        }
        return await withTaskGroup(of: Match?.self) { group in
            for run in runs {
                group.addTask {
                    // The longest name found wins: "Will Smith" before "Smith", and "Omar sy" in "Omar sy where".
                    let spans = (run.lowerBound + 2...run.upperBound).reversed().flatMap { upper in (run.lowerBound..<upper - 1).map { $0..<upper } }
                    for range in spans {
                        let name = tokens[range].map(\.text).joined(separator: " ")
                        guard let person = await person(named: name) else { continue }
                        let role = role(before: range.lowerBound, in: words)
                        return Match(range: range.lowerBound - (role?.words.count ?? 0)..<range.upperBound,
                                     condition: .people([person.slug], role: role?.role), titles: [person.name])
                    }
                    return nil
                }
            }
            for range in surnames {
                group.addTask {
                    guard let found = await people(withSurname: tokens[range.lowerBound].text), found.count == 1, let person = found.first else { return nil }
                    let role = role(before: range.lowerBound, in: words)
                    return Match(range: range.lowerBound - (role?.words.count ?? 0)..<range.upperBound, condition: .people([person.slug], role: role?.role),
                                 titles: [person.name])
                }
            }
            return await group.reduce(into: []) { matches, match in
                if let match = match {
                    matches.append(match)
                }
            }
        }
    }

    // MARK: - Studios

    /// Well-known studios by name, or a distinctive part typed capitalized, as "Pixar" or "Ghibli". Any other studio is
    /// found on Trakt as typed after "by" or "from": "by Blumhouse".
    private static func studioMatches(in tokens: [Token], claimed: Set<Int>) async -> [Match] {
        var matches = tokens.indices.flatMap { start in
            (1...min(4, tokens.count - start)).compactMap { length -> Match? in
                let range = start..<start + length
                guard let studio = knownStudio(named: tokens[range].map(\.word), byPart: tokens[range].allSatisfy(\.isCapitalized)) else { return nil }
                let isIntroduced = start > 0 && ["by", "from"].contains(tokens[start - 1].word)
                return Match(range: (isIntroduced ? start - 1 : start)..<range.upperBound, condition: .studios([studio.value]), titles: [studio.title])
            }
        }
        for index in tokens.indices where ["by", "from"].contains(tokens[index].word) && claimed.contains(index) == false {
            var end = index + 1
            while end < tokens.count, end - index <= 3, claimed.contains(end) == false, tokens[end].isCapitalized {
                end += 1
            }
            guard end > index + 1 else { continue }
            let name = tokens[index + 1..<end].map(\.text).joined(separator: " ")
            guard let slug = await searchedStudioSlug(named: name) else { continue }
            matches.append(Match(range: index..<end, condition: .studios([slug]), titles: [name]))
        }
        return matches
    }

    // MARK: - Genres

    /// Genres by their Trakt name, singular or plural: "comedies", "science fiction", and "sci-fi".
    private static func genreMatches(in words: [String], lists: Lists) -> [Match] {
        let genres = lists.genres.filter { $0.value != "none" }
        let named = genres.map { (SmartListAssistant.words(in: $0.title), $0) }
            + genreAliases.compactMap { alias, value in genres.first { $0.value == value }.map { ([alias], $0) } }
        return named.flatMap { name, genre in
            ranges(of: name, in: words).filter { genre.value != "short" || isShortFilm(at: $0, in: words) }.map {
                Match(range: $0, condition: .genres([genre.value]), titles: [genre.title])
            }
        }
    }

    /// The Short genre is "shorts" or "short films"; "short" alone is a runtime.
    private static func isShortFilm(at range: Range<Int>, in words: [String]) -> Bool {
        words[range.lowerBound] != "short" || (range.upperBound < words.count && ["film", "films"].contains(words[range.upperBound]))
    }
}
