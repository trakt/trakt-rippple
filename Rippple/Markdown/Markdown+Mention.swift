//
//  Markdown+Mention.swift
//  Rippple
//
//  Created by Kevin Cador on 17/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Haring

class MarkdownMention: MarkdownCommonElement {
    fileprivate static let regex = "(\\s+|^|\\B)@[\\w_-]+"

    open var font: UIFont?
    open var color: UIColor?

    open var regex: String {
        return MarkdownMention.regex
    }

    init(font: UIFont? = nil, color: UIColor? = nil) {
        self.font = font
        self.color = color
    }

    func match(_ match: NSTextCheckingResult, attributedString: NSMutableAttributedString) {
        addAttributes(attributedString, range: match.range)
    }
}
