//
//  CommentTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import Receiver
import UIKit

#if !targetEnvironment(macCatalyst)
import SwiftUI
import Translation
#endif

protocol CommentTableViewCellDelegate: AnyObject {
    func cell(_ cell: CommentTableViewCell, action: CommentTableViewCell.Action)
    func actionsMenu(for cell: CommentTableViewCell) -> UIMenu?
}

final class CommentTableViewCell: TintedCanvasTableViewCell {
    enum Action {
        case presentReplies
        case presentAuthor
        case presentLikes
        case presentMediaDetails
        case share
        case reply
        case presentParentComment
    }

    weak var delegate: CommentTableViewCellDelegate? {
        didSet {
            contextMenu.controller = delegate as? UIViewController
            setupActionsMenu()
        }
    }

    // Media
    @IBOutlet var mediaViews: [UIView]!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var subtitleLabel: UILabel!
    @IBOutlet var commentCountLabel: CommentCountLabel!
    @IBOutlet var poster: PosterButton?

    // Comment
    @IBOutlet var ratingAndSpoilerLabel: CommentMetadataLabel!
    @IBOutlet var commentLabel: LinkEnabledLabel!
    @IBOutlet var replyCountButton: ReplyCountButton!
    @IBOutlet var commentReactionButton: CommentReactionButton!
    @IBOutlet var wordCountLabel: UILabel!

    @IBOutlet var replyParentLabel: UILabel?
    @IBOutlet var replyParentLink: UIButton?

    /// Sentiments
    var sentiments: CommentsSentiments? {
        didSet {
            if commentModel == nil { return }
            if sentiments == nil { return }
            setupRatingAndSpoiler()
        }
    }

    // User
    @IBOutlet var avatarImageView: UIImageView?
    @IBOutlet var byLabel: UILabel!
    @IBOutlet var replyMicImageView: UIImageView?
    @IBOutlet var timeLabel: UILabel!

    // Actions
    @IBOutlet var actionViews: [UIView]!
    @IBOutlet var likeButton: ReactButton?
    @IBOutlet var replyButton: UIButton?
    @IBOutlet var editButton: UIButton!
    @IBOutlet var shareButton: UIButton!
    @IBOutlet var presentRepliesButton: UIButton!

    /// Reply chat background image
    @IBOutlet var chatBubbleBackgroundImage: UIImageView?

    /// Pin image
    @IBOutlet var pinImage: UIImageView?

    /// Filter
    private static let userFilter = RoundCornerImageProcessor(
        cornerRadius: 13.0,
        targetSize: CGSize(width: 26.0, height: 26.0)
    )

    private static let dateFormatter = RelativeDateTimeFormatter()

    private let disposeBag = DisposeBag()

    private let contextMenu = MediaContextMenuInteractionDelegate()

    @IBOutlet var mediaMenuAction: UIButton?

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

        replyMicImageView?.image = UIImage(systemName: "microphone.dynamic.on.stand")
            ?? UIImage(systemName: "music.microphone")

        if let poster = poster {
            poster.layer.cornerRadius = ViewRadius.medium.rawValue
            poster.layer.cornerCurve = .continuous
            poster.layer.masksToBounds = true
            poster.layer.borderWidth = 1
            poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

            poster.backgroundColor = UIColor.tertiarySystemFill
        }

        if let avatarImageView = avatarImageView {
            avatarImageView.layer.cornerRadius = avatarImageView.bounds.height / 2.0
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
            setupActionsMenu()
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
        case .episode(let episode, let show):
            setupEpisode(episode: episode, show: show)
            contextMenu.media = show.mediaModel
        case .season(let season, let show):
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
            ratingAndSpoilerLabel.configure(texts: texts,
                                            comment: comment)
        }
        if comment.isFiltered {
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
            if isGood, isBad {
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
            editButton.setTitle("Edit", for: .normal)
            shareButton?.isHidden = false // not available for replies
        } else {
            likeButton?.isHidden = false
            replyButton?.isHidden = false // not available for replies
            editButton.isHidden = !comment.isReply
            editButton.setTitle("Report", for: .normal)
            shareButton?.isHidden = false // not available for replies
        }
    }

    private func setupActionsMenu() {
        guard let commentModel = commentModel else { return }

        let canShowActions = !commentModel.comment.isFiltered && !commentModel.comment.user.isBlocked
        let showsInlineMenu = canShowActions && (commentModel.comment.isReply || commentModel.isOwnComment)

        editButton.menu = showsInlineMenu ? delegate?.actionsMenu(for: self) : nil
        editButton.showsMenuAsPrimaryAction = editButton.menu != nil
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

// MARK: - Comment metadata

final class CommentMetadataLabel: LinkEnabledLabel {
    private static let translationURL = URL(string: "rippple://translate-comment")!

    #if !targetEnvironment(macCatalyst)
    private var translationHostingController: UIHostingController<CommentTranslationPresentationView>?
    #endif

    func configure(texts: [String], comment: Comment) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font as Any,
            .foregroundColor: textColor as Any
        ]
        let fullString = NSMutableAttributedString(string: texts.joined(separator: " · "),
                                                   attributes: attributes)

        #if !targetEnvironment(macCatalyst)
        didTapOnURL = { _ in }
        #endif

        if !comment.isFiltered, let language = comment.localizedLanguageName {
            if fullString.length > 0 {
                fullString.append(NSAttributedString(string: " · ", attributes: attributes))
            }

            #if targetEnvironment(macCatalyst)
            fullString.append(NSAttributedString(string: language, attributes: attributes))
            #else
            let translationRangeStart = fullString.length
            let symbolStyle = UIImage.SymbolConfiguration(font: font)
            let translationAttachment = NSTextAttachment()
            translationAttachment.image = UIImage(systemName: "translate")?
                .withConfiguration(symbolStyle)
                .withTintColor(textColor, renderingMode: .alwaysOriginal)
            fullString.append(NSAttributedString(attachment: translationAttachment))
            fullString.append(NSAttributedString(string: " \(language)", attributes: attributes))

            let translationRange = NSRange(location: translationRangeStart,
                                           length: fullString.length - translationRangeStart)
            addTappableURL(CommentMetadataLabel.translationURL,
                           to: fullString,
                           range: translationRange)

            let text = comment.body.htmlDecoded
            didTapOnURL = { [weak self] _ in
                self?.presentTranslation(text)
            }
            #endif
        }

        attributedText = fullString
        isHidden = fullString.length == 0
    }

    #if !targetEnvironment(macCatalyst)
    private func presentTranslation(_ text: String) {
        guard !text.isEmpty else { return }
        guard translationHostingController == nil else { return }
        guard let viewController = containingViewController else { return }

        let hostingController = UIHostingController(rootView: CommentTranslationPresentationView(text: text) { [weak self] in
            self?.removeTranslationPresenter()
        })
        translationHostingController = hostingController

        viewController.addChild(hostingController)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(hostingController.view, at: 0)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        hostingController.didMove(toParent: viewController)
    }

    private var containingViewController: UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }

    private func removeTranslationPresenter() {
        guard let hostingController = translationHostingController else { return }
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
        translationHostingController = nil
    }
    #endif
}

#if !targetEnvironment(macCatalyst)
private struct CommentTranslationPresentationView: View {
    let text: String
    let didDismiss: () -> Void

    @State private var isPresented = false

    var body: some View {
        Color.clear
            .translationPresentation(isPresented: $isPresented, text: text)
            .onAppear {
                DispatchQueue.main.async {
                    isPresented = true
                }
            }
            .onChange(of: isPresented) { wasPresented, isPresented in
                guard wasPresented, !isPresented else { return }
                DispatchQueue.main.async {
                    didDismiss()
                }
            }
    }
}
#endif
