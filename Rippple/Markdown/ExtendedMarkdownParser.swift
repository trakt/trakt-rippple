//
//  ExtendedMarkdownParser.swift
//  Rippple
//
//  Created by Kevin Cador on 20/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Haring

final class SpoilerMarkdownParser: MarkdownParser {
    let highlight = MarkdownHighlight(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let mention = MarkdownMention(font: UIFont.preferredFont(forTextStyle: .headline), color: .label)
    let strike = MarkdownStrike(font: UIFont.preferredFont(forTextStyle: .body), color: .label)

    let spoiler = MarkdownSpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let allSpoiler = MarkdownAllSpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let displaySpoiler = MarkdownDisplaySpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)

    var spoilerStrategy: SpoilerStrategy? {
        didSet {
            guard let spoilerStrategy = spoilerStrategy else {
                _elements = [header, list, quote, link, automaticLink, bold, italic, highlight, mention, strike]
                return
            }
            switch spoilerStrategy {
            case .hideAllSpoilers:
                _elements = [allSpoiler]
            case .hideInlineSpoilers:
                _elements = [spoiler, header, list, link, automaticLink, quote, bold, italic, highlight, mention, strike]
            case .showAllSpoilers:
                _elements = [displaySpoiler, header, link, automaticLink, list, quote, bold, italic, highlight, mention, strike]
            }
        }
    }

    private lazy var _elements: [MarkdownElement] = [header, list, quote, bold, italic, highlight, mention, strike]

    override func elements() -> [MarkdownElement] {
        return _elements
    }
}

final class BoldMarkdownParser: MarkdownParser {
    override func elements() -> [MarkdownElement] {
        return [bold]
    }
}
