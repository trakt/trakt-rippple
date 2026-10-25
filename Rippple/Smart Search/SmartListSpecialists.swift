//
//  SmartListSpecialists.swift
//  Rippple
//
//  Created by Kevin Cador on 23/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import FoundationModels
import UIKit

/// The Apple Intelligence specialists of `SmartListAssistant`: the on-device model reads the request once per kind of
/// condition, each time with a short prompt of its own, and code only keeps what it can check. Every finding must quote
/// words that were typed and say what it claims, and every value must exist on Trakt.
extension SmartListAssistant {
    /// One kind of condition read by the model. A new specialist is a new case.
    enum Specialist: CaseIterable {
        case moviesOrShows
        case genres
        case places
        case people
        case services
        case studios
        case themes
        case releaseYears
        case runtime
        case ratings
        case watchStatus
        case showStatus
        case certifications

        /// What this matcher finds out about typed words, as said in the conversation: "who “Kubrick” is".
        func question(about words: [String]) -> String {
            // "Not directed by Nolan" asks who “Nolan” is.
            let leads = ["not ", "without ", "no ", "never ", "directed by ", "written by ", "starring ", "featuring ", "with ", "by "]
            let words = self == .people ? words.map { word in
                var name = String(word.dropFirst())
                while let lead = leads.first(where: { name.lowercased().hasPrefix($0) }) {
                    name.removeFirst(lead.count)
                }
                return "“" + name
            } : words
            let quoted = listed(words)
            let isAre = words.count == 1 ? "is" : "are"
            switch self {
            case .moviesOrShows: return "whether \(quoted) \(words.count == 1 ? "means" : "mean") movies or shows"
            case .genres: return "which genre \(quoted) \(words.count == 1 ? "means" : "mean")"
            case .places: return "which place \(quoted) \(isAre)"
            case .people: return "who \(quoted) \(isAre)"
            case .services: return "which service \(quoted) \(isAre)"
            case .studios: return "which studio \(quoted) \(isAre)"
            case .themes: return "what \(quoted) \(isAre) about"
            case .releaseYears: return "when \(quoted) \(isAre)"
            case .runtime: return "how long \(quoted) \(isAre)"
            case .ratings: return "what rating \(quoted) \(words.count == 1 ? "means" : "mean")"
            case .watchStatus: return "what \(quoted) \(words.count == 1 ? "means" : "mean") for your history"
            case .showStatus: return "what \(quoted) \(words.count == 1 ? "says" : "say") about a show's status"
            case .certifications: return "which certification \(quoted) \(words.count == 1 ? "means" : "mean")"
            }
        }

        /// The kinds of condition this specialist may find; anything else it returns is ignored.
        fileprivate var kinds: Set<AskCondition.Kind> {
            switch self {
            case .moviesOrShows: return []
            case .genres: return [.genre]
            case .places: return [.country, .language]
            case .people: return [.actor, .director, .person]
            case .services: return [.streamingService]
            case .studios: return [.studio]
            case .themes: return [.theme]
            case .releaseYears: return [.releaseYears, .releasedAfter, .releasedBefore]
            case .runtime: return [.shorterThan, .longerThan]
            case .ratings: return [.traktRating, .imdbRating, .rottenTomatoesScore]
            case .watchStatus: return [.notWatched, .notStarted, .notOnWatchlist]
            case .showStatus: return [.showStatus]
            case .certifications: return [.certification]
            }
        }

        /// A role, one direct command and short examples, as Apple suggests for the on-device model. Examples can't leak
        /// into a finding: findings quoting words that weren't typed are dropped.
        fileprivate func instructions(lists: Lists) -> String {
            let role = "You are a movie and TV show search assistant."
            switch self {
            case .moviesOrShows:
                return """
                \(role) Tell whether a person's request asks for movies, shows or both, and where titles come from: a chart \
                such as trending or popular, the person's watchlist or library, or not said. Copy the request's words for each. \
                For example, "binge-worthy series on my watchlist" asks for shows (words: series) from the watchlist (words: \
                on my watchlist).
                """
            case .genres:
                // Only Trakt's genres, as Apple suggests settling what's known in code rather than in the prompt.
                let names = lists.genres.filter { $0.value != "none" }.map(\.title).joined(separator: ", ")
                return """
                \(role) Find the genres a person's request asks for, by Trakt's genre names, with the request's words for \
                each. Trakt's genres are \(names). For example, "scary" asks for horror and "funny" for comedy. Only list \
                genres.
                """
            case .places:
                return """
                \(role) Find the countries titles come from and the spoken languages a person's request asks for, with the \
                request's words for each. For example, "French movies" come from France (words: French), and "in Korean" is \
                the Korean language (words: in Korean).
                """
            case .people:
                return """
                \(role) Find the people a person's request names, as actors, directors or anyone, by their full names, with \
                the request's words for each. For example, "with Leo DiCaprio" names the actor Leonardo DiCaprio (words: with \
                Leo DiCaprio).
                """
            case .services:
                // Only Trakt's main services, so a service is named as Trakt names it.
                let services = lists.services.map(\.title).filter { $0.contains("(") == false }.prefix(80).joined(separator: ", ")
                return """
                \(role) Find the streaming services a person's request wants titles to be on, with the request's words for \
                each. Name each service as Trakt does: \(services). For example, "on Netflix" names Netflix (words: on \
                Netflix), and "on Disney Plus" names Disney+ (words: on Disney Plus). A way to watch without a service is one of \
                For Free, With a Subscription, On Favorite Services or Anywhere. Don't list studios or channels.
                """
            case .studios:
                return """
                \(role) Find the studios or production companies that made the titles a person's request asks for, by their \
                full names, with the request's words for each. For example, "Pixar movies" names Pixar (words: Pixar), and \
                "made by Blumhouse" names Blumhouse Productions (words: Blumhouse). Don't list streaming services or people.
                """
            case .themes:
                return """
                \(role) Find what a person's request wants titles to be about: subjects, settings or events, each as a short \
                keyword made of the request's own words, singular and without words such as stories or films. For example, \
                "set in Paris" is about paris (words: set in Paris), "for Halloween" about halloween (words: for Halloween), and \
                "spaceship adventures" about spaceship (words: spaceship). Don't list genres, people or countries.
                """
            case .releaseYears:
                return """
                \(role) The current year is \(SmartListConditions.currentYear). Find when the titles a person's request asks \
                for were released, with the request's words. Give a year, a decade such as 1990s, or a range such as \
                2010-2014. For example, "from the 90s" is the 1990s, "after 2015" is released after 2015, and "from the \
                turn of the millennium" is 1998-2002. Don't list runtimes.
                """
            case .runtime:
                return """
                \(role) Find how long the titles a person's request asks for should be, in minutes, with the request's words. \
                For example, "under 2 hours" is shorter than 120 minutes, "longer than two hours" is longer than 120 minutes, \
                "quick to watch, under 90 minutes" is shorter than 90 minutes, "short movies" are shorter than 90 minutes, \
                and "short shows" have episodes shorter than 30 minutes. Don't list release years.
                """
            case .ratings:
                return """
                \(role) Find the lowest rating a person's request asks for, with the request's words. Ratings are percents: \
                good is 70%, great is 80%, and IMDb ratings are out of 10. A site the person names, like IMDb or Rotten \
                Tomatoes, is the rating to use. For example, "with good reviews" is a Trakt rating of 70%, "IMDb 8 or more" is \
                an IMDb rating of 8, "loved on Rotten Tomatoes" is a Rotten Tomatoes score of 80%, and "Rotten Tomatoes 90%" \
                is a Rotten Tomatoes score of 90%.
                """
            case .watchStatus:
                return """
                \(role) Find whether a person's request wants titles they haven't watched, titles they haven't started, or \
                titles that aren't on their watchlist, with the request's words. For example, "I still need to catch" is not \
                watched, "new to me" is not watched, "haven't finished" is not watched, "haven't begun yet" is not started, and \
                "that I haven't saved" is not on the watchlist.
                """
            case .showStatus:
                return """
                \(role) Find which status the shows a person's request asks for should have, or shouldn't have, with the \
                request's words. Statuses are returning series, in production, planned, upcoming, canceled and ended. For \
                example, "not canceled" leaves out canceled, "still going" is returning series, "that got axed" is canceled, \
                and "that finished their run" is ended.
                """
            case .certifications:
                return """
                \(role) Find which US certifications the titles of a person's request should have, with the request's \
                words. Movies are G, PG, PG-13 or R, and shows TV-Y, TV-Y7, TV-G, TV-PG, TV-14 or TV-MA. For example, "for \
                adults" is R or TV-MA, "safe for my kids" is G, PG, TV-Y, TV-Y7 or TV-G, "for teens" is PG-13 or TV-14, and \
                "rated R" is R. List each certification as its own condition.
                """
            }
        }
    }

    /// What a specialist found and the code checked: a condition, or movies or shows, or a source.
    struct Finding {
        enum Value {
            case condition(Match)
            case mediaType(SmartListMediaType)
            case source(SmartListSource)
        }

        let value: Value
        let range: Range<Int>
        let specialist: Specialist

        /// What a finding says, as "“scary” means horror" or "“Kubrick” is Stanley Kubrick".
        func meaning(in tokens: [Token]) -> String {
            let typed = "“\(quote(range, in: tokens))”"
            switch value {
            case .condition(var match):
                // What the words mean, as "“spooky” means horror": a negation typed before them is told in the closing.
                if let negation = match.negation, range.contains(negation.lowerBound) == false {
                    match.isNegated = false
                }
                switch match.condition {
                case .people, .services, .studios, .countries, .languages: return "\(typed) is \(listed(match.titles, or: match.requiresAll == false))"
                case .themes: return "\(typed) is about \(listed(match.titles, or: match.requiresAll == false))"
                case .statuses: return "\(typed) means \(match.isNegated ? "not " : "")\(match.titles.joined(separator: " or ").lowercased())"
                default: return "\(typed) means \(spoken(match))"
                }
            case .mediaType(let mediaType): return "\(typed) means \(mediaTitle(mediaType).lowercased())"
            case .source(let source): return "\(typed) means \(phrase(of: source))"
            }
        }

        func describe(in tokens: [Token]) -> String {
            let typed = "“\(quote(range, in: tokens))”"
            switch value {
            case .condition(let match): return "\(typed) as \(SmartListAssistant.describe(match))"
            case .mediaType(let mediaType): return "\(typed) as \(mediaTitle(mediaType).lowercased())"
            case .source(let source): return "\(typed) as \(phrase(of: source))"
            }
        }
    }

    /// One matcher's findings, told as its own message: what it found, and what it couldn't use and why. `known` are the
    /// findings from its own words, which the rules already read and it only tells; the model only reads the words in
    /// `focus`, and only its findings are returned, for the judge.
    static func reading(by specialist: Specialist, of request: String, focus: [Range<Int>], known: [Finding], tokens: [Token],
                        lists: Lists) async -> ([Finding], Step) {
        let words = tokens.map(\.word)
        var findings = [Finding]()
        var lines = [Line]()
        var pickedPeople = Set<Range<Int>>()
        if focus.isEmpty == false {
            let session = LanguageModelSession(instructions: specialist.instructions(lists: lists))
            let prompt = "Request: \(request)\nLook into: \(listed(focus.map { "“\(quote($0, in: tokens))”" }))"
            // Greedy sampling gives the same findings for the same words.
            let options = GenerationOptions(samplingMode: .greedy)
            // Only the words handed to it: the rest is already understood.
            let isFocused = { (range: Range<Int>) in focus.contains { $0.overlaps(range) } }
            if specialist == .moviesOrShows {
                if let kind = try? await session.respond(to: prompt, generating: AskKind.self, options: options).content {
                    if kind.mediaType != .both, let range = grounded(kind.mediaTypeWords, in: words), isFocused(range) {
                        findings.append(Finding(value: .mediaType(kind.mediaType == .movies ? .movies : .shows), range: range, specialist: specialist))
                    }
                    if let source = kind.source.source, let range = grounded(kind.sourceWords, in: words), isFocused(range) {
                        findings.append(Finding(value: .source(source), range: range, specialist: specialist))
                    }
                }
            } else if specialist == .people {
                // "Hitchcock or Kubrick" are two people, each looked up on their own.
                for typed in focus.flatMap({ listed(in: $0, of: words) }) {
                    let (found, line) = await person(meantBy: typed, in: request, tokens: tokens)
                    findings += found.map { [$0] } ?? []
                    if found != nil, line != nil {
                        pickedPeople.insert(typed)
                    }
                    lines += line.map { [$0] } ?? []
                }
            } else if let found = try? await session.respond(to: prompt, generating: AskConditions.self, options: options).content {
                for condition in found.conditions {
                    // What isn't this matcher's, wasn't typed or wasn't handed to it is dropped quietly.
                    guard specialist.kinds.contains(condition.kind), let range = grounded(condition.words, in: words), isFocused(range),
                          (known + findings).allSatisfy({ $0.range.overlaps(range) == false }) else { continue }
                    let typed = "“\(quote(range, in: tokens))”"
                    // A rating of a site no filter searches isn't read as another site's.
                    if [.traktRating, .imdbRating, .rottenTomatoesScore].contains(condition.kind), namesOtherRating(words) {
                        lines.append(Line(kind: .leftOut, text: "I'll have to skip \(typed), as I can't search by that rating."))
                        continue
                    }
                    // Either end of "rated between 6 and 8" alone would search outside it.
                    if [.traktRating, .imdbRating, .rottenTomatoesScore].contains(condition.kind), hasScoreRange(words) {
                        lines.append(Line(kind: .leftOut, text: "I'll have to skip \(typed), as a list can only have a lowest rating."))
                        continue
                    }
                    guard says(condition.kind, isExcluded: condition.isExcluded, Array(words[range])) else {
                        let isHighest = [.traktRating, .imdbRating, .rottenTomatoesScore].contains(condition.kind) && Set(words[range]).isDisjoint(with: maximums) == false
                        lines.append(Line(kind: .leftOut, text: isHighest ? "I'll have to skip \(typed), as a list can only have a lowest rating."
                                : "\(typed) doesn't really say a \(condition.kind.title.lowercased()), so I'm leaving it."))
                        continue
                    }
                    // A theme the rules leave as a name or a compared title, as "zombie" in "movies by zombie", stays one.
                    if condition.kind == .theme,
                       let themed = ranges(of: SmartListAssistant.words(in: condition.value), in: words).first(where: range.contains),
                       await isNameOrComparedTitle(themed, in: tokens) {
                        continue
                    }
                    guard var match = await resolved(condition, range: range, typed: Array(words[range]), lists: lists) else {
                        let isNamed = [.country, .language, .theme].contains(condition.kind) == false
                            || ranges(of: SmartListAssistant.words(in: condition.value), in: Array(words[range])).isEmpty == false
                        lines.append(Line(kind: .leftOut, text: isNamed ? "\(typed) might be “\(condition.value)”, but Trakt doesn't have it."
                                : "\(typed) doesn't name “\(condition.value)”, so I'm leaving it."))
                        continue
                    }
                    match.isNegated = condition.isExcluded
                    if let reason = unsearchable(match) {
                        lines.append(Line(kind: .leftOut, text: "I'll have to skip \(typed), \(reason)."))
                        continue
                    }
                    findings.append(Finding(value: .condition(match), range: range, specialist: specialist))
                }
            } else if known.isEmpty {
                return ([], Step(lines: [Line(kind: .note, text: "Hmm, I couldn't make sense of that.")]))
            }
        }
        // People the model picked already said whom they mean.
        let found = (known + findings).filter { finding in pickedPeople.contains(finding.range) == false }.map { $0.meaning(in: tokens) }
        if found.isEmpty == false {
            lines.insert(Line(kind: .kept, text: "Looks like \(listed(found))."), at: 0)
        } else if lines.isEmpty {
            let looked = (focus + known.map(\.range)).map { "“\(quote($0, in: tokens))”" }.removingDuplicates()
            lines = [Line(kind: .note, text: "Hmm, I couldn't make sense of \(listed(looked, or: true)).")]
        }
        return (findings, Step(lines: lines))
    }

    // MARK: - People

    private static let personRoles: [(words: [String], role: SmartListFilters.PersonRole)] = [
        (["directed", "by"], .directing), (["written", "by"], .writing), (["produced", "by"], .producing),
        (["executive", "produced", "by"], .producing), (["starring"], .cast),
        (["featuring"], .cast), (["with"], .cast), (["by"], .directing)
    ]

    private static let personInstructions = """
    You are a movie and TV expert. A person's request names someone by a short name, a last name or a nickname. Give the \
    full name of the person they most likely mean, given the rest of the request, as a director for "films by". A single \
    name may be a first name: the people listed only share it as a last name. For example, "Hitchcock thrillers" means \
    Alfred Hitchcock, "movies with Arnold" means Arnold Schwarzenegger, and "with Tom Hanks and Leo" means Leonardo \
    DiCaprio. When several people are equally likely, leave the name empty.
    """

    /// The words of a leftover group that name someone, from its start: one to three capitalized words, after a
    /// negation or a role word if any, that someone on Trakt has as a last or full name, and more names listed with "and"
    /// or "or". "Cozy" is a word, "Hitchcock" a name, "Blumhouse" no one's, and "Scorsese" in "Scorsese gangster" is.
    static func name(in group: Range<Int>, tokens: [Token], lists: Lists) async -> Range<Int>? {
        let words = tokens.map(\.word)
        var start = group.lowerBound
        while start < group.upperBound, negatives.contains(words[start]) {
            start += 1
        }
        let lead = personRoles.first { Array(words[start..<group.upperBound]).starts(with: $0.words) }
        start += lead?.words.count ?? 0
        // "With Arnie" names someone whatever Trakt's last names are; "by" also introduces studios.
        let role = lead ?? personRoles.first { words[..<group.lowerBound].reversed().starts(with: $0.words.reversed()) }
        let isPersonRole = role.map { $0.words != ["by"] } ?? false
        let known = knownWords(lists)
        let isNamePart = { (index: Int) in
            tokens[index].isCapitalized && tokens[index].word.allSatisfy { $0.isLetter || $0 == "'" } && known.contains(tokens[index].word) == false
        }
        var parts = [Range<Int>]()
        var partStart = start
        var end = start
        while end < group.upperBound {
            if isNamePart(end), end - partStart < 3 {
                end += 1
            } else if ["and", "or"].contains(words[end]), end > partStart, end + 1 < group.upperBound, isNamePart(end + 1) {
                parts.append(partStart..<end)
                partStart = end + 1
                end += 1
            } else {
                break
            }
        }
        guard end > partStart else { return nil }
        parts.append(partStart..<end)
        // Without a role word or a negation before it, an everyday word isn't taken for a name: "The Rock" isn't Chris Rock.
        let isIntroduced = start > group.lowerBound || personRoles.contains { words[..<group.lowerBound].reversed().starts(with: $0.words.reversed()) }
        for part in parts {
            let name = tokens[part]
            guard let last = name.last else { return nil }
            if isIntroduced == false, await isDictionaryWord(last.word) {
                return nil
            }
            if isPersonRole {
                continue
            }
            if name.count > 1, await person(named: name.map(\.text).joined(separator: " ")) != nil {
                continue
            }
            let surnamed = await people(withSurname: last.text.replacingOccurrences(of: "'s", with: "")) ?? []
            guard surnamed.isEmpty == false else { return nil }
        }
        return group.lowerBound..<end
    }

    /// The parts of a list typed with "and" or "or": "Hitchcock or Kubrick". A part keeps the words before the first
    /// name, as "not by" in "not by Hitchcock or Kubrick".
    static func listed(in range: Range<Int>, of words: [String]) -> [Range<Int>] {
        var parts = [Range<Int>]()
        var start = range.lowerBound
        for index in range where ["and", "or"].contains(words[index]) {
            if index > start {
                parts.append(start..<index)
            }
            start = index + 1
        }
        if range.upperBound > start {
            parts.append(start..<range.upperBound)
        }
        return parts
    }

    @MainActor
    private static func isDictionaryWord(_ word: String) -> Bool {
        UITextChecker().rangeOfMisspelledWord(in: word, range: NSRange(location: 0, length: (word as NSString).length), startingAt: 0, wrap: false,
                                              language: "en_US").location == NSNotFound
    }

    /// The person a short name, last name or nickname stands for: the on-device model picks among the people Trakt has
    /// by that name, or names whom a nickname means, and Trakt must have that person exactly.
    private static func person(meantBy typed: Range<Int>, in request: String, tokens: [Token]) async -> (Finding?, Line?) {
        // "Without Hitchcock" or "not by Hitchcock": a negation before the name leaves the person out.
        let all = tokens.map(\.word)
        var start = typed.lowerBound
        while start < typed.upperBound - 1, negatives.contains(all[start]) {
            start += 1
        }
        let negation = start > typed.lowerBound ? typed.lowerBound..<start : negation(before: typed.lowerBound, in: all).map { $0..<$0 + 1 }
        let words = Array(all[start..<typed.upperBound])
        let lead = personRoles.first { words.starts(with: $0.words) && $0.words.count < words.count }
        // "Movies by Shyamalan": the role word may come just before the words handed over.
        let role = lead?.role ?? personRoles.first { all[..<start].reversed().starts(with: $0.words.reversed()) }?.role
        let range = start + (lead?.words.count ?? 0)..<typed.upperBound
        let name = quote(range, in: tokens)
        let surname = tokens[range.upperBound - 1].text.replacingOccurrences(of: "'s", with: "")
        let finding = { (person: (slug: String, name: String)) in
            Finding(value: .condition(Match(range: start..<typed.upperBound, condition: .people([person.slug], role: role), titles: [person.name],
                                            isNegated: negation != nil, negation: negation)),
                    range: typed, specialist: .people)
        }
        // Lowercase words without "with" or "by" are a name only when typed in full: "after a stressful day" isn't Doris Day.
        guard role != nil || tokens[range].contains(where: { $0.text.first?.isUppercase == true }) else {
            return (await person(named: name).map(finding), nil)
        }
        let candidates = (await people(withSurname: surname)) ?? []
        if candidates.count == 1, let only = candidates.first {
            return (finding(only), nil)
        }
        let prompt = "Request: \(request)\nName: “\(name)”" + (candidates.isEmpty ? "" : "\nPeople on Trakt with that name: \(candidates.prefix(8).map(\.name).joined(separator: ", "))")
        let answer = try? await LanguageModelSession(instructions: personInstructions)
            .respond(to: prompt, generating: AskPerson.self, options: GenerationOptions(samplingMode: .greedy)).content
        let meant = answer?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let others = candidates.map(\.name).filter { nameKey($0) != nameKey(meant) }
        var named = candidates.first { nameKey($0.name) == nameKey(meant) }
        // A theme's words name nobody: "directed by Time Travel" isn't Christopher Nolan. A nickname, as "Arnie", still can.
        let isGuessed = candidates.isEmpty && Set(SmartListAssistant.words(in: meant)).isDisjoint(with: words)
            && knownThemes.contains(name.lowercased())
        if named == nil, meant.isEmpty == false, isGuessed == false {
            named = await person(named: meant)
        }
        if meant.isEmpty == false, let person = named {
            let note = others.isEmpty ? "" : ", not \(listed(Array(others.prefix(3)), or: true))"
            return (finding(person), Line(kind: .kept, text: "“\(name)” is most likely \(person.name)\(note)."))
        }
        guard candidates.isEmpty == false else {
            return (nil, Line(kind: .leftOut, text: "Hmm, I couldn't find “\(name)” on Trakt."))
        }
        let names = candidates.prefix(3).map(\.name) + (candidates.count > 3 ? ["others"] : [])
        return (nil, Line(kind: .leftOut, text: "“\(name)” could be \(listed(names, or: true)). Type the full name to pick one."))
    }

    // MARK: - Exact words

    /// What a matcher knows without the model: its own words for Trakt's values, as "whodunit" for Mystery or "Prime
    /// Video" for Amazon Prime Video. As exact as the rules, which read them.
    static func exactFindings(by specialist: Specialist, in group: Range<Int>, tokens: [Token], lists: Lists) async -> [Finding] {
        let words = tokens.map(\.word)
        let finding = { (value: Finding.Value, range: Range<Int>) in
            Finding(value: value, range: range, specialist: specialist)
        }
        let condition = { (condition: Condition, title: String, range: Range<Int>) in
            finding(.condition(Match(range: range, condition: condition, titles: [title])), range)
        }
        switch specialist {
        case .moviesOrShows:
            return group.compactMap { index in
                if seriesKinds.contains(where: { isSame(words[index], $0) }) {
                    return finding(.mediaType(.shows), index..<index + 1)
                }
                return movieKinds.contains(words[index]) ? finding(.mediaType(.movies), index..<index + 1) : nil
            }
        case .genres:
            let genres = Dictionary(lists.genres.map { ($0.value, $0) }) { first, _ in first }
            let names = genreWords.merging(lists.genres.map { ($0.title.lowercased(), $0.value) }) { first, _ in first }
            return phrases(in: group, of: words, from: names).compactMap { range, slug in
                genres[slug].map { condition(.genres([$0.value]), $0.title, range) }
            }
        case .places:
            let countries = Dictionary(lists.countries.map { ($0.value, $0) }) { first, _ in first }
            let languages = Dictionary(lists.languages.map { ($0.value, $0) }) { first, _ in first }
            var places = [String: String]()
            for country in lists.countries {
                places[country.title.lowercased()] = "country:\(country.value)"
            }
            for (name, code) in countryNames.merging(nationalities, uniquingKeysWith: { first, _ in first }) {
                places[name] = "country:\(code)"
            }
            for language in lists.languages where places[language.title.lowercased()] == nil {
                places[language.title.lowercased()] = "language:\(language.value)"
            }
            places.merge(placeWords) { _, alias in alias }
            // "Set in France" is where a story happens, which the theme fallback reads, and "us" is only the country typed
            // as "US", as the rules read it.
            let isPlace = { (range: Range<Int>) in
                isSetting(before: range.lowerBound, in: words) == false && (words[range] != ["us"] || tokens[range.lowerBound].text == "US")
            }
            return phrases(in: group, of: words, from: places).filter { isPlace($0.0) }.compactMap { range, place in
                let parts = place.split(separator: ":").map(String.init)
                if parts[0] == "country", let country = countries[parts[1]] {
                    return condition(.countries([country.value]), country.title, range)
                }
                return languages[parts[1]].map { condition(.languages([$0.value]), $0.title, range) }
            }
        case .people:
            // A full name only: a last name alone could be anyone, which the model weighs instead.
            let roleWords = Set(personRoles.flatMap(\.words))
            let named = tokens[group].drop { roleWords.contains($0.word) }.map(\.text)
            guard named.count >= 2, let person = await person(named: named.joined(separator: " ")) else { return [] }
            return [condition(.people([person.slug], role: nil), person.name, group)]
        case .services:
            let services = lists.services
            var found = (serviceMatches(in: tokens, services: services) + broadServiceMatches(in: words))
                .filter { group.contains($0.range.lowerBound) && $0.range.upperBound <= group.upperBound }
                .map { finding(.condition($0), $0.range) }
            let titles = Dictionary(services.map { ($0.title, $0) }) { first, _ in first }
            for (range, title) in phrases(in: group, of: words, from: serviceWords) where found.allSatisfy({ $0.range.overlaps(range) == false }) {
                // A short word, as "max" or "prime", is a service only when typed as a name.
                guard range.count > 1 || tokens[range.lowerBound].isCapitalized, let service = titles[title] else { continue }
                found.append(condition(.services([service.value]), service.title, range))
            }
            return found
        case .studios:
            // Studios are typed as names: the capitalized words of the group, as "Blumhouse" in "made by Blumhouse". Words
            // the reader knows aren't, as "IMDb" in "below 5 on IMDb".
            let known = knownWords(lists)
            let capitalized = group.filter { tokens[$0].isCapitalized && known.contains(tokens[$0].word) == false }
            guard let first = capitalized.first, let last = capitalized.last else { return [] }
            let range = first..<last + 1
            if let studio = knownStudio(named: Array(words[range]), byPart: true) {
                return [condition(.studios([studio.value]), studio.title, range)]
            }
            return await searchedStudioSlug(named: quote(range, in: tokens)).map { [condition(.studios([$0]), quote(range, in: tokens), range)] } ?? []
        case .themes:
            // "time-travel stories" is the theme "time travel": hyphens are spaces, and words around a theme aren't it.
            var named = Array(words[group]).flatMap { $0.split(separator: "-").map(String.init) }
            // Trakt has a keyword for nearly any word, as "rock" or "kids": a theme is only exact when introduced as one,
            // as "set in Paris", or when it's a common one, as "heist".
            let isIntroduced = named.first.map(themeLeads.contains) == true
            while let first = named.first, themeLeads.contains(first) || linkingWords.contains(first) {
                named.removeFirst()
            }
            while let last = named.last, themeTails.contains(last) || movieWords.contains(last) || showWords.contains(last) {
                named.removeLast()
            }
            let phrase = named.joined(separator: " ")
            // As the rules leave them: "Zombie" in "movies by Zombie" names a person, and in "movies like Zombie" a title.
            // Checked on the words of the theme itself, as "zombie" without "by", where they're typed whole.
            let themed = ranges(of: named, in: words).first { group.contains($0.lowerBound) } ?? group
            guard named.isEmpty == false, isIntroduced || commonThemes.contains(where: { isSame(phrase, $0) }),
                  await isNameOrComparedTitle(themed, in: tokens) == false, let name = await themeName(for: phrase) else { return [] }
            return [condition(.themes([name]), name, group)]
        case .releaseYears, .runtime:
            return releaseFindings(in: group, words: words).filter { found in
                if case .runtimes = found.0 {
                    return specialist == .runtime
                }
                return specialist == .releaseYears
            }.map { condition($0.0, $0.1, $0.2) }
        case .ratings:
            guard namesOtherRating(words) == false else { return [] }
            return phrases(in: group, of: words, from: criticWords).compactMap { range, value in
                let parts = value.split(separator: ":")
                // "Feel good" is a mood, not a rating.
                guard parts.count == 2, let minimum = Int(parts[1]), range.lowerBound == 0 || words[range.lowerBound - 1] != "feel"
                else { return nil }
                let score: Score = parts[0] == "rt" ? .rottenTomatoes : parts[0] == "trakt" ? .trakt : .metacritic
                return condition(.rating(score, minimum: minimum), ratingTitle(score, minimum), range)
            }
        case .watchStatus:
            return phrases(in: group, of: words, from: watchWords).map { range, status in
                status == "watchlist" ? condition(.notOnWatchlist, "Not on my watchlist", range) : condition(.unwatched, "Not watched", range)
            }
        case .certifications:
            let audiences = audienceWords.merging(moreAudienceWords) { $1 }.mapValues(\.rawValue)
            var found = phrases(in: group, of: words, from: audiences).compactMap { range, audience in
                Audience(rawValue: audience).flatMap { certificationMatch(for: $0, at: range, in: words) }.map { finding(.condition($0), range) }
            }
            // "With my 8 year old": a child's age says who titles are for.
            for index in max(0, group.lowerBound - 1)..<group.upperBound where words[index] == "my" && found.allSatisfy({ $0.range.contains(index) == false }) {
                guard index + 1 < words.count, let age = amount(words[index + 1]) ?? ages[words[index + 1]], (1...17).contains(age),
                      words.dropFirst(index + 2).starts(with: ["year", "old"]) || words.dropFirst(index + 2).starts(with: ["years", "old"])
                      || (index + 2 < words.count && ["year-old", "yo"].contains(words[index + 2]))
                else { continue }
                let end = index + 2 < words.count && ["year-old", "yo"].contains(words[index + 2]) ? index + 3 : index + 4
                if let match = certificationMatch(for: age < 13 ? .kids : .teens, at: index..<end, in: words) {
                    found.append(finding(.condition(match), index..<end))
                }
            }
            return found
        case .showStatus:
            return phrases(in: group, of: words, from: statusWords.merging(moreStatusWords) { $1 }).map { range, status in
                condition(.statuses([status]), status.smartListTitle, range)
            }
        }
    }

    /// Kinds of titles that are series: "sitcoms" are shows.
    static let seriesKinds = ["sitcom", "miniseries", "mini-series", "docuseries", "docu-series", "telenovela", "soap opera"]
    static let movieKinds: Set<String> = ["flick", "flicks", "feature-length", "features"]

    /// Words for Trakt's genres, besides their names: moods and kinds of titles.
    private static let genreWords = [
        "scary": "horror", "spooky": "horror", "creepy": "horror", "slasher": "horror", "gory": "horror", "frightening": "horror",
        "terrifying": "horror", "funny": "comedy", "hilarious": "comedy", "comedic": "comedy", "sitcom": "comedy", "whodunit": "mystery",
        "whodunnit": "mystery", "cartoon": "animation", "animated": "animation", "tearjerker": "drama", "dramatic": "drama",
        "romantic": "romance", "love story": "romance", "docuseries": "documentary", "docu-series": "documentary", "doc": "documentary",
        "docs": "documentary", "biopic": "biography", "miniseries": "mini-series", "limited series": "mini-series", "telenovela": "soap",
        "soap opera": "soap", "action-packed": "action", "family-friendly": "family", "sci-fi": "science-fiction", "scifi": "science-fiction",
        "science fiction": "science-fiction", "superheroes": "superhero",
        // Trakt filters a show's episode length, not its total, so a show finished in a weekend is a mini-series.
        "finish in a weekend": "mini-series", "binge in a weekend": "mini-series", "watch in a weekend": "mini-series",
        "finish over a weekend": "mini-series", "binge over a weekend": "mini-series", "in a weekend": "mini-series",
        "over a weekend": "mini-series", "in one weekend": "mini-series", "weekend binge": "mini-series"
    ]

    /// Places by a name Trakt doesn't use: "Bollywood" is India, "Mandarin" is Chinese.
    private static let placeWords = ["bollywood": "country:in", "mandarin": "language:zh", "hollywood": "country:us"]

    /// Services by the name people use: "Prime Video" is Amazon Prime Video.
    private static let serviceWords = [
        "prime video": "Amazon Prime Video", "amazon prime": "Amazon Prime Video", "prime": "Amazon Prime Video", "max": "HBO Max",
        "hbo": "HBO Max", "peacock": "Peacock Premium", "paramount+": "Paramount+ Premium", "paramount plus": "Paramount+ Premium",
        "paramount": "Paramount+ Premium"
    ]

    /// Critics' praise is a Metascore: 75 and above is "generally favorable" and beyond. "Certified Fresh" is Rotten
    /// Tomatoes' label for 75% and above. "Good" and "great" alone are Trakt ratings, as in the rules' "good rating".
    private static let criticWords = ["critically acclaimed": "mc:75", "acclaimed by critics": "mc:75", "loved by critics": "mc:75",
                                      "praised by critics": "mc:75", "critics love": "mc:75", "critics' favorites": "mc:75",
                                      "certified fresh": "rt:75", "good": "trakt:70", "great": "trakt:80", "excellent": "trakt:80",
                                      "well reviewed": "trakt:70", "well-reviewed": "trakt:70", "highly regarded": "trakt:80"]

    /// Ways to say not watched yet that the rules don't read: "new to me", "never got around to".
    private static let watchWords = [
        "new to me": "unwatched", "never got around to": "unwatched", "haven't caught": "unwatched", "still need to catch": "unwatched",
        "haven't gotten around to": "unwatched", "not in my watchlist yet": "watchlist", "haven't saved": "watchlist"
    ]

    /// Audiences said loosely: "grown-up" is adults, "little ones" are kids.
    private static let moreAudienceWords: [String: Audience] = [
        "grown-up": .adults, "not for kids": .adults, "for the kids": .kids, "for little ones": .kids, "for toddlers": .kids,
        "safe for kids": .kids, "suitable for kids": .kids, "teenage": .teens, "my kids": .kids, "my kid": .kids, "my son": .kids,
        "my daughter": .kids, "my children": .kids, "my little ones": .kids, "the kids": .kids, "my teenagers": .teens, "my teens": .teens,
        "safe to watch": .kids, "safe for the family": .kids, "safe for children": .kids
    ]

    private static let ages = ["one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
                               "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17]

    /// Show statuses said loosely: "axed" is canceled, "still going" is returning series.
    private static let moreStatusWords = [
        "axed": "canceled", "got the axe": "canceled", "scrapped": "canceled", "still going": "returning series",
        "coming back": "returning series", "finished airing": "ended", "wrapped up": "ended", "concluded": "ended"
    ]

    private static let themeLeads: Set<String> = ["about", "involving", "set", "featuring", "take", "takes", "taking", "place", "located"]

    private static let themeTails: Set<String> = ["story", "stories", "tale", "tales", "plot", "plots", "themed", "theme"]

    /// Release years and runtimes said in ways the rules don't read: "the last 5 years", "this decade", "90-minute".
    private static func releaseFindings(in group: Range<Int>, words: [String]) -> [(Condition, String, Range<Int>)] {
        let currentYear = SmartListConditions.currentYear
        let numbers = ["a": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
                       "twenty": 20, "few": 3, "couple": 2]
        var found = [(Condition, String, Range<Int>)]()
        for index in group {
            let word = words[index]
            // "the last 5 years", "past decade", "the last two decades".
            if ["last", "past"].contains(word), index + 1 < group.upperBound {
                var next = index + 1
                var count = 1
                if let number = amount(words[next]) ?? numbers[words[next]] {
                    count = number
                    next += 1
                }
                guard next < group.upperBound else { continue }
                let span = isSame(words[next], "year") ? count : isSame(words[next], "decade") ? count * 10 : 0
                guard span > 0 else { continue }
                // Trakt's years start in 1900.
                let typed = "\(max(1900, currentYear - span)) \(currentYear)"
                found.append((.years([typed]), "", index..<next + 1))
            } else if word == "this", index + 1 < group.upperBound, words[index + 1] == "decade" {
                found.append((.years(["\(currentYear - currentYear % 10) \(currentYear)"]), "", index..<index + 2))
            } else if let minutes = Int(word.replacingOccurrences(of: "-minute", with: "").replacingOccurrences(of: "-min", with: "")),
                      word.contains("-min"), (30...300).contains(minutes) {
                // "90-minute comedies": about that long.
                let range = [minutes - 15, min(minutes + 15, 300)]
                found.append((.runtimes(range), runtimeTitle(range), index..<index + 1))
            }
        }
        return found
    }

    /// Phrases of `names` typed in the group, longest first, each word in one phrase at most. Plurals match. A phrase may
    /// reach into the linking words around the group, as "to me" in "new to me".
    private static func phrases(in group: Range<Int>, of words: [String], from names: [String: String]) -> [(Range<Int>, String)] {
        var taken = Set<Int>()
        var found = [(Range<Int>, String)]()
        let isInGroup = { (range: Range<Int>) in
            range.overlaps(group) && range.allSatisfy { group.contains($0) || linkingWords.contains(words[$0]) }
        }
        for (name, value) in names.sorted(by: { $0.key.count > $1.key.count }) {
            for range in ranges(of: SmartListAssistant.words(in: name), in: words) where isInGroup(range) && taken.isDisjoint(with: range) {
                taken.formUnion(range)
                found.append((range, value))
            }
        }
        return found.sorted { $0.0.lowerBound < $1.0.lowerBound }
    }

    // MARK: - Coordinator

    private static let coordinatorInstructions = """
    You coordinate a movie and TV show search. Some words of a person's request aren't understood yet. Hand each to the \
    matcher that can read it: moviesOrShows for movies, series or where titles come from, such as trending or a watchlist; \
    genres for kinds of titles and moods, such as scary or funny; places for countries, nationalities and languages; people \
    for actors and directors; services for streaming services, such as Netflix; studios for studios and production \
    companies, such as Pixar; themes for subjects, settings, holidays and events, such as zombies, Paris or Halloween; \
    releaseYears for years, decades and eras; runtime for how long titles are; ratings for scores and reviews; \
    watchStatus for whether titles were watched or saved; showStatus for whether shows are canceled, ended or still \
    running; certifications for audiences and ratings such as for adults, for kids or rated R. \
    Skip words no matcher can read.
    """

    /// Which matchers look into which of the words the rules couldn't read, as one quick model request, told as the
    /// coordinator's plan. `nil` when the model can't answer, as when its safety filter stops a name such as "Hitchcock".
    /// After the first round, `understood` says what's already understood, so the words left read in that light.
    static func coordinating(request: String, tokens: [Token], unread: [Range<Int>], understood: String? = nil) async
        -> (plan: [(specialist: Specialist, ranges: [Range<Int>])]?, lines: [Line]) {
        let words = tokens.map(\.word)
        let quoted = unread.map { "“\(quote($0, in: tokens))”" }
        let prompt = "Request: \(request)\n" + (understood.map { "Already understood: \($0)\n" } ?? "") + "Not understood yet: \(listed(quoted))"
        guard let plan = try? await LanguageModelSession(instructions: coordinatorInstructions)
            .respond(to: prompt, generating: AskPlan.self, options: GenerationOptions(samplingMode: .greedy)).content else {
            return (nil, [])
        }
        var assigned = [Specialist: [Range<Int>]]()
        var handed = Set<Int>()
        for assignment in plan.assignments {
            guard let range = grounded(assignment.words, in: words), let group = unread.first(where: { $0.overlaps(range) }) else { continue }
            let specialist = assignment.matcher.specialist
            guard assigned[specialist]?.contains(group) != true else { continue }
            assigned[specialist, default: []].append(group)
            handed.formUnion(group)
        }
        let order = Specialist.allCases.filter { assigned[$0] != nil }
        var lines = [Line]()
        let skipped = unread.filter { handed.isDisjoint(with: $0) }.map { "“\(quote($0, in: tokens))”" }
        if skipped.isEmpty == false {
            lines.append(Line(kind: .leftOut, text: "I'll have to skip \(listed(skipped)), as I can't search for \(skipped.count == 1 ? "it" : "them")."))
        }
        return (order.map { ($0, assigned[$0] ?? []) }, lines)
    }

    /// Where the model's words were typed. Words that weren't, as an example copied from the prompt, aren't a reading.
    static func grounded(_ quote: String, in words: [String]) -> Range<Int>? {
        let quoted = SmartListAssistant.words(in: quote)
        guard quoted.isEmpty == false else { return nil }
        return ranges(of: quoted, in: words).first
    }

    /// Words saying a highest value, as "under 2 hours" or "below 5".
    private static let maximums: Set = ["under", "below", "less", "shorter", "lower", "most", "max", "maximum", "within"]

    /// Whether the quoted words can say this at all: "not watched" needs a negation, "longer than" a word such as
    /// "over", and a quote of only "movies" or linking words says nothing. The model sometimes ties a condition to words
    /// that don't mean it, as "not watched" to "watch" in "movies I can watch with my kids".
    private static func says(_ kind: AskCondition.Kind, isExcluded: Bool, _ quoted: [String]) -> Bool {
        let typed = Set(quoted)
        let isNegated = typed.isDisjoint(with: negatives.union(["haven't", "hasn't", "didn't", "never"])) == false
            || quoted.contains { $0.hasPrefix("un") }
        let minimums: Set = ["over", "above", "more", "longer", "higher", "least", "minimum", "plus", "or", "+"]
        guard typed.subtracting(linkingWords).subtracting(movieWords).subtracting(showWords).isEmpty == false,
              isExcluded == false || isNegated else { return false }
        switch kind {
        case .notWatched: return isNegated && typed.isDisjoint(with: ["watched", "seen", "saw", "watch", "see", "unwatched", "unseen"]) == false
        case .notStarted: return isNegated && typed.isDisjoint(with: ["started", "start", "begun", "began"]) == false
        // "got" in "got axed" says nothing on its own.
        case .showStatus: return typed.subtracting(["got", "get", "gets", "been", "be", "is", "are", "was", "were", "has", "have"]).isEmpty == false
        case .notOnWatchlist: return isNegated && typed.contains("watchlist")
        case .shorterThan: return typed.isDisjoint(with: maximums) == false
        case .longerThan: return typed.isDisjoint(with: minimums) == false && typed.isDisjoint(with: maximums)
        // A rating is of the site typed, if any: "Metacritic user score" isn't a Trakt rating, and a Rotten Tomatoes
        // audience score isn't its critics' score.
        case .traktRating, .imdbRating, .rottenTomatoesScore:
            let named = Set(typed.compactMap { scoreNames[$0] })
            let site: Score = kind == .imdbRating ? .imdb : kind == .rottenTomatoesScore ? .rottenTomatoes : .trakt
            let isAudience = typed.isDisjoint(with: audienceRatingWords) == false
            return typed.isDisjoint(with: maximums) && (named.isEmpty || named == [site]) && (site != .rottenTomatoes || isAudience == false)
        default: return true
        }
    }

    /// The Trakt value of a condition the model read, checked as the rules check theirs.
    /// Countries, languages and themes must be named by the typed words: "set in Paris" isn't France, and "for Halloween"
    /// isn't the theme "horror". Genres may be a mood, as "scary" for Horror, and people a nickname, as "Leo DiCaprio".
    private static func resolved(_ condition: AskCondition, range: Range<Int>, typed: [String], lists: Lists) async -> Match? {
        let value = condition.value.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = value.lowercased()
        let match = { (condition: Condition, title: String) in Match(range: range, condition: condition, titles: [title]) }
        let isTyped = { (name: String) in ranges(of: words(in: name), in: typed).isEmpty == false }
        switch condition.kind {
        case .genre:
            let slug = genreAliases[lowercased] ?? lowercased
            return lists.genres.first { $0.value == slug || isSame(lowercased, $0.title.lowercased()) }
                .map { match(.genres([$0.value]), $0.title) }
        case .country:
            let code = nationalities[lowercased] ?? countryNames[lowercased] ?? lowercased
            guard let country = lists.countries.first(where: { $0.value == code || $0.title.lowercased() == lowercased }) else { return nil }
            let names = [country.title] + nationalities.filter { $0.value == country.value }.map(\.key) + countryNames.filter { $0.value == country.value }.map(\.key)
            return names.contains(where: isTyped) ? match(.countries([country.value]), country.title) : nil
        case .language:
            return lists.languages.first { ($0.value == lowercased || $0.title.lowercased() == lowercased) && isTyped($0.title) }
                .map { match(.languages([$0.value]), $0.title) }
        case .streamingService:
            // Only typed as the rules read it: "cheap" isn't free.
            if let broad = SmartListChoices.watchNow.first(where: { serviceKey($0.title) == serviceKey(value) || $0.value == lowercased }) {
                let isTyped = broadServiceMatches(in: typed).contains { $0.condition == .services([broad.value]) }
                return isTyped ? match(.services([broad.value]), SmartListChoices.watchNowTitle(for: broad.value)) : nil
            }
            return lists.services.first { serviceKey($0.title) == serviceKey(value) }.map { match(.services([$0.value]), $0.title) }
        case .actor, .director, .person:
            let role: SmartListFilters.PersonRole? = condition.kind == .actor ? .cast : condition.kind == .director ? .directing : nil
            return await person(named: value).map { match(.people([$0.slug], role: role), $0.name) }
        case .studio:
            if let studio = knownStudio(named: words(in: value), byPart: true) {
                return match(.studios([studio.value]), studio.title)
            }
            return await searchedStudioSlug(named: value).map { match(.studios([$0]), value) }
        case .theme:
            guard isTyped(value) else { return nil }
            return await themeName(for: value).map { match(.themes([$0]), $0) }
        case .releaseYears, .releasedAfter, .releasedBefore:
            // "2010-2014" is a range of two years.
            let period = value.replacingOccurrences(of: #"(\d{4})\s*[-–]\s*(\d{4})"#, with: "$1 $2", options: .regularExpression)
            let typed = condition.kind == .releasedAfter ? "after \(period)" : condition.kind == .releasedBefore ? "before \(period)" : period
            return years(of: [typed]) == nil ? nil : match(.years([typed]), "")
        case .shorterThan, .longerThan:
            guard let minutes = Int(value.filter(\.isNumber)), minutes > 0 else { return nil }
            let range = condition.kind == .shorterThan ? [0, minutes] : [minutes, longestRuntime]
            return match(.runtimes(range), runtimeTitle(range))
        case .traktRating, .imdbRating, .rottenTomatoesScore:
            guard let minimum = percent(of: value.replacingOccurrences(of: " ", with: ""), next: nil, isOutOfTen: condition.kind != .rottenTomatoesScore)?.percent
            else { return nil }
            let score: Score = condition.kind == .imdbRating ? .imdb : condition.kind == .rottenTomatoesScore ? .rottenTomatoes : .trakt
            return match(.rating(score, minimum: minimum), ratingTitle(score, minimum))
        case .notWatched:
            return match(.unwatched, "Not watched")
        case .notStarted:
            return match(.notStarted, "Not started")
        case .certification:
            let code = lowercased.replacingOccurrences(of: "rated ", with: "").trimmingCharacters(in: .whitespaces)
            return certificationCodes.contains(code) ? match(.certifications([code]), code.uppercased()) : nil
        case .showStatus:
            let status = lowercased == "cancelled" ? "canceled" : lowercased
            return showStatuses.contains(status) ? match(.statuses([status]), status.smartListTitle) : nil
        case .notOnWatchlist:
            return match(.notOnWatchlist, "Not on my watchlist")
        }
    }
}

// MARK: - Generated values

@Generable
private struct AskKind {
    @Generable
    enum MediaType {
        case movies
        case shows
        case both
    }

    @Generable
    enum Source {
        case trending
        case popular
        case anticipated
        case recommended
        case watchlist
        case library
        case notSaid

        var source: SmartListSource? {
            switch self {
            case .trending: return .trending
            case .popular: return .popular
            case .anticipated: return .anticipated
            case .recommended: return .recommendations
            case .watchlist: return .watchlist
            case .library: return .library
            case .notSaid: return nil
            }
        }
    }

    @Guide(description: "movies or shows when the request says which, otherwise both.")
    var mediaType: MediaType
    @Guide(description: "The request's words saying movies or shows. Empty if none.")
    var mediaTypeWords: String
    @Guide(description: "Where titles come from: a chart, the person's watchlist or library, or notSaid.")
    var source: Source
    @Guide(description: "The request's words naming where titles come from. Empty if none.")
    var sourceWords: String
}

@Generable
private struct AskPlan {
    @Guide(description: "Each matcher handed some of the words not understood yet, or none.")
    var assignments: [AskAssignment]
}

@Generable
private struct AskAssignment {
    @Generable
    enum Matcher {
        case moviesOrShows
        case genres
        case places
        case people
        case services
        case studios
        case themes
        case releaseYears
        case runtime
        case ratings
        case watchStatus
        case showStatus
        case certifications

        var specialist: SmartListAssistant.Specialist {
            switch self {
            case .moviesOrShows: return .moviesOrShows
            case .genres: return .genres
            case .places: return .places
            case .people: return .people
            case .services: return .services
            case .studios: return .studios
            case .themes: return .themes
            case .releaseYears: return .releaseYears
            case .runtime: return .runtime
            case .ratings: return .ratings
            case .watchStatus: return .watchStatus
            case .showStatus: return .showStatus
            case .certifications: return .certifications
            }
        }
    }

    @Guide(description: "The words handed to the matcher, copied exactly from the request.")
    var words: String
    var matcher: Matcher
}

@Generable
private struct AskPerson {
    /// First, so the model reasons before it names someone, as Apple suggests.
    @Guide(description: "One sentence on who the request most likely means.")
    var reasoning: String
    @Guide(description: "The person's full name, or empty when it's unclear.")
    var name: String
}

@Generable
private struct AskConditions {
    @Guide(description: "Each condition found, or none.")
    var conditions: [AskCondition]
}

@Generable
private struct AskCondition {
    @Generable
    enum Kind {
        case genre
        case country
        case language
        case streamingService
        case actor
        case director
        case person
        case studio
        case theme
        case releaseYears
        case releasedAfter
        case releasedBefore
        case shorterThan
        case longerThan
        case traktRating
        case imdbRating
        case rottenTomatoesScore
        case notWatched
        case notOnWatchlist
        case notStarted
        case showStatus
        case certification

        var title: String {
            switch self {
            case .genre: return "Genre"
            case .country: return "Country"
            case .language: return "Language"
            case .streamingService: return "Service"
            case .actor: return "Actor"
            case .director: return "Director"
            case .person: return "Person"
            case .studio: return "Studio"
            case .theme: return "Theme"
            case .releaseYears, .releasedAfter, .releasedBefore: return "Release years"
            case .shorterThan, .longerThan: return "Runtime"
            case .traktRating, .imdbRating, .rottenTomatoesScore: return "Rating"
            case .notWatched: return "Not watched"
            case .notOnWatchlist: return "Not on watchlist"
            case .notStarted: return "Not started"
            case .showStatus: return "Show status"
            case .certification: return "Certification"
            }
        }
    }

    @Guide(description: "The request's own words for this condition, copied exactly.")
    var words: String
    var kind: Kind
    @Guide(description: "The value in Trakt's terms rather than the request's words: a genre such as horror, a person's full name such as Leonardo DiCaprio, a country, language, streaming service, studio or theme; a year or decade such as 1990s; minutes; or a rating such as 80%.")
    var value: String
    @Guide(description: "true when the request asks to leave this out, as in not on Netflix.")
    var isExcluded: Bool
}
