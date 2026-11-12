//
//  MediaPosterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

/// The poster on its blurred backdrop. A poster that fits the card's width fills the card. On a wider card it keeps the
/// card's maximum height, inset by the same margin on every side, and the backdrop shows around it.
final class MediaPosterTableViewCell: TintedCanvasTableViewCell {
    private enum Layout {
        static let margin: CGFloat = 16
        static let maximumCardHeight: CGFloat = 620
    }

    let backdropView = MediaBackdropView()
    let posterView = MediaPosterView()

    private let insideCardView = InsideCardView()

    private lazy var posterTopConstraint = posterView.topAnchor.constraint(equalTo: insideCardView.topAnchor)
    private lazy var posterBottomConstraint = posterView.bottomAnchor.constraint(equalTo: insideCardView.bottomAnchor)
    private lazy var posterLeadingConstraint = posterView.leadingAnchor.constraint(greaterThanOrEqualTo: insideCardView.leadingAnchor)
    private lazy var preferredPosterHeightConstraint = posterView.heightAnchor
        .constraint(equalToConstant: Layout.maximumCardHeight)
        .withPriority(UILayoutPriority(999))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                          withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                          verticalFittingPriority: UILayoutPriority) -> CGSize {
        updatePosterMargin(forContentWidth: targetSize.width - safeAreaInsets.left - safeAreaInsets.right)
        return super.systemLayoutSizeFitting(targetSize,
                                             withHorizontalFittingPriority: horizontalFittingPriority,
                                             verticalFittingPriority: verticalFittingPriority)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if updatePosterMargin(forContentWidth: contentView.bounds.width) {
            // The card's height follows the margin, so the table measures the row again.
            invalidateIntrinsicContentSize()
            super.layoutSubviews()
        }
    }

    @discardableResult
    private func updatePosterMargin(forContentWidth contentWidth: CGFloat) -> Bool {
        guard contentWidth > 0 else { return false }
        let cardInsets = UITableViewCell.mediaCardInsets
        let cardWidth = contentWidth - cardInsets.leading - cardInsets.trailing
        let margin = cardWidth * 1.5 > Layout.maximumCardHeight ? Layout.margin : 0
        guard posterTopConstraint.constant != margin else { return false }
        posterTopConstraint.constant = margin
        posterBottomConstraint.constant = -margin
        posterLeadingConstraint.constant = margin
        preferredPosterHeightConstraint.constant = Layout.maximumCardHeight - margin * 2
        return true
    }

    private func setup() {
        selectionStyle = .none
        addMediaCard(around: insideCardView)

        backdropView.style = .blurred
        for view in [backdropView, posterView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            insideCardView.addSubview(view)
        }
        // On a narrow card the poster's width wins over its preferred height.
        NSLayoutConstraint.activate(backdropView.edgeConstraints(to: insideCardView) + [
            posterTopConstraint,
            posterBottomConstraint,
            posterView.centerXAnchor.constraint(equalTo: insideCardView.centerXAnchor),
            posterLeadingConstraint,
            posterView.widthAnchor.constraint(equalTo: posterView.heightAnchor, multiplier: 2.0 / 3.0),
            preferredPosterHeightConstraint
        ])
    }
}

extension MediaPosterTableViewCell: MediaDragSource {
    var dragMedia: MediaModel? {
        return posterView.media
    }

    var dragPreviewView: UIView? {
        return posterView.posterImageView
    }
}
