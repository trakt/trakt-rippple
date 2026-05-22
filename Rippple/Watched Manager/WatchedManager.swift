//
//  WatchedManager.swift
//  Rippple
//
//  Created by Kevin Cador on 10/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Foundation
import Receiver
import TinyStorage
import UIKit

extension TinyStorage {
    static let cache: TinyStorage = {
        let containerURL = URL.cachesDirectory
        return .init(insideDirectory: containerURL, name: "rippple-tiny-cache")
    }()
}

let (onWatchedMoviesChangedTransmitter, onWatchedMoviesChangedReceiver) = Receiver<Set<Int64>>.make(with: .warm(upTo: 1))
let (onWatchedShowsChangedTransmitter, onWatchedShowsChangedReceiver) = Receiver<Set<Int64>>.make(with: .warm(upTo: 1))

final class WatchedManager {
    private let disposeBag = DisposeBag()

    private var debouncedRefreshWatchedMovies: Debouncer!
    private var debouncedRefreshWatchedShows: Debouncer!
    private var debouncedRefreshWatchedEpisodes: Debouncer!

    private init() {
        debouncedRefreshWatchedMovies = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.performRefreshWatchedMovies()
        }
        debouncedRefreshWatchedShows = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.performRefreshWatchedShows()
        }
        debouncedRefreshWatchedEpisodes = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.performRefreshWatchedEpisodes()
        }
    }

    private var lastShowsAndEpisodesCheck: Date = .now
    private var lastMoviesCheck: Date = .now

    func setup() {
        if let array = TinyStorage.cache.retrieve(type: [WatchedItem].self, forKey: "WatchedManager.showsHistoryItems") {
            showsHistoryItems = array
        }

        if let array = TinyStorage.cache.retrieve(type: [WatchedItem].self, forKey: "WatchedManager.moviesHistoryItems") {
            moviesHistoryItems = array
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
                }

                if let data = UserDefaults.standard.data(forKey: "WatchedManager.moviesHistoryItems"), let array = try? PropertyListDecoder().decode([WatchedItem].self, from: data) {
                    self.moviesHistoryItems = array
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

    var watchedMoviesItems: [WatchedItem] {
        return moviesHistoryItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    var watchedShowsItems: [WatchedItem] {
        return showsHistoryItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
    }

    fileprivate var showsHistoryItems = [WatchedItem]() {
        didSet {
            watchedShows = Set(showsHistoryItems.compactMap { $0.show?.identifiers.trakt })
            rewatchingShows = Set(showsHistoryItems.filter { $0.resetAt != nil }.compactMap { $0.show?.identifiers.trakt })

            if oldValue.isEmpty == false {
                let oldShows = Set(oldValue)
                let newShows = Set(showsHistoryItems)
                let changedShows = oldShows.symmetricDifference(newShows).compactMap { $0.show }.removingDuplicates()
                for show in changedShows {
                    print("Refreshing progress for \(show.title) because history changed...")
                    ProgressManager.shared.refreshProgress(for: show)
                }
            }

            TinyStorage.cache.store(showsHistoryItems, forKey: "WatchedManager.showsHistoryItems")
            onWatchedShowsChangedTransmitter.broadcast(watchedShows)
        }
    }

    fileprivate var moviesHistoryItems = [WatchedItem]() {
        didSet {
            watchedMovies = Set(moviesHistoryItems.compactMap { $0.movie?.identifiers.trakt })
            TinyStorage.cache.store(moviesHistoryItems, forKey: "WatchedManager.moviesHistoryItems")
            onWatchedMoviesChangedTransmitter.broadcast(watchedMovies)
        }
    }

    fileprivate var episodeHistoryItems = [HistoryItem]() {
        didSet {
            TinyStorage.cache.store(episodeHistoryItems, forKey: "WatchedManager.episodeHistoryItems")
        }
    }

    fileprivate var watchedEpisodes = [Int64]()

    fileprivate var watchedShows = Set<Int64>()
    fileprivate var watchedMovies = Set<Int64>()

    fileprivate var rewatchingShows = Set<Int64>()
}

extension WatchedManager {
    private func refreshWatchedEpisodes() {
        debouncedRefreshWatchedEpisodes.call()
    }

    func refreshWatchedMovies() {
        debouncedRefreshWatchedMovies.call()
    }

    func refreshWatchedShows() {
        debouncedRefreshWatchedShows.call()
    }

    private func performRefreshWatchedEpisodes() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.history(type: .episodes, id: nil, pageInfo: PageInfo.firstPage(with: 100), endDate: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
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
            case .failure(let error):
                print("History request failure \(error)")
            }
        }
    }

    private func performRefreshWatchedMovies() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllWatchedItems(type: .movies,
                                              extended: .full) { result in
            switch result {
            case .success(let items):
                DispatchQueue.main.async {
                    self.moviesHistoryItems = items
                }
            case .failure(let error):
                print("Watched Movies request failure \(error)")
                DispatchQueue.main.async {
                    onWatchedMoviesChangedTransmitter.broadcast(self.watchedMovies)
                }
            }
        }
    }

    private func performRefreshWatchedShows() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchAllWatchedItems(slug: "me",
                                              type: .shows,
                                              extended: .fullnoseasons) { result in
            switch result {
            case .success(let items):
                DispatchQueue.main.async {
                    self.showsHistoryItems = items
                }
            case .failure(let error):
                print("Watched Shows request failure \(error)")
                DispatchQueue.main.async {
                    onWatchedShowsChangedTransmitter.broadcast(self.watchedShows)
                }
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
