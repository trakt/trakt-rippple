//
//  CalendarManager.swift
//  Rippple
//
//  Created by Kevin Cador on 10/10/2025.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import TinyStorage

struct CalendarData: Codable {
    let shows: [ShowEpisodeCalendarItem]
    let movies: [CalendarMovieRelease]
    let trendingShows: Set<Show>
    let anticipatedShows: Set<Show>
    let trendingMovies: Set<Movie>
    let anticipatedMovies: Set<Movie>

    let nextEpisodes: [MediaModel]
    let nextMovies: [MediaModel]
}

struct CalendarMovieRelease: Codable, Hashable {
    enum ReleaseType: String, Codable {
        case premiere
        case physical
        case streaming

        var tag: String {
            switch self {
            case .premiere:
                return "Premiere"
            case .physical:
                return "Physical Release"
            case .streaming:
                return "Start Streaming"
            }
        }
    }

    let movie: Movie
    let released: Date
    let releaseType: ReleaseType

    var tag: String {
        return releaseType.tag
    }

    var releaseCountryCode: String? {
        switch releaseType {
        case .premiere:
            return movie.country
        case .physical, .streaming:
            return "US"
        }
    }

    var mediaModel: MediaModel {
        return movie.mediaModel
    }
}

let (calendarDataUpdatedTransmitter, calendarDataUpdatedReceiver) = Receiver<CalendarData>.make(with: .warm(upTo: 1))

let (nextMoviesTransmitter, nextMoviesReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (nextEpisodesTransmitter, nextEpisodesReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (calendarSearchableDataSourceTransmitter, calendarSearchableDataSourceReceiver) = Receiver<ToWatchSearchableDataSource>.make(with: .warm(upTo: 1))

final class CalendarManager {
    static let shared = CalendarManager()

    private let disposeBag = DisposeBag()

    private var debouncedReload: Debouncer!

    private init() {}

    private var cachedData: CalendarData? {
        didSet {
            transmitSearchableDataSource()
            transmitCachedData()
        }
    }

    private let storage = TinyStorage.cache
    private let storageKey = "CalendarManager.calendarCache"

    func setup() {
        loadCacheFromDisk()
        if cachedData == nil {
            Task {
                do {
                    try await self.reload(force: true)
                } catch {
                    print("CalendarManager error \(#function) : \(error)")
                }
            }
        }

        debouncedReload = Debouncer(delay: 5.0) {
            Task {
                do {
                    try await self.reload(force: true)
                } catch {
                    print("CalendarManager error \(#function) : \(error)")
                }
            }
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cachedData = nil
            self.storage.remove(key: self.storageKey)
            nextMoviesTransmitter.broadcast([])
            nextEpisodesTransmitter.broadcast([])
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.hotOnly().listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60 * 60 * 2 {
                    self.debouncedReload.call()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onWatchlistChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onRecommendedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onMovieCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onShowsToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.transmitSearchableDataSource()
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onListChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onSyncWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onShowsHiddenFromCalendarMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onMoviesHiddenFromCalendarMediaChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        // Settings changes
        calendarSettingsUpdatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.fireNow()
        }.disposed(by: disposeBag)

        // Day change
        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }

        let refreshOnUpcomingChange: (Bool) -> Void = { [weak self] _ in
            guard let self = self else { return }
            self.transmitCachedData()
            self.transmitSearchableDataSource()
        }

        movieUpcomingEnabledReceiver.listen(to: refreshOnUpcomingChange).disposed(by: disposeBag)
        episodeUpcomingEnabledReceiver.listen(to: refreshOnUpcomingChange).disposed(by: disposeBag)
        episodeToWatchBingeableOnlyReceiver.listen(to: refreshOnUpcomingChange).disposed(by: disposeBag)
    }

    private func transmitCachedData() {
        guard let cachedData = cachedData else { return }
        print("Sending CalendarManager CachedData")
        calendarDataUpdatedTransmitter.broadcast(cachedData)
        nextMoviesTransmitter.broadcast(cachedData.nextMovies)
        nextEpisodesTransmitter.broadcast(cachedData.nextEpisodes)
    }

    private func transmitSearchableDataSource() {
        guard let cachedData = cachedData else {
            calendarSearchableDataSourceTransmitter.broadcast(.empty)
            return
        }
        calendarSearchableDataSourceTransmitter.broadcast(ToWatchSearchableDataSource(
            shows: cachedData.nextEpisodesWithBingeableFinales,
            movies: cachedData.nextMovies
        ))
    }

    private func loadCacheFromDisk() {
        cachedData = try? storage.retrieveOrThrow(type: CalendarData.self, forKey: storageKey)
    }

    private func saveCacheToDisk(_ data: CalendarData) {
        storage.store(data, forKey: storageKey)
    }

    private func loadCacheFromDiskIfNeeded() -> CalendarData? {
        if cachedData == nil {
            loadCacheFromDisk()
        }

        return cachedData
    }

    func movieWithReleases(in movies: Set<Movie>) -> [Movie] {
        guard let cachedData = loadCacheFromDiskIfNeeded() else { return [] }
        let now = Date()

        return cachedData.movies
            .filter { movies.contains($0.movie) }
            .sorted { lhs, rhs in
                abs(lhs.released.timeIntervalSince(now)) < abs(rhs.released.timeIntervalSince(now))
            }
            .map { $0.movie }
            .removingDuplicates()
    }

    @discardableResult
    private func reload(referenceDate: Date = .now, force: Bool = false) async throws -> CalendarData {
        if force == false, let cachedData = cachedData {
            return cachedData
        }

        // UserDefaults flags
        let myShows = UserDefaults.standard.bool(forKey: "CalendarSettings.myShows")
        let filtersShowToWatch = UserDefaults.standard.bool(forKey: "CalendarSettings.filtersShowToWatch")
        let addAnticipatedShows = UserDefaults.standard.bool(forKey: "CalendarSettings.addAnticipatedShows")
        let addTrendingShows = UserDefaults.standard.bool(forKey: "CalendarSettings.addTrendingShows")
        let myMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.myMovies")
        let addTrendingMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.addTrendingMovies")
        let addAnticipatedMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.addAnticipatedMovies")
        let hideHiddenMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.hideHiddenMovies")
        let hideHiddenShows = UserDefaults.standard.bool(forKey: "CalendarSettings.hideHiddenShows")
        let hideRecentlyWatchedMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.hideRecentlyWatchedMovies")
        let hideRecentlyWatchedShows = UserDefaults.standard.bool(forKey: "CalendarSettings.hideRecentlyWatchedShows")

        let dayRange: TimeInterval = 33 * 60 * 60 * 24

        // Shows
        let myPastShows: [ShowEpisodeCalendarItem] = try myShows ? (await fetchMyShowCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureShows: [ShowEpisodeCalendarItem] = try myShows ? (await fetchMyShowCalendar(date: referenceDate, days: 33)) : []
        let rawMyShows = (myPastShows + myFutureShows)
        let filteredMyShows = rawMyShows.filter { (filtersShowToWatch ? $0.show.isInToWatch : true) && $0.episode.season != 0 }

        let futurePremiereShows = try await fetchPremiereCalendar(date: referenceDate, days: 33)
        let pastPremiereShows = try await fetchPremiereCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)

        let toWatchShows = filteredMyShows.map { $0.show }
        let anticipatedShowsList: [Show] = addAnticipatedShows ? try await fetchAnticipatedShows(count: 20).filter { !toWatchShows.contains($0) } : []
        let trendingShowsList: [Show] = addTrendingShows ? try await fetchTrendingShows(count: 20).filter { !toWatchShows.contains($0) } : []

        let premieres = (pastPremiereShows + futurePremiereShows).filter { anticipatedShowsList.contains($0.show) || trendingShowsList.contains($0.show) }
        let shows = (filteredMyShows + premieres).removingDuplicates().filter {
            if hideHiddenShows {
                if $0.show.isHiddenFromCalendar {
                    return false
                }
            }
            if hideRecentlyWatchedShows {
                if $0.episode.isWatched {
                    return false
                }
            }
            return true
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        // Movies
        let myPastMovies: [MovieCalendarItem] = try myMovies ? (await fetchMyMovieCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureMovies: [MovieCalendarItem] = try myMovies ? (await fetchMyMovieCalendar(date: referenceDate, days: 33)) : []
        let myPremiereMovieReleases = (myPastMovies + myFutureMovies).map {
            CalendarMovieRelease(movie: $0.movie, released: $0.released, releaseType: .premiere)
        }

        let myPastDVDMovies: [MovieCalendarItem] = try myMovies ? (await fetchDVDMovieCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureDVDMovies: [MovieCalendarItem] = try myMovies ? (await fetchDVDMovieCalendar(date: referenceDate, days: 33)) : []
        let myDVDMovieReleases = (myPastDVDMovies + myFutureDVDMovies).map {
            CalendarMovieRelease(movie: $0.movie, released: $0.released, releaseType: .physical)
        }

        let myPastStreamingMovies: [MovieCalendarItem] = try myMovies ? (await fetchStreamingMovieCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureStreamingMovies: [MovieCalendarItem] = try myMovies ? (await fetchStreamingMovieCalendar(date: referenceDate, days: 33)) : []
        let myStreamingMovieReleases = (myPastStreamingMovies + myFutureStreamingMovies).map {
            CalendarMovieRelease(movie: $0.movie, released: $0.released, releaseType: .streaming)
        }

        let myMovieReleases = myPremiereMovieReleases + myDVDMovieReleases + myStreamingMovieReleases
        let myMoviesList = myMovieReleases.map { $0.movie }

        let anticipatedMoviesList: [Movie] = addAnticipatedMovies ? try await fetchAnticipatedMovies(count: 20).filter { !myMoviesList.contains($0) } : []
        let trendingMoviesList: [Movie] = addTrendingMovies ? try await fetchTrendingMovies(count: 20).filter { !myMoviesList.contains($0) } : []
        let anticipatedMovieReleases: [CalendarMovieRelease] = anticipatedMoviesList.compactMap { movie -> CalendarMovieRelease? in
            guard let released = movie.released,
                  let date = formatter.date(from: released) else { return nil }
            return CalendarMovieRelease(movie: movie, released: date, releaseType: .premiere)
        }
        let trendingMovieReleases: [CalendarMovieRelease] = trendingMoviesList.compactMap { movie -> CalendarMovieRelease? in
            guard let released = movie.released,
                  let date = formatter.date(from: released) else { return nil }
            return CalendarMovieRelease(movie: movie, released: date, releaseType: .premiere)
        }

        let moviesCombined = (myMovieReleases + trendingMovieReleases + anticipatedMovieReleases)
        let movies = moviesCombined.removingDuplicates().filter {
            if hideHiddenMovies {
                if $0.movie.isHiddenFromCalendar {
                    return false
                }
            }
            if hideRecentlyWatchedMovies {
                if $0.movie.isWatched {
                    return false
                }
            }
            return true
        }.sorted { lhs, rhs in
            if lhs.released != rhs.released { return lhs.released < rhs.released }
            if lhs.movie.title != rhs.movie.title { return lhs.movie.title < rhs.movie.title }
            return lhs.releaseType.rawValue < rhs.releaseType.rawValue
        }

        let now = Date()

        let nextMovieModels: [MediaModel] = {
            let moviesWithDates = movies.filter { $0.releaseType == CalendarMovieRelease.ReleaseType.premiere && $0.released >= now }
                .sorted { lhs, rhs in
                    if lhs.released != rhs.released { return lhs.released < rhs.released }
                    return lhs.movie.title < rhs.movie.title
                }

            return moviesWithDates.map { $0.movie.mediaModel }.removingDuplicates()
        }()

        let upcomingEpisodes: [ShowEpisodeCalendarItem] = {
            let upcoming = shows.filter { item in
                guard item.firstAired >= now else { return false }
                // Only include series premiere if the show has never been watched
                if item.show.isWatchedAtLeastOnce == false, item.episode.episodeType != .seriesPremiere {
                    return false
                }
                return true
            }
            let grouped = Dictionary(grouping: upcoming, by: { $0.show })
            let earliestPerShow = grouped.values.compactMap { items in
                items.min(by: { $0.firstAired < $1.firstAired })
            }
            return earliestPerShow.sorted { lhs, rhs in
                if lhs.firstAired != rhs.firstAired { return lhs.firstAired < rhs.firstAired }
                return lhs.show.title < rhs.show.title
            }
        }()
        let nextEpisodeModels: [MediaModel] = upcomingEpisodes.map { $0.episode.mediaModel(given: $0.show) }

        let data = CalendarData(
            shows: shows,
            movies: movies,
            trendingShows: Set(trendingShowsList),
            anticipatedShows: Set(anticipatedShowsList),
            trendingMovies: Set(trendingMoviesList),
            anticipatedMovies: Set(anticipatedMoviesList),
            nextEpisodes: nextEpisodeModels,
            nextMovies: nextMovieModels
        )

        cachedData = data
        saveCacheToDisk(data)

        return data
    }
}

extension CalendarData {
    var nextEpisodesWithBingeableFinales: [MediaModel] {
        guard EpisodeToWatchSettings.shared.bingeableOnly else { return nextEpisodes }

        let now = Date.now
        let futureFinales = shows.filter { item in
            item.firstAired >= now &&
                item.episode.season != 0 &&
                item.episode.isBingeableFinale &&
                item.show.isInToWatch
        }
        let earliestFinalePerShow = Dictionary(grouping: futureFinales, by: \ShowEpisodeCalendarItem.show)
            .values
            .compactMap { items in
                items.min(by: { $0.firstAired < $1.firstAired })
            }
            .sorted { lhs, rhs in
                if lhs.firstAired != rhs.firstAired { return lhs.firstAired < rhs.firstAired }
                return lhs.show.title < rhs.show.title
            }

        guard !earliestFinalePerShow.isEmpty else { return nextEpisodes }

        let finaleModels = earliestFinalePerShow.map { item in
            item.episode.mediaModel(given: item.show)
        }

        return (finaleModels + nextEpisodes).removingDuplicates()
    }
}

// MARK: - fetch helpers

private extension CalendarManager {
    func fetchMyShowCalendar(date: Date, days: Int) async throws -> [ShowEpisodeCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myShowsCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchMyMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myMoviesCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchPremiereCalendar(date: Date, days: Int) async throws -> [ShowEpisodeCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.premiereCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.moviesCalendar(startDate: date, days: days, filters: [String: String]()), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchDVDMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myDvdMoviesCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchStreamingMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myStreamingMoviesCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAnticipatedMovies(count: Int) async throws -> [Movie] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedMovies(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.movie }
                        continuation.resume(returning: movies)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchTrendingMovies(count: Int) async throws -> [Movie] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.trendingMovies(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.movie }
                        continuation.resume(returning: movies)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchAnticipatedShows(count: Int) async throws -> [Show] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedShows(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let shows = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.show }
                        continuation.resume(returning: shows)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func fetchTrendingShows(count: Int) async throws -> [Show] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.trendingShows(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let shows = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.show }
                        continuation.resume(returning: shows)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
