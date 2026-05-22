//
//  MediaCommentsCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

import Kingfisher

import Receiver

final class MediaCommentsCollectionViewCell: UICollectionViewCell {
    // Comment
    @IBOutlet weak var ratingAndSpoilerLabel: UILabel!
    @IBOutlet weak var commentLabel: UILabel!

    @IBOutlet weak var wordCountLabel: UILabel!

    @IBOutlet weak var replyCountButton: ReplyCountButton!
    @IBOutlet weak var commentReactionButton: CommentReactionButton!

    // Sentiments
    var sentiments: CommentsSentiments? {
        didSet {
            if commentModel == nil { return }
            if sentiments == nil { return }
            setupRatingAndSpoiler()
        }
    }

    // User
    @IBOutlet weak var avatarImageView: UIImageView?
    @IBOutlet weak var byLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!

    @IBOutlet weak var pinImage: UIImageView!

    // Filter
    private static let userFilter = RoundCornerImageProcessor(
        cornerRadius: 13.0,
        targetSize: CGSize(width: 26.0, height: 26.0)
    )

    private static let dateFormatter = RelativeDateTimeFormatter()

    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        if let avatarImageView = avatarImageView {
            avatarImageView.layer.cornerRadius = avatarImageView.bounds.height/2.0
            avatarImageView.layer.borderWidth = 1
            avatarImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
            avatarImageView.clipsToBounds = true
        }

        MediaCommentsCollectionViewCell.dateFormatter.unitsStyle = .abbreviated
        MediaCommentsCollectionViewCell.dateFormatter.dateTimeStyle = .numeric
        MediaCommentsCollectionViewCell.dateFormatter.formattingContext = .listItem

        commentModelRefreshedReceiver.listen { [weak self] commentModel in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if commentModel == self.commentModel {
                    self.commentModel = commentModel
                }
            }
        }.disposed(by: disposeBag)

        RatingsManager.shared.onRatedItemsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.setupRatingAndSpoiler()
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .large
    }

    var commentModel: CommentModel! {
        didSet {
            setupRatingAndSpoiler()
            setupComment()
            setupUser()
        }
    }

    private func setupComment() {
        if commentModel.comment.parentIdentifier != 0 { return } // not a reply

        let comment = commentModel.comment

        commentLabel.attributedText = commentModel.commentAttributedString

        if comment.isReview, let commentWordCount = commentModel.commentWordCount {
            wordCountLabel.text = "\(commentWordCount) \(commentWordCount <= 1 ? "word" : "words")"
        } else {
            wordCountLabel.text = ""
        }

        replyCountButton.comment = comment
        commentReactionButton.comment = comment
    }

    private func setupRatingAndSpoiler() {
        let comment = commentModel.comment
        var texts = [String]()

        defer {
            ratingAndSpoilerLabel.text = texts.joined(separator: " · ")
            ratingAndSpoilerLabel.isHidden = ratingAndSpoilerLabel.text == ""
        }

        if commentModel.comment.isFiltered {
            texts.append("Blocked User")
            return
        }

        if commentModel.isOwnComment, let userRating = commentModel.media.userRating {
            texts.append("\(userRating)/10")
        } else if let rating = comment.userRating {
            texts.append("\(rating)/10")
        }

        if comment.containsSpoiler {
            texts.append("Spoiler Alert!")
        }

        if let sentiments = sentiments {
            var isGood = false
            var isBad = false
            for good in sentiments.good where good.commentIds.contains(where: { $0 == comment.identifier }) {
                isGood = true
            }
            for bad in sentiments.bad where bad.commentIds.contains(where: { $0 == comment.identifier }) {
                isBad = true
            }
            if isGood && isBad {
                texts.append("● Neutral")
            } else if isGood {
                texts.append("▲ Positive")
            } else if isBad {
                texts.append("▼ Negative")
            }
        }
    }

    private func setupUser() {
        let user = commentModel.comment.user

        if let avatarImageView = avatarImageView {
            if let images = user.images {
                avatarImageView.kf.setImage(with: images.avatar.full,
                                            placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                            options: [.scaleFactor(traitCollection.displayScale),
                                                      .processor(MediaCommentsCollectionViewCell.userFilter)])
            } else {
                avatarImageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_tiny")
            }
        }

        byLabel.attributedText = commentModel.userAttributedString

        timeLabel.text = MediaCommentsCollectionViewCell.dateFormatter.localizedString(for: commentModel.comment.createDate, relativeTo: Date())
    }
}
