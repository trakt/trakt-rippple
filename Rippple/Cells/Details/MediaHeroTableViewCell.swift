//
//  MediaHeroTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

/// The media header when there is room for it: the backdrop fills the card, the poster sits on one side, and the title card sits
/// in the bottom corner of the other.
final class MediaHeroTableViewCell: TintedCanvasTableViewCell {
    private enum Layout {
        static let margin: CGFloat = 16
        static let titleCardMaximumWidth: CGFloat = 390
        static let titleCardMinimumWidth: CGFloat = 340
        static let hingeClearance: CGFloat = 36
        static let posterMinimumWidth: CGFloat = 200
        #if targetEnvironment(macCatalyst)
        static let posterMaximumWidth: CGFloat = 300
        #else
        static let posterMaximumWidth: CGFloat = 280
        #endif
    }

    /// The room inside the card, between its margins, for a cell content view this wide.
    private static func innerWidth(forContentWidth contentWidth: CGFloat) -> CGFloat {
        let cardInsets = UITableViewCell.mediaCardInsets
        return contentWidth - cardInsets.leading - cardInsets.trailing - Layout.margin * 2
    }

    /// The poster shrinks first, down to its minimum, so the title card keeps its full width for as long as it can.
    private static func posterWidth(forContentWidth contentWidth: CGFloat) -> CGFloat {
        let roomForPoster = innerWidth(forContentWidth: contentWidth) - Layout.margin - Layout.titleCardMaximumWidth
        return min(Layout.posterMaximumWidth, max(Layout.posterMinimumWidth, roomForPoster))
    }

    /// The card is as tall as the poster, episodes included, so every card on a screen this wide has the same height.
    private static func cardHeight(forPosterWidth posterWidth: CGFloat) -> CGFloat {
        return posterWidth * 1.5 + Layout.margin * 2
    }

    /// Whether a cell content view this wide leaves the title card enough room beside the poster. When it doesn't, the
    /// media page uses the compact rows instead. A card without a poster counts it too, so an episode switches at the
    /// same width as a show and its title card never covers most of the still.
    static func fitsTitleCard(inContentWidth contentWidth: CGFloat) -> Bool {
        let posterSpace = posterWidth(forContentWidth: contentWidth) + Layout.margin
        return innerWidth(forContentWidth: contentWidth) - posterSpace >= Layout.titleCardMinimumWidth
    }

    let backdropView = MediaBackdropView()
    let posterView = MediaPosterView()
    let titleCardView = MediaTitleCardView.loadFromNib()

    private let insideCardView = InsideCardView()

    private(set) var media: MediaModel?
    private var showsPoster = true
    private weak var scrollingTableView: UITableView?

    private var isHalfFolded = false {
        didSet {
            guard isHalfFolded != oldValue else { return }
            animateLayoutChange()
            // A narrower title card can be taller, so the table measures the row again.
            scrollingTableView?.performBatchUpdates(nil)
        }
    }

    private lazy var posterWidthConstraint = posterView.widthAnchor.constraint(equalToConstant: Layout.posterMaximumWidth)
    private lazy var cardMinimumHeightConstraint = insideCardView.heightAnchor
        .constraint(greaterThanOrEqualToConstant: MediaHeroTableViewCell.cardHeight(forPosterWidth: Layout.posterMaximumWidth))
    private lazy var preferredCardHeightConstraint = insideCardView.heightAnchor
        .constraint(equalToConstant: MediaHeroTableViewCell.cardHeight(forPosterWidth: Layout.posterMaximumWidth))
        .withPriority(.defaultLow)
    /// Keeping the title card clear of the poster and the hinge can't always hold while a cell is still at its default
    /// width, so those limits give way rather than break.
    private lazy var titleCardAfterPosterConstraint = titleCardView.leadingAnchor
        .constraint(greaterThanOrEqualTo: posterView.trailingAnchor, constant: Layout.margin)
        .withPriority(UILayoutPriority(999))
    private lazy var titleCardAfterHingeConstraint = titleCardView.leadingAnchor
        .constraint(greaterThanOrEqualTo: insideCardView.leadingAnchor)
        .withPriority(UILayoutPriority(999))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        titleCardView.prepareForReuse()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachToScrollingTableView()
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        updateSizing(forContentWidth: targetSize.width - safeAreaInsets.left - safeAreaInsets.right)
        return super.systemLayoutSizeFitting(targetSize,
                                             withHorizontalFittingPriority: horizontalFittingPriority,
                                             verticalFittingPriority: verticalFittingPriority)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let didResize = updateSizing(forContentWidth: contentView.bounds.width)
        if didResize {
            // The card's height follows the poster's, so the table measures the row again.
            invalidateIntrinsicContentSize()
        }
        if updateHingeConstraints() || didResize {
            super.layoutSubviews()
        }
    }

    /// Sizes the poster, and the card with it, for the width the card gets.
    @discardableResult
    private func updateSizing(forContentWidth contentWidth: CGFloat) -> Bool {
        guard contentWidth > 0 else { return false }
        let posterWidth = MediaHeroTableViewCell.posterWidth(forContentWidth: contentWidth)
        guard posterWidthConstraint.constant != posterWidth else { return false }
        posterWidthConstraint.constant = posterWidth
        let cardHeight = MediaHeroTableViewCell.cardHeight(forPosterWidth: posterWidth)
        cardMinimumHeightConstraint.constant = cardHeight
        preferredCardHeightConstraint.constant = cardHeight
        return true
    }

    /// Episodes and posters that failed to load show the backdrop alone, sharp.
    func configure(media: MediaModel, showsPoster: Bool) {
        self.media = media
        self.showsPoster = showsPoster

        backdropView.style = showsPoster ? .blurred : .sharp
        backdropView.configure(media: media)

        posterView.isHidden = showsPoster == false
        if showsPoster {
            posterView.media = media
        }

        titleCardView.media = media
        titleCardAfterPosterConstraint.isActive = showsPoster
    }

    // MARK: - Layout

    private func animateLayoutChange() {
        setNeedsLayout()
        guard window != nil else { return }
        let animator = UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.8) { [weak self] in
            guard let self = self else { return }
            self.layoutIfNeeded()
        }
        animator.startAnimation()
    }

    /// The fold runs across the middle of the screen's long side. While the device is half folded and that line crosses
    /// the card, the title card stays on its own half instead of bending over the hinge.
    @discardableResult
    private func updateHingeConstraints() -> Bool {
        var hingeX: CGFloat?
        if isHalfFolded, let screen = window?.windowScene?.screen, screen.bounds.width > screen.bounds.height {
            let hingePoint = CGPoint(x: screen.bounds.midX, y: screen.bounds.midY)
            let x = insideCardView.convert(hingePoint, from: screen.coordinateSpace).x
            if x > 0, x < insideCardView.bounds.width {
                hingeX = x
            }
        }

        let afterHingeConstant = (hingeX ?? 0) + Layout.hingeClearance
        let isAfterHingeActive = hingeX != nil
        guard titleCardAfterHingeConstraint.constant != afterHingeConstant ||
            titleCardAfterHingeConstraint.isActive != isAfterHingeActive else { return false }

        titleCardAfterHingeConstraint.constant = afterHingeConstant
        titleCardAfterHingeConstraint.isActive = isAfterHingeActive
        return true
    }

    private func attachToScrollingTableView() {
        var view = superview
        while let current = view, (current is UITableView) == false {
            view = current.superview
        }
        scrollingTableView = view as? UITableView
    }

    // MARK: - Setup

    private func setup() {
        selectionStyle = .none

        // The card's minimum height is required, so its bottom gives way while the row still has an old or default
        // height, instead of a constraint breaking somewhere inside the card.
        addMediaCard(around: insideCardView, bottomPriority: UILayoutPriority(999))

        titleCardView.castsShadow = true

        for view in [backdropView, posterView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            insideCardView.addSubview(view)
        }
        insideCardView.addSubview(titleCardView)

        NSLayoutConstraint.activate(backdropView.edgeConstraints(to: insideCardView) + [
            cardMinimumHeightConstraint,
            preferredCardHeightConstraint,

            posterView.topAnchor.constraint(equalTo: insideCardView.topAnchor, constant: Layout.margin),
            posterView.leadingAnchor.constraint(equalTo: insideCardView.leadingAnchor, constant: Layout.margin),
            posterView.bottomAnchor.constraint(lessThanOrEqualTo: insideCardView.bottomAnchor, constant: -Layout.margin),
            posterWidthConstraint,
            posterView.heightAnchor.constraint(equalTo: posterView.widthAnchor, multiplier: 1.5),

            titleCardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.titleCardMaximumWidth),
            titleCardView.widthAnchor.constraint(equalToConstant: Layout.titleCardMaximumWidth).withPriority(.defaultHigh),
            titleCardView.topAnchor.constraint(greaterThanOrEqualTo: insideCardView.topAnchor, constant: Layout.margin),
            titleCardView.bottomAnchor.constraint(equalTo: insideCardView.bottomAnchor, constant: -Layout.margin),
            titleCardView.leadingAnchor.constraint(greaterThanOrEqualTo: insideCardView.leadingAnchor, constant: Layout.margin),
            titleCardView.trailingAnchor.constraint(equalTo: insideCardView.trailingAnchor, constant: -Layout.margin),
            titleCardAfterPosterConstraint
        ])

        #if !targetEnvironment(macCatalyst)
        if #available(iOS 27.1, *) {
            let hingeInteraction = UIHingeInteraction { [weak self] _, update in
                guard let self = self else { return }
                self.isHalfFolded = update.hinge?.status == .partiallyOpen
            }
            contentView.addInteraction(hingeInteraction)
        }
        #endif
    }
}

extension MediaHeroTableViewCell: MediaDragSource {
    var dragMedia: MediaModel? {
        return media
    }

    var dragPreviewView: UIView? {
        return showsPoster ? posterView.posterImageView : backdropView.dragPreviewView
    }
}
