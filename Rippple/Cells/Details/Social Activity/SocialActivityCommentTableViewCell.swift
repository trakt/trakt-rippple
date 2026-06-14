//
//  SocialActivityCommentTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import UIKit

final class SocialActivityCommentTableViewCell: UITableViewCell {
    @IBOutlet var card: CardView!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var chevronImageView: UIImageView!

    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    var cardType: CardType = .bottom {
        didSet {
            card.cardType = cardType

            switch cardType {
            case .top:
                topConstraint.constant = 4
                bottomConstraint.constant = 0
            case .middle:
                topConstraint.constant = 0
                bottomConstraint.constant = 0
            case .bottom:
                topConstraint.constant = 0
                bottomConstraint.constant = 4
            case .alone:
                topConstraint.constant = 4
                bottomConstraint.constant = 4
            }
        }
    }

    var comment: SocialActivityCommentSummary? {
        didSet {
            render()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = .clear
        backgroundColor = .clear
        selectionStyle = .none
        maximumContentSizeCategory = .extraExtraExtraLarge

        titleLabel.font = .preferredFont(forTextStyle: .footnote)
        titleLabel.textColor = .secondaryLabel
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let configuration = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        chevronImageView.image = UIImage(systemName: "chevron.right", withConfiguration: configuration)
        chevronImageView.tintColor = .tertiaryLabel
        chevronImageView.contentMode = .scaleAspectFit
        chevronImageView.isAccessibilityElement = false
        chevronImageView.setContentHuggingPriority(.required, for: .horizontal)
        chevronImageView.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        titleLabel.text = nil
        comment = nil
    }

    private func render() {
        guard let comment else { return }
        titleLabel.text = comment.text()
    }
}
