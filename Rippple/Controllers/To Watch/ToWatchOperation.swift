//
//  ToWatchOperation.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

struct ToWatchGroup<Media: Codable & Hashable>: Codable {
    let name: String
    let order: Int
    let shows: Set<Media>
    let source: String?
}

// MARK: - Asynchronous operation

class ToWatchAsyncOperation: Operation, @unchecked Sendable {
    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    // `finish()` and `cancel()` can run on network callback queues while the operation queue reads state.
    // Transitions hold `transitionLock` through their KVO notifications so they never interleave, while
    // `stateLock` only guards reads and writes, letting observers read state back synchronously.
    private let transitionLock = NSRecursiveLock()
    private let stateLock = NSLock()
    private var state = State.isReady
    private var cancellables = [Cancellable]()

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        withStateLock { state } == .isExecuting
    }

    override var isFinished: Bool {
        let state = withStateLock { self.state }
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        guard !isCancelled, transition(to: .isExecuting) else { return }
        execute()
    }

    /// Subclasses do their work here and call `finish()` once done.
    func execute() {
        finish()
    }

    func finish() {
        transition(to: .isFinished)
    }

    func track(_ cancellable: Cancellable?) {
        guard let cancellable = cancellable else { return }
        withStateLock { cancellables.append(cancellable) }
    }

    override func cancel() {
        let cancellables = withStateLock { self.cancellables }
        for cancellable in cancellables {
            cancellable.cancel()
        }
        super.cancel()
        finish()
    }

    private func withStateLock<T>(_ work: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return work()
    }

    @discardableResult
    private func transition(to newState: State) -> Bool {
        transitionLock.lock()
        defer { transitionLock.unlock() }
        let oldState = withStateLock { state }
        guard oldState != .isFinished, oldState != newState else { return false }
        willChangeValue(forKey: oldState.rawValue)
        willChangeValue(forKey: newState.rawValue)
        withStateLock { state = newState }
        didChangeValue(forKey: newState.rawValue)
        didChangeValue(forKey: oldState.rawValue)
        return true
    }
}

// MARK: - Sources

struct ToWatchSource<Media: Codable & Hashable> {
    let id: String
    let name: String
    let order: Int
    let fetch: (@escaping (Result<[Media], Error>) -> Void) -> Cancellable?
}

extension ToWatchSource {
    static func fixed(id: String, name: String, order: Int, media: Set<Media>) -> ToWatchSource {
        ToWatchSource(id: id, name: name, order: order) { completion in
            completion(.success(Array(media)))
            return nil
        }
    }

    static func watchlist(type: ListMediaType, order: Int, media: @escaping (WatchlistItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: "watchlist", name: "Watchlisted", order: order) { completion in
            TraktAPIProvider.fetchAllWatchlistItems(slug: "me", type: type, extended: .full, sort: .none) { result in
                completion(result.map { $0.compactMap(media) })
            }
            return nil
        }
    }

    static func favorites(type: ListMediaType, order: Int, media: @escaping (WatchlistItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: "favorites", name: "Favorites", order: order) { completion in
            TraktAPIProvider.fetchAllRecommendedItems(slug: "me", type: type, extended: .full, sort: .none) { result in
                completion(result.map { $0.compactMap(media) })
            }
            return nil
        }
    }

    static func collection(type: ListMediaType, order: Int, media: @escaping (CollectionItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: "collection", name: "Collected", order: order) { completion in
            TraktAPIProvider.fetchAllCollectionItems(slug: "me", type: type, extended: .full, sort: .none) { result in
                completion(result.map { $0.compactMap(media) })
            }
            return nil
        }
    }

    static func list(_ list: List, id: String, order: Int, type: ListMediaType, media: @escaping (WatchlistItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: id, name: list.name, order: order) { completion in
            TraktAPIProvider.fetchAllListItems(list: list, type: type) { result in
                completion(result.map { $0.compactMap(media) })
            }
            return nil
        }
    }

    /// Only the first few items of the media type, so a broad smart list never floods To Watch.
    static func smartList(_ smartList: SmartList,
                          id: String,
                          order: Int,
                          mediaType: SmartListMediaType,
                          media: @escaping (MediaItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: id, name: smartList.name.emojiUnescapedString, order: order) { completion in
            let includesMediaType = mediaType == .movies ? smartList.mediaType.includesMovies : smartList.mediaType.includesShows
            guard smartList.source != .unknown, includesMediaType else {
                completion(.success([]))
                return nil
            }
            // Read through the preview, narrowed to one media type, so a mixed list still gives a full page of it.
            var draft = SmartListDraft(smartList: smartList)
            draft.mediaType = mediaType
            let pageInfo = PageInfo.firstPage(with: TraktAPIProvider.smartListToWatchItemsLimit)
            return TraktAPIProvider.provider.request(.smartListPreview(draft, pageInfo: pageInfo), callbackQueue: .global(qos: .utility)) { result in
                completion(Result {
                    try result.get().filterSuccessfulStatusCodes()
                        .map([MediaItem].self, using: TraktAPIProvider.decoder)
                        .compactMap(media)
                })
            }
        }
    }

    static func smartSearch(_ smartSearch: SmartSearch, id: String, order: Int, media: @escaping (MediaItem) -> Media?) -> ToWatchSource {
        ToWatchSource(id: id, name: smartSearch.name ?? "Smart Search", order: order) { completion in
            let service = smartSearch.service
            return TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .utility)) { result in
                completion(Result {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    switch service {
                    case .popularShows, .popularMovies:
                        // Popular endpoints return bare media instead of wrapped items.
                        return try response.map([Media].self, using: TraktAPIProvider.decoder)
                    default:
                        return try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap(media)
                    }
                })
            }
        }
    }
}

// MARK: - Sources operation

/// Fetches every To Watch source and groups the results. A source that fails keeps its last known media,
/// so one broken source never freezes the whole list or drops what it contributed.
final class ToWatchSourcesOperation<Media: Codable & Hashable>: ToWatchAsyncOperation, @unchecked Sendable {
    private let sources: [ToWatchSource<Media>]
    private let lastKnownGroups: [ToWatchGroup<Media>]

    // Mutated on the main queue only.
    private(set) var media = Set<Media>()
    private(set) var groups = [ToWatchGroup<Media>]()
    private var sourceFetchFailed = false

    var completedSuccessfully: Bool {
        !isCancelled && !sourceFetchFailed
    }

    init(sources: [ToWatchSource<Media>], lastKnownGroups: [ToWatchGroup<Media>]) {
        self.sources = sources
        self.lastKnownGroups = lastKnownGroups
    }

    override func execute() {
        let dispatchGroup = DispatchGroup()
        for source in sources {
            dispatchGroup.enter()
            track(source.fetch { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    defer { dispatchGroup.leave() }
                    guard let self = self, !self.isCancelled else { return }
                    self.apply(result, from: source)
                }
            })
        }
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.finish()
        }
    }

    private func apply(_ result: Result<[Media], Error>, from source: ToWatchSource<Media>) {
        switch result {
        case .success(let fetchedMedia):
            append(Set(fetchedMedia), from: source)
        case .failure(let error):
            sourceFetchFailed = true
            print("ToWatchSourcesOperation \(source.name) failed: \(error)")
            if let lastKnownGroup = lastKnownGroups.first(where: { $0.matches(source) }) {
                print("ToWatchSourcesOperation reusing the last known media for \(source.name)")
                append(lastKnownGroup.shows, from: source)
            }
        }
    }

    private func append(_ sourceMedia: Set<Media>, from source: ToWatchSource<Media>) {
        media.formUnion(sourceMedia)
        groups.append(ToWatchGroup(name: source.name, order: source.order, shows: sourceMedia, source: source.id))
    }
}

private extension ToWatchGroup {
    func matches(_ toWatchSource: ToWatchSource<Media>) -> Bool {
        if let source = source {
            return source == toWatchSource.id
        }
        // Groups cached before sources were recorded can only be matched by name and order.
        return name == toWatchSource.name && order == toWatchSource.order
    }
}
