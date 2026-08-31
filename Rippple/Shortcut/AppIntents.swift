//
//  AppIntents.swift
//  Rippple
//
//  Created by Kevin Cador on 29/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import Foundation
import Moya
import Receiver
import UIKit

// MARK: - Navigation Intents

struct OpenMediaIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Media"
    static let description = IntentDescription("Opens the selected movie, TV show, or episode in Rippple. This action does not return a value.",
                                               categoryName: "Navigation")

    @Parameter(title: "Media",
               description: "The movie, TV show, or episode to open in Rippple.")
    var target: MediaEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        if DeeplinkManager.shared.registerDeeplink(url: target.deeplinkURL),
           SessionManager.shared.isLoggedIn,
           DeeplinkManager.shared.shouldOpenDeeplink() {
            UIApplication.shared.switchToDeeplink()
        }
        return .result()
    }
}

// MARK: - Errors

enum RipppleIntentError: Error, CustomLocalizedStringResourceConvertible {
    case notLoggedIn
    case checkInAlreadyInProgress
    case episodeCheckInUnavailable
    case movieCheckInUnavailable
    case noMoviesToWatch
    case noEpisodesToWatch
    case noNextEpisode
    case noWatchedMedia
    case nothingCurrentlyWatching
    case watchlistRequiresMovieOrShow
    case watchedHistoryRequiresMovieOrEpisode
    case nextEpisodeRequiresShow
    case trendingMediaRequiresMovieOrShow
    case trendingMoviesRequiresMovie
    case trendingShowsRequiresShow
    case moviesToWatchRequiresMovie
    case episodesToWatchRequiresEpisode
    case searchRequiresMovieOrShow

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notLoggedIn:
            return "Sign in to Rippple first."
        case .checkInAlreadyInProgress:
            return "A Trakt check-in is already in progress."
        case .episodeCheckInUnavailable:
            return "This episode can’t be checked in yet. It may not have aired."
        case .movieCheckInUnavailable:
            return "This movie can’t be checked in yet. It may not have been released."
        case .noMoviesToWatch:
            return "There are no movies to watch."
        case .noEpisodesToWatch:
            return "There are no episodes to watch."
        case .noNextEpisode:
            return "No next episode was found."
        case .noWatchedMedia:
            return "No watched movie or episode was found."
        case .nothingCurrentlyWatching:
            return "You aren’t currently checked in to a movie or episode."
        case .watchlistRequiresMovieOrShow:
            return "Only movies and TV shows can be added to the watchlist."
        case .watchedHistoryRequiresMovieOrEpisode:
            return "Only movies and episodes can be marked watched."
        case .nextEpisodeRequiresShow:
            return "Choose a TV show to get its next episode."
        case .trendingMediaRequiresMovieOrShow:
            return "Choose a movie or TV show from the trending media."
        case .trendingMoviesRequiresMovie:
            return "Choose a movie from the trending movies."
        case .trendingShowsRequiresShow:
            return "Choose a TV show from the trending TV shows."
        case .moviesToWatchRequiresMovie:
            return "Choose a movie from Movies to Watch."
        case .episodesToWatchRequiresEpisode:
            return "Choose an episode from Episodes to Watch."
        case .searchRequiresMovieOrShow:
            return "Choose a movie or TV show from the search results."
        }
    }
}

extension RipppleIntentError: WidgetIntentNotificationFailureProviding {
    var widgetIntentNotificationFailure: WidgetIntentNotificationsManager.Failure {
        switch self {
        case .checkInAlreadyInProgress:
            return .checkInAlreadyInProgress
        default:
            return .generic
        }
    }
}

// MARK: - Service

private enum RipppleIntentService {
    // MARK: Authentication

    private static func requireLoggedIn() throws {
        guard SessionManager.shared.isLoggedIn else {
            throw RipppleIntentError.notLoggedIn
        }
    }

    // MARK: Discovery

    static func trendingMedia() async throws -> [MediaEntity] {
        let items: [MediaItem] = try await request(.trendingMedia(filters: [:],
                                                                  extended: .full,
                                                                  pageInfo: PageInfo.firstPage(with: 10)))
        return items.compactMap { item in
            if let movie = item.movie,
               let entity = MovieEntity(movie: movie) {
                return .movie(entity)
            }
            if let show = item.show,
               let entity = ShowEntity(show: show) {
                return .show(entity)
            }
            return nil
        }
    }

    static func trendingMovies() async throws -> [MovieEntity] {
        let items: [MediaItem] = try await request(.trendingMovies(filters: [:],
                                                                   extended: .full,
                                                                   pageInfo: PageInfo.firstPage(with: 10)))
        return items.compactMap(\.movie).compactMap(MovieEntity.init)
    }

    static func trendingShows() async throws -> [ShowEntity] {
        let items: [MediaItem] = try await request(.trendingShows(filters: [:],
                                                                  extended: .full,
                                                                  pageInfo: PageInfo.firstPage(with: 10)))
        return items.compactMap(\.show).compactMap(ShowEntity.init)
    }

    @MainActor
    static func moviesToWatch() throws -> [MovieEntity] {
        try requireLoggedIn()

        let movies = MovieToWatchManager.shared.filteredMediaModels
            .compactMap(\.movie)
            .compactMap(MovieEntity.init)
        guard movies.isEmpty == false else {
            throw RipppleIntentError.noMoviesToWatch
        }
        return movies
    }

    @MainActor
    static func episodesToWatch() throws -> [EpisodeEntity] {
        try requireLoggedIn()

        let episodes: [EpisodeEntity] = EpisodeToWatchManager.shared.filteredMediaModels.compactMap { media -> EpisodeEntity? in
            guard let show = media.showProgressShow,
                  let episode = media.showProgressEpisode else { return nil }
            return EpisodeEntity(episode: episode, show: show)
        }
        guard episodes.isEmpty == false else {
            throw RipppleIntentError.noEpisodesToWatch
        }
        return episodes
    }

    static func lastWatchedMedia() async throws -> MediaEntity {
        try requireLoggedIn()

        let items: [HistoryItem] = try await request(.history(slug: "me",
                                                              type: nil,
                                                              id: nil,
                                                              pageInfo: PageInfo.firstPage(with: 1),
                                                              endDate: nil))
        guard let item = items.first else {
            throw RipppleIntentError.noWatchedMedia
        }
        if let movie = item.movie,
           let entity = MovieEntity(movie: movie) {
            return .movie(entity)
        }
        if let episode = item.episode,
           let show = item.show,
           let entity = EpisodeEntity(episode: episode, show: show) {
            return .episode(entity)
        }
        throw RipppleIntentError.noWatchedMedia
    }

    // MARK: Entity Resolution

    static func searchMovies(matching query: String) async throws -> [MovieEntity] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return [] }
        let items: [MediaItem] = try await request(.search(type: .movie, query: query))
        return items.compactMap(\.movie).compactMap(MovieEntity.init)
    }

    static func searchShows(matching query: String) async throws -> [ShowEntity] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return [] }
        let items: [MediaItem] = try await request(.search(type: .show, query: query))
        return items.compactMap(\.show).compactMap(ShowEntity.init)
    }

    static func searchMedia(matching query: String) async throws -> [MediaEntity] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return [] }

        let results: TMDbResults = try await tmdbRequest(.search(query))
        var media = [MediaEntity]()
        for result in results.results
            .filter({ $0.mediaType == "movie" || $0.mediaType == "tv" })
            .prefix(10) {
            let type: TmdbType = result.mediaType == "movie" ? .movie : .show
            guard let items: [MediaItem] = try? await request(.lookup(tmdbID: String(result.id),
                                                                      type: type)) else { continue }
            if let movie = items.compactMap(\.movie).compactMap(MovieEntity.init).first {
                media.append(.movie(movie))
            } else if let show = items.compactMap(\.show).compactMap(ShowEntity.init).first {
                media.append(.show(show))
            }
        }
        return media
    }

    static func movies(with identifiers: [Int]) async throws -> [MovieEntity] {
        var movies = [MovieEntity]()
        for identifier in identifiers {
            let movie: Movie = try await request(.movie(id: String(identifier), extended: .full))
            guard let entity = MovieEntity(movie: movie) else { continue }
            movies.append(entity)
        }
        return movies
    }

    static func shows(with identifiers: [Int]) async throws -> [ShowEntity] {
        var shows = [ShowEntity]()
        for identifier in identifiers {
            let show: Show = try await request(.show(id: String(identifier), extended: .full))
            guard let entity = ShowEntity(show: show) else { continue }
            shows.append(entity)
        }
        return shows
    }

    static func seasons(with identifiers: [String]) async throws -> [SeasonEntity] {
        var seasons = [SeasonEntity]()
        for identifier in identifiers {
            let components = identifier.split(separator: ":").compactMap { Int($0) }
            guard components.count == 2 else { continue }
            let show: Show = try await request(.show(id: String(components[0]), extended: .full))
            guard let entity = SeasonEntity(number: components[1], show: show) else { continue }
            seasons.append(entity)
        }
        return seasons
    }

    static func episodes(with identifiers: [String]) async throws -> [EpisodeEntity] {
        var episodes = [EpisodeEntity]()
        for identifier in identifiers {
            let components = identifier.split(separator: ":").compactMap { Int($0) }
            guard components.count == 3 else { continue }
            let episode: Episode = try await request(.episode(id: String(components[0]),
                                                              season: components[1],
                                                              episode: components[2]))
            let show: Show = try await request(.show(id: String(components[0]), extended: .full))
            guard let entity = EpisodeEntity(episode: episode, show: show) else { continue }
            episodes.append(entity)
        }
        return episodes
    }

    // MARK: Episodes

    static func nextEpisode(for showEntity: ShowEntity) async throws -> EpisodeEntity {
        try requireLoggedIn()

        let show: Show = try await request(.show(id: String(showEntity.traktIdentifier), extended: .full))
        let progress: ShowProgress = try await request(.showProgress(id: Int64(showEntity.traktIdentifier),
                                                                     includesSpecials: false))

        let episode: Episode?
        if let nextToRewatch = progress.nextToRewatch {
            episode = try await request(.episode(id: String(showEntity.traktIdentifier),
                                                 season: nextToRewatch.0.number,
                                                 episode: nextToRewatch.1.number))
        } else {
            episode = progress.nextEpisodeToWatch
        }

        guard let episode = episode,
              let entity = EpisodeEntity(episode: episode, show: show) else {
            throw RipppleIntentError.noNextEpisode
        }
        return entity
    }

    // MARK: Check-In

    static func checkIn(movie: MovieEntity) async throws -> MediaModel {
        let movie: Movie = try await request(.movie(id: String(movie.traktIdentifier), extended: .full))
        try await checkIn(isEpisode: false,
                          item: CheckinItem(movie: movie))
        return movie.mediaModel
    }

    static func checkIn(episode: EpisodeEntity) async throws -> MediaModel {
        async let episodeRequest: Episode = request(.episode(id: String(episode.show.traktIdentifier),
                                                             season: episode.season.number,
                                                             episode: episode.episodeNumber))
        async let showRequest: Show = request(.show(id: String(episode.show.traktIdentifier), extended: .full))
        let (episodeModel, showModel) = try await(episodeRequest, showRequest)

        try await checkIn(isEpisode: true,
                          item: CheckinItem(episode: episodeModel))
        return .episode(episodeModel, showModel)
    }

    private static func checkIn(isEpisode: Bool, item: CheckinItem) async throws {
        try requireLoggedIn()

        do {
            let response = try await rawResponse(.checkin(item: item))
            _ = try response.filterSuccessfulStatusCodes()
        } catch let error as MoyaError {
            guard let statusCode = error.response?.statusCode,
                  let intentError = checkInError(for: statusCode, isEpisode: isEpisode) else {
                throw error
            }
            throw intentError
        }
    }

    private static func checkInError(for statusCode: Int, isEpisode: Bool) -> RipppleIntentError? {
        switch statusCode {
        case 409:
            return .checkInAlreadyInProgress
        case 422:
            return isEpisode ? .episodeCheckInUnavailable : .movieCheckInUnavailable
        default:
            return nil
        }
    }

    static func cancelCheckIn() async throws {
        let watchingItem = try? await currentWatchingItem()
        let media = mediaEntity(for: watchingItem)

        try await performAuthenticated(.cancelCheckin)
        await MainActor.run {
            WatchingManager.shared.updateWatchingItem(with: nil, forceBroadcast: true)
        }
        if let media = media {
            await refreshActivityPunchcard(for: media)
        }
    }

    // MARK: Watchlist

    static func addToWatchlist(movie: MovieEntity) async throws {
        try await performAuthenticated(.addToWatchlist(item: await item(for: movie)))
        await MainActor.run {
            WatchlistManager.shared.refresh()
        }
    }

    static func addToWatchlist(show: ShowEntity) async throws {
        try await performAuthenticated(.addToWatchlist(item: await item(for: show)))
        await MainActor.run {
            WatchlistManager.shared.refresh()
        }
    }

    private static func item(for entity: MovieEntity) async throws -> WatchlistedItem {
        try requireLoggedIn()
        let movie: Movie = try await request(.movie(id: String(entity.traktIdentifier), extended: .full))
        return WatchlistedItem(movie: movie)
    }

    private static func item(for entity: ShowEntity) async throws -> WatchlistedItem {
        try requireLoggedIn()
        let show: Show = try await request(.show(id: String(entity.traktIdentifier), extended: .full))
        return WatchlistedItem(show: show)
    }

    // MARK: History

    static func markWatched(movie: MovieEntity, at date: Date) async throws -> MediaModel {
        try requireLoggedIn()

        let model: Movie = try await request(.movie(id: String(movie.traktIdentifier), extended: .full))
        try await performAuthenticated(.addMovieToHistory(id: Int64(movie.traktIdentifier),
                                                          watchedAt: date))
        return model.mediaModel
    }

    static func markWatched(episode: EpisodeEntity, at date: Date) async throws -> MediaModel {
        try requireLoggedIn()

        async let episodeRequest: Episode = request(.episode(id: String(episode.show.traktIdentifier),
                                                             season: episode.season.number,
                                                             episode: episode.episodeNumber))
        async let showRequest: Show = request(.show(id: String(episode.show.traktIdentifier), extended: .full))
        let (episodeModel, showModel) = try await(episodeRequest, showRequest)

        try await performAuthenticated(.addEpisodeToHistory(id: Int64(episode.traktIdentifier),
                                                            watchedAt: date))
        return .episode(episodeModel, showModel)
    }

    static func refreshActivityPunchcard(for media: MediaEntity) async {
        let type: SyncWatchedType
        switch media.value {
        case .movie:
            type = .movies
        case .episode:
            type = .episodes
        case .show:
            return
        }
        await SyncWatchedManager.shared.refreshImmediately(type: type)
    }

    // MARK: Ratings

    static func rate(movie: MovieEntity, rating: Int) async throws {
        try await performAuthenticated(.rateMovie(id: Int64(movie.traktIdentifier), rating: rating))
    }

    static func rate(show: ShowEntity, rating: Int) async throws {
        try await performAuthenticated(.rateShow(id: Int64(show.traktIdentifier), rating: rating))
    }

    static func rate(episode: EpisodeEntity, rating: Int) async throws {
        try await performAuthenticated(.rateEpisode(id: Int64(episode.traktIdentifier), rating: rating))
    }

    // MARK: Live Activity

    static func refreshLiveActivity() async throws -> MediaEntity? {
        try requireLoggedIn()

        let watchingItem = try await currentWatchingItem()
        let media = mediaEntity(for: watchingItem)

        await MainActor.run {
            WatchingManager.shared.updateWatchingItem(with: watchingItem, forceBroadcast: true)
        }
        return media
    }

    @MainActor
    static func refreshWidgetData() async throws {
        async let moviesRefresh: Void = SyncWatchedManager.shared.refreshImmediately(type: .movies)
        async let showsRefresh: Void = SyncWatchedManager.shared.refreshImmediately(type: .shows)
        async let episodesRefresh: Void = SyncWatchedManager.shared.refreshImmediately(type: .episodes)
        _ = await(moviesRefresh, showsRefresh, episodesRefresh)
        WidgetManager.shared.refreshActivityPunchcard()

        EpisodeToWatchManager.shared.forcedUserRefresh()
        MovieToWatchManager.shared.forcedUserRefresh()
        try await CalendarManager.shared.refresh()
    }

    private static func mediaEntity(for item: WatchingItem?) -> MediaEntity? {
        if let movie = item?.movie,
           let entity = MovieEntity(movie: movie) {
            return .movie(entity)
        }
        if let show = item?.show,
           let episode = item?.episode,
           let entity = EpisodeEntity(episode: episode, show: show) {
            return .episode(entity)
        }
        if let show = item?.show,
           let entity = ShowEntity(show: show) {
            return .show(entity)
        }
        return nil
    }

    private static func currentWatchingItem() async throws -> WatchingItem? {
        try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.watching(slug: "me"),
                                              callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case .success(let response):
                    do {
                        if response.statusCode == 204 {
                            continuation.resume(returning: nil)
                            return
                        }
                        let response = try response.filterSuccessfulStatusCodes()
                        let item = try response.map(WatchingItem.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: item)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Networking

    private static func performAuthenticated(_ target: TraktAPIService) async throws {
        try requireLoggedIn()

        _ = try await rawResponse(target).filterSuccessfulStatusCodes()
    }

    private static func request<Response: Decodable>(_ target: TraktAPIService) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(target, callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case .success(let response):
                    do {
                        let response = try response.filterSuccessfulStatusCodes()
                        try continuation.resume(returning: response.map(Response.self, using: TraktAPIProvider.decoder))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func tmdbRequest<Response: Decodable>(_ target: TmdbAPIService) async throws -> Response {
        try await withCheckedThrowingContinuation { continuation in
            TmdbAPIProvider.provider.request(target, callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case .success(let response):
                    do {
                        let response = try response.filterSuccessfulStatusCodes()
                        try continuation.resume(returning: response.map(Response.self, using: TmdbAPIProvider.decoder))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func rawResponse(_ target: TraktAPIService) async throws -> Moya.Response {
        try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(target,
                                              callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Movie Entity

struct MovieEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Movie")
    static let defaultQuery = MovieEntityQuery()

    let id: Int

    @Property(title: "Trakt ID")
    var traktIdentifier: Int

    @Property
    var title: String

    @Property
    var year: Int?

    var tmdbIdentifier: Int?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = year.map { LocalizedStringResource(stringLiteral: String($0)) }
        return DisplayRepresentation(title: "\(title)",
                                     subtitle: subtitle)
    }

    init?(movie: Movie) {
        guard let identifier = movie.identifiers.trakt,
              let id = Int(exactly: identifier) else { return nil }
        self.id = id
        traktIdentifier = id
        title = movie.title
        year = movie.releaseYear
        tmdbIdentifier = movie.identifiers.tmdb.flatMap(Int.init(exactly:))
    }

    init(widgetMovie: ToWatchWidgetMovie) {
        id = widgetMovie.movieTraktIdentifier
        traktIdentifier = widgetMovie.movieTraktIdentifier
        title = widgetMovie.title
        year = widgetMovie.releaseYear
        tmdbIdentifier = widgetMovie.movieTMDbIdentifier
    }
}

struct MovieEntityQuery: EntityStringQuery {
    func entities(for identifiers: [MovieEntity.ID]) async throws -> [MovieEntity] {
        try await RipppleIntentService.movies(with: identifiers)
    }

    func suggestedEntities() async throws -> [MovieEntity] {
        try await RipppleIntentService.trendingMovies()
    }

    func entities(matching string: String) async throws -> [MovieEntity] {
        try await RipppleIntentService.searchMovies(matching: string)
    }
}

// MARK: - TV Show Entity

struct ShowEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "TV Show")
    static let defaultQuery = ShowEntityQuery()

    let id: Int

    @Property(title: "Trakt ID")
    var traktIdentifier: Int

    @Property
    var title: String

    @Property
    var episodeCount: Int?

    var tmdbIdentifier: Int?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = episodeCount.map {
            LocalizedStringResource(stringLiteral: "\($0) episodes")
        }
        return DisplayRepresentation(title: "\(title)",
                                     subtitle: subtitle)
    }

    init?(show: Show) {
        guard let identifier = show.identifiers.trakt,
              let id = Int(exactly: identifier) else { return nil }
        self.id = id
        traktIdentifier = id
        title = show.title
        episodeCount = show.airedEpisodes
        tmdbIdentifier = show.identifiers.tmdb.flatMap(Int.init(exactly:))
    }

    init(traktIdentifier: Int, title: String, tmdbIdentifier: Int? = nil) {
        id = traktIdentifier
        self.traktIdentifier = traktIdentifier
        self.title = title
        episodeCount = nil
        self.tmdbIdentifier = tmdbIdentifier
    }
}

struct ShowEntityQuery: EntityStringQuery {
    func entities(for identifiers: [ShowEntity.ID]) async throws -> [ShowEntity] {
        try await RipppleIntentService.shows(with: identifiers)
    }

    func suggestedEntities() async throws -> [ShowEntity] {
        try await RipppleIntentService.trendingShows()
    }

    func entities(matching string: String) async throws -> [ShowEntity] {
        try await RipppleIntentService.searchShows(matching: string)
    }
}

// MARK: - Season Entity

struct SeasonEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Season")
    static let defaultQuery = SeasonEntityQuery()

    let id: String

    @Property
    var show: ShowEntity

    @Property
    var number: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(show.title)",
                              subtitle: "Season \(number)")
    }

    init?(number: Int, show: Show) {
        guard let showEntity = ShowEntity(show: show) else { return nil }
        id = "\(showEntity.id):\(number)"
        self.show = showEntity
        self.number = number
    }

    init?(episode: Episode, show: Show) {
        self.init(number: episode.season, show: show)
    }

    init(number: Int, show: ShowEntity) {
        id = "\(show.id):\(number)"
        self.show = show
        self.number = number
    }
}

struct SeasonEntityQuery: EntityQuery {
    func entities(for identifiers: [SeasonEntity.ID]) async throws -> [SeasonEntity] {
        try await RipppleIntentService.seasons(with: identifiers)
    }
}

// MARK: - Episode Entity

struct EpisodeEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Episode")
    static let defaultQuery = EpisodeEntityQuery()

    let id: String

    @Property(title: "Trakt ID")
    var traktIdentifier: Int

    @Property
    var show: ShowEntity

    @Property
    var title: String

    @Property
    var season: SeasonEntity

    @Property
    var episodeNumber: Int

    var localizedEpisodeNumber: String {
        let seasonNumber = season.number < 10 ? "0\(season.number)" : "\(season.number)"
        let number = episodeNumber < 10 ? "0\(episodeNumber)" : "\(episodeNumber)"
        return "S\(seasonNumber)E\(number)"
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle = LocalizedStringResource(stringLiteral: localizedEpisodeNumber)
        return DisplayRepresentation(title: "\(show.title)",
                                     subtitle: subtitle)
    }

    init?(episode: Episode, show: Show) {
        guard let episodeIdentifier = episode.identifiers.trakt,
              let traktIdentifier = Int(exactly: episodeIdentifier),
              let showEntity = ShowEntity(show: show),
              let seasonEntity = SeasonEntity(episode: episode, show: show) else { return nil }
        id = "\(showEntity.id):\(episode.season):\(episode.number)"
        self.traktIdentifier = traktIdentifier
        self.show = showEntity
        title = episode.title ?? episode.localizedEpisodeNumber
        season = seasonEntity
        episodeNumber = episode.number
    }

    init(widgetEpisode: ToWatchWidgetEpisode) {
        let show = ShowEntity(traktIdentifier: widgetEpisode.showTraktIdentifier,
                              title: widgetEpisode.showTitle,
                              tmdbIdentifier: widgetEpisode.showTMDbIdentifier)
        let season = SeasonEntity(number: widgetEpisode.seasonNumber, show: show)
        id = "\(show.id):\(season.number):\(widgetEpisode.episodeNumber)"
        traktIdentifier = widgetEpisode.episodeTraktIdentifier
        self.show = show
        title = "Episode \(widgetEpisode.episodeNumber)"
        self.season = season
        episodeNumber = widgetEpisode.episodeNumber
    }
}

struct EpisodeEntityQuery: EntityQuery {
    func entities(for identifiers: [EpisodeEntity.ID]) async throws -> [EpisodeEntity] {
        try await RipppleIntentService.episodes(with: identifiers)
    }

    func suggestedEntities() async throws -> [EpisodeEntity] {
        try await RipppleIntentService.episodesToWatch()
    }
}

// MARK: - Media Entity

enum MediaEntityType: String, AppEnum {
    case movie
    case show
    case episode

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Media Type")
    static let typeDisplayName: LocalizedStringResource = "Media Type"
    static let caseDisplayRepresentations: [MediaEntityType: DisplayRepresentation] = [
        .movie: "Movie",
        .show: "Show",
        .episode: "Episode"
    ]
}

struct MediaEntity: AppEntity {
    fileprivate enum Value {
        case movie(MovieEntity)
        case show(ShowEntity)
        case episode(EpisodeEntity)
    }

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Media")
    static let defaultQuery = MediaEntityQuery()

    fileprivate let value: Value

    @Property(title: "Type")
    var type: MediaEntityType

    static func movie(_ movie: MovieEntity) -> MediaEntity {
        MediaEntity(value: .movie(movie), type: .movie)
    }

    static func show(_ show: ShowEntity) -> MediaEntity {
        MediaEntity(value: .show(show), type: .show)
    }

    static func episode(_ episode: EpisodeEntity) -> MediaEntity {
        MediaEntity(value: .episode(episode), type: .episode)
    }

    private init(value: Value, type: MediaEntityType) {
        self.value = value
        self.type = type
    }

    var id: String {
        switch value {
        case .movie(let movie):
            return "movie:\(movie.id)"
        case .show(let show):
            return "show:\(show.id)"
        case .episode(let episode):
            return "episode:\(episode.id)"
        }
    }

    var displayRepresentation: DisplayRepresentation {
        switch value {
        case .movie(let movie):
            return movie.displayRepresentation
        case .show(let show):
            return show.displayRepresentation
        case .episode(let episode):
            return episode.displayRepresentation
        }
    }

    var deeplinkURL: URL {
        switch value {
        case .movie(let movie):
            return URL(string: "ripl://movies/\(movie.traktIdentifier)")!
        case .show(let show):
            return URL(string: "ripl://shows/\(show.traktIdentifier)")!
        case .episode(let episode):
            return URL(string: "ripl://shows/\(episode.show.traktIdentifier)/seasons/\(episode.season.number)/episodes/\(episode.episodeNumber)")!
        }
    }
}

struct MediaEntityQuery: EntityStringQuery {
    func entities(for identifiers: [MediaEntity.ID]) async throws -> [MediaEntity] {
        var entities = [MediaEntity]()
        for identifier in identifiers {
            let components = identifier.split(separator: ":", maxSplits: 1).map(String.init)
            guard components.count == 2 else { continue }

            switch components[0] {
            case "movie":
                guard let identifier = Int(components[1]) else { continue }
                try entities.append(contentsOf: await RipppleIntentService.movies(with: [identifier]).map(MediaEntity.movie))
            case "show":
                guard let identifier = Int(components[1]) else { continue }
                try entities.append(contentsOf: await RipppleIntentService.shows(with: [identifier]).map(MediaEntity.show))
            case "episode":
                try entities.append(contentsOf: await RipppleIntentService.episodes(with: [components[1]]).map(MediaEntity.episode))
            default:
                continue
            }
        }
        return entities
    }

    func suggestedEntities() async throws -> [MediaEntity] {
        try await RipppleIntentService.trendingMedia()
    }

    func entities(matching string: String) async throws -> [MediaEntity] {
        try await RipppleIntentService.searchMedia(matching: string)
    }
}

// MARK: - Media Options

struct TrendingMediaOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MediaEntity] {
        try await RipppleIntentService.trendingMedia()
    }
}

struct TrendingMovieMediaOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MediaEntity] {
        try await RipppleIntentService.trendingMovies().map(MediaEntity.movie)
    }
}

struct TrendingShowMediaOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MediaEntity] {
        try await RipppleIntentService.trendingShows().map(MediaEntity.show)
    }
}

struct EpisodesToWatchMediaOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MediaEntity] {
        try await RipppleIntentService.episodesToWatch().map(MediaEntity.episode)
    }
}

struct MoviesToWatchMediaOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> [MediaEntity] {
        try await RipppleIntentService.moviesToWatch().map(MediaEntity.movie)
    }
}

struct SearchMediaOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<SearchMediaIntent>(\.$query)
    var query

    func results() async throws -> [MediaEntity] {
        guard let query = query?.query else { return [] }
        return try await RipppleIntentService.searchMedia(matching: query)
    }
}

// MARK: - Search Intents

struct SearchMediaIntent: AppIntent {
    static let title: LocalizedStringResource = "Search Movies and TV Shows"
    static let description = IntentDescription("Searches Trakt for a title, lets you choose a movie or TV show from the matches, and returns the selected media for use in later actions.",
                                               categoryName: "Discover",
                                               resultValueName: "Media")

    @Parameter(title: "Search",
               description: "The title or keywords to search for on Trakt.",
               requestValueDialog: "What do you want to search for?")
    var query: String

    @Parameter(title: "Media",
               description: "The movie or TV show to return from the search results.",
               requestValueDialog: "Which movie or TV show?",
               optionsProvider: SearchMediaOptionsProvider())
    var media: MediaEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query) and choose \(\.$media)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        switch media.value {
        case .movie(let movie):
            return .result(value: media, dialog: "Selected \(movie.title).")
        case .show(let show):
            return .result(value: media, dialog: "Selected \(show.title).")
        case .episode:
            throw RipppleIntentError.searchRequiresMovieOrShow
        }
    }
}

// MARK: - Trending Intents

struct FetchTrendingMoviesIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Trending Movies"
    static let description = IntentDescription("Loads the movies currently trending on Trakt, lets you choose one, and returns the selected movie for use in later actions.",
                                               categoryName: "Discover",
                                               resultValueName: "Movie")

    @Parameter(title: "Movie",
               description: "The movie to return from the current Trakt trends.",
               requestValueDialog: "Which trending movie?",
               optionsProvider: TrendingMovieMediaOptionsProvider())
    var media: MediaEntity

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        guard case .movie(let movie) = media.value else {
            throw RipppleIntentError.trendingMoviesRequiresMovie
        }
        return .result(value: media, dialog: "Selected \(movie.title).")
    }
}

struct FetchTrendingShowsIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Trending TV Shows"
    static let description = IntentDescription("Loads the TV shows currently trending on Trakt, lets you choose one, and returns the selected show for use in later actions.",
                                               categoryName: "Discover",
                                               resultValueName: "TV Show")

    @Parameter(title: "TV Show",
               description: "The TV show to return from the current Trakt trends.",
               requestValueDialog: "Which trending TV show?",
               optionsProvider: TrendingShowMediaOptionsProvider())
    var media: MediaEntity

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        guard case .show(let show) = media.value else {
            throw RipppleIntentError.trendingShowsRequiresShow
        }
        return .result(value: media, dialog: "Selected \(show.title).")
    }
}

struct FetchTrendingMediaIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Trending Media"
    static let description = IntentDescription("Loads the movies and TV shows currently trending on Trakt, lets you choose one, and returns the selected media for use in later actions.",
                                               categoryName: "Discover",
                                               resultValueName: "Media")

    @Parameter(title: "Media",
               description: "The movie or TV show to return from the current Trakt trends.",
               requestValueDialog: "Which trending movie or TV show?",
               optionsProvider: TrendingMediaOptionsProvider())
    var media: MediaEntity

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        switch media.value {
        case .movie(let movie):
            return .result(value: media, dialog: "Selected \(movie.title).")
        case .show(let show):
            return .result(value: media, dialog: "Selected \(show.title).")
        case .episode:
            throw RipppleIntentError.trendingMediaRequiresMovieOrShow
        }
    }
}

// MARK: - Watchlist Intents

struct AddToWatchlistIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to Watchlist"
    static let description = IntentDescription("Adds the selected movie or TV show to your Trakt watchlist and returns the same media for use in later actions. Requires a signed-in Trakt account.",
                                               categoryName: "Watchlist",
                                               resultValueName: "Media")

    @Parameter(title: "Media",
               description: "The movie or TV show to add. Episodes cannot be added to a Trakt watchlist.",
               requestValueDialog: "What would you like to add to your watchlist?",
               inputConnectionBehavior: .connectToPreviousIntentResult)
    var media: MediaEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$media) to the watchlist")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        switch media.value {
        case .movie(let movie):
            try await RipppleIntentService.addToWatchlist(movie: movie)
            return .result(value: media, dialog: "Added \(movie.title) to your watchlist.")
        case .show(let show):
            try await RipppleIntentService.addToWatchlist(show: show)
            return .result(value: media, dialog: "Added \(show.title) to your watchlist.")
        case .episode:
            throw RipppleIntentError.watchlistRequiresMovieOrShow
        }
    }
}

// MARK: - History Intents

struct MarkWatchedIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark Watched"
    static let description = IntentDescription("Adds the selected movie or episode to your Trakt watched history at the specified time and returns the same media for use in later actions. Requires a signed-in Trakt account.",
                                               categoryName: "History",
                                               resultValueName: "Media")

    @Parameter(title: "Media",
               description: "The movie or episode to add to your watched history. TV shows must be marked one episode at a time.",
               requestValueDialog: "What did you watch?",
               inputConnectionBehavior: .connectToPreviousIntentResult)
    var media: MediaEntity

    @Parameter(title: "Watched At",
               description: "The date and time the movie or episode was watched. Uses the current date and time when left empty.")
    var watchedAt: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Mark \(\.$media) watched")
    }

    init() {}

    init(media: MediaEntity, watchedAt: Date? = nil) {
        self.media = media
        self.watchedAt = watchedAt
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let model: MediaModel
        let dialog: IntentDialog
        let watchedAt = watchedAt ?? .now
        switch media.value {
        case .movie(let movie):
            model = try await RipppleIntentService.markWatched(movie: movie, at: watchedAt)
            dialog = "Marked \(movie.title) watched."
        case .episode(let episode):
            model = try await RipppleIntentService.markWatched(episode: episode, at: watchedAt)
            dialog = "Marked \(episode.show.title) \(episode.localizedEpisodeNumber) watched."
        case .show:
            throw RipppleIntentError.watchedHistoryRequiresMovieOrEpisode
        }
        await refreshAppData(afterMarking: model)
        await RipppleIntentService.refreshActivityPunchcard(for: media)
        return .result(value: media, dialog: dialog)
    }

    private func refreshAppData(afterMarking media: MediaModel) async {
        await MainActor.run {
            onMarkWatchedTransmitter.broadcast(media)
            TraktStatusCheckManager.shared.refresh()
        }
    }
}

struct FetchLastWatchedMediaIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Last Watched Media"
    static let description = IntentDescription("Gets and returns the most recent movie or episode in your Trakt watched history. This action has no input and requires a signed-in Trakt account.",
                                               categoryName: "History",
                                               resultValueName: "Media")

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let media = try await RipppleIntentService.lastWatchedMedia()
        switch media.value {
        case .movie(let movie):
            return .result(value: media,
                           dialog: "Last watched: \(movie.title).")
        case .show(let show):
            return .result(value: media,
                           dialog: "Last watched: \(show.title).")
        case .episode(let episode):
            return .result(value: media,
                           dialog: "Last watched: \(episode.show.title) \(episode.localizedEpisodeNumber).")
        }
    }
}

// MARK: - Rating Intents

struct RatingOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<Int> {
        IntentItemCollection {
            IntentItemSection(items: [
                IntentItem(1, title: "1 - I fell asleep"),
                IntentItem(2, title: "2 - Terrible"),
                IntentItem(3, title: "3 - Bad"),
                IntentItem(4, title: "4 - Poor"),
                IntentItem(5, title: "5 - Meh"),
                IntentItem(6, title: "6 - Fair"),
                IntentItem(7, title: "7 - Good"),
                IntentItem(8, title: "8 - Great"),
                IntentItem(9, title: "9 - Superb"),
                IntentItem(10, title: "10 - Masterpiece")
            ])
        }
    }
}

struct RateMediaIntent: AppIntent {
    static let title: LocalizedStringResource = "Rate Media"
    static let description = IntentDescription("Rates the selected movie, TV show, or episode from 1 to 10 on Trakt and returns the same media for use in later actions. Requires a signed-in Trakt account.",
                                               categoryName: "Ratings",
                                               resultValueName: "Media")

    @Parameter(title: "Media",
               description: "The movie, TV show, or episode to rate.",
               requestValueDialog: "What would you like to rate?",
               inputConnectionBehavior: .connectToPreviousIntentResult)
    var media: MediaEntity

    @Parameter(title: "Rating",
               description: "Your Trakt rating from 1 (lowest) to 10 (highest).",
               inclusiveRange: (1, 10),
               requestValueDialog: "How would you rate it?",
               optionsProvider: RatingOptionsProvider())
    var rating: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Rate \(\.$media) \(\.$rating) out of 10")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let dialog: IntentDialog
        switch media.value {
        case .movie(let movie):
            try await RipppleIntentService.rate(movie: movie, rating: rating)
            dialog = "Rated \(movie.title) \(rating) out of 10."
        case .show(let show):
            try await RipppleIntentService.rate(show: show, rating: rating)
            dialog = "Rated \(show.title) \(rating) out of 10."
        case .episode(let episode):
            try await RipppleIntentService.rate(episode: episode, rating: rating)
            dialog = "Rated \(episode.show.title) \(episode.localizedEpisodeNumber) \(rating) out of 10."
        }
        return .result(value: media, dialog: dialog)
    }
}

// MARK: - To Watch Intents

struct FetchMoviesToWatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Movies to Watch"
    static let description = IntentDescription("Lets you choose from the movies currently shown in Rippple's Movies to Watch list and returns the selected movie for use in later actions. Requires a signed-in Trakt account.",
                                               categoryName: "Movies",
                                               resultValueName: "Movie")

    @Parameter(title: "Movie",
               description: "The movie to return. When left empty, the action asks you to choose one when it runs.",
               optionsProvider: MoviesToWatchMediaOptionsProvider())
    var media: MediaEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let selectedMedia: MediaEntity
        if let media = media {
            selectedMedia = media
        } else {
            selectedMedia = try await $media.requestValue("Which movie do you want to watch?")
        }
        guard case .movie(let movie) = selectedMedia.value else {
            throw RipppleIntentError.moviesToWatchRequiresMovie
        }
        return .result(value: selectedMedia,
                       dialog: "Selected \(movie.title).")
    }
}

struct FetchEpisodesToWatchIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Episodes to Watch"
    static let description = IntentDescription("Lets you choose from the episodes currently shown in Rippple's Episodes to Watch list and returns the selected episode for use in later actions. Requires a signed-in Trakt account.",
                                               categoryName: "Episodes",
                                               resultValueName: "Episode")

    @Parameter(title: "Episode",
               description: "The episode to return. When left empty, the action asks you to choose one when it runs.",
               optionsProvider: EpisodesToWatchMediaOptionsProvider())
    var media: MediaEntity?

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let selectedMedia: MediaEntity
        if let media = media {
            selectedMedia = media
        } else {
            selectedMedia = try await $media.requestValue("Which episode do you want to watch?")
        }
        guard case .episode(let episode) = selectedMedia.value else {
            throw RipppleIntentError.episodesToWatchRequiresEpisode
        }
        return .result(value: selectedMedia,
                       dialog: "Selected \(episode.show.title) \(episode.localizedEpisodeNumber).")
    }
}

struct FetchNextEpisodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get Next Episode"
    static let description = IntentDescription("Finds and returns the next unwatched episode of the selected TV show according to your Trakt history. Requires a signed-in Trakt account.",
                                               categoryName: "Episodes",
                                               resultValueName: "Episode")

    @Parameter(title: "TV Show",
               description: "The TV show whose next unwatched episode should be returned.",
               requestValueDialog: "Which TV show?",
               inputConnectionBehavior: .connectToPreviousIntentResult,
               optionsProvider: TrendingShowMediaOptionsProvider())
    var media: MediaEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Get the next episode for \(\.$media)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        guard case .show(let show) = media.value else {
            throw RipppleIntentError.nextEpisodeRequiresShow
        }
        let episode = try await RipppleIntentService.nextEpisode(for: show)
        let media = MediaEntity.episode(episode)
        return .result(value: media,
                       dialog: "Next: \(episode.show.title) \(episode.localizedEpisodeNumber).")
    }
}

// MARK: - Check-In Intents

struct CheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Check In"
    static let description = IntentDescription("Starts a Trakt check-in for the selected movie or episode. When given a TV show, it checks in to the next unwatched episode. Returns the movie or episode that was checked in and requires a signed-in Trakt account.",
                                               categoryName: "Check-In",
                                               resultValueName: "Media")

    private var requestsConfirmation = true

    @Parameter(title: "Media",
               description: "The movie or episode to check in to, or a TV show whose next unwatched episode should be used.",
               requestValueDialog: "What would you like to check in to?",
               inputConnectionBehavior: .connectToPreviousIntentResult,
               optionsProvider: TrendingMediaOptionsProvider())
    var media: MediaEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Check in to \(\.$media)")
    }

    init() {}

    init(media: MediaEntity, requestsConfirmation: Bool = true) {
        self.media = media
        self.requestsConfirmation = requestsConfirmation
    }

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        let checkedInMedia: MediaEntity
        let checkedInModel: MediaModel
        let dialog: IntentDialog
        switch media.value {
        case .movie(let movie):
            if requestsConfirmation {
                try await requestConfirmation(actionName: .checkIn,
                                              dialog: "Check in to \(movie.title)?")
            }
            checkedInModel = try await RipppleIntentService.checkIn(movie: movie)
            checkedInMedia = media
            dialog = "Checked in to \(movie.title)."
        case .show(let show):
            let episode = try await RipppleIntentService.nextEpisode(for: show)
            if requestsConfirmation {
                try await requestConfirmation(actionName: .checkIn,
                                              dialog: "Check in to \(episode.show.title) \(episode.localizedEpisodeNumber)?")
            }
            checkedInModel = try await RipppleIntentService.checkIn(episode: episode)
            checkedInMedia = .episode(episode)
            dialog = "Checked in to \(episode.show.title) \(episode.localizedEpisodeNumber)."
        case .episode(let episode):
            if requestsConfirmation {
                try await requestConfirmation(actionName: .checkIn,
                                              dialog: "Check in to \(episode.show.title) \(episode.localizedEpisodeNumber)?")
            }
            checkedInModel = try await RipppleIntentService.checkIn(episode: episode)
            checkedInMedia = media
            dialog = "Checked in to \(episode.show.title) \(episode.localizedEpisodeNumber)."
        }
        await MainActor.run {
            WatchingManager.shared.updateWatchingItem(with: WatchingItem(media: checkedInModel), forceBroadcast: true)
        }
        await RipppleIntentService.refreshActivityPunchcard(for: checkedInMedia)
        return .result(value: checkedInMedia, dialog: dialog)
    }
}

extension ToWatchWidgetActionHandler {
    static let app = ToWatchWidgetActionHandler { action, widgetMedia in
        let media: MediaEntity
        switch widgetMedia {
        case .episode(let episode):
            media = .episode(EpisodeEntity(widgetEpisode: episode))
        case .movie(let movie):
            media = .movie(MovieEntity(widgetMovie: movie))
        }
        switch action {
        case .none:
            return
        case .checkIn:
            _ = try await CheckInIntent(media: media, requestsConfirmation: false).callAsFunction(donate: false)
        case .markWatched:
            _ = try await MarkWatchedIntent(media: media).callAsFunction(donate: false)
        }
    } refreshEpisode: { showTraktIdentifier in
        await EpisodeToWatchManager.shared.refreshProgress(forShowWithTraktIdentifier: Int64(showTraktIdentifier))
    } refreshMovies: {
        await MovieToWatchManager.shared.refreshProgressAfterWidgetAction()
    }
}

extension WatchingControlWidgetActionHandler {
    static let app = WatchingControlWidgetActionHandler {
        async let mediaRefresh = RipppleIntentService.refreshLiveActivity()
        async let widgetDataRefresh: Void = RipppleIntentService.refreshWidgetData()
        let (media, _) = try await(mediaRefresh, widgetDataRefresh)
        if let media = media {
            let dates = await currentWatchingDates()
            await publishWatchingControlWidgetItem(media: media,
                                                   state: .currentlyWatching,
                                                   isCheckInActive: true,
                                                   checkInStartDate: dates.start,
                                                   checkInEndDate: dates.end)
        } else {
            await publishWatchingControlWidgetItem(media: nil,
                                                   state: .lastWatched,
                                                   isCheckInActive: false,
                                                   checkInStartDate: nil,
                                                   checkInEndDate: nil)
        }
    } cancelCheckIn: {
        try await RipppleIntentService.cancelCheckIn()
        await publishWatchingControlWidgetItem(media: nil,
                                               state: .lastWatched,
                                               isCheckInActive: false,
                                               checkInStartDate: nil,
                                               checkInEndDate: nil)
    }
}

@MainActor
private func currentWatchingDates() -> (start: Date?, end: Date?) {
    (WatchingManager.shared.watchingItem?.startDate,
     WatchingManager.shared.watchingItem?.expireDate)
}

private func publishWatchingControlWidgetItem(media: MediaEntity?,
                                              state: WatchingControlWidgetItemState,
                                              isCheckInActive: Bool,
                                              checkInStartDate: Date?,
                                              checkInEndDate: Date?) async {
    let resolvedMedia: MediaEntity?
    if let media = media {
        resolvedMedia = media
    } else {
        resolvedMedia = try? await RipppleIntentService.lastWatchedMedia()
    }

    let item: WatchingControlWidgetItem?
    switch resolvedMedia?.value {
    case .movie(let movie):
        item = WatchingControlWidgetItem(state: state,
                                         traktIdentifier: movie.traktIdentifier,
                                         tmdbIdentifier: movie.tmdbIdentifier,
                                         tmdbMediaType: "movie",
                                         title: movie.title,
                                         subtitle: movie.year.map(String.init),
                                         deeplink: URL(string: "ripl://movies/\(movie.traktIdentifier)")!,
                                         showTraktIdentifier: nil,
                                         isCheckInActive: isCheckInActive,
                                         checkInStartDate: checkInStartDate,
                                         checkInEndDate: checkInEndDate)
    case .show(let show):
        item = WatchingControlWidgetItem(state: state,
                                         traktIdentifier: show.traktIdentifier,
                                         tmdbIdentifier: show.tmdbIdentifier,
                                         tmdbMediaType: "tv",
                                         title: show.title,
                                         subtitle: nil,
                                         deeplink: URL(string: "ripl://shows/\(show.traktIdentifier)")!,
                                         showTraktIdentifier: show.traktIdentifier,
                                         isCheckInActive: isCheckInActive,
                                         checkInStartDate: checkInStartDate,
                                         checkInEndDate: checkInEndDate)
    case .episode(let episode):
        item = WatchingControlWidgetItem(state: state,
                                         traktIdentifier: episode.traktIdentifier,
                                         tmdbIdentifier: episode.show.tmdbIdentifier,
                                         tmdbMediaType: "tv",
                                         title: episode.show.title,
                                         subtitle: episode.localizedEpisodeNumber,
                                         deeplink: URL(string: "ripl://shows/\(episode.show.traktIdentifier)/seasons/\(episode.season.number)/episodes/\(episode.episodeNumber)")!,
                                         showTraktIdentifier: episode.show.traktIdentifier,
                                         isCheckInActive: isCheckInActive,
                                         checkInStartDate: checkInStartDate,
                                         checkInEndDate: checkInEndDate)
    case nil:
        item = nil
    }
    WatchingControlWidgetStorage.publish(item)
}

struct CancelCheckInIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cancel Current Check-In"
    static let description = IntentDescription("Asks for confirmation, then cancels your current Trakt check-in. This action has no input and does not return a value. Requires a signed-in Trakt account.",
                                               categoryName: "Check-In")

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(
            actionName: .custom(acceptLabel: "Cancel Check-In",
                                acceptAlternatives: ["Cancel"],
                                denyLabel: "Keep Watching",
                                denyAlternatives: ["Don’t Cancel"],
                                destructive: true),
            dialog: "Cancel the current check-in?"
        )
        try await RipppleIntentService.cancelCheckIn()
        return .result(dialog: "Canceled the current check-in.")
    }
}

struct RefreshLiveActivityIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Refresh App Data"
    static let description = IntentDescription("Refreshes your watched activity, To Watch, calendar, upcoming, and currently watching data throughout the app and its widgets, then returns the media from your active check-in. This action has no input and requires a signed-in Trakt account.",
                                               categoryName: "Data",
                                               resultValueName: "Currently Watching")

    func perform() async throws -> some IntentResult & ReturnsValue<MediaEntity> & ProvidesDialog {
        async let currentlyWatchingRefresh = RipppleIntentService.refreshLiveActivity()
        async let widgetDataRefresh: Void = RipppleIntentService.refreshWidgetData()
        let (refreshedMedia, _) = try await(currentlyWatchingRefresh, widgetDataRefresh)
        guard let media = refreshedMedia else {
            throw RipppleIntentError.nothingCurrentlyWatching
        }

        let dialog: IntentDialog
        switch media.value {
        case .movie(let movie):
            dialog = "Refreshed your app data. You're currently watching \(movie.title)."
        case .show(let show):
            dialog = "Refreshed your app data. You're currently watching \(show.title)."
        case .episode(let episode):
            dialog = "Refreshed your app data. You're currently watching \(episode.show.title) \(episode.localizedEpisodeNumber)."
        }
        return .result(value: media, dialog: dialog)
    }
}

// MARK: - App Shortcuts

struct RipppleAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: FetchTrendingMoviesIntent(),
                    phrases: [
                        "Get trending movies in \(.applicationName)",
                        "Show trending movies in \(.applicationName)"
                    ],
                    shortTitle: "Trending Movies",
                    systemImageName: "film")

        AppShortcut(intent: FetchTrendingShowsIntent(),
                    phrases: [
                        "Get trending TV shows in \(.applicationName)",
                        "Show trending TV shows in \(.applicationName)"
                    ],
                    shortTitle: "Trending TV Shows",
                    systemImageName: "tv")

        AppShortcut(intent: FetchTrendingMediaIntent(),
                    phrases: [
                        "Get trending media in \(.applicationName)",
                        "Show trending media in \(.applicationName)"
                    ],
                    shortTitle: "Trending Media",
                    systemImageName: "rectangle.stack")

        AppShortcut(intent: AddToWatchlistIntent(),
                    phrases: [
                        "Add media to my watchlist in \(.applicationName)",
                        "Add something to my watchlist in \(.applicationName)"
                    ],
                    shortTitle: "Add to Watchlist",
                    systemImageName: "bookmark")

        AppShortcut(intent: FetchEpisodesToWatchIntent(),
                    phrases: [
                        "Get my episodes to watch in \(.applicationName)",
                        "Show my episodes to watch in \(.applicationName)"
                    ],
                    shortTitle: "Episodes to Watch",
                    systemImageName: "play.square.stack")

        AppShortcut(intent: FetchNextEpisodeIntent(),
                    phrases: [
                        "Get my next episode in \(.applicationName)",
                        "Find the next episode in \(.applicationName)"
                    ],
                    shortTitle: "Next Episode",
                    systemImageName: "play.rectangle")

        AppShortcut(intent: CheckInIntent(),
                    phrases: [
                        "Check in with \(.applicationName)",
                        "Start a check-in in \(.applicationName)"
                    ],
                    shortTitle: "Check In",
                    systemImageName: "play.circle")

        AppShortcut(intent: CancelCheckInIntent(),
                    phrases: [
                        "Cancel my check-in in \(.applicationName)",
                        "Stop my current check-in in \(.applicationName)"
                    ],
                    shortTitle: "Cancel Check-In",
                    systemImageName: "stop.circle")

        AppShortcut(intent: RefreshLiveActivityIntent(),
                    phrases: [
                        "Refresh my data in \(.applicationName)",
                        "Update my app data in \(.applicationName)"
                    ],
                    shortTitle: "Refresh Data",
                    systemImageName: "arrow.clockwise")

        AppShortcut(intent: SearchMediaIntent(),
                    phrases: [
                        "Search for media in \(.applicationName)",
                        "Find media in \(.applicationName)"
                    ],
                    shortTitle: "Search Media",
                    systemImageName: "magnifyingglass")
    }
}
