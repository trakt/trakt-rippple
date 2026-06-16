//
//  SyncWatchedManager.swift
//  Rippple
//
//  Created by Kevin Cador on 14/06/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation
import Receiver
import TinyStorage

let (onSyncWatchedMoviesChangedTransmitter, onSyncWatchedMoviesChangedReceiver) = Receiver<Set<Int64>>.make(with: .warm(upTo: 1))
let (onSyncWatchedShowsChangedTransmitter, onSyncWatchedShowsChangedReceiver) = Receiver<Set<Int64>>.make(with: .warm(upTo: 1))
let (onSyncWatchedEpisodesChangedTransmitter, onSyncWatchedEpisodesChangedReceiver) = Receiver<Set<Int64>>.make(with: .warm(upTo: 1))

final class SyncWatchedManager {
    private enum CacheKey {
        static let movies = "SyncWatchedManager.movieWatchedItems"
        static let shows = "SyncWatchedManager.showWatchedItems"
        static let episodes = "SyncWatchedManager.episodeWatchedItems"
    }

    static let shared = SyncWatchedManager()

    private let disposeBag = DisposeBag()

    private var lastShowsAndEpisodesCheck: Date = .now
    private var lastMoviesCheck: Date = .now

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

    private(set) var movieWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:]) {
        didSet {
            watchedMovies = Set(movieWatchedItems.watchedDatesByTraktId.keys)
            TinyStorage.cache.store(movieWatchedItems, forKey: CacheKey.movies)
            onSyncWatchedMoviesChangedTransmitter.broadcast(watchedMovies)
        }
    }

    private(set) var showWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:]) {
        didSet {
            watchedShows = Set(showWatchedItems.watchedDatesByTraktId.keys)
            watchedSeasons = showWatchedItems.watchedSeasonIds
            TinyStorage.cache.store(showWatchedItems, forKey: CacheKey.shows)
            onSyncWatchedShowsChangedTransmitter.broadcast(watchedShows)
        }
    }

    private(set) var episodeWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:]) {
        didSet {
            watchedEpisodes = Set(episodeWatchedItems.watchedDatesByTraktId.keys)
            TinyStorage.cache.store(episodeWatchedItems, forKey: CacheKey.episodes)
            onSyncWatchedEpisodesChangedTransmitter.broadcast(watchedEpisodes)
        }
    }

    private(set) var watchedMovies = Set<Int64>()
    private(set) var watchedShows = Set<Int64>()
    private(set) var watchedSeasons = Set<Int64>()
    private(set) var watchedEpisodes = Set<Int64>()

    func setup() {
        loadCachedItems()
        setupListeners()

        lastShowsAndEpisodesCheck = .now
        lastMoviesCheck = .now
        refresh()
    }

    func refresh() {
        refreshWatchedMovies()
        refreshWatchedShows()
        refreshWatchedEpisodes()
    }

    func refreshWatchedMovies() {
        debouncedRefreshWatchedMovies.call()
    }

    func refreshWatchedShows() {
        debouncedRefreshWatchedShows.call()
    }

    func refreshWatchedEpisodes() {
        debouncedRefreshWatchedEpisodes.call()
    }

    func isWatched(type: SyncWatchedType, traktId: Int64) -> Bool {
        switch type {
        case .movies:
            return watchedMovies.contains(traktId)
        case .shows:
            return watchedShows.contains(traktId)
        case .episodes:
            return watchedEpisodes.contains(traktId)
        }
    }

    func isSeasonWatchedAtLeastOnce(traktId: Int64) -> Bool {
        return watchedSeasons.contains(traktId)
    }

    func watchedDates(for type: SyncWatchedType, traktId: Int64) -> [Date] {
        switch type {
        case .movies:
            return movieWatchedItems[traktId] ?? []
        case .shows:
            return showWatchedItems[traktId] ?? []
        case .episodes:
            return episodeWatchedItems[traktId] ?? []
        }
    }

    func lastWatchedAt(for type: SyncWatchedType, traktId: Int64) -> Date? {
        return watchedDates(for: type, traktId: traktId).max()
    }
}

private extension SyncWatchedManager {
    func loadCachedItems() {
        if let items = TinyStorage.cache.retrieve(type: SyncWatchedItems.self, forKey: CacheKey.movies) {
            movieWatchedItems = items
        }

        if let items = TinyStorage.cache.retrieve(type: SyncWatchedItems.self, forKey: CacheKey.shows) {
            showWatchedItems = items
        }

        if let items = TinyStorage.cache.retrieve(type: SyncWatchedItems.self, forKey: CacheKey.episodes) {
            episodeWatchedItems = items
        }
    }

    func setupListeners() {
        onLastWatchedEpisodeActivitiesChangedReceiver.listen { [weak self] lastActivities in
            guard let self = self else { return }
            if self.lastShowsAndEpisodesCheck < lastActivities.watchedAt {
                self.lastShowsAndEpisodesCheck = .now
                self.refreshWatchedShows()
                self.refreshWatchedEpisodes()
            }
        }.disposed(by: disposeBag)

        onLastWatchedMovieActivitiesChangedReceiver.listen { [weak self] lastActivities in
            guard let self = self else { return }
            if self.lastMoviesCheck < lastActivities.watchedAt {
                self.lastMoviesCheck = .now
                self.refreshWatchedMovies()
            }
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.lastShowsAndEpisodesCheck = .now
                    self.lastMoviesCheck = .now
                    self.refresh()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.hotOnly().listen { [weak self] settings in
            guard let self = self else { return }
            if settings != nil {
                self.lastShowsAndEpisodesCheck = .now
                self.lastMoviesCheck = .now
                self.refresh()
            } else {
                self.lastShowsAndEpisodesCheck = .now
                self.lastMoviesCheck = .now
                self.movieWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:])
                self.showWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:])
                self.episodeWatchedItems = SyncWatchedItems(watchedDatesByTraktId: [:])
            }
        }.disposed(by: disposeBag)
    }

    func performRefreshWatchedMovies() {
        performRefreshWatchedItems(type: .movies) { [weak self] items in
            guard let self = self else { return }
            self.movieWatchedItems = items
        }
    }

    func performRefreshWatchedShows() {
        performRefreshWatchedItems(type: .shows) { [weak self] items in
            guard let self = self else { return }
            self.showWatchedItems = items
        }
    }

    func performRefreshWatchedEpisodes() {
        performRefreshWatchedItems(type: .episodes) { [weak self] items in
            guard let self = self else { return }
            self.episodeWatchedItems = items
        }
    }

    func performRefreshWatchedItems(type: SyncWatchedType, assign: @escaping (SyncWatchedItems) -> Void) {
        if SessionManager.shared.isLoggedOut {
            return
        }

        TraktAPIProvider.fetchSyncWatchedItems(type: type) { result in
            switch result {
            case .success(let items):
                DispatchQueue.main.async {
                    assign(items)
                }
            case .failure(let error):
                print("Sync Watched \(type.rawValue.capitalized) request failure \(error)")
            }
        }
    }
}
