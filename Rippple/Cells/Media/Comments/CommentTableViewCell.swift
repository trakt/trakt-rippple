//
//  CommentTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import Kingfisher

import Receiver

protocol CommentTableViewCellDelegate: AnyObject {
    func cell(_ cell: CommentTableViewCell, action: CommentTableViewCell.Action)
}

final class CommentTableViewCell: UITableViewCell {

    enum Action {
        case presentReplies
        case presentAuthor
        case presentLikes
        case presentMediaDetails
        case share
        case edit
        case reply
        case presentParentComment
    }

    weak var delegate: CommentTableViewCellDelegate? {
        didSet {
            contextMenu.controller = delegate as? UIViewController
        }
    }

    // Media
    @IBOutlet var mediaViews: [UIView]!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var commentCountLabel: CommentCountLabel!
    @IBOutlet weak var poster: PosterButton?

    // Comment
    @IBOutlet weak var ratingAndSpoilerLabel: UILabel!
    @IBOutlet weak var commentLabel: LinkEnabledLabel!
    @IBOutlet weak var replyCountButton: ReplyCountButton!
    @IBOutlet weak var commentReactionButton: CommentReactionButton!
    @IBOutlet weak var wordCountLabel: UILabel!

    @IBOutlet weak var replyParentLabel: UILabel?
    @IBOutlet weak var replyParentLink: UIButton?

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
    @IBOutlet weak var replyMicImageView: UIImageView?
    @IBOutlet weak var timeLabel: UILabel!

    // Actions
    @IBOutlet var actionViews: [UIView]!
    @IBOutlet weak var likeButton: ReactButton?
    @IBOutlet weak var replyButton: UIButton?
    @IBOutlet weak var editButton: UIButton!
    @IBOutlet weak var shareButton: UIButton!
    @IBOutlet weak var presentRepliesButton: UIButton!

    // Reply chat background image
    @IBOutlet weak var chatBubbleBackgroundImage: UIImageView?

    // Pin image
    @IBOutlet weak var pinImage: UIImageView?

    // Filter
    private static let userFilter = RoundCornerImageProcessor(
        cornerRadius: 13.0,
        targetSize: CGSize(width: 26.0, height: 26.0)
    )

    private static let dateFormatter = RelativeDateTimeFormatter()

    private let disposeBag = DisposeBag()

    private let contextMenu = MediaContextMenuInteractionDelegate()

    @IBOutlet weak var mediaMenuAction: UIButton?

    deinit {
        print("deiniting Comment Table View Cell")
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        CommentTableViewCell.dateFormatter.unitsStyle = .abbreviated
        CommentTableViewCell.dateFormatter.dateTimeStyle = .numeric
        CommentTableViewCell.dateFormatter.formattingContext = .listItem
        CommentTableViewCell.dateFormatter.locale = Locale(identifier: "en_US")

        if let poster = poster {
            poster.layer.cornerRadius = ViewRadius.medium.rawValue
            poster.layer.cornerCurve = .continuous
            poster.layer.masksToBounds = true
            poster.layer.borderWidth = 1
            poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

            poster.backgroundColor = UIColor.tertiarySystemFill
        }

        if let avatarImageView = avatarImageView {
            avatarImageView.layer.cornerRadius = avatarImageView.bounds.height/2.0
            avatarImageView.layer.borderWidth = 1
            avatarImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
            avatarImageView.clipsToBounds = true
        }

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

        if let poster = poster {
            let interaction = UIContextMenuInteraction(delegate: contextMenu)
            poster.addInteraction(interaction)
        }

        sentimentEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.setupRatingAndSpoiler()
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .extraExtraExtraLarge
        likeButton?.maximumContentSizeCategory = .extraExtraExtraLarge
        replyButton?.maximumContentSizeCategory = .extraExtraExtraLarge
        editButton?.maximumContentSizeCategory = .extraExtraExtraLarge
        shareButton?.maximumContentSizeCategory = .extraExtraExtraLarge
    }

    var commentModel: CommentModel! {
        didSet {
            if commentModel.comment.parentIdentifier == 0 {
                setupMedia()
                setupRatingAndSpoiler()
                setupComment()
                setupUser()
                setupActions()
            } else {
                setupRatingAndSpoiler()
                setupReply()
                setupUser()
                setupActions()
            }
            UIView.performWithoutAnimation {
                self.invalidateIntrinsicContentSize()
            }
        }
    }

    private let menuButtonContextMenu = MediaContextMenuInteractionDelegate()

    private func setupMedia() {
        switch commentModel.media {
        case .movie(let movie):
            setupMovie(movie: movie)
            contextMenu.media = commentModel.media
        case .show(let show):
            setupShow(show: show)
            contextMenu.media = commentModel.media
        case let .episode(episode, show):
            setupEpisode(episode: episode, show: show)
            contextMenu.media = show.mediaModel
        case let .season(season, show):
            setupSeason(season: season, show: show)
            contextMenu.media = show.mediaModel
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }

        if let mediaMenuAction = mediaMenuAction {
            menuButtonContextMenu.media = commentModel.media

            mediaMenuAction.menu = menuButtonContextMenu.menu
            mediaMenuAction.showsMenuAsPrimaryAction = true

            var configuration = UIButton.Configuration.plain()
            configuration.buttonSize = .small
            configuration.image = UIImage(systemName: "ellipsis")
            mediaMenuAction.configuration = configuration
            mediaMenuAction.preferredBehavioralStyle = .pad

            mediaMenuAction.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                mediaMenuAction.menu = self.menuButtonContextMenu.menu
                UISelectionFeedbackGenerator().selectionChanged()
                mediaMenuAction.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
             }, for: .menuActionTriggered)
        }
    }

    private func setupMovie(movie: Movie) {
        titleLabel.text = "\(movie.title)"
        if let release = movie.releaseYear {
            subtitleLabel.text = "\(release)"
        } else {
            subtitleLabel.text = ""
        }

        commentCountLabel.media = .movie(movie)

        if let posterImageView = poster {
            posterImageView.movie = movie
        }
    }

    private func setupEpisode(episode: Episode, show: Show) {
        titleLabel.text = "\(show.title)"
        subtitleLabel.text = episode.localizedEpisodeNumber

        commentCountLabel.media = .episode(episode, show)

        if let posterImageView = poster {
            posterImageView.show = show
        }
    }

    private func setupSeason(season: Season, show: Show) {
        titleLabel.text = "\(show.title)"
        subtitleLabel.text = "Season \(season.number)"

        commentCountLabel.media = .season(season, show)

        if let posterImageView = poster {
            posterImageView.show = show
        }
    }

    private func setupShow(show: Show) {
        titleLabel.text = "\(show.title)"
        if let release = show.releaseYear {
            subtitleLabel.text = "\(release)"
        } else {
            subtitleLabel.text = ""
        }

        commentCountLabel.media = .show(show)

        if let posterImageView = poster {
            posterImageView.show = show
        }
    }

    private func setupComment() {
        if commentModel.comment.parentIdentifier != 0 { return } // not a reply
        if chatBubbleBackgroundImage != nil { return } // not reply UI

        let comment = commentModel.comment

        commentLabel.attributedText = commentModel.commentAttributedString

        if comment.isReview, let commentWordCount = commentModel.commentWordCount {
            wordCountLabel.text = "\(commentWordCount) \(commentWordCount <= 1 ? "word" : "words")"
        } else {
            wordCountLabel.text = ""
        }

        replyCountButton.comment = comment
        commentReactionButton.comment = comment

        commentReactionButton.addTarget(self,
                                        action: #selector(presentLikes(_:)),
                                        for: .touchUpInside)
    }

    private func setupRatingAndSpoiler() {
        let comment = commentModel.comment
        var texts = [String]()

        defer {
            ratingAndSpoilerLabel.text = texts.joined(separator: " · ")
            ratingAndSpoilerLabel.isHidden = ratingAndSpoilerLabel.text == ""
        }

        if commentModel.comment.user.isBlocked {
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

    private func setupReply() {
        if commentModel.comment.parentIdentifier == 0 { return } // not a reply

        let comment = commentModel.comment

        guard let attributedString = commentModel.commentAttributedString?.mutableCopy() as? NSMutableAttributedString else {
            print("setupReply() attributed string could not be created")
            return
        }

        commentLabel.attributedText = attributedString

        commentReactionButton.comment = comment

        if commentModel.media.movie != nil {
            replyParentLink?.setTitle(commentModel.media.movie?.title, for: .normal)
        } else {
            replyParentLink?.setTitle(commentModel.media.show?.title, for: .normal)
        }
    }

    private func setupUser() {
        let user = commentModel.comment.user

        if let avatarImageView = avatarImageView {
            if let images = user.images {
                avatarImageView.kf.setImage(with: images.avatar.full,
                                            placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                            options: [.scaleFactor(traitCollection.displayScale), .processor(CommentTableViewCell.userFilter)])
            } else {
                avatarImageView.image = #imageLiteral(resourceName: "bg_placeholder_avatar_tiny")
            }
        }

        byLabel.attributedText = commentModel.userAttributedString

        timeLabel.text = CommentTableViewCell.dateFormatter.localizedString(for: commentModel.comment.createDate, relativeTo: Date())
    }

    private func setupActions() {
        let comment = commentModel.comment

        likeButton?.comment = comment

        if comment.isFiltered || comment.user.isBlocked {
            hideActions()
            return
        } else {
            showActions()
        }

        if comment.user.isCurrentUser {
            likeButton?.isHidden = false
            replyButton?.isHidden = true // not available for replies
            editButton.isHidden = false
            shareButton?.isHidden = false // not available for replies
        } else {
            likeButton?.isHidden = false
            replyButton?.isHidden = false // not available for replies
            editButton.isHidden = comment.isReply ? false : true
            shareButton?.isHidden = false // not available for replies
        }
    }

    func hideMedia() {
        mediaViews.forEach { $0.isHidden = true }
    }

    func hideActions() {
        actionViews.forEach { $0.isHidden = true }
    }

    func showActions() {
        actionViews.forEach { $0.isHidden = false }
    }

    func hideParent() {
        replyParentLink?.isHidden = true
        replyParentLabel?.isHidden = true
    }

    func showParent() {
        replyParentLink?.isHidden = false
        replyParentLabel?.isHidden = false
    }

    @IBAction func share(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .share)
    }

    @IBAction func edit(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .edit)
    }

    @IBAction func reply(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .reply)
    }

    @IBAction func presentReplies(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentReplies)
    }

    @IBAction func presentUser(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentAuthor)
    }

    @IBAction func presentLikes(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentLikes)
    }

    @IBAction func presentMediaDetails(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentMediaDetails)
    }

    @IBAction func presentParent(_ sender: Any) {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .presentParentComment)
    }
}
