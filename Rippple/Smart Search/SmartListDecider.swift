//
//  SmartListDecider.swift
//  Rippple
//
//  Created by Kevin Cador on 23/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import FoundationModels

/// The judge of `SmartListAssistant`: it weighs the model's findings against what the rules understood, which is exact
/// and includes the matchers' own words. Code sets aside what can't be added, as a finding of a kind the rules already
/// read; the on-device model judges the rest, all at once. What it keeps is written into the request for the rules to
/// read again.
extension SmartListAssistant {
    private static let judgeInstructions = """
    You are a careful judge for a movie and TV show search. Read a person's request and a numbered list of conditions \
    found in it. Keep a condition only if the request asks for it. Say why in one sentence, then list the numbers of the \
    conditions to keep.
    """

    /// The findings to keep, and what the judge tells of the others.
    static func judged(request: String, tokens: [Token], rules: Candidate, findings: [Finding]) async -> (kept: [Finding], lines: [Line]) {
        let ruleKinds = Set(rules.matches.map(kind(of:)))
        // The model sometimes quotes more than the words of a condition, as a whole request for its years: a finding
        // adds to the rules when it reads words they didn't, and is of a kind they didn't read.
        let isNew = { (range: Range<Int>) in range.contains { rules.used.contains($0) == false && linkingWords.contains(tokens[$0].word) == false } }
        var additions = [Finding]()
        var covered = [String]()
        // One finding per kind for the same words: "sitcoms" may be both shows and comedy, but not two genres.
        let sameKind = { (finding: Finding, other: Finding) -> Bool in
            switch (finding.value, other.value) {
            case (.condition(let a), .condition(let b)): return kind(of: a) == kind(of: b)
            case (.mediaType, .mediaType), (.source, .source): return true
            default: return false
            }
        }
        for finding in findings where isNew(finding.range) && additions.allSatisfy({ $0.range.overlaps(finding.range) == false || sameKind(finding, $0) == false }) {
            switch finding.value {
            // A guess doesn't join a kind the rules read: "horror" isn't joined by a guessed "without horror".
            case .condition(let match) where ruleKinds.contains(kind(of: match)) == false: additions.append(finding)
            // Except someone else, with the same role: "with Tom Hanks and Leo" names two people.
            case .condition(let match) where isAnotherPerson(match, than: rules.matches): additions.append(finding)
            case .mediaType where rules.isMediaTyped == false: additions.append(finding)
            case .source where rules.typedSource == nil: additions.append(finding)
            default: covered.append("“\(quote(finding.range, in: tokens))”")
            }
        }
        let coveredLine = covered.isEmpty ? [] : [Line(kind: .leftOut, text: "You already said \(listed(covered)), so I'll count it once.")]
        guard additions.isEmpty == false else {
            return ([], coveredLine)
        }
        let prompt = "Request: \(request)\n\nConditions:\n" + additions.enumerated().map { "\($0.offset + 1). \($0.element.describe(in: tokens))" }
            .joined(separator: "\n")
        var lines = [Line]()
        var kept = Set<Int>()
        if let check = try? await LanguageModelSession(instructions: judgeInstructions)
            .respond(to: prompt, generating: AskCheck.self, options: GenerationOptions(samplingMode: .greedy)).content {
            kept = Set(check.keep.map { $0 - 1 }.filter(additions.indices.contains))
        } else {
            // Every finding already quotes typed words that say it, and exists on Trakt.
            kept = Set(additions.indices)
            lines.append(Line(kind: .note, text: "I couldn't double-check what I found, so I'll keep all of it."))
        }
        let quoted = { (index: Int) in "“\(quote(additions[index].range, in: tokens))”" }
        let dropped = additions.indices.filter { kept.contains($0) == false }.map(quoted).removingDuplicates()
        // What's kept shows in the closing sentence; only what's left out is told.
        if dropped.isEmpty == false {
            lines.append(Line(kind: .leftOut, text: "I'll skip \(listed(dropped)), since you didn't really ask for \(dropped.count == 1 ? "it" : "them")."))
        }
        return (additions.indices.sorted().filter(kept.contains).map { additions[$0] }, lines + coveredLine)
    }
}

extension SmartListAssistant {
    /// A person none of `matches` names, with the role they share, or none: a list has one role for all its people.
    static func isAnotherPerson(_ match: Match, than matches: [Match]) -> Bool {
        guard case .people(let slugs, let role) = match.condition else { return false }
        for other in matches {
            guard case .people(let named, let shared) = other.condition else { continue }
            guard Set(named).isDisjoint(with: slugs), role == nil || role == shared else { return false }
        }
        return true
    }
}

@Generable
private struct AskCheck {
    /// First, so the model reasons before it decides, as Apple suggests.
    @Guide(description: "One sentence on which conditions the request asks for, and why.")
    var reasoning: String
    @Guide(description: "The numbers of the conditions the request asks for.")
    var keep: [Int]
}
