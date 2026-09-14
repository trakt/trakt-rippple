//
//  SocialActivityUserTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import UIKit

final class SocialActivityUserTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var card: CardView!

    @IBOutlet var topConstraint: NSLayoutConstraint!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var nameLabel: UILabel!
    @IBOutlet var activityLabel: UILabel!
    @IBOutlet var ratingLabel: UILabel!

    private let avatarSize: CGFloat = 52.0
    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric
        formatter.formattingContext = .listItem
        return formatter
    }()

    private lazy var avatarFilter = RoundCornerImageProcessor(
        cornerRadius: avatarSize / 2.0,
        targetSize: CGSize(width: avatarSize, height: avatarSize)
    )

    var cardType: CardType = .alone {
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

    var summary: SocialActivityUserSummary? {
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

        avatarImageView.layer.cornerRadius = avatarSize / 2.0
        avatarImageView.layer.borderWidth = 1
        avatarImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = .ripppleTertiaryBackground.withAlphaComponent(1.0)

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.numberOfLines = 2
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        activityLabel.font = .preferredFont(forTextStyle: .footnote)
        activityLabel.textColor = .secondaryLabel
        activityLabel.adjustsFontForContentSizeCategory = true
        activityLabel.numberOfLines = 0
        activityLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        ratingLabel.font = ratingNumberFont
        ratingLabel.textColor = .label
        ratingLabel.textAlignment = .right
        ratingLabel.adjustsFontForContentSizeCategory = true
        ratingLabel.numberOfLines = 1
        ratingLabel.isHidden = true
        ratingLabel.setContentHuggingPriority(.required, for: .horizontal)
        ratingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        avatarImageView.kf.cancelDownloadTask()
        avatarImageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_big")
        nameLabel.text = nil
        activityLabel.text = nil
        ratingLabel.attributedText = nil
        ratingLabel.isHidden = true
        summary = nil
    }

    private func render() {
        guard let summary else { return }

        let user = summary.user
        nameLabel.text = user.name
        activityLabel.text = summary.activityDetails
            .map { $0.text(using: relativeDateTimeFormatter) }
            .joined(separator: "\n")
        activityLabel.isHidden = summary.activityDetails.isEmpty
        if let rating = summary.rating {
            ratingLabel.attributedText = ratingAttributedText(for: rating)
            ratingLabel.isHidden = false
        } else {
            ratingLabel.attributedText = nil
            ratingLabel.isHidden = true
        }
        avatarImageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_big")

        if let imageURL = user.images?.avatar.full {
            avatarImageView.kf.setImage(with: imageURL,
                                        placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_big"),
                                        options: [.scaleFactor(traitCollection.displayScale), .processor(avatarFilter)])
        } else if user.isCurrentUser, let imageURL = UserManager.shared.currentUser?.images?.avatar.full {
            avatarImageView.kf.setImage(with: imageURL,
                                        placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_big"),
                                        options: [.scaleFactor(traitCollection.displayScale), .processor(avatarFilter)])
        }
    }

    private func ratingAttributedText(for rating: Int) -> NSAttributedString {
        let ratingText = "\(rating)"
        let suffix = "/10"
        let text = ratingText + suffix
        let attributedText = NSMutableAttributedString(string: text, attributes: [
            .font: ratingNumberFont,
            .foregroundColor: UIColor.label
        ])
        attributedText.addAttributes([
            .font: ratingSuffixFont,
            .foregroundColor: UIColor.secondaryLabel
        ], range: NSRange(location: ratingText.count, length: suffix.count))
        return attributedText
    }

    private var ratingNumberFont: UIFont {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .title3).pointSize,
                                     weight: .semibold)
        return UIFontMetrics(forTextStyle: .title3).scaledFont(for: font)
    }

    private var ratingSuffixFont: UIFont {
        let font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .subheadline).pointSize,
                                     weight: .semibold)
        return UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: font)
    }
}
