//
//  Markdown+Strike.swift
//  Rippple
//
//  Created by Kevin Cador on 22/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Haring

class MarkdownStrike: MarkdownCommonElement {
    fileprivate static let regex = "(\\s+|^|\\B)(~~)(.+?)(\\2)"

    open var font: UIFont?
    open var color: UIColor?
    open var strikeColor: UIColor?

    open var regex: String {
        return MarkdownStrike.regex
    }

    init(font: UIFont? = nil, color: UIColor? = nil, strikeColor: UIColor? = nil) {
        self.font = font
        self.color = color
        self.strikeColor = strikeColor
    }

    open func addAttributes(_ attributedString: NSMutableAttributedString, range: NSRange) {
        let matchString = attributedString.attributedSubstring(from: range).string
        let newRange = NSRange(location: range.location, length: (matchString as NSString).length)
        attributedString.addAttributes(attributes, range: newRange)
    }

    var attributes: [NSAttributedString.Key: Any] {
        return [NSAttributedString.Key.strikethroughStyle: 1,
                NSAttributedString.Key.baselineOffset: 0,
                NSAttributedString.Key.foregroundColor: color ?? .darkText,
                NSAttributedString.Key.strikethroughColor: strikeColor ?? color ?? .darkText]
    }

    func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        // deleting trailing markdown
        attributedString.deleteCharacters(in: match.range(at: 4))
        // formatting string (may alter the length)
        addAttributes(attributedString, range: match.range(at: 3))
        // deleting leading markdown
        attributedString.deleteCharacters(in: match.range(at: 2))
    }
}
