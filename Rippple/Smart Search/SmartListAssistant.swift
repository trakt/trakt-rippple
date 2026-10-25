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
import UIKit

/// Turns a typed request into a smart list definition. The rules read it first: spelling, movies or shows, the source,
/// conditions, then exclusions, each only taking the phrases they read exactly. With Apple Intelligence, a specialist
/// for each kind of condition reads it too, with a prompt of its own, and one decider keeps the rules' reading and adds
/// the specialists' findings the request asks for. Each step is summarized as soon as it's done, which the prompt screen
/// shows as a conversation before the composer opens.
///
/// Scope: this is a quick start in plain English, not a replacement for the composer. A phrase that could mean more than
/// one thing isn't read: it's left out and shown as such, and the composer has every condition a tap away. What matters
/// is never returning a list that means something other than what the log says was kept. When a request falls outside
/// this scope, leave its words out rather than adding a rule for it.
enum SmartListAssistant {
    struct Definition {
        let source: SmartListSource
        let mediaType: SmartListMediaType
        let filters: SmartListFilters
        /// What each pass kept and left out, in order.
        let steps: [Step]
    }

    /// One speaker's message: what the rules understood, a matcher's findings, or the judge's.
    struct Step {
        let lines: [Line]
    }

    struct Line {
        enum Kind {
            case kept
            case fixed
            case chose
            case leftOut
            /// A pass with nothing to report, as "Nothing to fix".
            case note
        }

        let kind: Kind
        let text: String
    }

    struct Token {
        /// As typed, to tell names from other words.
        let text: String
        /// Lowercased, to compare.
        let word: String

        var isCapitalized: Bool {
            text.first.map { $0.isUppercase || $0.isNumber } == true
        }
    }

    /// The request as one pass read it.
    struct Candidate {
        var mediaType: SmartListMediaType
        /// Typed words said movies or shows, rather than the reading choosing both.
        var isMediaTyped: Bool
        var typedSource: SmartListSource?
        var matches: [Match]
        /// Typed words the reading used, which the specialists' findings don't read again.
        var used: Set<Int>

        /// Nothing to make a list from: "Movies" alone is popular movies.
        var isEmpty: Bool {
            matches.isEmpty && typedSource == nil && isMediaTyped == false
        }
    }

    static var isModelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// Loads the model while the request is typed.
    static func prewarm() {
        guard isModelAvailable else { return }
        LanguageModelSession().prewarm()
    }

    /// The rules read the request first, exactly and at once. A coordinator then hands the words they couldn't read to
    /// the Apple Intelligence matchers that can, each with a prompt of its own, and a judge keeps what the request asks
    /// for among their findings. What's kept is written into the request, which the rules read again, so every finding
    /// is read as the rules read theirs and the next round starts from a clearer request: up to three rounds, while one
    /// understands something new. Each speaker's message is told through `onStep` as soon as it's done.
    static func definition(from typed: String, onStep: (@MainActor (Step) -> Void)? = nil) async -> Definition? {
        guard Task.isCancelled == false else { return nil }
        var steps = [Step]()
        func tell(_ step: Step) async {
            steps.append(step)
            await onStep?(step)
        }
        let openings = ["Let me take a look.", "Okay, let me see what you're after.", "Ooh, fun one. Let me read it.", "On it."]
        await tell(Step(lines: [Line(kind: .chose, text: openings[variety(of: typed, among: openings.count)])]))
        let (request, fixes) = await correctingTypos(in: typed)
        let typedTokens = tokens(in: request)
        guard typedTokens.isEmpty == false else { return nil }
        var written = Written(tokens: typedTokens, ids: Array(typedTokens.indices), pinned: [])
        var nextID = typedTokens.count
        var read = await rulesReading(of: typedTokens)
        let first = read
        var told = Set(read.notes)
        // Words each matcher already looked into, by word, so a later round doesn't ask it again.
        var tried = Set<String>()
        let triedKey = { (specialist: Specialist, range: Range<Int>, ids: [Int]) in "\(specialist)|" + range.map { "\(ids[$0])" }.joined(separator: ",") }

        // The coordinator tells what the rules understood, and who will look into the rest.
        var pending = fixes.isEmpty ? [] : [Line(kind: .fixed, text: "I'm guessing you meant \(listed(fixes.map { "“\($0.fixed)” for “\($0.typed)”" })).")]
        if let heard = read.heard, read.known.isEmpty == false || read.unread.isEmpty == false {
            pending.append(Line(kind: .kept, text: "Got it, \(heard)."))
        }
        pending += read.notes.map { Line(kind: .leftOut, text: $0) }
        if read.unread.isEmpty, read.candidate.isEmpty {
            pending.append(Line(kind: .note, text: "Hmm, I don't see anything I can search for in that."))
        }
        for round in 1...3 {
            guard Task.isCancelled == false else { return nil }
            let tokens = written.tokens
            let text = written.text
            // Leftover names, as "Hitchcock" in "thrillers not by Hitchcock", go straight to the people matcher: the
            // coordinator can't route what it can't read, and its safety filter stops some names.
            // A name leading a group, as "Scorsese" in "Scorsese gangster flicks", goes there too, and the rest to the
            // coordinator.
            var names = [Range<Int>]()
            var remaining = [Range<Int>]()
            for group in read.unread {
                guard let name = await name(in: group, tokens: tokens, lists: read.lists) else {
                    remaining.append(group)
                    continue
                }
                names.append(name)
                var rest = name.upperBound
                while rest < group.upperBound, linkingWords.contains(tokens[rest].word) {
                    rest += 1
                }
                if rest < group.upperBound {
                    remaining.append(rest..<group.upperBound)
                }
            }
            var plan = names.isEmpty ? [Specialist: [Range<Int>]]() : [.people: names]
            var skipped = [Line]()
            if remaining.isEmpty == false, isModelAvailable == false {
                skipped.append(Line(kind: .leftOut, text: "Without Apple Intelligence, I'll have to skip \(listed(remaining.map { "“\(quote($0, in: tokens))”" }))."))
            } else if remaining.isEmpty == false {
                let understood = round == 1 || read.candidate.isEmpty ? nil
                    : sentence(mediaType: read.candidate.mediaType, source: read.candidate.typedSource, matches: read.candidate.matches)
                let coordinated = await coordinating(request: text, tokens: tokens, unread: remaining, understood: understood)
                for (specialist, ranges) in coordinated.plan ?? [] {
                    plan[specialist, default: []] += ranges
                }
                // Without a plan, as when the model's safety filter stops it, the words are left out rather than guessed at:
                // every matcher looking at once finds things nobody asked for.
                skipped = coordinated.plan == nil
                    ? [Line(kind: .leftOut, text: "I'll have to skip \(listed(remaining.map { "“\(quote($0, in: tokens))”" })), as I can't search for \(remaining.count == 1 ? "it" : "them").")]
                    : coordinated.lines
            }
            // A matcher isn't asked twice about the same words.
            for (specialist, ranges) in plan {
                plan[specialist] = ranges.filter { tried.insert(triedKey(specialist, $0, written.ids)).inserted }
                if plan[specialist]?.isEmpty == true {
                    plan[specialist] = nil
                }
            }
            let known = read.known
            // Who looks into what, in one sentence: words a matcher knows, then those the plan handed out.
            let asks = Specialist.allCases.compactMap { specialist -> String? in
                // "Who “Hitchcock” and “Kubrick” are": people listed are asked about one by one.
                let asked = (plan[specialist] ?? []).flatMap { specialist == .people ? listed(in: $0, of: tokens.map(\.word)) : [$0] }
                let words = ((known[specialist] ?? []).map(\.range) + asked).map { "“\(quote($0, in: tokens))”" }.removingDuplicates()
                return words.isEmpty ? nil : specialist.question(about: words)
            }
            if asks.isEmpty == false {
                pending.append(Line(kind: .chose, text: "\(round == 1 ? "Let me check" : "Now let me check") \(listed(asks))."))
            }
            let called = Specialist.allCases.filter { known[$0] != nil || plan[$0] != nil }
            guard called.isEmpty == false else {
                pending += skipped
                break
            }
            await tell(Step(lines: pending))
            pending = []
            var findings = [Finding]()
            await withTaskGroup(of: ([Finding], Step).self) { group in
                for specialist in called {
                    group.addTask {
                        await reading(by: specialist, of: text, focus: plan[specialist] ?? [], known: known[specialist] ?? [], tokens: tokens,
                                      lists: read.lists)
                    }
                }
                for await(found, step) in group where found.isEmpty == false || step.lines.isEmpty == false {
                    findings += found
                    await tell(step)
                }
            }
            guard Task.isCancelled == false else { return nil }
            // Matchers finish in any order; the judge weighs them in a set one.
            let order = Specialist.allCases
            findings.sort { (order.firstIndex(of: $0.specialist) ?? 0) < (order.firstIndex(of: $1.specialist) ?? 0) }
            let judged = findings.isEmpty ? (kept: [], lines: []) : await judged(request: text, tokens: tokens, rules: read.candidate, findings: findings)
            guard Task.isCancelled == false else { return nil }
            pending = judged.lines
            guard judged.kept.isEmpty == false else {
                pending += skipped
                break
            }
            // What was understood is written in, as the rules read it, and the request is read again.
            // A matcher's own words are among those the rules used, and are written in too, so they aren't read again.
            let knownWords = Set(known.values.joined().flatMap(\.range))
            written = rewritten(written, with: known.values.joined() + judged.kept, used: read.candidate.used.subtracting(knownWords), nextID: &nextID)
            read = await rulesReading(of: written.tokens, pinned: written.pinned)
            pending += read.notes.filter { told.insert($0).inserted }.map { Line(kind: .leftOut, text: $0) }
            guard round < 3, read.unread.isEmpty == false else {
                pending += skipped
                break
            }
            let now = sentence(mediaType: read.candidate.mediaType, source: read.candidate.typedSource, matches: read.candidate.matches)
            pending.append(Line(kind: .kept, text: "So now I have \(now)."))
        }
        var chosen = read.candidate
        // Words that said again what was already read, told as typed.
        pending += first.repeats.map { Line(kind: .leftOut, text: $0) }
        let conflicts = conflicting(&chosen.matches, in: written.tokens)
        pending += conflicts.map { Line(kind: .leftOut, text: $0) }
        // Movies or shows alone make a list only when that's all that was asked: "Movies like Inception" or "movies rated
        // under 50%" aren't popular movies.
        let isOnlyMedia = chosen.matches.isEmpty && chosen.typedSource == nil
        guard chosen.isEmpty == false, isOnlyMedia == false || (read.unread.isEmpty && read.notes.isEmpty && conflicts.isEmpty) else {
            await tell(Step(lines: pending + [Line(kind: .note, text: "I couldn't turn that into a list, sorry. Tap your request to say it another way.")]))
            return nil
        }
        var (filters, isCatalog) = filters(of: chosen.matches)
        let source = chosen.typedSource ?? (isCatalog ? .discover : .popular)
        var closing = "Here's what I came up with: \(sentence(mediaType: chosen.mediaType, source: source, matches: chosen.matches))"
        // Across all of Trakt, ratings alone surface titles rated by a handful of people.
        if source == .discover, filters.ratings != nil || filters.metascores != nil {
            filters.votes = [1000, SmartListConditions.votesCeiling]
            closing += ", with at least 1,000 votes so a handful of ratings can't sway it"
        }
        closing += "."
        await tell(Step(lines: pending + [Line(kind: .chose, text: closing)]))
        return Definition(source: source, mediaType: chosen.mediaType, filters: filters, steps: steps)
    }

    // MARK: - Rounds

    /// The request as understood so far: its words, with what earlier rounds understood written in, and the conditions
    /// those written words stand for.
    private struct Written {
        var tokens: [Token]
        /// One id per word that stays the same across rewrites, so words already looked into are known again.
        var ids: [Int]
        /// Conditions found in earlier rounds, at the words written in for them: the rules take them as read.
        var pinned: [Match]

        var text: String {
            tokens.map(\.text).joined(separator: " ")
        }
    }

    /// The request with each finding's words replaced by what they mean, as "spooky" by "horror" or "Leo" by "starring
    /// Leonardo DiCaprio". Only words nothing read are written over; a negation typed before them goes with them.
    private static func rewritten(_ written: Written, with findings: [Finding], used: Set<Int>, nextID: inout Int) -> Written {
        let words = written.tokens.map(\.word)
        var replacements = [(range: Range<Int>, phrases: [String], matches: [Match])]()
        for finding in findings {
            var range = finding.range
            while range.isEmpty == false, used.contains(range.lowerBound) {
                range = range.lowerBound + 1..<range.upperBound
            }
            while range.isEmpty == false, used.contains(range.upperBound - 1) {
                range = range.lowerBound..<range.upperBound - 1
            }
            guard range.isEmpty == false, range.allSatisfy({ used.contains($0) == false }) else { continue }
            var matches = [Match]()
            if case .condition(var match) = finding.value {
                if match.isNegated, let start = match.negation?.lowerBound ?? negation(before: range.lowerBound, in: words), start < range.lowerBound,
                   (start..<range.lowerBound).allSatisfy({ used.contains($0) == false }) {
                    range = start..<range.upperBound
                }
                match.negation = nil
                matches.append(match)
            }
            replacements.append((range, [wording(of: finding.value)], matches))
        }
        // Findings of the same words, as "sitcoms" for shows and comedy, are written in together.
        var merged = [(range: Range<Int>, phrases: [String], matches: [Match])]()
        for replacement in replacements.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            if let last = merged.last, last.range.overlaps(replacement.range) {
                merged[merged.count - 1] = (min(last.range.lowerBound, replacement.range.lowerBound)..<max(last.range.upperBound, replacement.range.upperBound),
                                            (last.phrases + replacement.phrases).removingDuplicates(), last.matches + replacement.matches)
            } else {
                merged.append(replacement)
            }
        }
        var rewritten = Written(tokens: [], ids: [], pinned: [])
        var moved = [Int: Int]()
        var index = 0
        while index < written.tokens.count {
            if let replacement = merged.first(where: { $0.range.lowerBound == index }) {
                let start = rewritten.tokens.count
                for token in tokens(in: replacement.phrases.joined(separator: " ")) {
                    rewritten.tokens.append(token)
                    rewritten.ids.append(nextID)
                    nextID += 1
                }
                rewritten.pinned += replacement.matches.map { match in
                    var match = match
                    match.range = start..<rewritten.tokens.count
                    return match
                }
                index = replacement.range.upperBound
            } else {
                moved[index] = rewritten.tokens.count
                rewritten.tokens.append(written.tokens[index])
                rewritten.ids.append(written.ids[index])
                index += 1
            }
        }
        // Conditions written in before keep their words, wherever they moved.
        rewritten.pinned += written.pinned.compactMap { match in
            guard let lower = moved[match.range.lowerBound], let upper = moved[match.range.upperBound - 1] else { return nil }
            var match = match
            match.range = lower..<upper + 1
            return match
        }
        return rewritten
    }

    /// What a finding means, in words: "horror", "starring Leonardo DiCaprio", "not on Netflix", "shows".
    private static func wording(of value: Finding.Value) -> String {
        switch value {
        case .condition(let match):
            switch match.condition {
            case .unwatched: return "not watched"
            case .notStarted: return "not started"
            case .notOnWatchlist: return "not on your watchlist"
            case .statuses: return (match.isNegated ? "not " : "") + match.titles.joined(separator: " or ").lowercased()
            default: return spoken(match)
            }
        case .mediaType(let mediaType): return mediaType == .movies ? "movies" : "shows"
        case .source(let source):
            switch source {
            case .trending: return "trending"
            case .anticipated: return "upcoming"
            case .recommendations: return "recommended"
            case .watchlist: return "on my watchlist"
            case .library: return "in my library"
            default: return "popular"
            }
        }
    }

    /// What the rules read, at once and exactly.
    private struct RulesReading {
        let candidate: Candidate
        /// The rules' own reading as a sentence, told before the matchers look into the rest: "horror movies".
        let heard: String?
        /// Typed words nothing read, in groups as typed, for the coordinator.
        let unread: [Range<Int>]
        /// What had to be left out, as sentences.
        let notes: [String]
        /// Words that said again what was already read: "spooky" after "horror".
        let repeats: [String]
        /// The matchers' own words read, as "spooky" for Horror, which they tell as their findings.
        let known: [Specialist: [Finding]]
        /// What Trakt offers for movies and shows, for the matchers.
        let lists: Lists
    }

    /// The rules passes: movies or shows, the source, conditions, then exclusions, each only taking exact phrasings. The
    /// matchers' own words, as "spooky" for Horror or "Prime Video", are as exact and read here too, so "not", "or" and
    /// "and" apply to them as to every condition. Not told on their own: the coordinator says what the rules understood,
    /// and the matchers what their words mean.
    private static func rulesReading(of tokens: [Token], pinned: [Match] = []) async -> RulesReading {
        var notes = [String]()
        // Service names hold media words, as "TV" in "Apple TV": they aren't read as movies or shows. Conditions found in
        // earlier rounds are already read, at the words written in for them.
        let services = Set(serviceMatches(in: tokens, services: await SmartListChoices.watchNowServices()).flatMap(\.range))
        let written = Set(pinned.flatMap(\.range))
        var claimed = services.union(written)
        let typedMedia = mediaType(of: tokens, claimed: &claimed)
        var mediaType = typedMedia
        var isMediaTyped = claimed.subtracting(services).subtracting(written).isEmpty == false
        claimed.subtract(services)
        let typedSource = typedSource(in: tokens, claimed: &claimed, leftOut: &notes)

        async let typedLists = Lists.load(for: typedMedia)
        async let allLists = Lists.load(for: .media)
        let lists = await allLists
        let ruled = await conditions(in: tokens, claimed: claimed, lists: await typedLists)

        // Each group of words the rules left goes to the matchers that know them. Studios and themes only take words no
        // other matcher knows: "spooky" is the Horror genre rather than a "spooky" theme, and Netflix a service rather
        // than a studio.
        var known = [Specialist: [Finding]]()
        for group in unread(tokens, claimed: claimed.union(ruled.flatMap(\.range))) {
            var found = [Specialist: [Finding]]()
            for specialist in Specialist.allCases where [.studios, .themes].contains(specialist) == false {
                let findings = await exactFindings(by: specialist, in: group, tokens: tokens, lists: lists)
                if findings.isEmpty == false {
                    found[specialist] = findings
                }
            }
            for fallback in [Specialist.studios, .themes] where found.isEmpty {
                let findings = await exactFindings(by: fallback, in: group, tokens: tokens, lists: lists)
                if findings.isEmpty == false {
                    found[fallback] = findings
                }
            }
            known.merge(found) { $0 + $1 }
        }
        var matches = ruled + pinned
        var kinds = Set<SmartListMediaType>()
        for finding in known.values.joined() {
            claimed.formUnion(finding.range)
            switch finding.value {
            case .condition(let match): matches.append(match)
            case .mediaType(let kind): kinds.insert(kind)
            case .source: break
            }
        }
        // "Sitcoms" are shows, unless the request named movies or shows itself.
        if isMediaTyped == false, kinds.count == 1, let kind = kinds.first {
            mediaType = kind
            isMediaTyped = true
        }

        matches = grouped(matches.sorted { $0.range.lowerBound < $1.range.lowerBound }, in: tokens.map(\.word))
        // Trakt applies one role to every person of a list: people named with another role are left out.
        let role = matches.lazy.compactMap { match -> SmartListFilters.PersonRole?? in
            guard case .people(_, let role) = match.condition else { return nil }
            return role
        }.first
        matches.removeAll { match in
            guard case .people(_, let other) = match.condition, let role = role, other != role else { return false }
            notes.append("I'll have to skip “\(quote(match.range, in: tokens))”, as a list has one role for all its people.")
            return true
        }
        negating(&matches, in: tokens)
        claimed.formUnion(checking(&matches, in: tokens, leftOut: &notes))
        // Repeats are read too, with their negation, though they add nothing.
        for match in matches {
            claimed.formUnion(match.range)
            claimed.formUnion(match.negation ?? 0..<0)
            claimed.formUnion(match.alsoRead ?? 0..<0)
        }
        let repeats = deduplicating(&matches, in: tokens)

        // What the rules alone understood, as told before the matchers say what their words mean.
        var said = ruled
        var unsaid = [String]()
        negating(&said, in: tokens)
        _ = checking(&said, in: tokens, leftOut: &unsaid)
        _ = conflicting(&said, in: tokens)
        let heard = said.isEmpty && typedSource == nil ? nil : sentence(mediaType: typedMedia, source: typedSource, matches: said)

        let candidate = Candidate(mediaType: mediaType, isMediaTyped: isMediaTyped, typedSource: typedSource, matches: matches, used: claimed)
        return RulesReading(candidate: candidate, heard: heard, unread: unread(tokens, claimed: claimed), notes: notes, repeats: repeats,
                            known: known, lists: lists)
    }

    /// A value typed twice, as "horror" and "spooky", is one condition, and a wanted value wins over the same one
    /// excluded, as in "horror movies that aren't spooky". Only the values said before are dropped: "spooky and funny"
    /// after "horror" still adds Comedy. Returns what was dropped, as sentences.
    private static func deduplicating(_ matches: inout [Match], in tokens: [Token]) -> [String] {
        let wanted = Dictionary(grouping: matches.filter { $0.isNegated == false }, by: kind(of:)).mapValues { Set($0.flatMap(\.titles)) }
        var said = [String: Set<String>]()
        var kept = [Match]()
        var repeats = [String]()
        for match in matches {
            let kind = kind(of: match)
            let had = match.isNegated ? wanted[kind] ?? [] : said[kind] ?? []
            if match.isNegated == false {
                said[kind, default: []].formUnion(match.titles)
            }
            if let rest = dropping(had, from: match) {
                kept.append(rest)
            } else {
                let typed = (match.negation?.lowerBound ?? match.range.lowerBound)..<match.range.upperBound
                repeats.append("You already said “\(quote(typed, in: tokens))”, so I'll count it once.")
            }
        }
        matches = kept
        return repeats
    }

    // MARK: - Spelling

    /// Misspelled words become the word the reader knows, as "moies" for "movies". Anything else stays as typed, and so do
    /// capitalized words past the first, which may be names: "Wes" isn't "was".
    @MainActor
    private static func correctingTypos(in request: String) -> (request: String, fixes: [(typed: String, fixed: String)]) {
        let checker = UITextChecker()
        let text = request as NSString
        var fixes = [(range: NSRange, typed: String, fixed: String)]()
        var start = 0
        while start < text.length {
            let range = checker.rangeOfMisspelledWord(in: request, range: NSRange(location: 0, length: text.length), startingAt: start, wrap: false,
                                                      language: "en_US")
            guard range.location != NSNotFound else { break }
            start = range.location + range.length
            let word = text.substring(with: range)
            let isCapitalized = word.first?.isUppercase == true
            let plain = { (text: String) in text.lowercased().replacingOccurrences(of: "’", with: "'") }
            let guesses = checker.guesses(forWordRange: range, in: request, language: "en_US")?
                .filter { correctableWords.contains(plain($0)) } ?? []
            // A dropped letter is the likeliest typo: "ddn't" is "didn't" rather than "don't".
            guard word.count >= 4, genreAliases[word.lowercased()] == nil, isCapitalized == false || range.location == 0,
                  let guess = guesses.first(where: { isDroppingLetters(plain(word), from: plain($0)) }) ?? guesses.first else { continue }
            fixes.append((range, word, isCapitalized ? guess.capitalized : guess.lowercased()))
        }
        let corrected = NSMutableString(string: request)
        for fix in fixes.reversed() {
            corrected.replaceCharacters(in: fix.range, with: fix.fixed)
        }
        return (corrected as String, fixes.map { ($0.typed, $0.fixed) })
    }

    private static func isDroppingLetters(_ typed: String, from word: String) -> Bool {
        var rest = Substring(word)
        for character in typed {
            guard let index = rest.firstIndex(of: character) else { return false }
            rest = rest[rest.index(after: index)...]
        }
        return true
    }

    /// Words of four letters or more the reader understands, which a typo is corrected to.
    private static let correctableWords: Set<String> = {
        let genres: Set = ["action", "adventure", "animation", "anime", "comedy", "comedies", "crime", "documentary", "documentaries",
                           "drama", "dramas", "family", "fantasy", "history", "horror", "musical", "musicals", "mystery", "mysteries",
                           "romance", "romances", "thriller", "thrillers", "western", "westerns", "superhero", "superheroes",
                           "science", "fiction"]
        let phrases = sourcePhrases.map(\.0) + ["about", "involving", "starring", "featuring", "directed", "written", "rating", "ratings",
                                                "rated", "highly", "watched", "unwatched", "watchlist", "minutes", "hours", "under", "over",
                                                "didn't", "haven't", "hasn't", "watch", "seen", "still", "checked", "started", "finished"]
        return linkingWords.union(movieWords).union(showWords).union(negatives).union(genres).union(nationalities.keys)
            .union(countryNames.keys).union(phrases.flatMap { words(in: $0) }).filter { $0.count >= 4 }
    }()

    // MARK: - Movies or shows

    static let movieWords: Set<String> = ["movie", "movies", "film", "films"]
    static let showWords: Set<String> = ["show", "shows", "series", "tv"]

    /// Movies or shows as the words name them, claimed or not, kinds of titles included: "sitcoms" are shows and
    /// "flicks" movies. Neither, or both, is both.
    static func mediaType(named words: [String]) -> SmartListMediaType {
        let movies = words.indices.filter { movieWords.contains(words[$0]) || movieKinds.contains(words[$0]) }
        let shows = words.indices.filter { index in
            (showWords.contains(words[index]) && isAsking(at: index, in: words) == false) || seriesKinds.contains { isSame(words[index], $0) }
        }
        let typed = Set(movies + shows)
        let isWanted = { (index: Int) in mediaNegation(at: index, in: words, typed: typed) == nil }
        let isMovies = movies.contains(where: isWanted) || (movies.isEmpty && shows.isEmpty == false && shows.contains(where: isWanted) == false)
        let isShows = shows.contains(where: isWanted) || (shows.isEmpty && movies.isEmpty == false && movies.contains(where: isWanted) == false)
        switch (isMovies, isShows) {
        case (true, false): return .movies
        case (false, true): return .shows
        default: return .media
        }
    }

    /// The negation of movies or shows typed at `index`, among the `typed` ones: "not TV shows" and "not movies or shows"
    /// negate every word, from the first.
    private static func mediaNegation(at index: Int, in words: [String], typed: Set<Int>) -> Int? {
        var start = index
        while typed.contains(start - 1) || (start > 1 && ["or", "nor", "and"].contains(words[start - 1]) && typed.contains(start - 2)) {
            start -= typed.contains(start - 1) ? 1 : 2
        }
        return negation(before: start, in: words)
    }

    /// Whether "show" asks for something rather than names a TV show: "show me horror movies", "please show movies from
    /// the 90s", "Show horror movies". "Show about zombies" and "a show with Tom Hanks" are shows.
    static func isAsking(at index: Int, in words: [String]) -> Bool {
        guard words[index] == "show" else { return false }
        let next = index + 1 < words.count ? words[index + 1] : ""
        let previous = index > 0 ? words[index - 1] : ""
        if ["me", "us", "some", "all", "any", "my"].contains(next) || ["please", "you", "just"].contains(previous) {
            return true
        }
        let nounLinks: Set = ["about", "with", "from", "on", "that", "which", "starring", "featuring", "set", "by", "where", "like", "for", "based",
                              "in", "of"]
        return index == 0 && next.isEmpty == false && nounLinks.contains(next) == false
    }

    /// Only as typed: a request naming neither, or both, is for both. One that's negated, as "not shows", means the other.
    private static func mediaType(of tokens: [Token], claimed: inout Set<Int>) -> SmartListMediaType {
        let words = tokens.map(\.word)
        let movies = tokens.indices.filter { movieWords.contains(words[$0]) && claimed.contains($0) == false }
        let shows = tokens.indices.filter { showWords.contains(words[$0]) && isAsking(at: $0, in: words) == false && claimed.contains($0) == false }
        let typed = Set(movies + shows)
        let negation = { (index: Int) in mediaNegation(at: index, in: words, typed: typed) }
        // Neither isn't a list: it's left unread.
        guard typed.isEmpty || typed.contains(where: { negation($0) == nil }) || Set(movies).isEmpty || Set(shows).isEmpty else { return .media }
        claimed.formUnion(typed.union(typed.compactMap(negation)))
        let isMovies = movies.contains { negation($0) == nil } || (movies.isEmpty && shows.isEmpty == false && shows.allSatisfy { negation($0) != nil })
        let isShows = shows.contains { negation($0) == nil } || (shows.isEmpty && movies.isEmpty == false && movies.allSatisfy { negation($0) != nil })
        switch (isMovies, isShows) {
        case (true, false): return .movies
        case (false, true): return .shows
        default: return .media
        }
    }

    // MARK: - Source

    private static let sourcePhrases: [(String, SmartListSource)] = [
        ("trending", .trending), ("popular", .popular), ("most popular", .popular), ("most watched", .popular),
        ("anticipated", .anticipated), ("most anticipated", .anticipated), ("upcoming", .anticipated), ("coming soon", .anticipated),
        ("recommended", .recommendations), ("recommendations", .recommendations), ("my watchlist", .watchlist), ("my library", .library),
        ("my collection", .library), ("all of trakt", .discover)
    ]

    /// When several are typed, the most personal wins: "trending movies on my watchlist" are on the watchlist.
    private static let sourcePriority: [SmartListSource] = [.watchlist, .library, .recommendations, .anticipated, .trending, .popular, .discover]

    /// The source as typed: a chart, the watchlist or library, or all of Trakt. One that's negated, as "not on my
    /// watchlist", is left to the conditions.
    private static func typedSource(in tokens: [Token], claimed: inout Set<Int>, leftOut: inout [String]) -> SmartListSource? {
        let words = tokens.map(\.word)
        var found = [(range: Range<Int>, source: SmartListSource)]()
        for (phrase, source) in sourcePhrases.sorted(by: { $0.0.count > $1.0.count }) {
            for range in ranges(of: SmartListAssistant.words(in: phrase), in: words) where found.allSatisfy({ $0.range.overlaps(range) == false }) {
                var start = range.lowerBound
                if start > 0, ["on", "in", "from"].contains(words[start - 1]) {
                    start -= 1
                }
                guard negation(before: start, in: words) == nil else { continue }
                let end = words.dropFirst(range.upperBound).starts(with: ["for", "me"]) ? range.upperBound + 2 : range.upperBound
                found.append((start..<end, source))
            }
        }
        guard let chosen = sourcePriority.first(where: { source in found.contains { $0.source == source } }) else { return nil }
        for match in found.sorted(by: { $0.range.lowerBound < $1.range.lowerBound }) {
            claimed.formUnion(match.range)
            if match.source != chosen {
                leftOut.append("I'll have to skip “\(quote(match.range, in: tokens))”, as a list has one source.")
            }
        }
        return chosen
    }

    // MARK: - Exclusions

    static let negatives: Set<String> = [
        "not", "no", "never", "without", "isn't", "aren't", "wasn't", "weren't", "don't", "doesn't", "haven't", "hasn't", "except",
        "excluding"
    ]

    /// A negation right before a condition, with only linking words in between, excludes all of it: "not on Netflix or
    /// Hulu", "without Tom Hanks". Conditions that say a negation themselves, as "haven't watched", already mean it.
    private static func negating(_ matches: inout [Match], in tokens: [Token]) {
        let words = tokens.map(\.word)
        for index in matches.indices {
            switch matches[index].condition {
            case .unwatched, .notStarted, .notOnWatchlist: continue
            default: break
            }
            let start = matches[index].range.lowerBound
            guard let negation = freeNegation(before: start, in: words, among: matches) else { continue }
            matches[index].isNegated = true
            matches[index].negation = negation..<start
        }
        // Once each negation has its condition, joined ones follow theirs, in order so a chain follows its first. A merged
        // condition still starts where its first part did.
        for index in matches.indices.sorted(by: { matches[$0].range.lowerBound < matches[$1].range.lowerBound }) {
            guard let joined = matches[index].joinedTo, let source = matches.first(where: { match in
                guard case .parental = match.condition else { return false }
                return match.range.contains(joined.lowerBound)
            }) else { continue }
            matches[index].isNegated = source.isNegated
            matches[index].negation = source.negation
        }
    }

    /// Readings the composer can't search are left out and told, with their negation. Returns the words they held.
    private static func checking(_ matches: inout [Match], in tokens: [Token], leftOut: inout [String]) -> Set<Int> {
        var dropped = Set<Int>()
        matches.removeAll { match in
            guard let reason = unsearchable(match) else { return false }
            let range = (match.negation?.lowerBound ?? match.range.lowerBound)..<match.range.upperBound
            dropped.formUnion(range)
            dropped.formUnion(match.alsoRead ?? 0..<0)
            leftOut.append("I'll have to skip “\(quote(range, in: tokens))”, \(reason).")
            return true
        }
        return dropped
    }

    /// A negation right before `start` that no condition holds as its own, as "not" in "not released yet with zombies".
    static func freeNegation(before start: Int, in words: [String], among matches: [Match]) -> Int? {
        guard let negation = negation(before: start, in: words), matches.contains(where: { $0.range.contains(negation) }) == false else { return nil }
        return negation
    }

    /// Where a negation right before a condition was typed: "aren't from the 90s", "not currently on my watchlist", "aren't
    /// too scary", with linking words, the condition's own lead-in and words such as "currently" in between. It reaches
    /// past negated movies or shows: "not shows or anime".
    static func negation(before start: Int, in words: [String]) -> Int? {
        var index = start - 1
        while index >= 0, ["are", "is", "that", "which", "the", "a", "an", "be", "been", "from", "in", "on", "by", "with", "of", "during", "released",
                           "currently", "already", "yet", "still", "even", "really", "now", "too", "very", "overly", "so"].contains(words[index]) {
            index -= 1
        }
        if index >= 0, negatives.contains(words[index]) {
            return index
        }
        let isMedia = { (index: Int) in index >= 0 && (movieWords.contains(words[index]) || showWords.contains(words[index])) }
        guard index >= 1, ["or", "nor"].contains(words[index]), isMedia(index - 1) else { return nil }
        var media = index - 1
        while isMedia(media - 1) {
            media -= 1
        }
        return negation(before: media, in: words)
    }

    // MARK: - Log

    /// Typed words the rules didn't read, in groups as typed: "cozy", "set in Paris".
    private static func unread(_ tokens: [Token], claimed: Set<Int>) -> [Range<Int>] {
        var groups = [Range<Int>]()
        var group = [Int]()
        let tell = {
            while let last = group.last, isLinking(tokens[last]) {
                group.removeLast()
            }
            guard let first = group.first, let last = group.last else { return }
            groups.append(first..<last + 1)
            group = []
        }
        for index in tokens.indices {
            // A clause starts a group of its own: "Leo" and "feel cozy" in "with Leo that feel cozy".
            if claimed.contains(index) || ["that", "which", "who"].contains(tokens[index].word) {
                tell()
            } else if isLinking(tokens[index]) {
                if group.isEmpty == false {
                    group.append(index)
                }
            } else {
                group.append(index)
            }
        }
        tell()
        return groups
    }

    /// A linking word as typed: "us" is one, "US" the country.
    private static func isLinking(_ token: Token) -> Bool {
        linkingWords.contains(token.word) && token.text != "US"
    }

    static func quote(_ range: Range<Int>, in tokens: [Token]) -> String {
        tokens[range].map(\.text).joined(separator: " ")
    }

    // MARK: - Words

    /// Words that only link conditions, never logged as left out.
    static let linkingWords: Set<String> = [
        "a", "an", "the", "i", "i've", "i'm", "i'd", "me", "my", "we", "our", "to", "of", "in", "on", "at", "by", "for", "with",
        "from", "and", "or", "that", "which", "who", "is", "are", "was", "were", "be", "been", "it", "its", "some", "any", "all",
        "want", "please", "show", "find", "give", "list", "see", "watch", "watching", "can", "could", "would", "should", "will",
        "do", "does", "did", "have", "has", "had", "get", "something", "anything", "titles", "ones", "also", "only", "just",
        "really", "very", "yet", "ever", "released", "made", "available", "streaming", "stream", "where", "when", "he", "she", "they",
        "him", "her", "his", "them", "their", "us"
    ]

    /// Words that aren't names when typed capitalized, as "Popular" or "Directed". Services aren't among them: one is
    /// "Ryan and Friends+", and a typed service is read before names anyway.
    static func knownWords(_ lists: Lists) -> Set<String> {
        let names = (lists.genres + lists.countries + lists.languages).flatMap { words(in: $0.title) }
        return linkingWords.union(movieWords).union(showWords).union(negatives).union(nationalities.keys).union(names)
            .union(sourcePhrases.flatMap { words(in: $0.0) })
            .union(["starring", "featuring", "directed", "written", "about", "involving", "rated", "highly", "top", "well", "imdb"])
    }

    /// Curly and straight apostrophes are alike, as in "haven’t" and "haven't". Percents and decimals stay in their
    /// word, as "80%" or "8.5/10".
    static func tokens(in text: String) -> [Token] {
        // "1990–2000" and "1990 - 2000" are one range, as "1990-2000".
        text.replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: #"(\d{4})\s*[-–—]\s*(\d{4})"#, with: "$1-$2", options: .regularExpression)
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "'+-%./")).inverted)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "'-./")) }
            .filter { $0.isEmpty == false }
            .map { Token(text: $0, word: $0.lowercased()) }
    }

    static func words(in text: String) -> [String] {
        tokens(in: text).map(\.word)
    }

    /// Plurals match, as "comedies" for "comedy" or "zombies" for "zombie". Short words only match as typed: "news" isn't
    /// "new".
    static func isSame(_ typed: String, _ word: String) -> Bool {
        guard typed != word else { return true }
        guard word.count > 3 else { return false }
        return typed == word + "s" || typed == word + "es" || (word.hasSuffix("y") && typed == word.dropLast() + "ies")
    }

    /// Every place a phrase was typed.
    static func ranges(of phrase: [String], in words: [String]) -> [Range<Int>] {
        guard phrase.isEmpty == false, phrase.count <= words.count else { return [] }
        return (0...words.count - phrase.count)
            .filter { start in zip(words[start..<start + phrase.count], phrase).allSatisfy { isSame($0, $1) } }
            .map { $0..<$0 + phrase.count }
    }
}
