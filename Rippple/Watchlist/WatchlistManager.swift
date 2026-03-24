//
//  WatchlistManager.swift
//  Rippple
//
//  Created by Kevin Cador on 16/04/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Foundation
import UIKit

import Receiver

let (onWatchlistChangedTransmitter, onWatchlistChangedReceiver) = Receiver<Bool>.make(with: .hot)
let (onMoviesWatchlistedChangedTransmitter, onMoviesWatchlistedChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onShowsWatchlistedChangedTransmitter, onShowsWatchlistedChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onEpisodesWatchlistedChangedTransmitter, onEpisodesWatchlistedChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onSeasonsWatchlistedChangedTransmitter, onSeasonsWatchlistedChangedReceiver) = Receiver<[Int64]>.make(with: .hot)

final class WatchlistManager {

    private let disposeBag = DisposeBag()

    private init() { }

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshWatchlist()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshWatchlist()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { _ in
            self.refreshWatchlist()
        }.disposed(by: disposeBag)

        // refresh if checkin in in progress
        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { watchingItem, _ in
            if let watchingItem = watchingItem,
               let mediaModel = MediaModel(item: watchingItem) {
                switch mediaModel {
                case .episode(_, let show):
                    if UserDefaults.standard.bool(forKey: "GeneralSettings.removeepisodeautowatchedsync") == true {
                        MediaModel.removeEpisodeFromAnyListUndercover(media: mediaModel)
                        // don't return, the watchlist has to be refreshed in this case
                    }
                    if UserDefaults.standard.bool(forKey: "GeneralSettings.removeshowtowatchfromlist") == true {
                        MediaModel.removeShowFromToWatchListUndercover(media: show.mediaModel)
                        // don't return, the watchlist has to be refreshed in this case
                    }
                case .movie:
                    if UserDefaults.standard.bool(forKey: "GeneralSettings.removemovietowatchfromlist") == true {
                        MediaModel.removeMovieFromToWatchListUndercover(media: mediaModel)
                        // don't return, the watchlist has to be refreshed in this case
                    }
                default:
                    break
                }
                // don't return, the watchlist has to be refreshed in this case
            }
            if let show = watchingItem?.show, show.isWatchlisted && UserDefaults.standard.bool(forKey: "GeneralSettings.watchlistaddback") {
                MediaModel.addShowsToWatchlistUndercover(medias: [show.mediaModel])
                return
            }
            if let show = watchingItem?.show, UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautowatchedsync") {
                MediaModel.addShowsToWatchlistUndercover(medias: [show.mediaModel])
                return
            }
            self.refreshWatchlist()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { media in
            switch media {
            case .episode(_, let show):
                if UserDefaults.standard.bool(forKey: "GeneralSettings.removeepisodeautowatchedsync") == true {
                    MediaModel.removeEpisodeFromAnyListUndercover(media: media)
                    // don't return, the watchlist has to be refreshed in this case
                }
                if UserDefaults.standard.bool(forKey: "GeneralSettings.removeshowtowatchfromlist") == true {
                    MediaModel.removeShowFromToWatchListUndercover(media: show.mediaModel)
                    // don't return, the watchlist has to be refreshed in this case
                }
            case .movie:
                if UserDefaults.standard.bool(forKey: "GeneralSettings.removemovietowatchfromlist") == true {
                    MediaModel.removeMovieFromToWatchListUndercover(media: media)
                    // don't return, the watchlist has to be refreshed in this case
                }
            default:
                break
            }

            switch media {
            case .episode(_, let show), .show(let show), .season(_, let show):
                if show.isWatchlisted && UserDefaults.standard.bool(forKey: "GeneralSettings.watchlistaddback") {
                    MediaModel.addShowsToWatchlistUndercover(medias: [show.mediaModel])
                    return
                }
                if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautowatchedsync") {
                    MediaModel.addShowsToWatchlistUndercover(medias: [show.mediaModel])
                    return
                }
            default:
                break
            }

            self.refreshWatchlist()
        }.disposed(by: disposeBag)

        refreshWatchlist()
    }

    func refresh() {
        refreshWatchlist()
    }

    static let shared = WatchlistManager()

    fileprivate var watchlist = [MediaItem]()

    fileprivate var watchlistedMovies = Set<Int64>() {
        didSet {
            if self.watchlistedMovies != oldValue {
                onMoviesWatchlistedChangedTransmitter.broadcast(Array(watchlistedMovies))
            }
        }
    }
    fileprivate var watchlistedShows = Set<Int64>() {
        didSet {
            if self.watchlistedShows != oldValue {
                onShowsWatchlistedChangedTransmitter.broadcast(Array(watchlistedShows))
            }
        }
    }
    fileprivate var watchlistedSeasons = Set<Int64>() {
        didSet {
            if self.watchlistedSeasons != oldValue {
                onSeasonsWatchlistedChangedTransmitter.broadcast(Array(watchlistedSeasons))
            }
        }
    }
    fileprivate var watchlistedEpisodes = Set<Int64>() {
        didSet {
            if self.watchlistedEpisodes != oldValue {
                onEpisodesWatchlistedChangedTransmitter.broadcast(Array(watchlistedEpisodes))
            }
        }
    }
}

private extension WatchlistManager {

    private func refreshWatchlist() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllWatchlistItems(slug: "me",
                                                type: nil,
                                                extended: .full,
                                                sort: .added) { result in
            switch result {
            case let .success(watchlistItems):
                let watchlistedItems = watchlistItems.map {
                    MediaItem(movie: $0.movie,
                              show: $0.show,
                              episode: $0.episode,
                              season: $0.season,
                              list: $0.list,
                              watchers: nil,
                              listedAt: $0.listedAt,
                              collectedAt: nil,
                              lastCollectedAt: nil,
                              notes: $0.notes)
                }

                var movieIds = Set<Int64>()
                var showIds = Set<Int64>()
                var episodeIds = Set<Int64>()
                var seasonIds = Set<Int64>()
                for item in watchlistedItems {
                    switch item.type {
                    case .movie:
                        movieIds.insert(item.movie!.identifiers.trakt!)
                    case .show:
                        showIds.insert(item.show!.identifiers.trakt!)
                    case .season:
                        seasonIds.insert(item.season!.identifiers.trakt!)
                    case .episode:
                        episodeIds.insert(item.episode!.identifiers.trakt!)
                    default:
                        continue
                    }
                }

                DispatchQueue.main.async {
                    self.watchlistedMovies = movieIds
                    self.watchlistedShows = showIds
                    self.watchlistedSeasons = seasonIds
                    self.watchlistedEpisodes = episodeIds
                    self.watchlist = watchlistedItems
                    onWatchlistChangedTransmitter.broadcast(true)
                }
            case let .failure(error):
                print("Watchlist request failure \(error)")
            }
        }
    }
}

extension MediaModel {
    var isWatchlisted: Bool {
        switch self {
        case .movie(let movie):
            return movie.isWatchlisted
        case .show(let show):
            return show.isWatchlisted
        case .episode(let episode, _):
            return episode.isWatchlisted
        case .season(let season, _):
            return season.isWatchlisted
        default:
            return false
        }
    }

    var watchlistMediaItem: MediaItem? {
        if isWatchlisted == false { return nil }
        switch self {
        case .movie(let movie):
            return WatchlistManager.shared.watchlist.first(where: { $0.movie == movie })
        case .show(let show):
            return WatchlistManager.shared.watchlist.first(where: { $0.show == show })
        case .episode(let episode, let show):
            return WatchlistManager.shared.watchlist.first(where: { $0.show == show && $0.episode == episode })
        case .season(let season, let show):
            return WatchlistManager.shared.watchlist.first(where: { $0.show == show && $0.season == season })
        default:
            return nil
        }
    }
}

extension Movie {
    var isWatchlisted: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchlistManager.shared.watchlistedMovies.contains(traktId)
    }
}

extension Show {
    var isWatchlisted: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchlistManager.shared.watchlistedShows.contains(traktId)
    }
}

extension Episode {
    var isWatchlisted: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchlistManager.shared.watchlistedEpisodes.contains(traktId)
    }
}

extension Season {
    var isWatchlisted: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchlistManager.shared.watchlistedSeasons.contains(traktId)
    }
}

extension UIView {
    func invalidateCellIntrinsicContentSize() {
        if let cell = self as? MediaTableViewCell {
            cell.invalidateIntrinsicContentSize()
            return
        }
        if let cell = self as? PulsePreviewTableViewCell {
            cell.invalidateIntrinsicContentSize()
            return
        }
        superview?.invalidateCellIntrinsicContentSize()
    }
}

final class WatchlistImageView: UIImageView {

    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            updateStatus()
        }
    }

    private func updateStatus() {
        switch media {
        case .movie(let movie):
            isHidden = !movie.isWatchlisted
        case .show(let show):
            isHidden = !show.isWatchlisted
        case .episode(let episode, _):
            isHidden = !episode.isWatchlisted
        case .season(let season, _):
            isHidden = !season.isWatchlisted
        default:
            isHidden = true
        }
        invalidateCellIntrinsicContentSize()
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onMoviesWatchlistedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let media = self.media else { return }
            if media.movie != nil {
                self.updateStatus()
            }
        }.disposed(by: disposeBag)

        onShowsWatchlistedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let media = self.media else { return }
            if media.showShow != nil {
                self.updateStatus()
            }
        }.disposed(by: disposeBag)

        onEpisodesWatchlistedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let media = self.media else { return }
            if media.episode != nil {
                self.updateStatus()
            }
        }.disposed(by: disposeBag)

        onSeasonsWatchlistedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let media = self.media else { return }
            if media.season != nil {
                self.updateStatus()
            }
        }.disposed(by: disposeBag)
    }
}
