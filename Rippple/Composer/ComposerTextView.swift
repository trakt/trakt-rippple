//
//  ComposerTextView.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerTextView: UITextView {
    var placeholder: String? {
        didSet {
            placeholderLabel.text = placeholder
        }
    }

    private let placeholderLabel = UILabel()

    override var text: String! {
        didSet {
            updatePlaceholder()
        }
    }

    init() {
        super.init(frame: .zero, textContainer: nil)
        font = .preferredFont(forTextStyle: .body)
        adjustsFontForContentSizeCategory = true
        backgroundColor = .clear
        isScrollEnabled = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        autocapitalizationType = .sentences
        textColor = .label
        tintColor = UIColor(asset: .globalTint)

        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isAccessibilityElement = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)

        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: widthAnchor),
            heightAnchor.constraint(greaterThanOrEqualTo: placeholderLabel.heightAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func textDidChange() {
        updatePlaceholder()
    }

    // MARK: - Markdown

    func wrapSelection(prefix: String, suffix: String) {
        guard let selectedRange = selectedTextRange else { return }
        let selectedText = text(in: selectedRange) ?? ""
        replace(selectedRange, withText: prefix + selectedText + suffix)
        let prefixLength = (prefix as NSString).length
        if let from = position(from: selectedRange.start, offset: prefixLength),
           let to = position(from: from, offset: (selectedText as NSString).length) {
            selectedTextRange = textRange(from: from, to: to)
        }
        notifyChange()
    }

    override func toggleBoldface(_ sender: Any?) {
        wrapSelection(prefix: "**", suffix: "**")
    }

    override func toggleItalics(_ sender: Any?) {
        wrapSelection(prefix: "_", suffix: "_")
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(toggleBoldface(_:)) || action == #selector(toggleItalics(_:)) {
            return isEditable
        }
        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: - Links

    func startsWord(at location: Int) -> Bool {
        let string = text as NSString
        guard location > 0 else { return true }
        guard location <= string.length else { return false }
        let previous = string.substring(with: NSRange(location: location - 1, length: 1))
        return previous.rangeOfCharacter(from: .whitespacesAndNewlines) != nil
    }

    func insert(_ markdown: String, at range: NSRange) {
        let length = (text as NSString).length
        let location = min(range.location, length)
        let replaced = NSRange(location: location, length: min(range.length, length - location))
        let prefix = startsWord(at: location) ? "" : " "
        guard let start = position(from: beginningOfDocument, offset: replaced.location),
              let end = position(from: start, offset: replaced.length),
              let textRange = textRange(from: start, to: end) else { return }
        replace(textRange, withText: prefix + markdown + " ")
        notifyChange()
    }

    // MARK: - Private

    private func updatePlaceholder() {
        placeholderLabel.isHidden = text.isEmpty == false
    }

    private func notifyChange() {
        delegate?.textViewDidChange?(self)
    }
}
