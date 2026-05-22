//
//  MovieToWatchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import TinyStorage

let (onMovieToWatchChangedTransmitter, onMovieToWatchChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (onAllMoviesToWatchChangedTransmitter, onAllMoviesToWatchChangedReceiver) = Receiver<[Movie]>.make(with: .warm(upTo: 1))
let (onMovieToWatchStatusChangedTransmitter, onMovieToWatchStatusChangedReceiver) = Receiver<MovieToWatchManager.Status>.make(with: .warm(upTo: 1))

struct MovieToWatchGroup: Codable {
    let name: String
    let order: Int
    let shows: Set<Movie>
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

    var moviesInList: [MovieToWatchGroup]? {
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

    private var timer: Timer?
    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }

    private var futureMediaModels = [MediaModel]() {
        didSet {
            debouncedTransmit.call()

            TinyStorage.cache.store(futureMediaModels, forKey: "MovieToWatchManager.futureMediaModels")

            // find the first movie that will air in the future and create a timer
            for media in futureMediaModels {
                if let movie = media.movie, let released = movie.released,
                   let releaseDate = dateFormatter.date(from: released), releaseDate.distance(to: .now) < 0 {
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
        if let moviesInList = TinyStorage.cache.retrieve(type: [MovieToWatchGroup].self, forKey: "MovieToWatchManager.moviesInList") {
            self.moviesInList = moviesInList
        }
        if let movies = TinyStorage.cache.retrieve(type: Set<Movie>.self, forKey: "MovieToWatchManager.movies") {
            self.movies = movies
        }
        if let mediaModels = TinyStorage.cache.retrieve(type: [MediaModel].self, forKey: "MovieToWatchManager.mediaModels") {
            self.mediaModels = mediaModels
        }

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

        onRecommendedChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            if MovieToWatchSettings.shared.recommended {
                print("MovieToWatchManager.debouncedForceRefresh because onRecommendedChangedReceiver")
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

        onWatchedMoviesChangedReceiver.skipRepeats().listen { [weak self] _ in
            guard let self = self else { return }
            print("MovieToWatchManager.debouncedRefreshProgress because onWatchedMoviesChangedReceiver")
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

    private func forceRefresh() {
        if SessionManager.shared.isLoggedOut {
            print("MovieToWatchManager.forceRefresh stop because NOT logged in")
            return
        }

        status = .loading

        print("MovieToWatchManager.forceRefresh START")

        let updateMoviesOperation = UpdateMoviesOperation(pinnedMovies: PinnedMoviesManager.shared.pinnedMovies)
        updateMoviesOperation.completionBlock = {
            if updateMoviesOperation.isCancelled { return }
            let movies = updateMoviesOperation.movies
            let updateMoviesWatchedOperation = UpdateMoviesWatchedOperation(movies: movies)
            updateMoviesWatchedOperation.completionBlock = {
                if updateMoviesWatchedOperation.isCancelled { return }
                self.movies = movies
                self.moviesInList = updateMoviesOperation.moviesInList
                self.mediaModels = updateMoviesWatchedOperation.mediaModels
                self.futureMediaModels = updateMoviesWatchedOperation.futureMediaModels
                print("MovieToWatchManager.forceRefresh STOP")
            }
            self.operationQueue.addOperation(updateMoviesWatchedOperation)
        }
        operationQueue.addOperation(updateMoviesOperation)
    }

    private func refreshProgress() {
        if SessionManager.shared.isLoggedOut { return }
        guard let movies = movies else { return }

        status = .loading

        print("MovieToWatchManager.refreshProgress for all movies \(movies.count) START")

        let updateMoviesWatchedOperation = UpdateMoviesWatchedOperation(movies: movies)
        updateMoviesWatchedOperation.completionBlock = {
            if updateMoviesWatchedOperation.isCancelled { return }
            self.mediaModels = updateMoviesWatchedOperation.mediaModels
            self.futureMediaModels = updateMoviesWatchedOperation.futureMediaModels
            print("MovieToWatchManager.refreshProgress STOP")
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

private class UpdateMoviesOperation: Operation, @unchecked Sendable {
    private let moviesDispatchGroup = DispatchGroup()
    private var cancellables = [Cancellable?]()

    fileprivate var movies = Set<Movie>()
    fileprivate var moviesInList = [MovieToWatchGroup]()

    private let pinnedMovies: Set<Movie>

    init(pinnedMovies: Set<Movie>) {
        self.pinnedMovies = pinnedMovies
    }

    override func cancel() {
        for cancellable in cancellables {
            cancellable?.cancel()
        }

        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        if isCancelled { return }

        state = .isExecuting

        let pinnedMovies = pinnedMovies
        movies.formUnion(pinnedMovies)
        moviesInList.append(MovieToWatchGroup(name: "Pinned", order: 0, shows: pinnedMovies))

        let toWatchSettings = MovieToWatchSettings.shared
        if toWatchSettings.watchlist {
            moviesDispatchGroup.enter()
            fetchWatchlistedMovies { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.moviesDispatchGroup.leave()
                }
            }
        }
        if toWatchSettings.recommended {
            moviesDispatchGroup.enter()
            fetchRecommendedMovies { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.moviesDispatchGroup.leave()
                }
            }
        }
        if toWatchSettings.collected {
            moviesDispatchGroup.enter()
            fetchCollectedMovies { [weak self] in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if self.isCancelled { return }
                    self.moviesDispatchGroup.leave()
                }
            }
        }
        for otherList in toWatchSettings.otherLists where otherList.enabled == true {
            if let list = otherList.list {
                moviesDispatchGroup.enter()
                fetchMovies(for: list, order: 100 + otherList.rank) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.isCancelled { return }
                        self.moviesDispatchGroup.leave()
                    }
                }
            } else if let smartSearch = otherList.smartSearch {
                moviesDispatchGroup.enter()
                fetchMovies(from: smartSearch, order: 100 + otherList.rank) { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.isCancelled { return }
                        self.moviesDispatchGroup.leave()
                    }
                }
            }
        }

        moviesDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.state = .isFinished
            }
        }
    }

    private func fetchWatchlistedMovies(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllWatchlistItems(slug: "me",
                                                type: .movies,
                                                extended: .full,
                                                sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let movies = items.map { $0.movie! }
                DispatchQueue.main.async {
                    self.movies.formUnion(movies)
                    self.moviesInList.append(MovieToWatchGroup(name: "Watchlisted", order: 1, shows: Set(movies)))
                }
            case .failure(let error):
                print("fetchWatchlistedMovies (towatch) request failure \(error)")
            }
        }
    }

    private func fetchRecommendedMovies(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllRecommendedItems(slug: "me",
                                                  type: .movies,
                                                  extended: .full,
                                                  sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let movies = items.map { $0.movie! }
                DispatchQueue.main.async {
                    self.movies.formUnion(movies)
                    self.moviesInList.append(MovieToWatchGroup(name: "Favorites", order: 2, shows: Set(movies)))
                }
            case .failure(let error):
                print("fetchRecommendedMovies (towatch) request failure \(error)")
            }
        }
    }

    private func fetchCollectedMovies(completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllCollectionItems(slug: "me",
                                                 type: .movies,
                                                 extended: .full,
                                                 sort: .none) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let movies = items.map { $0.movie! }
                DispatchQueue.main.async {
                    self.movies.formUnion(movies)
                    self.moviesInList.append(MovieToWatchGroup(name: "Collected", order: 3, shows: Set(movies)))
                }
            case .failure(let error):
                print("fetchCollectedMovies (towatch) request failure \(error)")
            }
        }
    }

    private func fetchMovies(for list: List, order: Int, completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                           id: list.identifiers.trakt!,
                                           type: .movies) { [weak self] result in
            guard let self = self else { return }
            defer { completion() }
            if self.isCancelled { return }
            switch result {
            case .success(let items):
                let movies = items.map { $0.movie! }
                DispatchQueue.main.async {
                    self.movies.formUnion(movies)
                    self.moviesInList.append(MovieToWatchGroup(name: list.name, order: order, shows: Set(movies)))
                }
            case .failure(let error):
                print("fetchMoviesforlist (towatch) request failure \(error)")
            }
        }
    }

    private func fetchMovies(from smartSearch: SmartSearch, order: Int, completion: @escaping (() -> Void)) {
        if isCancelled {
            completion()
            return
        }

        let service = smartSearch.service
        let cancellable = TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else {
                return
            }

            defer {
                completion()
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    var searchResults: [MediaItem]
                    if case .popularMovies = service {
                        searchResults = try response.map([Movie].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                    } else {
                        searchResults = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)
                    }

                    DispatchQueue.main.async {
                        let movies = searchResults.compactMap { $0.movie }
                        self.movies.formUnion(movies)
                        self.moviesInList.append(MovieToWatchGroup(name: smartSearch.name ?? "Smart Search", order: order, shows: Set(movies)))
                    }
                } catch {
                    print("fetchMovies for Smart Search (towatch) request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("fetchMovies for Smart Search (towatch) request failure \(error)")
            }
        }
        cancellables.append(cancellable)
    }
}

private class UpdateMoviesWatchedOperation: Operation, @unchecked Sendable {
    private let watchedDispatchGroup = DispatchGroup()

    private var cancellables = [Cancellable?]()

    private var unwatchedMovies = Set<Movie>()
    private var movies = Set<Movie>()

    private var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }

    fileprivate var mediaModels = [MediaModel]()
    fileprivate var futureMediaModels = [MediaModel]()

    init(movies: Set<Movie>) {
        self.movies = movies
    }

    override func cancel() {
        for cancellable in cancellables {
            cancellable?.cancel()
        }

        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var filteredMovies: [Movie] {
        if isCancelled { return [Movie]() }
        let now = Date()
        return unwatchedMovies.filter { movie -> Bool in
            if movie.status == "planned" || movie.status == "rumored" || movie.status == "canceled" {
                return false
            }
            if let released = movie.released,
               let releaseDate = dateFormatter.date(from: released) {
                return now > releaseDate
            }
            return false
        }
    }

    private var futureMovies: [Movie] {
        if isCancelled { return [Movie]() }
        let now = Date.now.advanced(by: -60 * 60 * 24 * 5)
        return unwatchedMovies.filter { movie -> Bool in
            if movie.status == "planned" || movie.status == "rumored" || movie.status == "canceled" {
                return false
            }
            if let released = movie.released,
               let releaseDate = dateFormatter.date(from: released) {
                return now <= releaseDate
            }
            return false
        }
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        guard !isCancelled else { return }

        state = .isExecuting

        unwatchedMovies = movies.filter { $0.isWatched == false }

        watchedDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }

            self.futureMediaModels = self.futureMovies.sorted {
                ($0.released ?? "0000-00-00", $0.title.sortableString) < ($1.released ?? "0000-00-00", $1.title.sortableString)
            }.compactMap { $0.mediaModel }

            self.sortByReleaseYear()

            switch MovieToWatchSettings.shared.sort {
            case .released:
                self.sortByReleaseYear()
            case .rating:
                self.sortByRating()
            case .voteCount:
                self.sortByVotes()
            case .runtime:
                self.sortByRuntime()
            case .random:
                self.sortByRandom()
            case .automatic:
                self.sortByAutomatic()
            case .title:
                self.sortByTitle()
            }

            if MovieToWatchSettings.shared.reverse {
                self.mediaModels.reverse()
            }

            self.state = .isFinished
        }
    }

    private func sortByAutomatic() {
        if isCancelled { return }

        var mediaModels = [MediaModel]()
        for movie in filteredMovies.sorted(by: { movie, anotherMovie -> Bool in
            let m = 3000.0
            let C = 6.5
            var v = Double(movie.votes ?? 0)
            var R = movie.rating ?? 0
            let firstWeightedRating = (v / (v + m)) * R + (m / (v + m)) * C
            v = Double(anotherMovie.votes ?? 0)
            R = anotherMovie.rating ?? 0
            let secondWeightedRating = (v / (v + m)) * R + (m / (v + m)) * C
            return (firstWeightedRating, anotherMovie.title.sortableString) > (secondWeightedRating, movie.title.sortableString)
        }) {
            mediaModels.append(movie.mediaModel)
        }

        self.mediaModels = mediaModels
    }

    private func sortByReleaseYear() {
        if isCancelled { return }

        mediaModels = filteredMovies.sorted {
            ($0.released ?? "0000-00-00", $1.title.sortableString) > ($1.released ?? "0000-00-00", $0.title.sortableString)
        }.compactMap { $0.mediaModel }
    }

    private func sortByRuntime() {
        if isCancelled { return }

        mediaModels = filteredMovies.sorted {
            ($0.runtime ?? 0, $1.title.sortableString) > ($1.runtime ?? 0, $0.title.sortableString)
        }.compactMap { $0.mediaModel }
    }

    private func sortByRandom() {
        if isCancelled { return }

        mediaModels = filteredMovies.shuffled().compactMap { $0.mediaModel }
    }

    private func sortByRating() {
        if isCancelled { return }

        mediaModels = filteredMovies.sorted {
            ($0.rating ?? 0, $1.title.sortableString) > ($1.rating ?? 0, $0.title.sortableString)
        }.compactMap { $0.mediaModel }
    }

    private func sortByTitle() {
        if isCancelled { return }

        mediaModels = filteredMovies.sorted {
            $0.title.sortableString < $1.title.sortableString
        }.compactMap { $0.mediaModel }
    }

    private func sortByVotes() {
        if isCancelled { return }

        mediaModels = filteredMovies.sorted {
            ($0.votes ?? 0, $1.title.sortableString) > ($1.votes ?? 0, $0.title.sortableString)
        }.compactMap { $0.mediaModel }
    }
}
