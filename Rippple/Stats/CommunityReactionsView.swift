//
//  CommunityReactionsView.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

/// The three most sent community reactions of a media, as bare emojis, with a smiley placeholder while loading and
/// when nobody reacted yet. A tappable control: the owner handles `.touchUpInside`.
///
/// Its size only depends on the font and the number of emojis, and states only animate opacity and transforms,
/// so the views around it never move.
final class CommunityReactionsView: UIControl {
    /// Custom symbol in the app asset catalog: a smiley with a plus badge.
    static let reactSymbolName = "custom.face.smiling.badge.plus"

    private let disposeBag = DisposeBag()
    /// Follows the view's own text size, so a container's maximum size category applies to the emojis too.
    private var font: UIFont {
        return UIFont.preferredFont(forTextStyle: .title3, compatibleWith: traitCollection)
    }

    /// One label per emoji, so each can slide on its own.
    private let emojiRow = UIStackView()
    private var emojiLabels = [UILabel]()
    private let smileyView = UIImageView(image: UIImage(named: CommunityReactionsView.reactSymbolName))

    private enum Display: Equatable {
        case idle
        case loading
        case noReactions
        case reactions([ReactionType])

        var reactions: [ReactionType] {
            if case .reactions(let reactions) = self {
                return reactions
            }
            return []
        }
    }

    private var display = Display.idle
    private var requestID = UUID()

    private var cancellable: Cancellable? {
        willSet {
            cancellable?.cancel()
        }
    }

    var media: MediaModel? {
        didSet {
            reload()
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

    deinit {
        cancellable?.cancel()
    }

    private func setup() {
        emojiRow.alignment = .center
        emojiRow.isUserInteractionEnabled = false
        emojiRow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(emojiRow)

        smileyView.tintColor = UIColor(asset: .globalTint)
        smileyView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        smileyView.isUserInteractionEnabled = false
        smileyView.alpha = 0
        smileyView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(smileyView)

        NSLayoutConstraint.activate([
            emojiRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            emojiRow.centerYAnchor.constraint(equalTo: centerYAnchor),
            smileyView.trailingAnchor.constraint(equalTo: trailingAnchor),
            smileyView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: CommunityReactionsView, _) in
            view.invalidateIntrinsicContentSize()
        }

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "Reactions"
        accessibilityHint = "Shows all reactions and lets you react"

        onMediaReactionsChangedReceiver.listen { [weak self] target in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, MediaReactionsTarget(media: self.media) == target else { return }
                self.reload()
            }
        }.disposed(by: disposeBag)

        onEmojiReactionsDisplayReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reload()
            }
        }.disposed(by: disposeBag)
    }

    /// Hidden, without any request, when reactions aren't shown for this media.
    private func reload() {
        cancellable = nil
        requestID = UUID()
        isHidden = !MediaReactionsManager.showsReactions(for: media)
        invalidateIntrinsicContentSize()
        guard !isHidden, let target = MediaReactionsTarget(media: media) else {
            apply(.idle)
            return
        }

        apply(MediaReactionsManager.shared.summary(for: target).map(display(for:)) ?? .loading)

        // A cancelled request still completes, with nothing: only the latest one may update the display.
        let requestID = requestID
        cancellable = MediaReactionsManager.shared.fetchSummary(for: target) { [weak self] summary in
            guard let self = self, self.requestID == requestID else { return }
            if let summary = summary {
                self.apply(self.display(for: summary))
            } else if self.display == .loading {
                // Settle on the smiley so the reactions sheet stays reachable.
                self.apply(.noReactions)
            }
        }
    }

    private func display(for summary: MediaReactionsSummary) -> Display {
        let reactions = summary.topReactions(using: MediaReactionsManager.shared.possibleReactions)
        return reactions.isEmpty ? .noReactions : .reactions(reactions)
    }

    private func apply(_ newDisplay: Display) {
        let previousDisplay = display
        display = newDisplay

        if emojiLabels.map({ $0.text }) != newDisplay.reactions.map({ $0.emoji }) {
            setEmojiLabels(for: newDisplay.reactions)
        }

        switch newDisplay {
        case .idle:
            accessibilityValue = nil
            stopPulsing()
            smileyView.alpha = 0
            setEmojis(visible: false)
        case .loading:
            accessibilityValue = "Loading"
            setEmojis(visible: false)
            startPulsing()
        case .noReactions:
            accessibilityValue = "No reactions yet"
            setEmojis(visible: false)
            settleSmiley(visible: true, animated: previousDisplay != .idle)
        case .reactions(let reactions):
            accessibilityValue = reactions.map { $0.displayName }.joined(separator: ", ")
            let isArriving = previousDisplay.reactions.isEmpty
            settleSmiley(visible: false, animated: isArriving)
            if isArriving {
                animateEmojisIn()
            } else {
                setEmojis(visible: true)
            }
        }
    }

    // MARK: - Layout and touches

    override var intrinsicContentSize: CGSize {
        let height = ceil(font.lineHeight)
        // Collapses when reactions are turned off, so the runtime row gets the space back.
        guard !isHidden else { return CGSize(width: 0, height: height) }
        let rowWidth = emojiRow.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        return CGSize(width: max(rowWidth, smileyView.intrinsicContentSize.width), height: height)
    }

    /// The bare emojis are small targets: accept taps slightly around them.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -8, dy: -8).contains(point)
    }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.5 : 1
        }
    }

    // MARK: - Emojis

    private func setEmojiLabels(for reactions: [ReactionType]) {
        emojiLabels.forEach { $0.removeFromSuperview() }
        emojiLabels = reactions.enumerated().map { index, reaction in
            let label = UILabel()
            label.text = reaction.emoji
            label.font = font
            label.adjustsFontForContentSizeCategory = true
            label.alpha = 0
            label.isAccessibilityElement = false
            // The most sent reaction stays on top while they overlap.
            label.layer.zPosition = CGFloat(reactions.count - index)
            emojiRow.addArrangedSubview(label)
            return label
        }
        invalidateIntrinsicContentSize()
    }

    private func setEmojis(visible: Bool) {
        for label in emojiLabels {
            label.layer.removeAllAnimations()
            label.alpha = visible ? 1 : 0
            label.transform = .identity
        }
    }

    /// Emojis start stacked on the last one, where the smiley sits, then spring into place while fading in.
    private func animateEmojisIn() {
        // Settle the final positions first so the slide starts from a laid-out row.
        UIView.performWithoutAnimation {
            layoutIfNeeded()
        }
        let reducesMotion = UIAccessibility.isReduceMotionEnabled
        let widths = emojiLabels.map { $0.intrinsicContentSize.width }

        for (index, label) in emojiLabels.enumerated() {
            // Distance from this emoji to the last one; only transforms move, so layout never jumps.
            let distance = widths[index..<(widths.count - 1)].reduce(0, +) + 10
            label.layer.removeAllAnimations()
            label.alpha = 0
            label.transform = reducesMotion ? .identity : CGAffineTransform(translationX: distance, y: 0).scaledBy(x: 0.85, y: 0.85)

            UIView.animate(withDuration: reducesMotion ? 0.3 : 0.65,
                           delay: reducesMotion ? 0 : 0.05 * Double(emojiLabels.count - 1 - index),
                           usingSpringWithDamping: 0.82,
                           initialSpringVelocity: 0,
                           options: .allowUserInteraction) {
                label.alpha = 1
                label.transform = .identity
            }
        }
    }

    // MARK: - Smiley

    private func startPulsing() {
        smileyView.layer.removeAllAnimations()
        smileyView.transform = .identity
        smileyView.alpha = 1
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse, .curveEaseInOut, .allowUserInteraction]) {
            self.smileyView.alpha = 0.3
        }
    }

    /// Freezes the pulse where it currently is.
    private func stopPulsing() {
        let currentAlpha = smileyView.layer.presentation()?.opacity ?? Float(smileyView.alpha)
        smileyView.layer.removeAllAnimations()
        smileyView.alpha = CGFloat(currentAlpha)
    }

    /// Ends the pulse from wherever it currently is, fully visible or gone.
    private func settleSmiley(visible: Bool, animated: Bool) {
        stopPulsing()
        guard animated else {
            smileyView.alpha = visible ? 1 : 0
            return
        }
        UIView.animate(withDuration: visible ? 0.25 : 0.2, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            self.smileyView.alpha = visible ? 1 : 0
            self.smileyView.transform = visible ? .identity : CGAffineTransform(scaleX: 0.8, y: 0.8)
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.smileyView.transform = .identity
        }
    }
}
