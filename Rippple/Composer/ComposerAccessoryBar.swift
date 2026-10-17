//
//  ComposerAccessoryBar.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ComposerAccessoryBar: UIView {
    enum Action {
        case bold
        case italic
        case strike
        case highlight
        case spoilerTags
        case insert

        var markdown: (prefix: String, suffix: String)? {
            switch self {
            case .bold: return ("**", "**")
            case .italic: return ("_", "_")
            case .strike: return ("~~", "~~")
            case .highlight: return ("==", "==")
            case .spoilerTags: return ("[spoiler]", "[/spoiler]")
            case .insert: return nil
            }
        }
    }

    private static let buttonSize: CGFloat = 34

    var onAction: ((Action) -> Void)?

    private let container = UIVisualEffectView(effect: {
        let effect = UIGlassContainerEffect()
        effect.spacing = 8
        return effect
    }())
    private let rowStack = UIStackView()
    private let formattingPill = ComposerGlassPill(scrolls: true)
    private let insertPill = ComposerGlassPill(scrolls: false)
    private var toolButtons = [UIButton]()
    private var isPreviewing = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        let spacer = UIView()
        spacer.setContentHuggingPriority(UILayoutPriority(1), for: .horizontal)
        spacer.setContentCompressionResistancePriority(UILayoutPriority(1), for: .horizontal)

        rowStack.axis = .horizontal
        rowStack.alignment = .center
        rowStack.spacing = 8
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        rowStack.addArrangedSubview(formattingPill)
        rowStack.addArrangedSubview(spacer)
        rowStack.addArrangedSubview(insertPill)
        container.contentView.addSubview(rowStack)
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: topAnchor),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowStack.topAnchor.constraint(equalTo: container.contentView.topAnchor),
            rowStack.leadingAnchor.constraint(equalTo: container.contentView.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: container.contentView.trailingAnchor),
            rowStack.bottomAnchor.constraint(equalTo: container.contentView.bottomAnchor),
            // Exact heights: the insert bubble shrinks back to the "+" capsule, and must not stretch it.
            formattingPill.heightAnchor.constraint(equalToConstant: ComposerAccessoryBar.buttonSize + 8),
            insertPill.heightAnchor.constraint(equalToConstant: ComposerAccessoryBar.buttonSize + 8)
        ])

        // The bar keeps its compact size so it never covers the text at large Dynamic Type sizes.
        maximumContentSizeCategory = .large
        accessibilityContainerType = .semanticGroup
        accessibilityLabel = "Composer tools"

        applyTint()
        registerForTraitChanges([RipppleTintTrait.self, RipppleTintedAppearanceTrait.self, UITraitUserInterfaceStyle.self],
                                action: #selector(applyTint))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(tools: ComposerTools) {
        formattingPill.removeAllButtons()
        insertPill.removeAllButtons()
        toolButtons.removeAll()

        if tools.contains(.formatting) {
            let formatting: [(String, String, Action)] = [
                ("bold", "Bold", .bold),
                ("italic", "Italic", .italic),
                ("strikethrough", "Strikethrough", .strike),
                ("highlighter", "Highlight", .highlight),
                ("text.redaction", "Spoiler tags", .spoilerTags)
            ]
            for (symbol, label, action) in formatting {
                formattingPill.addButton(makeButton(symbol: symbol, accessibilityLabel: label, action: action))
            }
        }
        if tools.contains(.formatting) || tools.contains(.gif) {
            let insert = makeButton(symbol: "plus", accessibilityLabel: tools.contains(.gif) ? "Insert a link or a GIF" : "Insert a link", action: .insert)
            insert.accessibilityHint = "Searches people, characters, movies and shows to link. You can also type a slash."
            insertPill.addButton(insert)
        }
        formattingPill.isHidden = formattingPill.isEmpty
        insertPill.isHidden = insertPill.isEmpty
        isHidden = formattingPill.isHidden && insertPill.isHidden
        updateTools()
    }

    var insertAnchorView: UIView {
        insertPill
    }

    func setInsertBubbleShown(_ isShown: Bool) {
        formattingPill.alpha = isShown ? 0 : 1
        insertPill.alpha = isShown ? 0 : 1
        isUserInteractionEnabled = isShown == false
    }

    func update(isPreviewing: Bool) {
        self.isPreviewing = isPreviewing
        updateTools()
    }

    // MARK: - Private

    private func updateTools() {
        for button in toolButtons {
            button.isEnabled = isPreviewing == false
        }
        container.alpha = isPreviewing ? 0.4 : 1
    }

    @objc private func applyTint() {
        tintColor = traitCollection.ripppleTintColor.color
    }

    private func makeButton(symbol: String, accessibilityLabel: String, action: Action) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        configuration.background.cornerRadius = ComposerAccessoryBar.buttonSize / 2
        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onAction?(action)
        })
        button.accessibilityLabel = accessibilityLabel
        button.isPointerInteractionEnabled = true
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: ComposerAccessoryBar.buttonSize),
            button.widthAnchor.constraint(equalToConstant: ComposerAccessoryBar.buttonSize)
        ])
        toolButtons.append(button)
        return button
    }
}

private final class ComposerGlassPill: UIVisualEffectView {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    var isEmpty: Bool {
        stack.arrangedSubviews.isEmpty
    }

    init(scrolls: Bool) {
        let effect = UIGlassEffect(style: .regular)
        effect.isInteractive = true
        super.init(effect: effect)
        cornerConfiguration = .capsule()
        clipsToBounds = true

        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        if scrolls {
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.alwaysBounceHorizontal = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(stack)
            contentView.addSubview(scrollView)
            let fitsContent = scrollView.frameLayoutGuide.widthAnchor.constraint(equalTo: scrollView.contentLayoutGuide.widthAnchor)
            fitsContent.priority = .defaultHigh
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -4),
                scrollView.frameLayoutGuide.heightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.heightAnchor),
                fitsContent
            ])
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        } else {
            contentView.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
                stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
                stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4)
            ])
            setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addButton(_ button: UIButton) {
        stack.addArrangedSubview(button)
    }

    func removeAllButtons() {
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
}
