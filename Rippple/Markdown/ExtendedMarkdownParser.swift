//
//  ExtendedMarkdownParser.swift
//  Rippple
//
//  Created by Kevin Cador on 20/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Haring
import UIKit

final class SpoilerMarkdownParser: MarkdownParser {
    let highlight = MarkdownHighlight(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let mention = MarkdownMention(font: UIFont.preferredFont(forTextStyle: .headline), color: .label)
    let strike = MarkdownStrike(font: UIFont.preferredFont(forTextStyle: .body), color: .label)

    let spoiler = MarkdownSpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let allSpoiler = MarkdownAllSpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)
    let displaySpoiler = MarkdownDisplaySpoiler(font: UIFont.preferredFont(forTextStyle: .body), color: .label)

    override init(font: UIFont = UIFont.systemFont(ofSize: UIFont.smallSystemFontSize),
                  color: UIColor = UIColor.black,
                  automaticLinkDetectionEnabled: Bool = true,
                  customElements: [MarkdownElement] = []) {
        super.init(font: font,
                   color: color,
                   automaticLinkDetectionEnabled: automaticLinkDetectionEnabled,
                   customElements: customElements)
        link.color = UIColor(asset: .globalTint)
        automaticLink.color = UIColor(asset: .globalTint)
    }

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

    /// Elements parsed after a spoiler (links, mentions, highlights) restyle its text, so hidden ranges are cleaned up at the end.
    override func parse(_ markdown: NSAttributedString) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(attributedString: super.parse(markdown))
        let fullRange = NSRange(location: 0, length: attributedString.length)
        attributedString.enumerateAttribute(MarkdownSpoiler.hiddenAttribute, in: fullRange) { value, range, _ in
            guard value != nil else { return }
            self.hideSpoiler(in: attributedString, range: range)
        }
        return attributedString
    }

    func hideSpoiler(in attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.addAttributes(allSpoiler.attributes, range: range)
        attributedString.removeAttribute(.link, range: range)
        attributedString.removeAttribute(.underlineStyle, range: range)
        attributedString.removeAttribute(.backgroundColor, range: range)
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
