//
//  CollectionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import LRUCache
import Receiver
import TinyStorage
import UIKit

let (onMovieCollectionChangedTransmitter, onMovieCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onShowCollectionChangedTransmitter, onShowCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)
let (onEpisodeCollectionChangedTransmitter, onEpisodeCollectionChangedReceiver) = Receiver<[Int64]>.make(with: .hot)

private struct LibrarySnapshot: Codable {
    let userSlug: String
    /// The collected dates the items were synced against, or nil when they were fetched before the collection loaded.
    let collection: [Int64: Date]?
    /// When every item was last downloaded; syncs only download the changes, so the rest keep this date.
    let fetchedAt: Date
    let items: [CollectionItem]
}

private extension CollectionItem {
    var traktId: Int64? {
        switch type {
        case .movie:
            return movie?.identifiers.trakt
        case .show:
            return show?.identifiers.trakt
        case .episode:
            return episode?.identifiers.trakt
        default:
            return nil
        }
    }
}

final class CollectionManager: @unchecked Sendable {
    private let disposeBag = DisposeBag()

    private init() {}

    func setup() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refresh()
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refresh()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        // Settings load at every launch; only a different signed-in user needs a new collection.
        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self, let settings = settings, settings.user != self.lastRefreshedUser else { return }
            self.refresh()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.loadedCollectionTypes.removeAll()
            self.movieCollection.removeAll()
            self.showCollection.removeAll()
            self.episodeCollection.removeAll()
            self.invalidateLibraryItems()
            self.lastRefreshedUser = nil
        }.disposed(by: disposeBag)
    }

    func refresh() {
        lastRefreshedUser = UserManager.shared.currentUser
        refreshMovieCollection()
        refreshShowCollection()
    }

    static let shared = CollectionManager()

    private var lastRefreshedUser: User?

    /// Types whose collected dates have loaded since launch or the last logout.
    private var loadedCollectionTypes = Set<ListMediaType>()

    // MARK: - Library items

    private static let storedLibraryTypes: [ListMediaType] = [.movies, .shows, .episodes]
    private static let incrementalPageLimit = 50
    /// Ratings, votes and other details change without the collected dates changing, so saved items are fully reloaded after this.
    private static let libraryMaxAge: TimeInterval = 7 * 24 * 3600

    private let libraryItemsCache = LRUCache<ListMediaType, LibrarySnapshot>(countLimit: 3)
    private let libraryStorageQueue = DispatchQueue(label: "CollectionManager.libraryStorage", qos: .userInitiated)
    /// Opened lazily on `libraryStorageQueue`, one file per type so saving movies never rewrites a large episodes file.
    private var libraryStorages = [ListMediaType: TinyStorage]()

    /// Every download or save takes a new generation, so only the newest one per type may save or report its items.
    private var libraryRequestGenerations = [ListMediaType: Int]()
    /// A newer request replaces a full reload still in flight, so it reloads fully too instead of dropping it.
    private var pendingFullReloadTypes = Set<ListMediaType>()
    /// Callers waiting on each type's in-flight request; a newer request takes them over, so no Library window is left loading.
    private var libraryWaiters = [ListMediaType: [(Result<[CollectionItem], Error>) -> Void]]()
    /// Advanced on logout, so a disk read or request started before it never downloads for the former account.
    private var librarySession = 0

    func cachedLibraryItems(for type: ListMediaType) -> [CollectionItem]? {
        guard let snapshot = libraryItemsCache.value(forKey: type),
              snapshot.userSlug == UserManager.shared.currentUser?.slug else { return nil }
        return snapshot.items
    }

    /// Reports the saved items first, then the synced ones when the collection changed since they were saved.
    /// Only new and updated items are downloaded, newest first; `fullReload` or a week-old save downloads everything again.
    func fetchLibraryItems(for type: ListMediaType, fullReload: Bool, update: @escaping (Result<[CollectionItem], Error>) -> Void) {
        guard let userSlug = UserManager.shared.currentUser?.slug else { return }
        let session = librarySession
        if fullReload {
            pendingFullReloadTypes.insert(type)
        }

        loadLibrarySnapshot(for: type, userSlug: userSlug) { [weak self] storedSnapshot in
            guard let self = self, session == self.librarySession else { return }
            let snapshot = self.pendingFullReloadTypes.contains(type) ? nil : storedSnapshot
            let collection = self.loadedCollectionTypes.contains(type) ? self.collection(for: type) : nil

            if let snapshot = snapshot {
                update(.success(snapshot.items))
            }

            // Saved items stay on screen when the sync after them fails, for example offline.
            let syncUpdate: (Result<[CollectionItem], Error>) -> Void = snapshot == nil ? update : { result in
                if case .failure(let error) = result {
                    print("Library sync failed \(error)")
                    return
                }
                update(result)
            }

            guard let collection = collection else {
                // The collection change broadcast triggers the sync once it loads.
                if snapshot == nil {
                    self.downloadLibraryItems(for: type, userSlug: userSlug, collection: nil, waiter: syncUpdate)
                } else {
                    self.joinLibraryRequestInFlight(for: type, waiter: syncUpdate)
                }
                return
            }

            guard let snapshot = snapshot,
                  let syncedCollection = snapshot.collection,
                  Date().timeIntervalSince(snapshot.fetchedAt) < CollectionManager.libraryMaxAge else {
                self.downloadLibraryItems(for: type, userSlug: userSlug, collection: collection, waiter: syncUpdate)
                return
            }

            guard syncedCollection != collection else {
                // The saved items already match, so a sync still running was for a collection that no longer applies.
                if self.libraryWaiters[type] != nil {
                    _ = self.beginLibraryRequest(for: type, waiter: nil)
                    self.finishLibraryRequest(for: type, with: .success(snapshot.items))
                }
                return
            }

            let generation = self.beginLibraryRequest(for: type, waiter: syncUpdate)
            let changedDates = collection.filter { syncedCollection[$0.key] != $0.value }.values
            guard let oldestChange = changedDates.min() else {
                let items = snapshot.items.filter { $0.traktId.map { collection[$0] != nil } ?? false }
                self.storeLibrarySnapshot(LibrarySnapshot(userSlug: userSlug, collection: collection, fetchedAt: snapshot.fetchedAt, items: items), for: type)
                self.finishLibraryRequest(for: type, with: .success(items))
                return
            }

            // A margin absorbs any rounding between the collected dates and the listed dates.
            TraktAPIProvider.fetchAllCollectionItems(slug: userSlug,
                                                     type: type,
                                                     extended: .full,
                                                     sort: nil,
                                                     limit: CollectionManager.incrementalPageLimit,
                                                     collectedSince: oldestChange.addingTimeInterval(-60)) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self, self.isCurrentLibraryRequest(generation, for: type) else { return }
                    switch result {
                    case .success(let recentItems):
                        let recentIds = Set(recentItems.compactMap(\.traktId))
                        let keptItems = snapshot.items.filter { item in
                            guard let traktId = item.traktId else { return false }
                            return !recentIds.contains(traktId) && collection[traktId] != nil
                        }
                        let items = Array(Set(recentItems)) + keptItems
                        self.storeLibrarySnapshot(LibrarySnapshot(userSlug: userSlug, collection: collection, fetchedAt: snapshot.fetchedAt, items: items), for: type)
                        self.finishLibraryRequest(for: type, with: .success(items))
                    case .failure(let error):
                        self.finishLibraryRequest(for: type, with: .failure(error))
                    }
                }
            }
        }
    }

    private func invalidateLibraryItems() {
        for type in [ListMediaType.movies, .shows, .episodes] {
            _ = beginLibraryRequest(for: type, waiter: nil)
            libraryItemsCache.removeValue(forKey: type)
        }
        librarySession += 1
        pendingFullReloadTypes.removeAll()
        libraryWaiters.removeAll()
        libraryStorageQueue.async { [weak self] in
            guard let self = self else { return }
            CollectionManager.storedLibraryTypes.forEach { self.libraryStorage(for: $0).remove(key: $0.rawValue) }
        }
    }

    /// Collected dates keyed by Trakt id. Shows use their latest collected episode.
    fileprivate var movieCollection = [Int64: Date]() {
        didSet {
            if movieCollection != oldValue {
                onMovieCollectionChangedTransmitter.broadcast(Array(movieCollection.keys))
            }
        }
    }

    fileprivate var showCollection = [Int64: Date]() {
        didSet {
            if showCollection != oldValue {
                onShowCollectionChangedTransmitter.broadcast(Array(showCollection.keys))
            }
        }
    }

    fileprivate var episodeCollection = [Int64: Date]() {
        didSet {
            if episodeCollection != oldValue {
                onEpisodeCollectionChangedTransmitter.broadcast(Array(episodeCollection.keys))
            }
        }
    }
}

private extension CollectionManager {
    func collection(for type: ListMediaType) -> [Int64: Date] {
        switch type {
        case .movies:
            return movieCollection
        case .shows:
            return showCollection
        case .episodes:
            return episodeCollection
        case .seasons:
            return [:]
        }
    }

    func libraryStorage(for type: ListMediaType) -> TinyStorage {
        if let storage = libraryStorages[type] {
            return storage
        }
        let storage = TinyStorage(insideDirectory: URL.cachesDirectory, name: "rippple-library-\(type.rawValue)")
        libraryStorages[type] = storage
        return storage
    }

    func beginLibraryRequest(for type: ListMediaType, waiter: ((Result<[CollectionItem], Error>) -> Void)?) -> Int {
        if let waiter = waiter {
            libraryWaiters[type, default: []].append(waiter)
        }
        libraryRequestGenerations[type, default: 0] += 1
        return libraryRequestGenerations[type, default: 0]
    }

    /// A caller that needs no request of its own still gets the result of one already running.
    func joinLibraryRequestInFlight(for type: ListMediaType, waiter: @escaping (Result<[CollectionItem], Error>) -> Void) {
        guard libraryWaiters[type] != nil else { return }
        libraryWaiters[type]?.append(waiter)
    }

    func finishLibraryRequest(for type: ListMediaType, with result: Result<[CollectionItem], Error>) {
        let waiters = libraryWaiters.removeValue(forKey: type) ?? []
        waiters.forEach { $0(result) }
    }

    func isCurrentLibraryRequest(_ generation: Int, for type: ListMediaType) -> Bool {
        generation == libraryRequestGenerations[type, default: 0]
    }

    func loadLibrarySnapshot(for type: ListMediaType, userSlug: String, completion: @escaping (LibrarySnapshot?) -> Void) {
        if let snapshot = libraryItemsCache.value(forKey: type) {
            completion(snapshot.userSlug == userSlug ? snapshot : nil)
            return
        }

        guard CollectionManager.storedLibraryTypes.contains(type) else {
            completion(nil)
            return
        }

        libraryStorageQueue.async { [weak self] in
            guard let self = self else { return }
            let storedSnapshot = self.libraryStorage(for: type).retrieve(type: LibrarySnapshot.self, forKey: type.rawValue)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // A request that finished during the read already saved newer items.
                guard let snapshot = self.libraryItemsCache.value(forKey: type) ?? storedSnapshot,
                      snapshot.userSlug == userSlug,
                      snapshot.userSlug == UserManager.shared.currentUser?.slug else {
                    completion(nil)
                    return
                }
                self.libraryItemsCache.setValue(snapshot, forKey: type)
                completion(snapshot)
            }
        }
    }

    func downloadLibraryItems(for type: ListMediaType,
                              userSlug: String,
                              collection: [Int64: Date]?,
                              waiter: @escaping (Result<[CollectionItem], Error>) -> Void) {
        let generation = beginLibraryRequest(for: type, waiter: waiter)
        let fetchedAt = Date()
        TraktAPIProvider.fetchAllCollectionItems(slug: userSlug, type: type, extended: .full, sort: nil) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self, self.isCurrentLibraryRequest(generation, for: type) else { return }
                self.pendingFullReloadTypes.remove(type)
                switch result {
                case .success(let items):
                    let items = Array(Set(items))
                    self.storeLibrarySnapshot(LibrarySnapshot(userSlug: userSlug, collection: collection, fetchedAt: fetchedAt, items: items), for: type)
                    self.finishLibraryRequest(for: type, with: .success(items))
                case .failure(let error):
                    self.finishLibraryRequest(for: type, with: .failure(error))
                }
            }
        }
    }

    func storeLibrarySnapshot(_ snapshot: LibrarySnapshot, for type: ListMediaType) {
        libraryItemsCache.setValue(snapshot, forKey: type)

        guard CollectionManager.storedLibraryTypes.contains(type) else { return }
        libraryStorageQueue.async { [weak self] in
            guard let self = self else { return }
            self.libraryStorage(for: type).store(snapshot, forKey: type.rawValue)
        }
    }

    /// Marks the type loaded before setting it, so the change broadcast syncs against it.
    /// The first load always broadcasts, so an empty collection still replaces items saved in an earlier launch.
    func setCollection(_ collection: [Int64: Date], for type: ListMediaType) {
        let isFirstLoad = loadedCollectionTypes.insert(type).inserted
        let needsBroadcast = isFirstLoad && self.collection(for: type) == collection
        switch type {
        case .movies:
            movieCollection = collection
            if needsBroadcast { onMovieCollectionChangedTransmitter.broadcast(Array(collection.keys)) }
        case .shows:
            showCollection = collection
            if needsBroadcast { onShowCollectionChangedTransmitter.broadcast(Array(collection.keys)) }
        case .episodes:
            episodeCollection = collection
            if needsBroadcast { onEpisodeCollectionChangedTransmitter.broadcast(Array(collection.keys)) }
        case .seasons:
            break
        }
    }

    private func refreshMovieCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchMinimalMovieCollection { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let movies):
                DispatchQueue.main.async {
                    self.setCollection(movies, for: .movies)
                }
            case .failure(let error):
                print("refreshMovieCollection request failure \(error)")
            }
        }
    }

    /// The shows payload nests every collected episode, so it also fills the episode collection.
    private func refreshShowCollection() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.fetchMinimalShowCollection { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let shows):
                var showCollection = [Int64: Date]()
                var episodeCollection = [Int64: Date]()
                for (showKey, seasons) in shows {
                    guard let showId = Int64(showKey) else { continue }
                    for episodes in seasons.values {
                        for (episodeKey, collectedAt) in episodes {
                            guard let episodeId = Int64(episodeKey) else { continue }
                            episodeCollection[episodeId] = collectedAt
                            showCollection[showId] = max(showCollection[showId] ?? collectedAt, collectedAt)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.setCollection(showCollection, for: .shows)
                    self.setCollection(episodeCollection, for: .episodes)
                }
            case .failure(let error):
                print("refreshShowCollection request failure \(error)")
            }
        }
    }
}

extension MediaModel {
    var isInCollection: Bool {
        switch self {
        case .movie(let movie):
            return movie.isInCollection
        case .show(let show):
            return show.isInCollection
        case .episode(let episode, _):
            return episode.isInCollection
        default:
            return false
        }
    }

    var collectedAt: Date? {
        switch self {
        case .movie(let movie):
            return movie.identifiers.trakt.flatMap { CollectionManager.shared.movieCollection[$0] }
        case .show(let show):
            return show.identifiers.trakt.flatMap { CollectionManager.shared.showCollection[$0] }
        case .episode(let episode, _):
            return episode.identifiers.trakt.flatMap { CollectionManager.shared.episodeCollection[$0] }
        default:
            return nil
        }
    }
}

extension Movie {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.movieCollection[traktId] != nil
    }
}

extension Show {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.showCollection[traktId] != nil
    }
}

extension Episode {
    var isInCollection: Bool {
        guard let traktId = identifiers.trakt else { return false }
        return CollectionManager.shared.episodeCollection[traktId] != nil
    }
}

final class CollectedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = !movie.isInCollection
            case .show(let show):
                isHidden = !show.isInCollection
            case .episode(let episode, _):
                isHidden = !episode.isInCollection
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onMovieCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onEpisodeCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isInCollection
                case .show(let show):
                    self.isHidden = !show.isInCollection
                case .episode(let episode, _):
                    self.isHidden = !episode.isInCollection
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
