//
//  Markdown+Highlight.swift
//  Rippple
//
//  Created by Kevin Cador on 22/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Haring
import UIKit

final class MarkdownHighlight: MarkdownCommonElement {
    fileprivate static let regex = "(\\s+|^|\\B)(==)(.+?)(\\2)"

    var font: UIFont?
    var color: UIColor?
    var highlightColor: UIColor?

    var regex: String {
        return MarkdownHighlight.regex
    }

    init(font: UIFont? = nil, color: UIColor? = nil, highlightColor: UIColor? = nil) {
        self.font = font
        self.color = color
        self.highlightColor = highlightColor
    }

    func addAttributes(_ attributedString: NSMutableAttributedString, range: NSRange) {
        let matchString = attributedString.attributedSubstring(from: range).string
        let newRange = NSRange(location: range.location, length: (matchString as NSString).length)
        attributedString.addAttributes(attributes, range: newRange)
    }

    var attributes: [NSAttributedString.Key: Any] {
        return [.foregroundColor: color ?? .darkText,
                .backgroundColor: highlightColor ?? UIColor.yellow,
                .font: font ?? UIFont.systemFont(ofSize: 16)]
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
