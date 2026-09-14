//
//  MediaCommentsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 15/01/2019.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol MediaCommentsTableViewCellDelegate: AnyObject {
    func cell(_ cell: MediaCommentsTableViewCell, action: MediaCommentsTableViewCell.Action)
}

final class MediaCommentsTableViewCell: TintedCanvasTableViewCell {
    private let disposeBag = DisposeBag()

    enum Action {
        case showAll
        case showComment(Comment)
    }

    deinit {
        print("deinit MediaCommentsTableViewCell")
    }

    weak var delegate: MediaCommentsTableViewCellDelegate?

    private var commentCount: Int?
    private var needsReload = false // used if an update happens when something is already loading
    private var isLoading = true {
        didSet {
            if isLoading == false {
                collectionView.reloadData()
                if needsReload {
                    loadComments()
                }
            } else {
                showLoading()
            }
        }
    }

    private var error: Error? {
        didSet {
            if error != nil {
                isLoading = false
                errorLabel.text = "Try again or try later...\n\(error!.localizedDescription)"
                showErrorView()
            } else {
                if media.movie != nil {
                    media = media.movie!.mediaModel
                } else {
                    media = media.show!.mediaModel
                }
            }
        }
    }

    private func showCommentsView() {
        if UserDefaults.standard.bool(forKey: "GeneralSettings.comments") == false {
            guard let comments = comments else {
                titleLabel.text = "Comments"
                return
            }
            if comments.isEmpty {
                if media.ownCommentItem != nil {
                    titleLabel.text = "Comments"
                } else {
                    titleLabel.text = "No comment"
                }
            } else {
                if let commentCount = commentCount {
                    titleLabel.text = "\(commentCount) comment\(commentCount <= 1 ? "" : "s")"
                } else {
                    titleLabel.text = "\(comments.count) comment\(comments.count <= 1 ? "" : "s")"
                }
            }
            moreAction.setTitle("See all", for: .normal)
            moreAction.isHidden = false
            errorView.isHidden = true
            emptyView.isHidden = true
            collectionView.isHidden = true
            heightLayoutContraint.constant = 0
            titleTopLayoutContraint.constant = 12
            titleBottomLayoutContraint.constant = 1
            invalidateIntrinsicContentSize()
            return
        }

        guard let comments = comments else {
            titleLabel.text = "Comments"
            return
        }
        if comments.isEmpty {
            if media.ownCommentItem != nil {
                titleLabel.text = "Comments"
            } else {
                titleLabel.text = "No comments"
            }
        } else if comments.count == 1 {
            titleLabel.text = "Comments"
        } else {
            if let commentCount = commentCount {
                if commentCount != comments.count {
                    titleLabel.text = "Most reacted out of \(commentCount) comments"
                } else {
                    titleLabel.text = "\(comments.count) comments"
                }
            } else {
                titleLabel.text = "\(comments.count) comments"
            }
        }
        moreAction.setTitle("See all", for: .normal)
        moreAction.isHidden = false
        errorView.isHidden = true
        emptyView.isHidden = true
        collectionView.isHidden = false
        heightLayoutContraint.constant = 210
        titleTopLayoutContraint.constant = 10
        titleBottomLayoutContraint.constant = 8
        invalidateIntrinsicContentSize()
    }

    private func showEmptyView() {
        titleLabel.text = "No comments"
        moreAction.isHidden = false
        errorView.isHidden = true
        emptyView.isHidden = true
        collectionView.isHidden = true
        heightLayoutContraint.constant = 0
        titleTopLayoutContraint.constant = 12
        titleBottomLayoutContraint.constant = 1
        invalidateIntrinsicContentSize()
    }

    private func showErrorView() {
        titleLabel.text = "Error..."
        moreAction.setTitle("Retry", for: .normal)
        moreAction.isHidden = false
        errorView.isHidden = false
        emptyView.isHidden = true
        collectionView.isHidden = true
        heightLayoutContraint.constant = 120
        invalidateIntrinsicContentSize()
    }

    private func showLoading() {
        titleLabel.text = "Loading comments..."
        moreAction.setTitle("", for: .normal)
        moreAction.isHidden = true
        errorView.isHidden = true
        emptyView.isHidden = true
        collectionView.isHidden = true
        heightLayoutContraint.constant = 0
        titleTopLayoutContraint.constant = 12
        titleBottomLayoutContraint.constant = 1
        invalidateIntrinsicContentSize()
    }

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var moreAction: UIButton!
    @IBOutlet var collectionView: UICollectionView!

    @IBOutlet var heightLayoutContraint: NSLayoutConstraint!
    @IBOutlet var titleTopLayoutContraint: NSLayoutConstraint!
    @IBOutlet var titleBottomLayoutContraint: NSLayoutConstraint!

    @IBOutlet var emptyView: UIView!
    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!

    private var comments: [Comment]? {
        didSet {
            isLoading = false
            reloadData()
        }
    }

    private var sentiments: CommentsSentiments? {
        didSet {
            if sentiments != nil {
                reloadData()
            }
        }
    }

    private func reloadData() {
        if isLoading == false {
            if comments?.isEmpty ?? false, media.ownCommentItem == nil, sentiments == nil {
                showEmptyView()
            } else {
                showCommentsView()
            }
            collectionView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.register(UINib(nibName: "MediaCommentsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "comment")
        collectionView.register(UINib(nibName: "SentimentsPeekCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "sentiments")

        moreAction.isHidden = true
        emptyView.isHidden = true
        errorView.isHidden = true

        // skip the first one
        onOwnCommentsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.reloadData()
        }.disposed(by: disposeBag)

        moreAction.maximumContentSizeCategory = .extraExtraLarge
        maximumContentSizeCategory = .large
    }

    var media: MediaModel! {
        didSet {
            if media == oldValue {
                return
            }

            loadComments()
        }
    }

    private func loadComments() {
        needsReload = false
        isLoading = true

        Task {
            self.sentiments = await media.fetchSentiments()
        }

        switch media! {
        case .movie(let movie):
            TraktAPIProvider.provider.request(TraktAPIService.comments(type: .movie(movieId: movie.identifiers.trakt!), pageInfo: PageInfo.firstPage(with: 15), sortBy: .likes, replies: nil),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if let response = response.response {
                            let allHTTPHeaders = response.allHeaderFields
                            if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                                DispatchQueue.main.async {
                                    self.commentCount = Int(itemCount)
                                }
                            }
                        }

                        let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder).sorted { $0.reactions?.distribution.score ?? $0.likes > $1.reactions?.distribution.score ?? $1.likes }

                        DispatchQueue.main.async {
                            self.comments = comments
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        case .show(let show):
            TraktAPIProvider.provider.request(TraktAPIService.comments(type: .show(showId: show.identifiers.trakt!), pageInfo: PageInfo.firstPage(with: 15), sortBy: .likes, replies: nil),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if let response = response.response {
                            let allHTTPHeaders = response.allHeaderFields
                            if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                                DispatchQueue.main.async {
                                    self.commentCount = Int(itemCount)
                                }
                            }
                        }

                        let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder).sorted { $0.reactions?.distribution.score ?? $0.likes > $1.reactions?.distribution.score ?? $1.likes }

                        DispatchQueue.main.async {
                            self.comments = comments
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        case .episode(let episode, let show):
            TraktAPIProvider.provider.request(TraktAPIService.comments(type: .episode(showId: show.identifiers.trakt!, season: episode.season, episode: episode.number), pageInfo: PageInfo.firstPage(with: 15), sortBy: .likes, replies: nil),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if let response = response.response {
                            let allHTTPHeaders = response.allHeaderFields
                            if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                                DispatchQueue.main.async {
                                    self.commentCount = Int(itemCount)
                                }
                            }
                        }

                        let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder).sorted { $0.reactions?.distribution.score ?? $0.likes > $1.reactions?.distribution.score ?? $1.likes }

                        DispatchQueue.main.async {
                            self.comments = comments
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        case .season(let season, let show):
            TraktAPIProvider.provider.request(TraktAPIService.comments(type: .season(showId: show.identifiers.trakt!, season: season.number), pageInfo: PageInfo.firstPage(with: 15), sortBy: .likes, replies: nil),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if let response = response.response {
                            let allHTTPHeaders = response.allHeaderFields
                            if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                                DispatchQueue.main.async {
                                    self.commentCount = Int(itemCount)
                                }
                            }
                        }

                        let comments = try response.map([Comment].self, using: TraktAPIProvider.decoder).sorted { $0.reactions?.distribution.score ?? $0.likes > $1.reactions?.distribution.score ?? $1.likes }

                        DispatchQueue.main.async {
                            self.comments = comments
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.error = error
                    }
                }
            }
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    @IBAction func showAll(_ sender: Any) {
        if error != nil {
            error = nil
            return
        }
        if isLoading == true { return }
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .showAll)
    }
}

extension MediaCommentsTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: min(collectionView.frame.width - 50.0, 350), height: 220)
    }
}

extension MediaCommentsTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 3
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if section == 0 {
            if sentiments == nil {
                return UIEdgeInsets()
            } else {
                return UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 0)
            }
        }
        if section == 1 {
            if media.ownCommentItem == nil {
                return UIEdgeInsets()
            } else {
                return UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 0)
            }
        }
        return UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isLoading == true { return 0 }
        if section == 0 {
            if sentiments != nil {
                return 1
            } else {
                return 0
            }
        }
        if section == 1 {
            if media.ownCommentItem != nil {
                return 1
            } else {
                return 0
            }
        }
        return comments?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "sentiments", for: indexPath) as! SentimentsPeekCollectionViewCell

            cell.sentiments = sentiments

            return cell
        } else if indexPath.section == 1 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "comment", for: indexPath) as! MediaCommentsCollectionViewCell

            cell.pinImage.isHidden = false
            cell.sentiments = sentiments
            let commentItem = media.ownCommentItem!
            cell.commentModel = CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers)

            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "comment", for: indexPath) as! MediaCommentsCollectionViewCell

            cell.pinImage.isHidden = true
            cell.sentiments = sentiments
            cell.commentModel = CommentModel(media: media, comment: comments![indexPath.row], spoilerStrategy: .hideAllSpoilers)

            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isLoading == true { return }
        guard let delegate = delegate else { return }

        if indexPath.section == 0 {
            delegate.cell(self, action: .showAll)
        } else if indexPath.section == 1 {
            guard let commentItem = media.ownCommentItem else { return }
            delegate.cell(self, action: .showComment(commentItem.comment))
        } else {
            guard let comment = comments?[indexPath.row] else { return }
            delegate.cell(self, action: .showComment(comment))
        }
    }
}

extension MediaCommentsTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? SentimentsPeekCollectionViewCell {
            return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                              previewProvider: {
                                                  let sentimentsPreviewViewController = UIStoryboard(name: "SentimentsPreview", bundle: nil).instantiateInitialViewController() as! SentimentsPreviewViewController

                                                  sentimentsPreviewViewController.sentiments = cell.sentiments

                                                  return sentimentsPreviewViewController
                                              }, actionProvider: { _ -> UIMenu? in
                                                  cell.sentiments.menu
                                              })
        }

        return nil
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? SentimentsPeekCollectionViewCell {
            cell.layer.zPosition = 100
            return UITargetedPreview(view: cell.cardView, parameters: UIPreviewParameters())
        }
        return nil
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? SentimentsPeekCollectionViewCell {
            cell.layer.zPosition = 0
            return UITargetedPreview(view: cell.cardView, parameters: UIPreviewParameters())
        }
        return nil
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        if isLoading == true { return }
        guard let delegate = delegate else { return }

        if indexPath.section == 0 {
            delegate.cell(self, action: .showAll)
        }
    }
}

final class SentimentsPreviewViewController: UIViewController {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bodyLabel: UILabel!
    @IBOutlet var metaLabel: UILabel!

    private static let dateFormatter = RelativeDateTimeFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.maximumContentSizeCategory = .large
        bodyLabel.maximumContentSizeCategory = .large
        metaLabel.maximumContentSizeCategory = .large

        SentimentsPreviewViewController.dateFormatter.unitsStyle = .abbreviated
        SentimentsPreviewViewController.dateFormatter.dateTimeStyle = .numeric
        SentimentsPreviewViewController.dateFormatter.formattingContext = .listItem

        setupSentiments()
    }

    var sentiments: CommentsSentiments!

    private func setupSentiments() {
        if sentiments.commentCount == 0 || sentiments.commentCount == 100000 {
            titleLabel.text = "Sentiment Highlights"
            bodyLabel.text = sentiments.formattedSentiment
            metaLabel.text = "Aggregated audience sentiment"
        } else {
            titleLabel.text = "Comments Highlights"
            bodyLabel.text = sentiments.formattedSentiment
            metaLabel.text = "\(sentiments.commentCount) comments analyzed \(SentimentsPreviewViewController.dateFormatter.localizedString(for: sentiments.analyzedAt, relativeTo: Date()))"
        }
    }
}

extension CommentsSentiments {
    var menu: UIMenu {
        let copyAction = UIAction(title: "Copy Highlights",
                                  image: UIImage(systemName: "doc.on.doc"),
                                  identifier: nil) { _ in
            UIPasteboard.general.string = formattedSentiment
        }
        return UIMenu(children: [copyAction])
    }
}
