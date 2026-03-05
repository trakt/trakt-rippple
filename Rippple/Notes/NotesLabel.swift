//
//  NotesLabel.swift
//  Rippple
//
//  Created by Kevin Cador on 08/10/2023.
//  Copyright © 2023 Trakt. All rights reserved.
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

    var didTapOnURL: (URL) -> Void = { url in
        let urlString = url.absoluteString
        let urlHasHttpPrefix = urlString.hasPrefix("http://")
        let urlHasHttpsPrefix = urlString.hasPrefix("https://")
        let validURL = (urlHasHttpPrefix || urlHasHttpsPrefix) ? url : URL(string: "https://\(urlString)")!

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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let url = self.url(at: touches) {
            didTapOnURL(url)
        } else {
            super.touchesEnded(touches, with: event)
        }
    }

    private func url(at touches: Set<UITouch>) -> URL? {
        guard let attributedText = attributedText, attributedText.length > 0 else { return nil }
        guard let touchLocation = touches.sorted(by: { $0.timestamp < $1.timestamp }).last?.location(in: self) else { return nil }
        guard let textStorage = preparedTextStorage() else { return nil }
        let layoutManager = textStorage.layoutManagers[0]
        let textContainer = layoutManager.textContainers[0]

        let characterIndex = layoutManager.characterIndex(for: touchLocation, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        guard characterIndex >= 0, characterIndex != NSNotFound else { return nil }

        // Glyph index is the closest to the touch, therefore also validate if we actually tapped on the glyph rect
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: characterIndex, length: 1), actualCharacterRange: nil)
        let characterRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        guard characterRect.contains(touchLocation) else { return nil }

        // Link styled by Apple
        return textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL
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
