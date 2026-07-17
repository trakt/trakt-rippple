//
//  Markdown+Spoilers.swift
//  Rippple
//
//  Created by Kevin Cador on 22/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Haring
import UIKit

class MarkdownSpoiler: MarkdownCommonElement {
    fileprivate static let regex = "(\\[spoiler\\])(.*?)(\\[\\/spoiler\\])"

    open var font: UIFont?
    open var color: UIColor?

    open var regex: String {
        return MarkdownSpoiler.regex
    }

    open func regularExpression() throws -> NSRegularExpression {
        return try NSRegularExpression(pattern: regex, options: .dotMatchesLineSeparators)
    }

    init(font: UIFont? = nil, color: UIColor? = nil) {
        self.font = font
        self.color = color
    }

    open func addAttributes(_ attributedString: NSMutableAttributedString, range: NSRange) {
        let matchString = attributedString.attributedSubstring(from: range).string
        let newRange = NSRange(location: range.location, length: (matchString as NSString).length)
        attributedString.addAttributes(attributes, range: newRange)
    }

    var attributes: [NSAttributedString.Key: Any] {
        return [NSAttributedString.Key.strikethroughStyle: 7,
                NSAttributedString.Key.baselineOffset: 0,
                NSAttributedString.Key.foregroundColor: UIColor.clear,
                NSAttributedString.Key.strikethroughColor: UIColor.label]
    }

    func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        // deleting trailing markdown
        attributedString.deleteCharacters(in: match.range(at: 3))
        // formatting string (may alter the length)
        addAttributes(attributedString, range: match.range(at: 2))
        // deleting leading markdown
        attributedString.deleteCharacters(in: match.range(at: 1))
    }

    func parse(_ attributedString: NSMutableAttributedString) {
        var location = 0
        do {
            let regex = try regularExpression()
            while let regexMatch =
                regex.firstMatch(in: attributedString.string,
                                 options: .withoutAnchoringBounds,
                                 range: NSRange(location: location,
                                                length: attributedString.length - location)), location < attributedString.length {
                let oldLength = attributedString.length
                match(regexMatch, attributedString: attributedString)
                let newLength = attributedString.length
                location = regexMatch.range.location + regexMatch.range.length + newLength - oldLength
            }
        } catch {}
    }
}

final class MarkdownAllSpoiler: MarkdownSpoiler {
    override var regex: String {
        return "([\\s\\S]*)"
    }

    override func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        addAttributes(attributedString, range: match.range(at: 1))
    }
}

final class MarkdownDisplaySpoiler: MarkdownSpoiler {
    override var attributes: [NSAttributedString.Key: Any] {
        return [NSAttributedString.Key.strikethroughStyle: 7,
                NSAttributedString.Key.baselineOffset: 0,
                NSAttributedString.Key.foregroundColor: color ?? UIColor.label,
                NSAttributedString.Key.strikethroughColor: color?.withAlphaComponent(0.2) ?? UIColor.label.withAlphaComponent(0.2)]
    }
}
