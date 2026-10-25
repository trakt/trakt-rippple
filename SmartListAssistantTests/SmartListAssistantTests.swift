//
//  SmartListAssistantTests.swift
//  SmartListAssistantTests
//
//  Created by Kevin Cador on 25/10/2026.
//  Copyright © Trakt. All rights reserved.
//

@testable import Rippple
import Testing

/// Tests for the smart list assistant only: how `SmartListAssistant` reads a typed request into a smart list. This target
/// isn't the app's test suite, and other features don't add tests here.
///
/// Each case of `SmartListAssistantTestCases` runs as its own test, through the app's real reader: its rules, Trakt
/// lookups and Apple Intelligence. They need a network connection, `Secrets.swift`, and Apple Intelligence turned on
/// where they run. Requests are read one at a time, as a person would type them, and as in the US: the scheme sets the
/// US locale, and the suite the US streaming services.
@Suite("Smart list assistant", .serialized)
struct SmartListAssistantTests {
    init() {
        SmartListChoices.testingWatchNowCountry = "us"
    }

    @Test("Reads every test case", arguments: SmartListAssistantTestCases.cases)
    func reads(_ testCase: SmartListAssistantTestCase) async {
        let reading = await SmartListAssistant.definition(from: testCase.prompt).map {
            SmartListAssistantTestCase.Reading(source: $0.source, mediaType: $0.mediaType, filters: $0.filters)
        }
        let accepting = Comment(rawValue: "Once this reading is reviewed as right, replace the case with:\n\(SmartListAssistantTestCase(prompt: testCase.prompt, reading: reading).swiftLiteral)")
        if let issue = testCase.knownIssue {
            withKnownIssue(Comment(rawValue: issue)) {
                #expect(reading == testCase.reading, accepting)
            }
        } else {
            #expect(reading == testCase.reading, accepting)
        }
    }
}

/// A request as typed, and the smart list the assistant must make of it.
struct SmartListAssistantTestCase: Identifiable, CustomTestStringConvertible {
    struct Reading: Hashable {
        let source: SmartListSource
        let mediaType: SmartListMediaType
        let filters: SmartListFilters
    }

    let prompt: String
    /// Nil when the request must make no list.
    let reading: Reading?
    /// Why the reading is right but not made yet. The case is then reported apart, and flagged once it passes.
    var knownIssue: String?

    var id: String {
        prompt
    }

    var testDescription: String {
        prompt
    }

    static func reads(_ prompt: String, _ source: SmartListSource, _ mediaType: SmartListMediaType, _ filters: SmartListFilters,
                      knownIssue: String? = nil) -> SmartListAssistantTestCase {
        SmartListAssistantTestCase(prompt: prompt, reading: Reading(source: source, mediaType: mediaType, filters: filters), knownIssue: knownIssue)
    }

    static func noList(_ prompt: String, knownIssue: String? = nil) -> SmartListAssistantTestCase {
        SmartListAssistantTestCase(prompt: prompt, reading: nil, knownIssue: knownIssue)
    }

    /// The case as written in `SmartListAssistantTestCases`, with the filters set in their declaration order.
    var swiftLiteral: String {
        let prompt = SmartListAssistantTestCase.quoted(self.prompt)
        guard let reading = reading else { return ".noList(\(prompt))" }
        let filters = Mirror(reflecting: reading.filters).children.compactMap { child -> String? in
            guard let label = child.label, let value = SmartListAssistantTestCase.literal(child.value) else { return nil }
            return "\(label): \(value)"
        }
        return ".reads(\(prompt), .\(reading.source.rawValue), .\(reading.mediaType.rawValue), SmartListFilters(\(filters.joined(separator: ", "))))"
    }

    /// A Swift string literal of `string`, with line breaks and other control characters escaped so it compiles.
    private static func quoted(_ string: String) -> String {
        let escaped = string.unicodeScalars.map { scalar -> String in
            switch scalar {
            case "\\": return "\\\\"
            case "\"": return "\\\""
            case "\n": return "\\n"
            case "\r": return "\\r"
            case "\t": return "\\t"
            default:
                return scalar.properties.generalCategory == .control ? "\\u{\(String(scalar.value, radix: 16))}" : String(scalar)
            }
        }
        return "\"\(escaped.joined())\""
    }

    private static func literal(_ value: Any) -> String? {
        switch value {
        case let string as String:
            return quoted(string)
        case let double as Double:
            return double.rounded() == double ? String(Int(double)) : String(double)
        case let values as [Any]:
            return "[\(values.compactMap { literal($0) }.joined(separator: ", "))]"
        case let value as any RawRepresentable<String>:
            return ".\(value.rawValue)"
        default:
            let mirror = Mirror(reflecting: value)
            guard mirror.displayStyle == .optional else { return String(describing: value) }
            return mirror.children.first.flatMap { literal($0.value) }
        }
    }
}
