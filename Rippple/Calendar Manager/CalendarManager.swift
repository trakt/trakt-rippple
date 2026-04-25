//
//  CalendarManager.swift
//  Rippple
//
//  Created by Assistant on 10/10/2025.
//

import Foundation
import Receiver
import TinyStorage

struct CalendarData: Codable {
    let shows: [ShowEpisodeCalendarItem]
    let movies: [Movie]
    let trendingShows: Set<Show>
    let anticipatedShows: Set<Show>
    let trendingMovies: Set<Movie>
    let anticipatedMovies: Set<Movie>

    let nextEpisodes: [MediaModel]
    let nextMovies: [MediaModel]
}

let (calendarDataUpdatedTransmitter, calendarDataUpdatedReceiver) = Receiver<CalendarData>.make(with: .warm(upTo: 1))

let (nextMoviesTransmitter, nextMoviesReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
let (nextEpisodesTransmitter, nextEpisodesReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))

final class CalendarManager {
    static let shared = CalendarManager()

    private let disposeBag = DisposeBag()

    private var debouncedReload: Debouncer!

    private init() {}

    private var cachedData: CalendarData? {
        didSet {
            guard let data = cachedData else { return }
            print("Sending CalendarManager CachedData")
            calendarDataUpdatedTransmitter.broadcast(data)
            nextMoviesTransmitter.broadcast(data.nextMovies)
            nextEpisodesTransmitter.broadcast(data.nextEpisodes)
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

        applicationLifecycleReceiver.hotOnly().listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60*60*2 {
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
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onListChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedReload.call()
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
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
            let cachedData = self.cachedData
            self.cachedData = cachedData
        }

        movieUpcomingEnabledReceiver.listen(to: refreshOnUpcomingChange).disposed(by: disposeBag)
        episodeUpcomingEnabledReceiver.listen(to: refreshOnUpcomingChange).disposed(by: disposeBag)
    }

    private func loadCacheFromDisk() {
        cachedData = try? storage.retrieveOrThrow(type: CalendarData.self, forKey: storageKey)
    }

    private func saveCacheToDisk(_ data: CalendarData) {
        storage.store(data, forKey: storageKey)
    }

    @discardableResult
    private func reload(referenceDate: Date = .now, force: Bool = false) async throws -> CalendarData {
        if force == false, let cachedData = self.cachedData {
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
        let myPastShows: [ShowEpisodeCalendarItem] = myShows ? (try await fetchMyShowCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureShows: [ShowEpisodeCalendarItem] = myShows ? (try await fetchMyShowCalendar(date: referenceDate, days: 33)) : []
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
                if $0.episode.isRecentlyWatched {
                    return false
                }
            }
            return true
        }

        // Movies
        let myPastMovies: [MovieCalendarItem] = myMovies ? (try await fetchMyMovieCalendar(date: referenceDate.addingTimeInterval(-dayRange), days: 33)) : []
        let myFutureMovies: [MovieCalendarItem] = myMovies ? (try await fetchMyMovieCalendar(date: referenceDate, days: 33)) : []
        let myMoviesList = (myPastMovies + myFutureMovies).map { $0.movie }

        let anticipatedMoviesList: [Movie] = addAnticipatedMovies ? try await fetchAnticipatedMovies(count: 20).filter { !myMoviesList.contains($0) } : []
        let trendingMoviesList: [Movie] = addTrendingMovies ? try await fetchTrendingMovies(count: 20).filter { !myMoviesList.contains($0) } : []

        let moviesCombined = (myMoviesList + trendingMoviesList + anticipatedMoviesList)
        let movies = moviesCombined.removingDuplicates().filter {
            if hideHiddenMovies {
                if $0.isHiddenFromCalendar {
                    return false
                }
            }
            if hideRecentlyWatchedMovies {
                if $0.isWatched {
                    return false
                }
            }
            return true
        }

        let now = Date()

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"

        let nextMovieModels: [MediaModel] = {
            let moviesWithDates: [(movie: Movie, date: Date)] = movies.compactMap { movie in
                guard let released = movie.released,
                        let date = formatter.date(from: released) else { return nil }
                return (movie, date)
            }.filter { $0.date >= now }
                .sorted { lhs, rhs in
                    if lhs.date != rhs.date { return lhs.date < rhs.date }
                    return lhs.movie.title < rhs.movie.title
                }

            return moviesWithDates.map { $0.movie.mediaModel }
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

        self.cachedData = data
        saveCacheToDisk(data)

        return data
    }
}

// MARK: - fetch helpers
private extension CalendarManager {

    func fetchMyShowCalendar(date: Date, days: Int) async throws -> [ShowEpisodeCalendarItem] {
        let result: [ShowEpisodeCalendarItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myShowsCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchMyMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        let result: [MovieCalendarItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.myMoviesCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchPremiereCalendar(date: Date, days: Int) async throws -> [ShowEpisodeCalendarItem] {
        let result: [ShowEpisodeCalendarItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.premiereCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchMovieCalendar(date: Date, days: Int) async throws -> [MovieCalendarItem] {
        let result: [MovieCalendarItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.moviesCalendar(startDate: date, days: days, filters: [String: String]()), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchAnticipatedMovies(count: Int) async throws -> [Movie] {
        let result: [Movie] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedMovies(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.movie }
                        continuation.resume(returning: movies)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchTrendingMovies(count: Int) async throws -> [Movie] {
        let result: [Movie] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.trendingMovies(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.movie }
                        continuation.resume(returning: movies)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchAnticipatedShows(count: Int) async throws -> [Show] {
        let result: [Show] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedShows(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let shows = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.show }
                        continuation.resume(returning: shows)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    func fetchTrendingShows(count: Int) async throws -> [Show] {
        let result: [Show] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.trendingShows(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: count)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let shows = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).compactMap { $0.show }
                        continuation.resume(returning: shows)
                    } catch {
                        print("CalendarManager error \(#function) : \(error)")
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    print("CalendarManager error \(#function) : \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }
}
