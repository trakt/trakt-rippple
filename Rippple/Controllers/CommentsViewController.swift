//
//  CommentsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class CommentsViewController: UITableViewController {
    enum ViewControllerSegue: String {
        case user
        case replies
        case media
        case compose
        case likes
        case seasons
        case details = "media details"
    }

    var coordinator: CommentsCoordinator! {
        didSet {
            coordinator.onCommentsChangedReceiver.listen { [weak self] comments in
                guard let self = self else { return }
                self.reloadData(with: comments)
            }.disposed(by: disposeBag)

            if coordinator.type.isPreview || coordinator.type.isReplies {
                coordinator.fetchFirst()
            }

            if isViewLoaded {
                updateHeaderForCurrentListType()
            }
        }
    }

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()
    private var isListeningForFollowingChanges = false

    @IBOutlet var loadingView: UIView!
    @IBOutlet var animationViewContainer: NVActivityIndicatorView!

    @IBOutlet var emptyView: UIView!
    @IBOutlet var emptyLabel: UILabel!

    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!

    @IBOutlet var footnoteView: UIView!
    @IBOutlet var footnoteLabel: UILabel!

    @IBOutlet var placeholderHeaderView: UIView!

    @IBOutlet var followingView: UIView!

    private var sentiments: CommentsSentiments? {
        didSet {
            guard let sentiments = sentiments else { return }
            var snapshot = dataSource.snapshot()
            // if there's no head, no need to try to update it
            if snapshot.indexOfSection(.header) == nil { return }
            if snapshot.itemIdentifiers(inSection: .header).first(where: { $0 == .sentiments(sentiments) }) == nil {
                snapshot.appendItems([.sentiments(sentiments)], toSection: .header)
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    @IBOutlet var moreActionsButtonItem: UIBarButtonItem!
    @IBOutlet var sortActionButtonItem: UIBarButtonItem!

    private enum Section: Int {
        case header
        case comments
        case footer
    }

    private enum Wrapper: Hashable {
        case media(MediaModel, String)
        case ownComment(CommentItem)
        case comment(CommentModel)
        case rating(MediaModel)
        case user(User)
        case stats(User)
        case punchcard
        case followAndFriends(User)
        case link(CardType, String, String)
        case lastWatched(User)
        case sentiments(CommentsSentiments)
        case spacer(Float)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .media(let mediaModel, let identifier):
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as! MediaTableViewCell
            cell.delegate = self
            cell.dimmedIfWatched = false
            cell.media = mediaModel
            return cell
        case .ownComment(let commentItem):
            let cell = tableView.dequeueReusableCell(withIdentifier: "comment") as! CommentTableViewCell
            cell.sentiments = sentiments
            cell.commentModel = CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers)
            cell.pinImage?.isHidden = false
            switch self.coordinator.type! {
            case .feed, .user, .forYou, .trending:
                fatalError()
            case .media:
                cell.delegate = self
                cell.hideMedia()
                cell.commentLabel.numberOfLines = 5
                cell.presentRepliesButton.isHidden = false
            case .preview:
                fatalError()
            case .replies:
                fatalError()
            }

            return cell
        case .comment(let commentModel):
            if commentModel.comment.isReply {
                let parentCommentUser = self.commentModel?.comment.user
                if commentModel.isOwnComment {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "own reply") as! CommentTableViewCell
                    cell.sentiments = sentiments
                    if case .user = self.coordinator.type {
                        cell.showParent()
                    } else {
                        cell.hideParent()
                    }
                    if let parentCommentUser = parentCommentUser {
                        cell.replyMicImageView?.isHidden = commentModel.comment.user != parentCommentUser
                    } else {
                        cell.replyMicImageView?.isHidden = true
                    }
                    cell.commentModel = commentModel
                    cell.commentLabel.numberOfLines = 0
                    cell.delegate = self
                    if self.coordinator.type.isPreview {
                        cell.hideActions()
                    }
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: "reply") as! CommentTableViewCell
                    cell.sentiments = sentiments
                    if case .user = self.coordinator.type {
                        cell.showParent()
                    } else {
                        cell.hideParent()
                    }
                    cell.commentModel = commentModel
                    cell.commentLabel.numberOfLines = 0
                    if let parentCommentUser = parentCommentUser {
                        cell.replyMicImageView?.isHidden = commentModel.comment.user != parentCommentUser
                    } else {
                        cell.replyMicImageView?.isHidden = true
                    }
                    cell.delegate = self
                    return cell
                }
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "comment") as! CommentTableViewCell
                cell.sentiments = sentiments
                cell.commentModel = commentModel
                cell.pinImage?.isHidden = true
                switch self.coordinator.type! {
                case .feed, .user, .forYou, .trending:
                    cell.delegate = self
                    cell.commentLabel.numberOfLines = 5
                    cell.presentRepliesButton.isHidden = false
                case .media:
                    cell.delegate = self
                    cell.hideMedia()
                    cell.commentLabel.numberOfLines = 5
                    cell.presentRepliesButton.isHidden = false
                case .preview:
                    cell.commentLabel.numberOfLines = 0
                    cell.presentRepliesButton.isHidden = true
                    cell.hideActions()
                    cell.hideMedia()
                    cell.delegate = nil
                case .replies:
                    cell.commentLabel.numberOfLines = 0
                    cell.presentRepliesButton.isHidden = true
                    cell.delegate = self
                }

                return cell
            }
        case .rating(let mediaModel):
            let cell = tableView.dequeueReusableCell(withIdentifier: "ratings") as! RatingsTableViewCell
            cell.media = mediaModel
            cell.viewController = self
            return cell
        case .user(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell
            cell.user = user
            return cell
        case .stats(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as! UserStatsTableViewCell
            cell.user = user
            return cell
        case .punchcard:
            let cell = tableView.dequeueReusableCell(withIdentifier: ActivityPunchcardTableViewCell.reuseIdentifier) as! ActivityPunchcardTableViewCell
            cell.setup(activityCounts: SyncWatchedManager.shared.activityCountsByDay(),
                       containerWidth: tableView.bounds.width)
            return cell
        case .followAndFriends(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "follow and friends") as! FollowersAndFriendsTableViewCell
            cell.user = user
            cell.delegate = self
            return cell
        case .link(let mode, let title, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "standard list") as! StandardListTableViewCell
            cell.title.text = title
            cell.card.cardType = mode
            return cell
        case .lastWatched(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "last watched") as! LastWatchedTableViewCell
            cell.user = user
            cell.delegate = self
            return cell
        case .sentiments(let sentiments):
            let cell = tableView.dequeueReusableCell(withIdentifier: "sentiments") as! SentimentsTableViewCell
            cell.sentiments = sentiments
            return cell
        case .spacer(let space):
            let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as! SpacerTableViewCell
            cell.space = space
            return cell
        }
    }

    deinit {
        print("deinit CommentsViewController")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(coordinator != nil)

        navigationItem.style = .browser

        tableView.allowsFocus = false
        tableView.separatorStyle = .none

        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")

        tableView.register(UINib(nibName: "MediaWithoutActionsTableViewCell", bundle: nil), forCellReuseIdentifier: "media without action")

        tableView.register(UINib(nibName: "CommentTableViewCell", bundle: nil), forCellReuseIdentifier: "comment")
        tableView.register(UINib(nibName: "UserTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.register(UINib(nibName: "ReplyTableViewCell", bundle: nil), forCellReuseIdentifier: "reply")
        tableView.register(UINib(nibName: "OwnReplyTableViewCell", bundle: nil), forCellReuseIdentifier: "own reply")
        tableView.register(UINib(nibName: "RatingsTableViewCell", bundle: nil), forCellReuseIdentifier: "ratings")
        tableView.register(UINib(nibName: "UserStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.register(UINib(nibName: "ActivityPunchcardTableViewCell", bundle: nil),
                           forCellReuseIdentifier: ActivityPunchcardTableViewCell.reuseIdentifier)
        tableView.register(UINib(nibName: "FollowersAndFriendsTableViewCell", bundle: nil), forCellReuseIdentifier: "follow and friends")
        tableView.register(UINib(nibName: "StandardListTableViewCell", bundle: nil), forCellReuseIdentifier: "standard list")
        tableView.register(UINib(nibName: "LastWatchedTableViewCell", bundle: nil), forCellReuseIdentifier: "last watched")
        tableView.register(UINib(nibName: "SentimentsTableViewCell", bundle: nil), forCellReuseIdentifier: "sentiments")
        tableView.register(UINib(nibName: "SpacerTableViewCell", bundle: nil), forCellReuseIdentifier: "spacer")

        tableView.sectionHeaderTopPadding = 0.0

        tableView.dataSource = dataSource
        dataSource.defaultRowAnimation = .fade

        reloadData(with: [CommentModel]()) // load empty comment datasource to kick things out

        if coordinator.sort == .newest {
            sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
        } else {
            sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
        }

        switch coordinator.type! {
        case .user(let user):
            title = "Profile"
            navigationItem.subtitle = user.username
            if user.isCurrentUser {
                emptyLabel.text = "No comments."
            } else if user.isBlocked {
                emptyLabel.text = "You've blocked this user."
            } else {
                emptyLabel.text = "Nothing to see here, move along folks.\nThis user didn't comment a thing."
            }
            if user.isCurrentUser {
                navigationItem.rightBarButtonItems = nil
            } else {
                navigationItem.rightBarButtonItems = [moreActionsButtonItem]
                moreActionsButtonItem.primaryAction = nil
                moreActionsButtonItem.menu = moreMenu()
            }
        case .replies(let commentModel, _):
            title = "Comment and Replies"
            navigationItem.subtitle = commentModel.media.mediaTitle
            emptyLabel.text = "No replies yet.\nNew replies may appear with a delay due to caching."
            footnoteLabel.text = "New replies may appear with a delay due to caching."
            if commentModel.comment.isFiltered || commentModel.isOwnComment {
                navigationItem.rightBarButtonItems = nil
            } else {
                let reply = UIBarButtonItem(image: UIImage(systemName: "arrowshape.turn.up.left"),
                                            primaryAction: .init(handler: { _ in
                                                self.showComposer(for: self.commentReply(for: commentModel.comment),
                                                                  media: commentModel.media)
                                            }))
                reply.tintColor = UIColor(asset: .globalTint)
                reply.style = .prominent
                navigationItem.rightBarButtonItems = [reply,
                                                      .fixedSpace(),
                                                      moreActionsButtonItem]
                moreActionsButtonItem.primaryAction = nil
                moreActionsButtonItem.menu = moreMenu()
            }
            if commentModel.comment.user.isBlocked {
                emptyLabel.text = "You've blocked this user."
            }
        case .media(let media):
            navigationItem.title = "Comments"
            navigationItem.subtitle = media.mediaTitle
            switch media {
            case .movie:
                emptyLabel.text = "Nothing to see here, move along folks.\nDoes it mean this movie is meh?\nNew comments may appear with a delay due to caching."
            case .show:
                emptyLabel.text = "Nothing to see here, move along folks.\nDoes it mean this show is meh?\nNew comments may appear with a delay due to caching."
            case .episode:
                emptyLabel.text = "Nothing to see here, move along folks.\nDoes it mean this episode is meh?\nNew comments may appear with a delay due to caching."
            case .season:
                emptyLabel.text = "Nothing to see here, move along folks.\nDoes it mean this season is meh?\nNew comments may appear with a delay due to caching."
            case .list:
                emptyLabel.text = "Nothing to see here, move along folks.\nDoes it mean this list is meh?\nNew comments may appear with a delay due to caching."
            case .showProgress:
                fatalError()
            }
            Task {
                self.sentiments = await media.fetchSentiments()
            }
            footnoteLabel.text = "New comments may appear with a delay due to caching."
            let compose = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"),
                                          primaryAction: .init(handler: { _ in
                                              self.showNewCommentComposer(for: media)
                                          }))
            compose.tintColor = UIColor(asset: .globalTint)
            compose.style = .prominent
            navigationItem.rightBarButtonItems = [compose,
                                                  .fixedSpace(),
                                                  sortActionButtonItem]
            sortActionButtonItem.primaryAction = nil
            sortActionButtonItem.menu = sortMenu()
        case .forYou:
            updateHeaderForCurrentListType()
            navigationItem.rightBarButtonItems = nil
        case .feed, .trending:
            navigationItem.rightBarButtonItems = nil
        case .preview:
            navigationItem.rightBarButtonItems = nil
            title = "Preview"
        }

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        navigationItem.largeTitleDisplayMode = .never

        switch coordinator.type! {
        case .preview:
            coordinator.reset() // force a reset to simulate fetching the preview comment
        default:
            break
        }

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPunchcard()
            }
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshPunchcard()
            }
        }.disposed(by: disposeBag)

        footnoteLabel.maximumContentSizeCategory = .large
        errorLabel.maximumContentSizeCategory = .large
    }

    private func showNewCommentComposer(for media: MediaModel) {
        if UserManager.shared.currentUser == nil {
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }

        showComposer(for: nil, media: media)
    }

    private func showComposer(for comment: Comment?, media: MediaModel) {
        if UserManager.shared.currentUser == nil {
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }

        let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController
        composer.mediaModel = media
        composer.editedComment = comment
        present(composer, animated: true)
    }

    private func commentReply(for comment: Comment) -> Comment {
        if UserManager.shared.currentUser == nil {
            return comment
        }

        if comment.parentIdentifier == 0 {
            return Comment(identifier: 0,
                           body: "",
                           containsSpoiler: false,
                           isReview: false,
                           parentIdentifier: comment.identifier,
                           createDate: Date(),
                           updateDate: Date(),
                           replies: 0,
                           likes: 0,
                           userRating: nil,
                           user: UserManager.shared.currentUser!,
                           reactions: nil)
        } else {
            return Comment(identifier: 0,
                           body: comment.user.username,
                           containsSpoiler: false,
                           isReview: false,
                           parentIdentifier: comment.identifier,
                           createDate: Date(),
                           updateDate: Date(),
                           replies: 0,
                           likes: 0,
                           userRating: nil,
                           user: UserManager.shared.currentUser!,
                           reactions: nil)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let headerView = tableView.tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            var headerFrame = headerView.frame

            // comparison necessary to avoid infinite loop
            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableView.tableHeaderView = headerView
            }
        }
    }

    private func reloadData(with comments: [CommentModel]?) {
        DispatchQueue.main.async {
            self.errorLabel.text = self.coordinator.errorMessage
        }

        if let comments = comments {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([Section.header, Section.comments, Section.footer])

            switch coordinator.type! {
            case .media(let mediaModel):
                switch mediaModel {
                case .episode:
                    // media + rating
                    snapshot.appendItems([Wrapper.media(mediaModel, "media")], toSection: Section.header)
                    snapshot.appendItems([Wrapper.rating(mediaModel)], toSection: Section.header)
                case .movie:
                    // media + rating
                    snapshot.appendItems([Wrapper.media(mediaModel, "media")], toSection: Section.header)
                    snapshot.appendItems([Wrapper.rating(mediaModel)], toSection: Section.header)
                case .show:
                    // media + rating + seasons
                    snapshot.appendItems([Wrapper.media(mediaModel, "media")], toSection: Section.header)
                    snapshot.appendItems([Wrapper.rating(mediaModel)], toSection: Section.header)
                case .season:
                    // media + rating + episodes
                    snapshot.appendItems([Wrapper.media(mediaModel, "media")], toSection: Section.header)
                    snapshot.appendItems([Wrapper.rating(mediaModel)], toSection: Section.header)
                case .list:
                    // media + rating
                    snapshot.appendItems([Wrapper.media(mediaModel, "media")], toSection: Section.header)
                case .showProgress:
                    fatalError()
                }
                if let sentiments = sentiments {
                    snapshot.appendItems([Wrapper.sentiments(sentiments)], toSection: Section.header)
                }
                if let commentItem = mediaModel.ownCommentItem {
                    snapshot.appendItems([Wrapper.ownComment(commentItem)], toSection: Section.header)
                }
            case .user(let user):
                // user model
                if user.isBlocked {
                    snapshot.appendItems([Wrapper.user(user)], toSection: Section.header)
                } else if user.isPrivate, !user.isFollowing, !user.isCurrentUser {
                    snapshot.appendItems([Wrapper.user(user)], toSection: Section.header)
                } else if user.isCurrentUser {
                    snapshot.appendItems([Wrapper.user(user),
                                          Wrapper.punchcard,
                                          Wrapper.followAndFriends(user),
                                          Wrapper.lastWatched(user),
                                          Wrapper.spacer(5.001),
                                          Wrapper.link(.top, "History", "activities"),
                                          Wrapper.link(.middle, "Ratings", "rated"),
                                          Wrapper.link(.middle, "Lists", "lists"),
                                          Wrapper.link(.bottom, "Notes", "notes"),
                                          Wrapper.spacer(5.002),
                                          Wrapper.stats(user)], toSection: Section.header)
                } else {
                    snapshot.appendItems([Wrapper.user(user),
                                          Wrapper.followAndFriends(user),
                                          Wrapper.lastWatched(user),
                                          Wrapper.spacer(5.001),
                                          Wrapper.link(.top, "History", "activities"),
                                          Wrapper.link(.middle, "Ratings", "rated"),
                                          Wrapper.link(.bottom, "Lists", "lists"),
                                          Wrapper.spacer(5.002),
                                          Wrapper.stats(user)], toSection: Section.header)
                }
            case .replies(let commentModel, _):
                snapshot.appendItems([Wrapper.comment(commentModel)], toSection: Section.header)
            case .preview(let commentModel):
                if !coordinator.type.isPreviewReply {
                    // media + rating
                    snapshot.appendItems([Wrapper.media(commentModel.media, "media without action")], toSection: Section.header)
                    snapshot.appendItems([Wrapper.rating(commentModel.media)], toSection: Section.header)
                }
            case .feed, .forYou, .trending:
                // no header
                break
            }

            snapshot.appendItems(comments.map { Wrapper.comment($0) }, toSection: Section.comments)
            // snapshot.reloadSections([.header])
            snapshot.reloadSections([.footer])
            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
                self.tableView.flashScrollIndicators()
            }
        } else {
            DispatchQueue.main.async {
                self.dataSource.applySnapshotUsingReloadData(self.dataSource.snapshot())
                self.tableView.flashScrollIndicators()
            }
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier != "following" { return true }
        guard let coordinator = coordinator, let type = coordinator.type else { return false }
        switch type {
        case .forYou, .feed, .trending:
            return true
        default:
            return false
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            if let type = sender as? CommentsCoordinator.ListType {
                commentsViewController.coordinator = CommentsCoordinator(type: type)
                if case .replies = type {
                    commentsViewController.sentiments = sentiments
                }
            } else {
                fatalError()
            }
        } else if let likesViewController = segue.destination as? ReactionsViewController {
            if let comment = sender as? Comment {
                likesViewController.comment = comment
            } else {
                fatalError()
            }
        } else if let seasonsViewController = segue.destination as? SeasonsViewController {
            if let show = sender as? Show {
                seasonsViewController.show = show
            } else if let showAndSeason = sender as? (show: Show, season: Season) {
                seasonsViewController.show = showAndSeason.show
                seasonsViewController.season = showAndSeason.season
            } else {
                fatalError()
            }
        } else if let mediaViewController = segue.destination as? MediaViewController {
            if let media = sender as? MediaModel {
                mediaViewController.media = media
            } else {
                fatalError()
            }
        } else if let seasonsRatingsViewController = segue.destination as? SeasonsRatingsViewController {
            switch coordinator.type! {
            case .media(let mediaModel):
                seasonsRatingsViewController.media = mediaModel
            case .preview(let commentModel):
                seasonsRatingsViewController.media = commentModel.media
            case .feed, .replies, .user, .forYou, .trending:
                fatalError()
            }
        } else if let activityViewController = segue.destination as? ActivityViewController {
            switch coordinator.type! {
            case .user(let user):
                activityViewController.user = user
            case .feed, .preview, .replies, .forYou, .trending, .media:
                fatalError()
            }
        } else if let listsViewController = segue.destination as? CustomListsViewController {
            switch coordinator.type! {
            case .user(let user):
                listsViewController.user = user
            case .feed, .preview, .replies, .forYou, .trending, .media:
                fatalError()
            }
        } else if let followersViewController = segue.destination as? FollowersViewController {
            if case .user(let user) = coordinator.type {
                followersViewController.user = user
            }
        } else if let followersViewController = segue.destination as? FollowingViewController {
            if case .user(let user) = coordinator.type {
                followersViewController.user = user
            }
        } else if let followersViewController = segue.destination as? FriendsViewController {
            if case .user(let user) = coordinator.type {
                followersViewController.user = user
            }
        } else if let ratingsViewController = segue.destination as? RatingsViewController {
            if case .user(let user) = coordinator.type {
                ratingsViewController.user = user
            }
        }
    }

    private func updateHeaderForFollowing() {
        guard let type = coordinator?.type, type.isForYou else {
            tableView.tableHeaderView = nil
            return
        }

        if FollowManager.shared.followingCount != 0 {
            if tableView.tableHeaderView !== followingView {
                tableView.tableHeaderView = followingView
            }
        } else {
            if tableView.tableHeaderView !== placeholderHeaderView {
                tableView.tableHeaderView = placeholderHeaderView
            }
        }
    }

    private func updateHeaderForCurrentListType() {
        guard let type = coordinator?.type, type.isForYou else {
            tableView.tableHeaderView = nil
            return
        }

        startListeningForFollowingChangesIfNeeded()
        updateHeaderForFollowing()
    }

    private func startListeningForFollowingChangesIfNeeded() {
        guard !isListeningForFollowingChanges else { return }

        isListeningForFollowingChanges = true

        FollowManager.shared.onFollowingChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateHeaderForCurrentListType()
            }
        }.disposed(by: disposeBag)
    }
}

extension CommentsViewController {
    @IBAction func retryAfterError(_ sender: Any) {
        coordinator.retry()

        reloadData(with: [CommentModel]())
    }

    @objc func refresh(_ sender: Any) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }

            var snapshot = self.dataSource.snapshot()
            snapshot.reloadSections([.header])
            self.dataSource.apply(snapshot)

            self.refreshControl?.endRefreshing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                self.coordinator.reset()
            }
        }
    }

    private func refreshPunchcard() {
        var snapshot = dataSource.snapshot()
        guard snapshot.itemIdentifiers.contains(.punchcard) else { return }
        snapshot.reconfigureItems([.punchcard])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    @IBAction func unwindFromCommentComposer(segue: UIStoryboardSegue) {}

    private func moreMenu() -> UIMenu? {
        switch coordinator.type! {
        case .user(let user):
            if user.isBlocked {
                let unblock = UIAction(title: "Unblock User", attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    user.unblock()
                    self.moreActionsButtonItem.menu = self.moreMenu()
                }
                return UIMenu(title: "", children: [unblock])
            } else {
                var menuChildren = [UIMenuElement]()
                let block = UIAction(title: "Block User", attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    user.block()
                    if let navigationController = self.navigationController {
                        navigationController.popViewController(animated: true)
                    }
                    self.moreActionsButtonItem.menu = self.moreMenu()
                }
                menuChildren.append(block)

                if FollowManager.shared.isPendingFollowing(user: user) {
                    let unfollow = UIAction(title: "Cancel Follow", attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        FollowManager.shared.unfollow(user: user)
                        self.moreActionsButtonItem.menu = self.moreMenu()
                    }
                    menuChildren.append(unfollow)
                } else if FollowManager.shared.followed(user: user) {
                    let unfollow = UIAction(title: "Unfollow", attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        FollowManager.shared.follow(user: user)
                        self.moreActionsButtonItem.menu = self.moreMenu()
                    }
                    menuChildren.append(unfollow)
                } else {
                    let follow = UIAction(title: "Follow") { [weak self] _ in
                        guard let self = self else { return }
                        FollowManager.shared.follow(user: user)
                        self.moreActionsButtonItem.menu = self.moreMenu()
                    }
                    menuChildren.append(follow)
                }

                return UIMenu(title: user.username, children: menuChildren)
            }
        case .replies(let commentModel, _):
            let report = UIAction(title: "Block User", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                commentModel.comment.filter()
                if let navigationController = self.navigationController {
                    navigationController.popViewController(animated: true)
                }
                self.moreActionsButtonItem.menu = self.moreMenu()
            }
            return UIMenu(title: "", children: [report])
        default:
            break
        }

        return nil
    }

    private func sortMenu() -> UIMenu {
        let newest = UIAction(title: "Newest First", state: coordinator.sort == .newest ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.coordinator.sort = CommentsSort.newest
            self.sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            self.sortActionButtonItem.menu = self.sortMenu()
        }

        let oldest = UIAction(title: "Oldest First", state: coordinator.sort == .oldest ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.coordinator.sort = CommentsSort.oldest
            self.sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            self.sortActionButtonItem.menu = self.sortMenu()
        }

        let likes = UIAction(title: "Most Reacted First", state: coordinator.sort == .likes ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.coordinator.sort = CommentsSort.likes
            self.sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            self.sortActionButtonItem.menu = self.sortMenu()
        }

        let reply = UIAction(title: "Most Replied First", state: coordinator.sort == .replies ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.coordinator.sort = CommentsSort.replies
            self.sortActionButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            self.sortActionButtonItem.menu = self.sortMenu()
        }

        return UIMenu(title: "Sort by...", children: [newest, oldest, likes, reply])
    }
}

extension CommentsViewController {
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if section == Section.footer.rawValue {
            if coordinator.showError || coordinator.showEmpty {
                return
            }

            if coordinator.showLoading {
                coordinator.fetchNext()
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == dataSource.snapshot().indexOfSection(Section.footer) {
            return 0
        }

        if indexPath.section == dataSource.snapshot().indexOfSection(Section.header) {
            guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return 0 }
            switch wrapper {
            case .media:
                return UITableView.automaticDimension
            case .comment, .ownComment:
                return UITableView.automaticDimension
            case .rating:
                return UITableView.automaticDimension
            case .user:
                return 275
            case .stats:
                return UITableView.automaticDimension
            case .punchcard:
                return UITableView.automaticDimension
            case .followAndFriends:
                return UITableView.automaticDimension
            case .link:
                return UITableView.automaticDimension
            case .lastWatched:
                return UITableView.automaticDimension
            case .sentiments:
                return UITableView.automaticDimension
            case .spacer:
                return UITableView.automaticDimension
            }
        }
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == Section.footer.rawValue {
            if coordinator.showError {
                return errorView
            }

            if coordinator.showEmpty {
                return emptyView
            }

            if coordinator.showLoading {
                return loadingView
            }

            if coordinator.type.isMedia || coordinator.type.isReplies {
                return footnoteView
            }
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == Section.footer.rawValue {
            if coordinator.showError || coordinator.showLoading || coordinator.showEmpty || coordinator.type.isMedia || coordinator.type.isReplies {
                return 100
            }
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }

        // Note, Comment, Share

        switch wrapper {
        case .lastWatched:
            let cell = tableView.cellForRow(at: indexPath) as! LastWatchedTableViewCell
            if let media = cell.media {
                let share = UIContextualAction(style: .normal,
                                               title: "Share") { _, _, boolValue in
                    guard let sharedURL = media.traktWebsiteMediaLink else { return }
                    let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
                    UIApplication.shared.present(activityViewController)
                    boolValue(true)
                }
                share.backgroundColor = UIColor(resource: .ripppleGray).darker()
                share.image = UIImage(systemName: "arrow.up.circle.fill")

                let comment = UIContextualAction(style: .normal,
                                                 title: "Write") { [weak self] _, _, boolValue in
                    guard let self = self else { return }
                    self.showNewCommentComposer(for: media)
                    boolValue(true)
                }
                comment.backgroundColor = UIColor(resource: .ripppleGray)
                comment.image = UIImage(systemName: "pencil.circle.fill")

                let notes = UIContextualAction(style: .normal,
                                               title: "Notes") { _, _, boolValue in
                    NotesManager.shared.showNotes(for: media)
                    boolValue(true)
                }
                notes.backgroundColor = UIColor(resource: .ripppleGray).lighter()
                notes.image = UIImage(systemName: "note.text")

                let configuration = UISwipeActionsConfiguration(actions: [notes, comment, share])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            }
            return nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }

        // Episodes, Next

        switch wrapper {
        case .lastWatched:
            let cell = tableView.cellForRow(at: indexPath) as! LastWatchedTableViewCell
            if let media = cell.media, let show = media.show {
                let next = UIContextualAction(style: .normal,
                                              title: "Next") { _, _, boolValue in
                    let nextEpisodeToWatchNavigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "next episode") as! UINavigationController

                    if let nextEpisodeViewController = nextEpisodeToWatchNavigationController.topViewController as? MediaShowNextLoadingViewController {
                        nextEpisodeViewController.media = media
                    }

                    UIApplication.shared.present(nextEpisodeToWatchNavigationController)
                    boolValue(true)
                }
                next.image = UIImage(systemName: "chevron.right.circle.fill")
                next.backgroundColor = UIColor(resource: .ripppleGray).lighter()

                let episodes = UIContextualAction(style: .normal,
                                                  title: "Episodes") { _, _, boolValue in
                    self.performSegue(withIdentifier: ViewControllerSegue.seasons.rawValue, sender: show)
                    boolValue(true)
                }
                episodes.image = UIImage(systemName: "list.bullet.circle.fill")
                episodes.backgroundColor = UIColor(resource: .ripppleGray)

                let configuration = UISwipeActionsConfiguration(actions: [next, episodes])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            }
            return nil
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return }
        switch wrapper {
        case .media(let mediaModel, _):
            switch mediaModel {
            case .movie, .episode, .season, .show:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: mediaModel)
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        case .comment(let commentModel):
            if coordinator.type.isPreview == false,
               coordinator.type.isPreviewReply == false,
               coordinator.type.isReplies == false {
                let media = commentModel.media
                let nextType = CommentsCoordinator.ListType.media(media)
                if nextType != coordinator.type {
                    performSegue(withIdentifier: ViewControllerSegue.media.rawValue,
                                 sender: nextType)
                }
            }
        case .ownComment(let commentItem):
            let media = CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers).media
            let nextType = CommentsCoordinator.ListType.media(media)
            if nextType != coordinator.type {
                performSegue(withIdentifier: ViewControllerSegue.media.rawValue,
                             sender: nextType)
            }
        case .rating:
            return
        case .user:
            return
        case .stats:
            return
        case .punchcard:
            return
        case .followAndFriends:
            return
        case .link(_, _, let segueIdentifier):
            if UserManager.shared.currentUser == nil {
                onNeedsToShowLoginTransmitter.broadcast(true)
                return
            }
            performSegue(withIdentifier: segueIdentifier, sender: nil)
            return
        case .lastWatched:
            let cell = tableView.cellForRow(at: indexPath) as! LastWatchedTableViewCell
            guard let media = cell.media else { return }
            switch media {
            case .movie, .episode, .show:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: media)
            case .season:
                // do nothing
                break
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
            return
        case .sentiments:
            return
        case .spacer:
            return
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if coordinator.type.isPreviewReply { return nil }
        if coordinator.type.isPreview { return nil }

        if let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell {
            if coordinator.type.isPreview == false, coordinator.type.isPreviewReply == false {
                contextMenu.cell = cell
                contextMenu.controller = self
            }

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        }

        if let cell = tableView.cellForRow(at: indexPath) as? CommentTableViewCell,
           let poster = cell.poster,
           poster.isHidden == false {
            contextMenu.cell = cell
            contextMenu.controller = self

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        }

        if let cell = tableView.cellForRow(at: indexPath) as? LastWatchedTableViewCell,
           cell.media != nil {
            contextMenu.cell = cell
            contextMenu.controller = self

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        }

        if let cell = tableView.cellForRow(at: indexPath) as? SentimentsTableViewCell {
            contextMenu.cell = cell
            contextMenu.controller = nil

            return UIContextMenuConfiguration(actionProvider: { _ in cell.sentiments.menu })
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        if let cell = contextMenu.cell {
            cell.layer.zPosition = 100
        }
        if coordinator.type.isPreviewReply { return nil }
        if coordinator.type.isPreview { return nil }

        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        if let cell = contextMenu.cell {
            cell.layer.zPosition = 0
        }
        if coordinator.type.isPreviewReply { return nil }
        if coordinator.type.isPreview { return nil }

        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        navigationController?.show(controller, sender: self)
    }
}

extension CommentsViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        // POSTER ACTION
        if action == .details {
            if indexPath.section == Section.header.rawValue, indexPath.row == 0 {
                switch coordinator.type! {
                case .media(let mediaModel):
                    switch mediaModel {
                    case .movie:
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: mediaModel)
                    case .episode(_, let show):
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: MediaModel.show(show))
                    case .season(_, let show):
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: MediaModel.show(show))
                    case .show:
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: mediaModel)
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                default:
                    break
                }
            }
        }
    }
}

extension CommentsViewController: CommentTableViewCellDelegate {
    private func share(comment: Comment, from button: UIButton) {
        guard let sharedURL = URL(string: "https://app.trakt.tv/comments/\(comment.identifier)") else { return }
        let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = button
        activityViewController.popoverPresentationController?.sourceRect = button.bounds
        present(activityViewController, animated: true, completion: nil)
    }

    private func edit(commentModel: CommentModel, from button: UIButton) {
        let alertController = UIAlertController(title: nil,
                                                message: nil,
                                                preferredStyle: .actionSheet)

        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(cancel)

        let edit = UIAlertAction(title: "Edit Comment", style: .default) { _ in
            self.showComposer(for: commentModel.comment,
                              media: commentModel.media)
        }

        let delete = UIAlertAction(title: "Delete Comment", style: .destructive) { _ in
            let confirmationAlertController = UIAlertController(title: nil,
                                                                message: "Are you sure you want to delete this comment?",
                                                                preferredStyle: .alert)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            confirmationAlertController.addAction(cancel)

            let delete = UIAlertAction(title: "Yes, Delete Comment", style: .destructive) { _ in
                TraktAPIProvider.provider.request(.deleteComment(id: commentModel.comment.identifier),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            if moyaResponse.statusCode == 409 {
                                DispatchQueue.main.async {
                                    let alertController = UIAlertController(title: "Can't Delete",
                                                                            message: "We cannot delete a comment that is older than 2 weeks or has at least one comment.",
                                                                            preferredStyle: .alert)

                                    let cancel = UIAlertAction(title: "Okay", style: .cancel)
                                    alertController.addAction(cancel)
                                    self.present(alertController, animated: true)
                                }
                            } else {
                                _ = try moyaResponse.filterSuccessfulStatusCodes()

                                DispatchQueue.main.async {
                                    commentPostedTransmitter.broadcast(commentModel)
                                    SwiftMessages.show(message: "🗑 Comment deleted")
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                        }
                    }
                }
            }
            confirmationAlertController.addAction(delete)

            self.present(confirmationAlertController, animated: true)
        }

        let reportReply = UIAlertAction(title: "Block User", style: .default) { _ in
            commentModel.comment.filter()
        }

        if commentModel.comment.isReply, !commentModel.isOwnComment {
            alertController.addAction(reportReply)
        } else {
            alertController.addAction(edit)
            alertController.addAction(delete)
        }

        alertController.popoverPresentationController?.sourceView = button

        present(alertController, animated: true)
    }

    private func reply(commentModel: CommentModel) {
        let nextType = CommentsCoordinator.ListType.replies(commentModel, true)
        if nextType != coordinator.type {
            performSegue(withIdentifier: ViewControllerSegue.replies.rawValue,
                         sender: nextType)
        }
    }

    func cell(_ cell: CommentTableViewCell, action: CommentTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        if indexPath.section == 0, case .replies(let commentModel, _) = coordinator.type! {
            switch action {
            case .presentAuthor:
                let comment = commentModel.comment
                let nextType = CommentsCoordinator.ListType.user(comment.user)
                if nextType != coordinator.type {
                    performSegue(withIdentifier: ViewControllerSegue.user.rawValue,
                                 sender: nextType)
                }
            case .presentReplies:
                break
            case .share:
                let comment = commentModel.comment
                share(comment: comment, from: cell.shareButton)
            case .reply:
                showComposer(for: commentReply(for: commentModel.comment),
                             media: commentModel.media)
            case .edit:
                edit(commentModel: commentModel, from: cell.editButton)
            case .presentLikes:
                let comment = commentModel.comment
                performSegue(withIdentifier: ViewControllerSegue.likes.rawValue,
                             sender: comment)
            case .presentMediaDetails:
                switch commentModel.media {
                case .movie(let movie):
                    let media = MediaModel.movie(movie)
                    performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                 sender: media)
                case .season(_, let show), .show(let show), .episode(_, let show):
                    let media = MediaModel.show(show)
                    performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                 sender: media)
                case .list:
                    fatalError()
                case .showProgress:
                    fatalError()
                }
            case .presentParentComment:
                fatalError()
            }
        } else {
            let wrapper = dataSource.itemIdentifier(for: indexPath)
            switch wrapper {
            case .comment(let commentModel):
                switch action {
                case .presentAuthor:
                    let nextType = CommentsCoordinator.ListType.user(commentModel.comment.user)
                    if nextType != coordinator.type {
                        performSegue(withIdentifier: ViewControllerSegue.user.rawValue,
                                     sender: nextType)
                    }
                case .presentReplies:
                    let nextType = CommentsCoordinator.ListType.replies(CommentModel(media: commentModel.media,
                                                                                     comment: commentModel.comment,
                                                                                     spoilerStrategy: .showAllSpoilers), false)
                    if nextType != coordinator.type {
                        performSegue(withIdentifier: ViewControllerSegue.replies.rawValue,
                                     sender: nextType)
                    }
                case .share:
                    share(comment: commentModel.comment, from: cell.shareButton)
                case .reply:
                    showComposer(for: commentReply(for: commentModel.comment),
                                 media: commentModel.media)
                case .edit:
                    edit(commentModel: CommentModel(media: commentModel.media,
                                                    comment: commentModel.comment,
                                                    spoilerStrategy: .showAllSpoilers),
                         from: cell.editButton)
                case .presentLikes:
                    performSegue(withIdentifier: ViewControllerSegue.likes.rawValue,
                                 sender: commentModel.comment)
                case .presentMediaDetails:
                    switch commentModel.media {
                    case .movie(let movie):
                        let media = MediaModel.movie(movie)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .episode(_, let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .season(_, let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .show(let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                case .presentParentComment:
                    let nextType = CommentsCoordinator.ListType.media(commentModel.media)
                    if nextType != coordinator.type {
                        performSegue(withIdentifier: ViewControllerSegue.media.rawValue, sender: nextType)
                    }
                }
            case .ownComment(let commentItem):
                let commentModel = CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers)
                switch action {
                case .presentAuthor:
                    let nextType = CommentsCoordinator.ListType.user(commentModel.comment.user)
                    if nextType != coordinator.type {
                        performSegue(withIdentifier: ViewControllerSegue.user.rawValue,
                                     sender: nextType)
                    }
                case .presentReplies:
                    let nextType = CommentsCoordinator.ListType.replies(CommentModel(media: commentModel.media,
                                                                                     comment: commentModel.comment,
                                                                                     spoilerStrategy: .showAllSpoilers), false)
                    if nextType != coordinator.type {
                        performSegue(withIdentifier: ViewControllerSegue.replies.rawValue,
                                     sender: nextType)
                    }
                case .share:
                    share(comment: commentModel.comment, from: cell.shareButton)
                case .reply:
                    showComposer(for: commentReply(for: commentModel.comment),
                                 media: commentModel.media)
                case .edit:
                    edit(commentModel: CommentModel(media: commentModel.media,
                                                    comment: commentModel.comment,
                                                    spoilerStrategy: .showAllSpoilers),
                         from: cell.editButton)
                case .presentLikes:
                    performSegue(withIdentifier: ViewControllerSegue.likes.rawValue,
                                 sender: commentModel.comment)
                case .presentMediaDetails:
                    switch commentModel.media {
                    case .movie(let movie):
                        let media = MediaModel.movie(movie)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .episode(_, let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .season(_, let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .show(let show):
                        let media = MediaModel.show(show)
                        performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                     sender: media)
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                case .presentParentComment:
                    fatalError()
                }
            default:
                fatalError()
            }
        }
    }

    private var commentModel: CommentModel? {
        switch coordinator.type! {
        case .replies(let commentModel, _):
            return commentModel
        default:
            return nil
        }
    }
}

extension CommentsViewController: FollowersAndFriendsTableViewCellDelegate {
    func cell(_ cell: FollowersAndFriendsTableViewCell, action: FollowersAndFriendsTableViewCell.Action) {
        switch action {
        case .followers:
            performSegue(withIdentifier: "followers", sender: nil)
        case .following:
            performSegue(withIdentifier: "following", sender: nil)
        case .friends:
            performSegue(withIdentifier: "friends", sender: nil)
        case .blocked:
            performSegue(withIdentifier: "blocked", sender: nil)
        }
    }
}

extension CommentsViewController: LastWatchedTableViewCellDelegate {
    func cell(_ cell: LastWatchedTableViewCell, action: LastWatchedTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return }
        switch wrapper {
        case .lastWatched:
            let cell = tableView.cellForRow(at: indexPath) as! LastWatchedTableViewCell
            if let media = cell.media {
                if let show = media.show {
                    performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                 sender: show.mediaModel)
                } else {
                    performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                                 sender: media)
                }
            }
            return
        default:
            return
        }
    }
}
