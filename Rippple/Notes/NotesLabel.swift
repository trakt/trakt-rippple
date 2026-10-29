//
//  NotesLabel.swift
//  Rippple
//
//  Created by Kevin Cador on 08/10/2023.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class NotesLabel: LinkEnabledLabel {
    var noteItem: NoteItem? {
        didSet {
            attributedText = attributedString()
        }
    }

    private var markdownParser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                                       automaticLinkDetectionEnabled: true)

    private func attributedString() -> NSAttributedString? {
        guard let noteItem = noteItem else { return nil }

        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label
        markdownParser.highlight.font = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge)))
        markdownParser.link.color = UIColor(asset: .globalTint)
        markdownParser.automaticLink.color = UIColor(asset: .globalTint)

        markdownParser.spoilerStrategy = .showAllSpoilers

        return markdownParser.parse(noteItem.note.notes.htmlDecoded.emojiUnescapedString)
    }
}

final class ActivityLabel: LinkEnabledLabel {
    private func commonInit() {
        isUserInteractionEnabled = true
        tintColor = UIColor(asset: .globalTint)
    }

    var activityText: String? {
        didSet {
            attributedText = attributedString()
        }
    }

    private var markdownParser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                                       automaticLinkDetectionEnabled: true)

    private func attributedString() -> NSAttributedString? {
        guard let activityText = activityText else { return nil }

        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label
        markdownParser.highlight.font = UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge)))
        markdownParser.link.color = UIColor(asset: .globalTint)
        markdownParser.automaticLink.color = UIColor(asset: .globalTint)

        markdownParser.spoilerStrategy = .showAllSpoilers

        return markdownParser.parse(activityText.htmlDecoded.emojiUnescapedString)
    }
}

class LinkEnabledLabel: UILabel {
    private static let tappableURLAttribute = NSAttributedString.Key("LinkEnabledLabel.tappableURL")

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isUserInteractionEnabled = true
        tintColor = UIColor(asset: .globalTint)
    }

    /// UILabel draws `.link` ranges in the system link color and ignores their foreground color.
    override var attributedText: NSAttributedString? {
        get { super.attributedText }
        set { super.attributedText = newValue.map(LinkEnabledLabel.replacingLinks) }
    }

    var didTapOnURL: (URL) -> Void = { url in
        let urlString = url.absoluteString
        let urlHasHttpPrefix = urlString.hasPrefix("http://")
        let urlHasHttpsPrefix = urlString.hasPrefix("https://")
        let validURL = (urlHasHttpPrefix || urlHasHttpsPrefix) ? url : URL(string: "https://\(urlString)")!

        if DeeplinkManager.shared.openInApp(validURL) {
            return
        }

        if UIApplication.shared.canOpenURL(validURL) {
            UIApplication.shared.open(validURL, options: [:], completionHandler: { success in
                if success {
                    print("Opened URL \(url) successfully")
                } else {
                    print("Failed to open URL \(url)")
                }
            })
        } else {
            print("Can't open the URL: \(url)")
        }
    }

    /// Keeps the enclosing cell from highlighting when the touch starts on a link.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard url(at: touches) == nil else { return }
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let url = url(at: touches) {
            didTapOnURL(url)
        } else {
            super.touchesEnded(touches, with: event)
        }
    }

    func addTappableURL(_ url: URL, to attributedString: NSMutableAttributedString, range: NSRange) {
        attributedString.addAttribute(LinkEnabledLabel.tappableURLAttribute, value: url, range: range)
    }

    func containsURL(at point: CGPoint) -> Bool {
        return url(at: point) != nil
    }

    private func url(at touches: Set<UITouch>) -> URL? {
        guard let touch = touches.sorted(by: { $0.timestamp < $1.timestamp }).last else { return nil }
        return url(at: touch.location(in: self))
    }

    private func url(at touchLocation: CGPoint) -> URL? {
        guard let attributedText = attributedText, attributedText.length > 0 else { return nil }
        guard let textStorage = preparedTextStorage() else { return nil }
        let layoutManager = textStorage.layoutManagers[0]
        let textContainer = layoutManager.textContainers[0]

        let characterIndex = layoutManager.characterIndex(for: touchLocation, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard characterIndex >= 0, characterIndex != NSNotFound else { return nil }

        // Glyph index is the closest to the touch, therefore also validate if we actually tapped on the glyph rect
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
        let characterRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        guard characterRect.contains(touchLocation) else { return nil }

        return textStorage.attribute(LinkEnabledLabel.tappableURLAttribute,
                                     at: characterIndex,
                                     effectiveRange: nil) as? URL
    }

    private static func replacingLinks(in attributedString: NSAttributedString) -> NSAttributedString {
        var links: [(url: URL?, range: NSRange)] = []
        attributedString.enumerateAttribute(.link,
                                            in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
            guard let value = value else { return }
            links.append(((value as? URL) ?? (value as? String).flatMap { URL(string: $0) }, range))
        }
        guard !links.isEmpty else { return attributedString }

        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        for link in links {
            mutableString.removeAttribute(.link, range: link.range)
            if let url = link.url {
                mutableString.addAttribute(LinkEnabledLabel.tappableURLAttribute, value: url, range: link.range)
            }
        }
        return mutableString
    }

    private func preparedTextStorage() -> NSTextStorage? {
        guard let attributedText = attributedText, attributedText.length > 0 else { return nil }

        // Creates and configures a text storage which matches with the UILabel's configuration.
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        textContainer.lineFragmentPadding = 0
        let textStorage = NSTextStorage(string: "")
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        textContainer.lineBreakMode = lineBreakMode
        textContainer.size = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines).size
        textStorage.setAttributedString(attributedText)

        return textStorage
    }
}
