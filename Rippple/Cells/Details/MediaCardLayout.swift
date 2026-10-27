//
//  MediaCardLayout.swift
//  Rippple
//
//  Created by Kevin Cador on 27/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

extension UITableViewCell {
    /// How far the media page's cards sit from the edges of their cell.
    static let mediaCardInsets = NSDirectionalEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12)

    /// Adds `insideCardView` to the content view with a `CardView` behind it, inset like the media page's other cards.
    func addMediaCard(around insideCardView: InsideCardView, bottomPriority: UILayoutPriority = .required) {
        for view in [CardView(), insideCardView] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
            let constraints = view.edgeConstraints(to: contentView, insets: UITableViewCell.mediaCardInsets)
            constraints.last?.priority = bottomPriority
            NSLayoutConstraint.activate(constraints)
        }
    }
}

extension UIView {
    /// Top, leading, trailing and bottom constraints to `view`, in that order.
    func edgeConstraints(to view: UIView, insets: NSDirectionalEdgeInsets = .zero) -> [NSLayoutConstraint] {
        return [
            topAnchor.constraint(equalTo: view.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: insets.leading),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -insets.trailing),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -insets.bottom)
        ]
    }

    /// The small shadow a poster or title card casts on the backdrop, around the card at `rect`. The path spares
    /// working the shadow out from the view's content on every frame.
    func castMediaCardShadow(around rect: CGRect) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.2
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowPath = UIBezierPath(roundedRect: rect, cornerRadius: ViewRadius.large.rawValue).cgPath
    }
}

extension NSLayoutConstraint {
    func withPriority(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}

extension UIImageView {
    /// An image view wants to be as big as its image, which would let a large backdrop stretch the card it fills.
    /// The card's constraints decide the size instead.
    func ignoresImageSize() {
        for axis: NSLayoutConstraint.Axis in [.horizontal, .vertical] {
            setContentHuggingPriority(.fittingSizeLevel, for: axis)
            setContentCompressionResistancePriority(.fittingSizeLevel, for: axis)
        }
    }
}
