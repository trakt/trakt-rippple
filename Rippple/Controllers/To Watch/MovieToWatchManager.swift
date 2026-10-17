//
//  MovieToWatchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/05/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import TinyStorage
import UserNotifications

let (onMovieToWatchChangedTransmitter, onMovieToWatchChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onAllMoviesToWatchChangedTransmitter, onAllMoviesToWatchChangedReceiver) = Receiver<[Movie]>.make(with: .warm(upTo: 1))
let (onMovieToWatchStatusChangedTransmitter, onMovieToWatchStatusChangedReceiver) = Receiver<MovieToWatchManager.Status>.make(with: .warm(upTo: 1))

private let movieReleaseDateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    return dateFormatter
}()

private struct MovieToWatchRelease: Codable {
    let releaseType: String
    let releaseDate: Date
    let note: String?
    let countryCode: String

    func displayText(relativeTo referenceDate: Date = .now) -> String {
        let releaseText = "\(releaseType.localizedCapitalized), \(CalendarRelativeDateFormatter.string(for: releaseDate, relativeTo: referenceDate))"

        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), note.isEmpty == false {
            return "\(releaseText) · \(note)"
        } else if let displayCountry = displayCountry {
            return "\(releaseText) · \(displayCountry)"
        } else {
            return "\(releaseText)"
        }
    }

    private var displayCountry: String? {
        let localCountry = Locale.current.language.region?.identifier.lowercased() ?? "us"
        guard countryCode.lowercased() != localCountry else { return nil }
        return Locale.current.localizedString(forRegionCode: countryCode.uppercased()) ?? countryCode
    }
}

final class MovieToWatchManager {
    private var debouncedForceRefresh: Debouncer!
    private var debouncedTransmit: Debouncer!
    private var debouncedRefreshProgress: Debouncer!

    enum Status {
        case loading
        case content
    }

    static let shared = MovieToWatchManager()

    private let disposeBag = DisposeBag()

    private init() {
        debouncedForceRefresh = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.forceRefresh()
        }
        debouncedTransmit = Debouncer(delay: 0.3) { [weak self] in
            guard let self = self else { return }
            self.transmit()
        }
        debouncedRefreshProgress = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.refreshProgress()
        }
    }

    var moviesInList: [ToWatchGroup<Movie>]? {
        didSet {
            TinyStorage.cache.store(moviesInList, forKey: "MovieToWatchManager.moviesInList")
        }
    }

    private let operationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Movie to-watch operation queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var status = Status.content {
        didSet {
            if status != oldValue {
                onMovieToWatchStatusChangedTransmitter.broadcast(status)
            }
        }
    }

    fileprivate var movies: Set<Movie>? {
        didSet {
            if let movies = movies {
                print("MovieToWatchManager.movies didSet -> Transmitting moviesToWatch")
                onAllMoviesToWatchChangedTransmitter.broadcast(Array(movies))
                TinyStorage.cache.store(movies, forKey: "MovieToWatchManager.movies")
            } else {
                TinyStorage.cache.remove(key: "MovieToWatchManager.movies")
            }
        }
    }

    private var mediaModels = [MediaModel]() {
        didSet {
            if oldValue.isEmpty {
                debouncedTransmit.fireNow()
            } else {
                debouncedTransmit.call()
            }

            TinyStorage.cache.store(mediaModels, forKey: "MovieToWatchManager.mediaModels")
        }
    }

    var filteredMediaModels: [MediaModel] {
        return mediaModels
    }

    private var releaseInfoCache = [Int64: MovieToWatchRelease]() {
        didSet {
            TinyStorage.cache.store(releaseInfoCache, forKey: "MovieToWatchManager.releaseInfoCache")
        }
    }

    func releaseLabel(for movie: Movie) -> String? {
        guard let traktId = movie.identifiers.trakt,
              let releaseInfo = releaseInfoCache[traktId] else { return nil }

        return releaseInfo.displayText()
    }

    private var timer: Timer?

    private var futureMediaModels = [MediaModel]() {
        didSet {
            debouncedTransmit.call()

            TinyStorage.cache.store(futureMediaModels, forKey: "MovieToWatchManager.futureMediaModels")

            // find the first movie that will air in the future and create a timer
            for media in futureMediaModels {
                if let movie = media.movie, let released = movie.released,
                   let releaseDate = movieReleaseDateFormatter.date(from: released), releaseDate.distance(to: .now) < 0 {
                    timer?.invalidate()
                    print("RELEASED: \(releaseDate)")
                    timer = Timer(fire: releaseDate,
                                  interval: 0,
                                  repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        print("MovieToWatchManager.debouncedForceRefresh because timer for future media was set")
                        self.debouncedForceRefresh.call()
                    }
                    if let timer = timer { RunLoop.main.add(timer, forMode: .common) }
                    break
                }
            }
        }
    }

    private func updateAppIcon() {
        DispatchQueue.main.async {
            if UserDefaults.standard.integer(forKey: "Badge.mode") == 1 {
                let count = self.filteredMediaModels.count
                UNUserNotificationCenter.current().setBadgeCount(count)
            }
            if UserDefaults.standard.integer(forKey: "Badge.mode") == 4 {
                let count = self.filteredMediaModels.count { $0.movie?.isPinned == true }
                UNUserNotificationCenter.current().setBadgeCount(count)
            }
        }
    }

    func setup() {
        if let futureMediaModels = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "MovieToWatchManager.futureMediaModels") {
            self.futureMediaModels = futureMediaModels
        }
        if let moviesInList = TinyStorage.cache.retrieve(type: [ToWatchGroup<Movie>].self, forKey: "MovieToWatchManager.moviesInList") {
            self.moviesInList = moviesInList
        }
        if let movies = TinyStorage.cache.retrieve(type: Set<Movie>.self, forKey: "MovieToWatchManager.movies") {
            self.movies = movies
        }
        if let releaseInfoCache = TinyStorage.cache.retrieve(type: [Int64: MovieToWatchRelease].self, forKey: "MovieToWatchManager.releaseInfoCache") {
            self.releaseInfoCache = releaseInfoCache
        }
        if let mediaModels = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "MovieToWatchManager.mediaModels") {
            self.mediaModels = mediaModels
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.operationQueue.cancelAllOperations()
            self.timer?.invalidate()
            self.timer = nil
            self.status = .content
            self.moviesInList = nil
            self.movies = nil
            self.mediaModels = []
            self.releaseInfoCache = [:]
            self.futureMediaModels = []
            TinyStorage.cache.remove(key: "MovieToWatchManager.moviesInList")
            TinyStorage.cache.remove(key: "MovieToWatchManager.movies")
            TinyStorage.cache.remove(key: "MovieToWatchManager.mediaModels")
            TinyStorage.cache.remove(key: "MovieToWatchManager.releaseInfoCache")
            TinyStorage.cache.remove(key: "MovieToWatchManager.futureMediaModels")
            onAllMoviesToWatchChangedTransmitter.broadcast([])
            self.debouncedTransmit.fireNow()
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("MovieToWatchManager.forceRefresh because settings changes")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                print("MovieToWatchManager.forceRefresh because app didFifnish launching")
                self.debouncedForceRefresh.call()
            case .didBecomeActive(let time):
                if time > 60 * 60 * 4 {
                    print("MovieToWatchManager.forceRefresh because did Become active after 4h")
                    self.debouncedForceRefresh.call()
                } else if time > 60 * 60 * 2 {
                    print("MovieToWatchManager.refresh progress because did become active after 2h")
                    self.debouncedRefreshProgress.call()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onMoviesWatchlistedChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if MovieToWatchSettings.shared.watchlist {
                print("MovieToWatchManager.debouncedForceRefresh because onMoviesWatchlistedChangedReceiver")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onUserFavoritesChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if MovieToWatchSettings.shared.recommended {
                print("MovieToWatchManager.debouncedForceRefresh because onUserFavoritesChangedReceiver")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onMovieCollectionChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if MovieToWatchSettings.shared.collected {
                print("MovieToWatchManager.debouncedForceRefresh because onMovieCollectionChangedReceiver")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        movieToWatchSettingsUpdatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("MovieToWatchManager.debouncedForceRefresh because movieToWatchSettingsUpdatedReceiver")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        onListChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            for list in lists where MovieToWatchSettings.shared.lists.contains(list) {
                print("MovieToWatchManager.debouncedForceRefresh because onListChangedReceiver")
                self.debouncedForceRefresh.call()
                return
            }
        }.disposed(by: disposeBag)

        onMovieSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if MovieToWatchSettings.shared.smartSearches.isEmpty == false {
                print("MovieToWatchManager.debouncedForceRefresh because onMovieSmartSearchChangedReceiver")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] watchingItem, oldWatchingItem in
            guard let self = self else { return }
            print("MovieToWatchManager.debouncedForceRefresh because onWatchingItemChangedReceiver")
            if let watchingItem = watchingItem, let movie = watchingItem.movie, (self.movies ?? Set<Movie>()).contains(movie) {
                self.debouncedForceRefresh.call()
            } else if let oldWatchingItem = oldWatchingItem, oldWatchingItem.movie != nil { // Cancel checkin or checkin ended -> check if the checkin was about a movie or do nothing
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] media in
            guard let self = self else { return }
            switch media {
            case .movie:
                print("MovieToWatchManager.debouncedRefreshProgress because onMarkWatchedReceiver")
                self.debouncedRefreshProgress.call()
            default:
                break
            }
        }.disposed(by: disposeBag)

        onRemoveWatchMediaReceiver.listen { [weak self] media in
            guard let self = self else { return }
            switch media {
            case .movie:
                print("MovieToWatchManager.debouncedRefreshProgress because onMarkWatchedReceiver")
                self.debouncedRefreshProgress.call()
            default:
                break
            }
        }.disposed(by: disposeBag)

        badgeModeReceiver.listen { [weak self] mode in
            guard let self = self else { return }
            if mode == 0 {
                UNUserNotificationCenter.current().setBadgeCount(0)
            } else {
                self.updateAppIcon()
            }
        }.disposed(by: disposeBag)

        movieToWatchGroupModeReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.call()
        }.disposed(by: disposeBag)

        movieToWatchHideDuplicatesReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTransmit.call()
        }.disposed(by: disposeBag)

        calendarDataUpdatedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self, self.movies != nil else { return }
            print("MovieToWatchManager.debouncedRefreshProgress because calendar data updated")
            self.debouncedRefreshProgress.call()
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.skipRepeats().listen { [weak self] _ in
            guard let self = self else { return }
            print("MovieToWatchManager.debouncedRefreshProgress because onSyncWatchedMoviesChangedReceiver")
            self.debouncedRefreshProgress.call()
        }.disposed(by: disposeBag)

        onPinnedMoviesToWatchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            print("MovieToWatchManager.debouncedForceRefresh because pinned movies changed")
            self.debouncedForceRefresh.call()
        }.disposed(by: disposeBag)

        onPinnedMovieToWatchAddedReceiver.listen { [weak self] movie in
            guard let self = self else { return }
            // If the added movie is already part of current movies set, refresh progress
            if let movies = self.movies, movies.contains(movie) {
                print("MovieToWatchManager.debouncedRefreshProgress because pinned movie added")
                self.debouncedRefreshProgress.call()
            } else {
                // Otherwise, a full refresh will ensure it's included
                print("MovieToWatchManager.debouncedForceRefresh because pinned movie added and not in current set")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)

        onPinnedMovieToWatchRemovedReceiver.listen { [weak self] movie in
            guard let self = self else { return }
            if let movies = self.movies, movies.contains(movie) {
                print("MovieToWatchManager.debouncedRefreshProgress because pinned movie removed")
                self.debouncedRefreshProgress.call()
            } else {
                print("MovieToWatchManager.debouncedForceRefresh because pinned movie removed and not in current set")
                self.debouncedForceRefresh.call()
            }
        }.disposed(by: disposeBag)
    }

    func forcedUserRefresh() {
        debouncedForceRefresh.call()
    }

    @MainActor
    func refreshProgressAfterWidgetAction() async {
        guard SessionManager.shared.isLoggedIn, let movies = movies else { return }

        status = .loading

        let updateMoviesWatchedOperation = UpdateMoviesWatchedOperation(movies: movies)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            updateMoviesWatchedOperation.completionBlock = {
                continuation.resume()
            }
            operationQueue.addOperation(updateMoviesWatchedOperation)
        }

        guard !updateMoviesWatchedOperation.isCancelled else { return }

        releaseInfoCache = updateMoviesWatchedOperation.releaseInfoByMovieId
        mediaModels = updateMoviesWatchedOperation.mediaModels
        futureMediaModels = updateMoviesWatchedOperation.futureMediaModels
        debouncedTransmit.fireNow()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                continuation.resume()
            }
        }
    }

    func refreshForBackgroundTask(completion: @escaping @Sendable (Bool) -> Void) {
        forceRefresh(completion: completion)
    }

    private func forceRefresh(completion: (@Sendable (Bool) -> Void)? = nil) {
        if SessionManager.shared.isLoggedOut {
            print("MovieToWatchManager.forceRefresh stop because NOT logged in")
            completion?(false)
            return
        }

        status = .loading

        print("MovieToWatchManager.forceRefresh START")

        let sourcesOperation = ToWatchSourcesOperation(sources: toWatchSources(), lastKnownGroups: moviesInList ?? [])
        sourcesOperation.completionBlock = { [weak self] in
            guard let self = self, !sourcesOperation.isCancelled else {
                completion?(false)
                return
            }
            let movies = sourcesOperation.media
            let updateMoviesWatchedOperation = UpdateMoviesWatchedOperation(movies: movies)
            updateMoviesWatchedOperation.completionBlock = { [weak self] in
                if updateMoviesWatchedOperation.isCancelled {
                    completion?(false)
                    return
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, !updateMoviesWatchedOperation.isCancelled, SessionManager.shared.isLoggedIn else {
                        completion?(false)
                        return
                    }
                    self.movies = movies
                    self.moviesInList = sourcesOperation.groups
                    self.releaseInfoCache = updateMoviesWatchedOperation.releaseInfoByMovieId
                    self.mediaModels = updateMoviesWatchedOperation.mediaModels
                    self.futureMediaModels = updateMoviesWatchedOperation.futureMediaModels
                    if let completion = completion {
                        self.debouncedTransmit.fireNow()
                        DispatchQueue.main.async {
                            completion(sourcesOperation.completedSuccessfully && updateMoviesWatchedOperation.completedSuccessfully)
                        }
                    }
                    print("MovieToWatchManager.forceRefresh STOP")
                }
            }
            self.operationQueue.addOperation(updateMoviesWatchedOperation)
        }
        operationQueue.addOperation(sourcesOperation)
    }

    private func toWatchSources() -> [ToWatchSource<Movie>] {
        let settings = MovieToWatchSettings.shared
        var sources = [ToWatchSource<Movie>.fixed(id: "pinned", name: "Pinned", order: 0, media: PinnedMoviesManager.shared.pinnedMovies)]
        if settings.watchlist {
            sources.append(.watchlist(type: .movies, order: 1, media: \.movie))
        }
        if settings.recommended {
            sources.append(.favorites(type: .movies, order: 2, media: \.movie))
        }
        if settings.collected {
            sources.append(.collection(type: .movies, order: 3, media: \.movie))
        }
        for otherList in settings.otherLists where otherList.enabled {
            if let list = otherList.list {
                sources.append(.list(list, id: otherList.id, order: 100 + otherList.rank, type: .movies, media: \.movie))
            } else if let smartSearch = otherList.smartSearch {
                sources.append(.smartSearch(smartSearch, id: otherList.id, order: 100 + otherList.rank, media: \.movie))
            }
        }
        return sources
    }

    private func refreshProgress() {
        if SessionManager.shared.isLoggedOut { return }
        guard let movies = movies else { return }

        status = .loading

        print("MovieToWatchManager.refreshProgress for all movies \(movies.count) START")

        let updateMoviesWatchedOperation = UpdateMoviesWatchedOperation(movies: movies)
        updateMoviesWatchedOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !updateMoviesWatchedOperation.isCancelled else { return }
                self.releaseInfoCache = updateMoviesWatchedOperation.releaseInfoByMovieId
                self.mediaModels = updateMoviesWatchedOperation.mediaModels
                self.futureMediaModels = updateMoviesWatchedOperation.futureMediaModels
                print("MovieToWatchManager.refreshProgress STOP")
            }
        }
        operationQueue.addOperation(updateMoviesWatchedOperation)
    }

    private func transmit() {
        print("MovieToWatchManager.mediaModels transmit MediaModels and Future MediaModels")

        onMovieToWatchChangedTransmitter.broadcast(filteredMediaModels)
        status = .content
        updateAppIcon()
    }
}

extension Movie {
    var isInToWatch: Bool {
        if UserManager.shared.currentUser == nil { return false }
        guard let moviesInToWatch = MovieToWatchManager.shared.movies else { return false }
        return moviesInToWatch.contains(self)
    }
}

private final class UpdateMoviesWatchedOperation: ToWatchAsyncOperation, @unchecked Sendable {
    private let movies: Set<Movie>
    private let releaseCallbackQueue = DispatchQueue(label: "Movie to-watch release info callback queue")
    private var sourceFetchFailed = false

    private(set) var mediaModels = [MediaModel]()
    private(set) var futureMediaModels = [MediaModel]()
    private(set) var releaseInfoByMovieId = [Int64: MovieToWatchRelease]()

    var completedSuccessfully: Bool {
        !isCancelled && !sourceFetchFailed
    }

    init(movies: Set<Movie>) {
        self.movies = movies
    }

    override func execute() {
        let unwatchedMovies = movies.filter { $0.isWatched == false }
        let releaseDispatchGroup = DispatchGroup()
        fetchReleaseInfo(for: unwatchedMovies, in: releaseDispatchGroup)

        releaseDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self, !self.isCancelled else { return }

            let excludedStatuses: Set<String?> = ["planned", "rumored", "canceled"]
            let datedMovies = unwatchedMovies.compactMap { movie -> (movie: Movie, releaseDate: Date)? in
                guard !excludedStatuses.contains(movie.status),
                      let released = movie.released,
                      let releaseDate = movieReleaseDateFormatter.date(from: released) else { return nil }
                return (movie, releaseDate)
            }
            let now = Date()
            let futureCutoff = now.advanced(by: -60 * 60 * 24 * 5)

            self.futureMediaModels = datedMovies.filter { futureCutoff <= $0.releaseDate }.map(\.movie).sorted {
                ($0.released ?? "0000-00-00", $0.title.sortableString) < ($1.released ?? "0000-00-00", $1.title.sortableString)
            }.map(\.mediaModel)
            self.mediaModels = self.sortedForToWatch(datedMovies.filter { now > $0.releaseDate }.map(\.movie))
            self.finish()
        }
    }

    private func fetchReleaseInfo(for movies: Set<Movie>, in dispatchGroup: DispatchGroup) {
        for movie in CalendarManager.shared.movieWithReleases(in: movies) {
            guard let traktId = movie.identifiers.trakt else { continue }

            dispatchGroup.enter()
            track(TraktAPIProvider.provider.request(.movieReleases(id: traktId),
                                                    callbackQueue: releaseCallbackQueue) { [weak self] result in
                    defer { dispatchGroup.leave() }
                    guard let self = self, !self.isCancelled else { return }
                    do {
                        let response = try result.get().filterSuccessfulStatusCodes()
                        let activities = try response.map([MovieReleaseActivity].self, using: TraktAPIProvider.decoder)
                        if let releaseInfo = self.closestReleaseEvent(for: movie, activities: activities) {
                            self.releaseInfoByMovieId[traktId] = releaseInfo
                        }
                    } catch {
                        self.sourceFetchFailed = true
                        print("MovieToWatchManager fetchMovieReleases request failed! \(error)")
                    }
                })
        }
    }

    private func sortedForToWatch(_ movies: [Movie]) -> [MediaModel] {
        let sortedMovies: [Movie]
        switch MovieToWatchSettings.shared.sort {
        case .automatic:
            sortedMovies = movies.sorted {
                ($0.weightedRating, $1.title.sortableString) > ($1.weightedRating, $0.title.sortableString)
            }
        case .released:
            sortedMovies = movies.sorted {
                ($0.released ?? "0000-00-00", $1.title.sortableString) > ($1.released ?? "0000-00-00", $0.title.sortableString)
            }
        case .rating:
            sortedMovies = movies.sorted {
                ($0.rating ?? 0, $1.title.sortableString) > ($1.rating ?? 0, $0.title.sortableString)
            }
        case .voteCount:
            sortedMovies = movies.sorted {
                ($0.votes ?? 0, $1.title.sortableString) > ($1.votes ?? 0, $0.title.sortableString)
            }
        case .runtime:
            sortedMovies = movies.sorted {
                ($0.runtime ?? 0, $1.title.sortableString) > ($1.runtime ?? 0, $0.title.sortableString)
            }
        case .random:
            sortedMovies = movies.shuffled()
        case .title:
            sortedMovies = movies.sorted { $0.title.sortableString < $1.title.sortableString }
        }
        let mediaModels = sortedMovies.map(\.mediaModel)
        return MovieToWatchSettings.shared.reverse ? mediaModels.reversed() : mediaModels
    }

    private func closestReleaseEvent(for movie: Movie, activities: [MovieReleaseActivity]) -> MovieToWatchRelease? {
        let candidates = releaseInfoCandidates(for: movie, from: activities)
        guard candidates.isEmpty == false else { return nil }

        let now = Date()
        return candidates.min { lhs, rhs in
            let lhsPriority = releasePriority(lhs)
            let rhsPriority = releasePriority(rhs)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            let lhsDistance = abs(lhs.releaseDate.timeIntervalSince(now))
            let rhsDistance = abs(rhs.releaseDate.timeIntervalSince(now))
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }

            return lhs.releaseDate < rhs.releaseDate
        }
    }

    private func releasePriority(_ release: MovieToWatchRelease) -> Int {
        switch release.releaseType.lowercased() {
        case "digital", "streaming":
            return 0
        case "physical":
            return 1
        case "theatrical":
            return 2
        default:
            return 3
        }
    }

    private func releaseInfoCandidates(for movie: Movie, from activities: [MovieReleaseActivity]) -> [MovieToWatchRelease] {
        return activities.filter {
            let countryCode = $0.country.lowercased()
            let localCountry = Locale.current.language.region?.identifier.lowercased() ?? "us"
            return countryCode == movie.country?.lowercased() || countryCode == localCountry
        }.map {
            MovieToWatchRelease(releaseType: $0.releaseType,
                                releaseDate: $0.releaseDate,
                                note: $0.note,
                                countryCode: $0.country)
        }
    }
}

private extension Movie {
    var weightedRating: Double {
        let m = 3000.0
        let C = 6.5
        let v = Double(votes ?? 0)
        let R = rating ?? 0
        return (v / (v + m)) * R + (m / (v + m)) * C
    }
}
