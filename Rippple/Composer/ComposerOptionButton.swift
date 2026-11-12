//
//  ComposerOptionButton.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerOptionButton: UIButton {
    struct Option: Equatable {
        var title: String
        var symbol: String
        var isTappable = true
        var isWarning = false
        var accessibilityLabel: String
        var accessibilityHint: String?
    }

    var onTap: (() -> Void)?

    var option: Option? {
        didSet {
            guard option != oldValue else { return }
            render()
        }
    }

    init() {
        super.init(frame: .zero)
        // Hidden until it has an option: `render()` only runs when the option changes, and it starts as nil.
        isHidden = true
        // The same chip on Mac Catalyst, instead of a native Mac push button.
        preferredBehavioralStyle = .pad
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .horizontal)
        isPointerInteractionEnabled = true
        maximumContentSizeCategory = .extraExtraExtraLarge
        addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            self.onTap?()
        }, for: .primaryActionTriggered)
        registerForTraitChanges([RipppleTintTrait.self, RipppleTintedAppearanceTrait.self, UITraitUserInterfaceStyle.self, UITraitPreferredContentSizeCategory.self],
                                action: #selector(setNeedsUpdateConfiguration))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConfiguration() {
        guard let option = option else { return }
        let color: UIColor = option.isWarning ? .systemRed : option.isTappable ? traitCollection.ripppleTintColor.color : .secondaryLabel
        var configuration = UIButton.Configuration.filled()
        configuration.baseForegroundColor = color
        configuration.baseBackgroundColor = color.withAlphaComponent(isHighlighted ? 0.25 : 0.15)
        configuration.cornerStyle = .fixed
        configuration.background.cornerRadius = 8
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        configuration.image = UIImage(systemName: option.symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        configuration.imagePadding = 6
        var title = AttributedString(option.title)
        title.font = UIFont.monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .footnote, compatibleWith: traitCollection).pointSize,
                                                      weight: .bold)
        configuration.attributedTitle = title
        configuration.titleLineBreakMode = .byClipping
        self.configuration = configuration
    }

    private func render() {
        isHidden = option == nil
        guard let option = option else { return }
        UIView.performWithoutAnimation {
            // Built directly: UIKit only asks a button that already has a configuration to update it.
            updateConfiguration()
            layoutIfNeeded()
        }
        isUserInteractionEnabled = option.isTappable
        accessibilityLabel = option.accessibilityLabel
        accessibilityHint = option.accessibilityHint
        accessibilityTraits = option.isTappable ? .button : .staticText
    }
}

extension NotePrivacy {
    var composerTitle: String {
        switch self {
        case .all: return "Public"
        case .friends: return "Friends"
        case .me, .unknown: return "Private"
        }
    }

    var composerSymbol: String {
        switch self {
        case .all: return "globe"
        case .friends: return "person.2"
        case .me, .unknown: return "lock"
        }
    }
}
