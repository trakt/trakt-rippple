//
//  ListStatsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 29/06/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class ListStatsTableViewCell: UITableViewCell {
    @IBOutlet var items: EFCountingLabel!
    @IBOutlet var watchedMovies: EFCountingLabel!
    @IBOutlet var watchedShows: EFCountingLabel!
    @IBOutlet var rated: EFCountingLabel!
    @IBOutlet var watchlisted: EFCountingLabel!
    @IBOutlet var recommended: EFCountingLabel!
    @IBOutlet var collected: EFCountingLabel!
    @IBOutlet var commented: EFCountingLabel!

    private let disposeBag = DisposeBag()

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

        onRecommendedChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.update()
        }.disposed(by: disposeBag)

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
                    if movie.isRecommended { recommendedCount += 1 }
                    if movie.isInCollection { collectedCount += 1 }
                    if media.userRating != nil { ratedCount += 1 }
                    if movie.ownCommentItem != nil { commentedCount += 1 }
                case .show(let show):
                    itemsCount += 1
                    if show.isWatchedAtLeastOnce { watchedShowsCount += 1 }
                    if show.isWatchlisted { watchlistedCount += 1 }
                    if show.isRecommended { recommendedCount += 1 }
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
