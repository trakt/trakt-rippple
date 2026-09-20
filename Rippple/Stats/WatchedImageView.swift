//
//  WatchedImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 09/12/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit

final class WatchedImageView: UIImageView {
    private static let watchedImage = UIImage(systemName: "checkmark.circle")
    private static let rewatchedImage = UIImage(systemName: "checkmark.circle.badge.plus")

    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .movie = self.media {
                self.updateFromSyncWatchedManager()
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .episode = self.media {
                self.updateFromSyncWatchedManager()
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onCompletedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if case .show(let show) = self.media {
                DispatchQueue.main.async {
                    if show.isCompleted {
                        self.isHidden = false
                    } else {
                        self.isHidden = true
                    }
                }
            }
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.hotOnly().listen { [weak self] progress in
            guard let self = self else { return }
            if case .season(let season, let show) = self.media, progress.show == show {
                DispatchQueue.main.async {
                    self.updateSeasonWatchedStatus(season: season, show: show)
                }
            }
        }.disposed(by: disposeBag)
    }

    var media: MediaModel? {
        didSet {
            isHidden = true
            image = WatchedImageView.watchedImage
            switch media {
            case .movie, .episode:
                updateFromSyncWatchedManager()
            case .show(let show):
                if show.isCompleted {
                    isHidden = false
                } else {
                    isHidden = true
                }
            case .season(let season, let show):
                updateSeasonWatchedStatus(season: season, show: show)
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    private func updateFromSyncWatchedManager() {
        switch media {
        case .movie(let movie):
            updateWatchedStatus(type: .movies, traktId: movie.identifiers.trakt)
        case .episode(let episode, _):
            updateWatchedStatus(type: .episodes, traktId: episode.identifiers.trakt)
        default:
            return
        }
    }

    private func updateWatchedStatus(type: SyncWatchedType, traktId: Int64?) {
        guard let traktId = traktId else {
            isHidden = true
            image = WatchedImageView.watchedImage
            return
        }

        let watchedCount = SyncWatchedManager.shared.watchedDates(for: type, traktId: traktId).count
        isHidden = watchedCount == 0
        image = watchedCount > 1 ? WatchedImageView.rewatchedImage : WatchedImageView.watchedImage
    }

    private func updateSeasonWatchedStatus(season: Season, show: Show) {
        isHidden = true
        invalidateCellIntrinsicContentSize()

        guard show.isWatchedAtLeastOnce else { return }

        show.mediaModel.progress { [weak self] progress in
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard case .season(let currentSeason, let currentShow) = self.media,
                      currentSeason == season,
                      currentShow == show else { return }

                self.isHidden = !(progress?.isWatched(season: season) == true)
                self.invalidateCellIntrinsicContentSize()
            }
        }
    }
}
