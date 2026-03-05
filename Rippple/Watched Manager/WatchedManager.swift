//
//  WatchedManager.swift
//  Rippple
//
//  Created by Kevin Cador on 10/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Foundation
import UIKit

import Receiver

import TinyStorage

extension TinyStorage {
    static let cache: TinyStorage = {
        let containerURL = URL.cachesDirectory
        return .init(insideDirectory: containerURL, name: "rippple-tiny-cache")
    }()
}

let (onWatchedMoviesChangedTransmitter, onWatchedMoviesChangedReceiver) = Receiver<[WatchedItem]>.make(with: .warm(upTo: 1))
let (onWatchedShowsChangedTransmitter, onWatchedShowsChangedReceiver) = Receiver<[WatchedItem]>.make(with: .warm(upTo: 1))

let (onWatchedShowsSetChangedTransmitter, onWatchedShowsSetChangedReceiver) = Receiver<Set<WatchedItem>>.make(with: .warm(upTo: 1))
let (onWatchedShowsChangedRemoteTransmitter, onWatchedShowsSetChangedRemoteReceiver) = Receiver<Bool>.make(with: .hot)

final class WatchedManager {

    private let disposeBag = DisposeBag()

    private init() { }

    private var lastShowsAndEpisodesCheck: Date = .now
    private var lastMoviesCheck: Date = .now

    func setup() {
        if let array = TinyStorage.cache.retrieve(type: [WatchedItem].self, forKey: "WatchedManager.showsHistoryItems") {
            showsHistoryItems = array
            let showsIds = showsHistoryItems.compactMap { $0.show?.identifiers.trakt }
            let rewatchingIds = showsHistoryItems.filter { $0.resetAt != nil }.compactMap { $0.show?.identifiers.trakt }
            watchedShows = showsIds
            rewatchingShows = rewatchingIds
        }

        if let array = TinyStorage.cache.retrieve(type: [WatchedItem].self, forKey: "WatchedManager.moviesHistoryItems") {
            moviesHistoryItems = array
            watchedMovies = moviesHistoryItems.map { $0.movie!.identifiers.trakt! }
        }

        if let array = TinyStorage.cache.retrieve(type: [HistoryItem].self, forKey: "WatchedManager.episodeHistoryItems") {
            episodeHistoryItems = array
            let episodeIds = episodeHistoryItems.map { $0.episode!.identifiers.trakt! }
            watchedEpisodes = episodeIds
        }

        onLastWatchedEpisodeActivitiesChangedReceiver.listen { lastActivities in
            if self.lastShowsAndEpisodesCheck < lastActivities.watchedAt {
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
                onWatchedShowsChangedRemoteTransmitter.broadcast(true)
            }
        }.disposed(by: disposeBag)

        onLastWatchedMovieActivitiesChangedReceiver.listen { lastActivities in
            if self.lastMoviesCheck < lastActivities.watchedAt {
                self.lastMoviesCheck = .now
                self.refreshWatchedMovies()
            }
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.lastShowsAndEpisodesCheck = .now
                    self.lastMoviesCheck = .now
                    self.refreshWatchedShows()
                    self.refreshWatchedEpisodes()
                    self.refreshWatchedMovies()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.hotOnly().listen { settings in
            if settings != nil {
                if let data = UserDefaults.standard.data(forKey: "WatchedManager.showsHistoryItems"), let array = try? PropertyListDecoder().decode([WatchedItem].self, from: data) {
                    self.showsHistoryItems = array
                    self.watchedShows = self.showsHistoryItems.map { $0.show!.identifiers.trakt! }
                }

                if let data = UserDefaults.standard.data(forKey: "WatchedManager.moviesHistoryItems"), let array = try? PropertyListDecoder().decode([WatchedItem].self, from: data) {
                    self.moviesHistoryItems = array
                    self.watchedMovies = self.moviesHistoryItems.map { $0.movie!.identifiers.trakt! }
                }
                self.lastShowsAndEpisodesCheck = .now
                self.lastMoviesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
                self.refreshWatchedMovies()
            } else {
                self.lastShowsAndEpisodesCheck = .now
                self.lastMoviesCheck = .now
                self.showsHistoryItems.removeAll()
                self.moviesHistoryItems.removeAll()
                self.episodeHistoryItems.removeAll()
                self.watchedEpisodes.removeAll()
                self.watchedShows.removeAll()
                self.watchedMovies.removeAll()
                self.rewatchingShows.removeAll()
            }
        }.disposed(by: disposeBag)

        // refresh if checkin in in progress
        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { watchingItem, oldWatchingItem in
            if let watchingItem = watchingItem, watchingItem.episode != nil {
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
            } else if let oldWatchingItem = oldWatchingItem, oldWatchingItem.episode != nil {
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
            } else {
                self.refreshWatchedMovies()
            }
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { media in
            switch media {
            case .episode, .show, .season:
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
            default:
                self.refreshWatchedMovies()
            }
        }.disposed(by: disposeBag)

        onRemoveWatchMediaReceiver.listen { media in
            switch media {
            case .movie:
                self.refreshWatchedMovies()
            case .episode:
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedEpisodes()
                self.refreshWatchedShows()
            default:
                break
            }
        }.disposed(by: disposeBag)

        onLastHiddenShowActivitiesChangedReceiver.listen { _ in
            self.lastShowsAndEpisodesCheck = .now
            self.refreshWatchedShows()
        }.disposed(by: disposeBag)

        lastShowsAndEpisodesCheck = .now
        lastMoviesCheck = .now
        refreshWatchedEpisodes()
        refreshWatchedMovies()
        refreshWatchedShows()
    }

    static let shared = WatchedManager()

    var watchedMoviesMediaModels: [MediaModel] {
        return moviesHistoryItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }.compactMap { $0.movie?.mediaModel }
    }
    var watchedShowsMediaModels: [MediaModel] {
        return showsHistoryItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }.compactMap { $0.show?.mediaModel }
    }

    fileprivate var showsHistoryItems = [WatchedItem]() {
        didSet {
            if oldValue.isEmpty == false {
                let oldShows = Set(oldValue)
                let newShows = Set(showsHistoryItems)
                let changedShows = oldShows.symmetricDifference(newShows).compactMap { $0.show }.removingDuplicates()
                for show in changedShows {
                    print("Refreshing progress for \(show.title) because history changed...")
                    ProgressManager.shared.refreshProgress(for: show)
                }
                if Set(oldShows.compactMap { $0.show }) != Set(newShows.compactMap { $0.show }) {
                    onWatchedShowsSetChangedTransmitter.broadcast(newShows)
                }
            }
            onWatchedShowsChangedTransmitter.broadcast(showsHistoryItems)
            TinyStorage.cache.store(showsHistoryItems, forKey: "WatchedManager.showsHistoryItems")
        }
    }
    fileprivate var moviesHistoryItems = [WatchedItem]() {
        didSet {
            onWatchedMoviesChangedTransmitter.broadcast(moviesHistoryItems)
            TinyStorage.cache.store(moviesHistoryItems, forKey: "WatchedManager.moviesHistoryItems")
        }
    }

    fileprivate var episodeHistoryItems = [HistoryItem]() {
        didSet {
            TinyStorage.cache.store(episodeHistoryItems, forKey: "WatchedManager.episodeHistoryItems")
        }
    }

    fileprivate var watchedEpisodes = [Int64]()

    fileprivate var watchedShows = [Int64]()
    fileprivate var watchedMovies = [Int64]()

    fileprivate var rewatchingShows = [Int64]()
}

private extension WatchedManager {

    private func refreshWatchedEpisodes() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.history(type: .episodes, id: nil, pageInfo: PageInfo.firstPage(with: 100), endDate: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)
                    let episodeIds = items.map { $0.episode!.identifiers.trakt! }

                    DispatchQueue.main.async {
                        self.watchedEpisodes = episodeIds
                        self.episodeHistoryItems = items
                    }
                } catch {
                    print("History request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("History request failure \(error)")
            }
        }
    }

    private func refreshWatchedMovies() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.watched(type: .movies,
                                                   extended: .full),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder)
                    let moviesIds = items.map { $0.movie!.identifiers.trakt! }

                    DispatchQueue.main.async {
                        self.watchedMovies = moviesIds
                        self.moviesHistoryItems = items
                    }
                } catch {
                    print("Watched Movies request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Watched Movies request failure \(error)")
            }
        }
    }

    private func refreshWatchedShows() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.syncWatched(type: .shows,
                                                   extended: .full),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder)
                    let showsIds = items.compactMap { $0.show?.identifiers.trakt }
                    let rewatchingIds = items.filter { $0.resetAt != nil }.compactMap { $0.show?.identifiers.trakt }

                    DispatchQueue.main.async {
                        self.watchedShows = showsIds
                        self.rewatchingShows = rewatchingIds
                        self.showsHistoryItems = items
                    }
                } catch {
                    print("Watched Shows request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Watched Shows request failure \(error)")
            }
        }
    }
}

extension Movie {
    var isWatched: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchedManager.shared.watchedMovies.contains(traktId)
    }
}

extension Episode {
    var isRecentlyWatched: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchedManager.shared.watchedEpisodes.contains(traktId)
    }
}

extension Show {
    var isWatchedAtLeastOnce: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchedManager.shared.watchedShows.contains(traktId)
    }

    var isBingeWatched: Bool {
        var episodeCountSeenRecently = 0
        for episodeWatchedItem in WatchedManager.shared.episodeHistoryItems where episodeWatchedItem.show == self {
            episodeCountSeenRecently += 1
        }
        if episodeCountSeenRecently > 5 {
            return true
        } else {
            return false
        }
    }
}

extension Show {
    var isRewatching: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return WatchedManager.shared.rewatchingShows.contains(traktId)
    }
}

extension Cast {
    var isRencentlyWatched: Bool {
        if let show = show { return show.isWatchedAtLeastOnce }
        if let movie = movie { return movie.isWatched }
        return false
    }

    var recentlyWatchedAt: Date? {
        if let show = show {
            for item in WatchedManager.shared.showsHistoryItems where item.show == show {
                return item.lastWatchedAt
            }
        } else if let movie = movie {
            for item in WatchedManager.shared.moviesHistoryItems where item.movie == movie {
                return item.lastWatchedAt
            }
        }
        return nil
    }
}
