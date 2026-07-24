//
//  ListStatsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 29/06/2022.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol ListStatsTableViewCellDelegate: AnyObject {
    func cell(_ cell: ListStatsTableViewCell, action: ListStatsTableViewCell.Action)
}

final class ListStatsTableViewCell: UITableViewCell {
    enum Action {
        case progress
    }

    @IBOutlet var statsStackView: UIStackView!

    @IBOutlet var items: EFCountingLabel!
    @IBOutlet var watchedMovies: EFCountingLabel!
    @IBOutlet var watchedShows: EFCountingLabel!
    @IBOutlet var rated: EFCountingLabel!
    @IBOutlet var watchlisted: EFCountingLabel!
    @IBOutlet var recommended: EFCountingLabel!
    @IBOutlet var collected: EFCountingLabel!
    @IBOutlet var commented: EFCountingLabel!

    private var progressCard: InsideCardView!
    private var progressPercentage: EFCountingLabel!
    private var progressTitle: UILabel!
    private var progressView: CircularProgressView!

    private let disposeBag = DisposeBag()
    private var progressDisposeBag = DisposeBag()

    weak var delegate: ListStatsTableViewCellDelegate?

    var listProgressContext: ListProgressContext? {
        didSet {
            progressDisposeBag = DisposeBag()

            guard let listProgressContext = listProgressContext else {
                progressCard?.isHiddenInStackView = true
                return
            }

            setupProgressCardIfNeeded()
            progressCard.isHiddenInStackView = false

            listProgressContext.onStatusChangedReceiver.listen { [weak self] status in
                guard let self = self else { return }
                self.updateProgress(with: status)
            }.disposed(by: progressDisposeBag)
        }
    }

    var mediaItems: [MediaModel]? {
        didSet {
            update()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onOwnCommentsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onWatchlistChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onMovieCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onEpisodeCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        onUserFavoritesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

        setupProgressCardIfNeeded()
        progressCard.isHiddenInStackView = true

        numberFormatter.numberStyle = .decimal

        items.text = "0"
        items.method = .easeInOut
        items.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        watchedMovies.text = "0"
        watchedMovies.method = .easeInOut
        watchedMovies.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0") of \((self.mediaItems ?? [MediaModel]()).filter { $0.movie != nil }.count)"
        }

        watchedShows.text = "0"
        watchedShows.method = .easeInOut
        watchedShows.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0") of \((self.mediaItems ?? [MediaModel]()).filter { $0.showShow != nil }.count)"
        }

        rated.text = "0"
        rated.method = .easeInOut
        rated.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        watchlisted.text = "0"
        watchlisted.method = .easeInOut
        watchlisted.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        recommended.text = "0"
        recommended.method = .easeInOut
        recommended.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        collected.text = "0"
        collected.method = .easeInOut
        collected.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        commented.text = "0"
        commented.method = .easeInOut
        commented.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        listProgressContext = nil
        delegate = nil
        progressCard?.isHiddenInStackView = true
    }

    private let numberFormatter: NumberFormatter = .init()

    private func update() {
        guard let mediaItems = mediaItems else {
            return
        }

        DispatchQueue.global(qos: .userInteractive).async {
            var itemsCount = 0.0
            var watchedMoviesCount = 0.0
            var watchedShowsCount = 0.0
            var commentedCount = 0.0
            var watchlistedCount = 0.0
            var collectedCount = 0.0
            var recommendedCount = 0.0
            var ratedCount = 0.0
            for media in mediaItems {
                switch media {
                case .movie(let movie):
                    itemsCount += 1
                    if movie.isWatched { watchedMoviesCount += 1 }
                    if movie.isWatchlisted { watchlistedCount += 1 }
                    if movie.isUserFavorite { recommendedCount += 1 }
                    if movie.isInCollection { collectedCount += 1 }
                    if media.userRating != nil { ratedCount += 1 }
                    if movie.ownCommentItem != nil { commentedCount += 1 }
                case .show(let show):
                    itemsCount += 1
                    if show.isWatchedAtLeastOnce { watchedShowsCount += 1 }
                    if show.isWatchlisted { watchlistedCount += 1 }
                    if show.isUserFavorite { recommendedCount += 1 }
                    if show.isInCollection { collectedCount += 1 }
                    if media.userRating != nil { ratedCount += 1 }
                    if show.ownCommentItem != nil { commentedCount += 1 }
                case .episode(let episode, _):
                    itemsCount += 1
                    if episode.isWatchlisted { watchlistedCount += 1 }
                    if episode.isInCollection { collectedCount += 1 }
                    if media.userRating != nil { ratedCount += 1 }
                    if episode.ownCommentItem != nil { commentedCount += 1 }
                case .season(let season, _):
                    itemsCount += 1
                    if season.isWatchlisted { watchlistedCount += 1 }
                    if media.userRating != nil { ratedCount += 1 }
                    if season.ownCommentItem != nil { commentedCount += 1 }
                case .list:
                    break
                case .showProgress:
                    break
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.items.countFromCurrentValueTo(itemsCount, withDuration: 0.7)
                self.watchedMovies.countFromCurrentValueTo(watchedMoviesCount, withDuration: 0.7)
                self.watchedShows.countFromCurrentValueTo(watchedShowsCount, withDuration: 0.7)
                self.watchlisted.countFromCurrentValueTo(watchlistedCount, withDuration: 0.7)
                self.recommended.countFromCurrentValueTo(recommendedCount, withDuration: 0.7)
                self.collected.countFromCurrentValueTo(collectedCount, withDuration: 0.7)
                self.rated.countFromCurrentValueTo(ratedCount, withDuration: 0.7)
                self.commented.countFromCurrentValueTo(commentedCount, withDuration: 0.7)
            }
        }
    }
}

private extension ListStatsTableViewCell {
    func setupProgressCardIfNeeded() {
        guard progressCard == nil else { return }

        progressCard = InsideCardView()
        progressCard.translatesAutoresizingMaskIntoConstraints = false
        progressCard.isUserInteractionEnabled = true
        progressCard.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                 action: #selector(progressCardTapped)))

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 12

        let labelsStack = UIStackView()
        labelsStack.axis = .vertical
        labelsStack.alignment = .leading
        labelsStack.spacing = 0

        progressPercentage = EFCountingLabel()
        progressPercentage.font = UIFont.preferredFont(forTextStyle: .title3).bold()
        progressPercentage.adjustsFontForContentSizeCategory = true
        progressPercentage.text = "0%"
        progressPercentage.method = .easeInOut
        progressPercentage.formatBlock = { value in
            "\(Int(value))%"
        }
        progressPercentage.setContentCompressionResistancePriority(.required, for: .horizontal)

        progressTitle = UILabel()
        progressTitle.font = UIFont.preferredFont(forTextStyle: .caption2)
        progressTitle.adjustsFontForContentSizeCategory = true
        progressTitle.textColor = .secondaryLabel
        progressTitle.text = "watched"

        labelsStack.addArrangedSubview(progressPercentage)
        labelsStack.addArrangedSubview(progressTitle)

        progressView = CircularProgressView()
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.trackTintColor = UIColor(asset: .globalTint).withAlphaComponent(0.2)
        progressView.progressTintColor = UIColor(asset: .globalTint)
        progressView.thicknessRatio = 0.2

        let progressContainer = UIView()
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.addSubview(progressView)

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: progressContainer.bottomAnchor),
            progressContainer.widthAnchor.constraint(equalToConstant: 30),
            progressContainer.heightAnchor.constraint(equalToConstant: 30)
        ])

        contentStack.addArrangedSubview(labelsStack)
        contentStack.addArrangedSubview(progressContainer)

        progressCard.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: 6),
            contentStack.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: 12),
            contentStack.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -12),
            contentStack.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -6),
            progressCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])

        statsStackView.insertArrangedSubview(progressCard, at: 0)
        statsStackView.setCustomSpacing(20, after: progressCard)
    }

    func updateProgress(with status: ListProgressContext.Status) {
        switch status {
        case .idle:
            progressTitle.text = "watched"
            progressPercentage.countFromCurrentValueTo(0, withDuration: 0)
            progressView.updateProgress(0, animated: false)
        case .loading:
            progressTitle.text = "Loading..."
            progressPercentage.countFromCurrentValueTo(0, withDuration: 0)
            progressView.updateProgress(0, animated: false)
        case .content(let result):
            progressTitle.text = "watched"
            progressPercentage.countFromCurrentValueTo(CGFloat(result.percentage), withDuration: 0.7)
            progressView.updateProgress(CGFloat(result.progress), animated: true, duration: 0.7)
        }
    }

    @objc func progressCardTapped() {
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .progress)
    }
}
