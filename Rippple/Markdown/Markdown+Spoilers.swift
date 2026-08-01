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

final class RedactableLabel: UILabel {
    @IBInspectable var isRedactedByDefault = false {
        didSet {
            resetRedaction()
        }
    }

    private enum SourceContent {
        case text(String)
        case attributedText(NSAttributedString)

        var string: String {
            switch self {
            case .text(let text):
                return text
            case .attributedText(let attributedText):
                return attributedText.string
            }
        }
    }

    private var sourceContent: SourceContent?
    private var redactedRange: NSRange?
    private var tapGestureRecognizer: UITapGestureRecognizer?
    private var isUpdatingText = false
    private var isRedacted = false

    override var text: String? {
        get {
            return sourceContent?.string
        }
        set {
            guard isUpdatingText == false else {
                super.text = newValue
                return
            }

            sourceContent = newValue.map(SourceContent.text)
            redactedRange = nil
            resetRedaction()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    override func accessibilityActivate() -> Bool {
        guard canToggleRedaction else {
            return super.accessibilityActivate()
        }

        toggleRedaction()
        return true
    }

    func setAttributedText(_ attributedText: NSAttributedString?, redacting range: NSRange? = nil) {
        sourceContent = attributedText.map {
            SourceContent.attributedText(NSAttributedString(attributedString: $0))
        }
        redactedRange = range
        resetRedaction()
    }

    func setText(_ text: String?, redacting range: NSRange? = nil) {
        sourceContent = text.map(SourceContent.text)
        redactedRange = range
        resetRedaction()
    }

    private var canToggleRedaction: Bool {
        return isRedactedByDefault && effectiveRedactedRange.length > 0
    }

    private func setup() {
        sourceContent = super.text.map(SourceContent.text)

        let tapGestureRecognizer = UITapGestureRecognizer(target: self,
                                                          action: #selector(handleRedactionTap(_:)))
        tapGestureRecognizer.delegate = self
        addGestureRecognizer(tapGestureRecognizer)
        self.tapGestureRecognizer = tapGestureRecognizer

        resetRedaction()
    }

    private func resetRedaction() {
        isRedacted = isRedactedByDefault && effectiveRedactedRange.length > 0
        updateText()
    }

    private func updateText() {
        isUpdatingText = true
        super.attributedText = nil

        if let sourceContent = sourceContent {
            if isRedacted {
                super.attributedText = redactedText(for: sourceContent)
            } else {
                restore(sourceContent)
            }
        } else {
            super.text = nil
        }
        isUpdatingText = false

        tapGestureRecognizer?.isEnabled = canToggleRedaction
        if canToggleRedaction {
            isUserInteractionEnabled = true
        }

        if isRedacted {
            isAccessibilityElement = true
            accessibilityLabel = redactedAccessibilityLabel
            accessibilityHint = "Double-tap to reveal"
            accessibilityTraits = .button
        } else {
            accessibilityLabel = nil
            accessibilityHint = canToggleRedaction ? "Double-tap to hide" : nil
            accessibilityTraits = canToggleRedaction ? .button : .staticText
        }
    }

    private func restore(_ sourceContent: SourceContent) {
        switch sourceContent {
        case .text(let text):
            // Clearing attributedText first guarantees that no redaction attributes survive.
            if redactedRange == nil {
                super.text = text
            } else {
                super.attributedText = attributedText(for: sourceContent)
            }
        case .attributedText(let attributedText):
            super.attributedText = attributedText
        }
    }

    private func redactedText(for sourceContent: SourceContent) -> NSAttributedString {
        let sourceAttributedText = attributedText(for: sourceContent)
        let redactedText = NSMutableAttributedString(attributedString: sourceAttributedText)
        sourceAttributedText.enumerateAttribute(.foregroundColor,
                                                in: effectiveRedactedRange) { _, range, _ in
            redactedText.addAttributes(
                [
                    .foregroundColor: UIColor.clear,
                    .strikethroughStyle: 7,
                    .strikethroughColor: UIColor.tertiaryLabel
                ],
                range: range
            )
        }
        return redactedText
    }

    private func attributedText(for sourceContent: SourceContent) -> NSAttributedString {
        let sourceAttributedText: NSAttributedString
        switch sourceContent {
        case .text(let text):
            sourceAttributedText = NSAttributedString(
                string: text,
                attributes: [
                    .font: font as Any,
                    .foregroundColor: textColor as Any
                ]
            )
        case .attributedText(let attributedText):
            sourceAttributedText = attributedText
        }
        return sourceAttributedText
    }

    private var redactedAccessibilityLabel: String {
        guard let sourceContent = sourceContent,
              redactedRange != nil else { return "Text hidden" }

        let accessibilityText = NSMutableString(string: sourceContent.string)
        accessibilityText.replaceCharacters(in: effectiveRedactedRange, with: "Text hidden")
        return accessibilityText as String
    }

    private var effectiveRedactedRange: NSRange {
        guard let sourceContent = sourceContent else {
            return NSRange(location: 0, length: 0)
        }

        let fullRange = NSRange(location: 0, length: (sourceContent.string as NSString).length)
        guard let redactedRange = redactedRange else { return fullRange }
        return NSIntersectionRange(fullRange, redactedRange)
    }

    @objc private func handleRedactionTap(_ tapGestureRecognizer: UITapGestureRecognizer) {
        guard redactedTextContains(tapGestureRecognizer.location(in: self)) else { return }

        toggleRedaction()
    }

    private func redactedTextContains(_ point: CGPoint) -> Bool {
        guard let attributedText = super.attributedText,
              attributedText.length > 0 else { return false }

        let textRect = textRect(forBounds: bounds,
                                limitedToNumberOfLines: numberOfLines)
        guard textRect.width > 0, textRect.height > 0 else { return false }

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: textRect.size)
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        layoutManager.addTextContainer(textContainer)

        let textStorage = NSTextStorage(attributedString: attributedText)
        textStorage.addLayoutManager(layoutManager)

        let redactedGlyphRange = layoutManager.glyphRange(
            forCharacterRange: effectiveRedactedRange,
            actualCharacterRange: nil
        )
        let visibleGlyphRange = layoutManager.glyphRange(for: textContainer)
        let tappableGlyphRange = NSIntersectionRange(redactedGlyphRange,
                                                     visibleGlyphRange)
        guard tappableGlyphRange.length > 0 else { return false }

        let textPoint = CGPoint(x: point.x - textRect.minX,
                                y: point.y - textRect.minY)
        var containsPoint = false
        layoutManager.enumerateEnclosingRects(
            forGlyphRange: tappableGlyphRange,
            withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
            in: textContainer
        ) { rect, _ in
            if rect.contains(textPoint) {
                containsPoint = true
            }
        }
        return containsPoint
    }

    private func toggleRedaction() {
        guard canToggleRedaction else { return }

        isRedacted.toggle()
        updateText()
        UIAccessibility.post(notification: .layoutChanged, argument: self)
    }
}

extension RedactableLabel: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        var touchedView = touch.view
        while let currentView = touchedView, currentView !== self {
            if currentView is UIControl {
                return false
            }
            touchedView = currentView.superview
        }
        return redactedTextContains(touch.location(in: self))
    }
}
