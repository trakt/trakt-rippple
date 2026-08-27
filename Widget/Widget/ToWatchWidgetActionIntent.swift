//
//  ToWatchWidgetActionIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 01/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import Foundation
import WidgetKit

enum ToWatchWidgetContent: String, AppEnum {
    case episodes
    case movies

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Content")
    static let typeDisplayName: LocalizedStringResource = "Content"
    static let caseDisplayRepresentations: [ToWatchWidgetContent: DisplayRepresentation] = [
        .episodes: "Episodes",
        .movies: "Movies"
    ]
}

enum ToWatchWidgetAction: String, AppEnum {
    case none
    case checkIn
    case markWatched

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Action")
    static let typeDisplayName: LocalizedStringResource = "Action"
    static let caseDisplayRepresentations: [ToWatchWidgetAction: DisplayRepresentation] = [
        .none: "No Button",
        .checkIn: "Check In",
        .markWatched: "Mark Watched"
    ]

    var systemImage: String? {
        switch self {
        case .none:
            return nil
        case .checkIn:
            return "play.fill"
        case .markWatched:
            return "checkmark"
        }
    }
}

enum ToWatchWidgetMedia {
    case episode(ToWatchWidgetEpisode)
    case movie(ToWatchWidgetMovie)
}

struct ToWatchWidgetActionHandler {
    let performAction: @Sendable (ToWatchWidgetAction, ToWatchWidgetMedia) async throws -> Void
    let refreshEpisode: @Sendable (Int) async -> Void
    let refreshMovies: @Sendable () async -> Void
}

private func performToWatchWidgetAction(_ action: ToWatchWidgetAction,
                                        media: ToWatchWidgetMedia,
                                        actionHandler: ToWatchWidgetActionHandler,
                                        refresh: @Sendable () async -> Void) async throws {
    let notificationAction: WidgetIntentNotificationsManager.Action
    switch action {
    case .none:
        return
    case .checkIn:
        notificationAction = .checkIn(media.notificationMedia)
    case .markWatched:
        notificationAction = .markWatched(media.notificationMedia)
    }
    let notification = WidgetIntentNotificationsManager.shared.start(action: notificationAction)

    do {
        try Task.checkCancellation()
        try await actionHandler.performAction(action, media)

        try Task.checkCancellation()
        await refresh()
        WidgetIntentNotificationsManager.shared.succeed(notification)
    } catch {
        WidgetIntentNotificationsManager.shared.fail(notification, error: error)
        throw error
    }
}

private extension ToWatchWidgetMedia {
    var notificationMedia: WidgetIntentNotificationsManager.Media {
        switch self {
        case .episode(let episode):
            return WidgetIntentNotificationsManager.Media(description: "\(episode.showTitle) · \(episode.localizedEpisodeNumber)",
                                                          deeplink: episode.episodeDeeplink)
        case .movie(let movie):
            return WidgetIntentNotificationsManager.Media(description: movie.title,
                                                          deeplink: movie.deeplink)
        }
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct EpisodesToWatchRefreshWidgetActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Update Episode To Watch"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: ToWatchWidgetActionHandler

    @Parameter(title: "Action")
    var action: ToWatchWidgetAction

    @Parameter(title: "Episode Trakt ID")
    var episodeTraktIdentifier: Int

    @Parameter(title: "Show Trakt ID")
    var showTraktIdentifier: Int

    @Parameter(title: "Show Title")
    var showTitle: String

    @Parameter(title: "Season Number")
    var seasonNumber: Int

    @Parameter(title: "Episode Number")
    var episodeNumber: Int

    init() {}

    init(action: ToWatchWidgetAction, episode: ToWatchWidgetEpisode) {
        self.action = action
        episodeTraktIdentifier = episode.episodeTraktIdentifier
        showTraktIdentifier = episode.showTraktIdentifier
        showTitle = episode.showTitle
        seasonNumber = episode.seasonNumber
        episodeNumber = episode.episodeNumber
    }

    func perform() async throws -> some IntentResult {
        guard action != .none else { return .result() }

        let episode = ToWatchWidgetEpisode(episodeTraktIdentifier: episodeTraktIdentifier,
                                           showTraktIdentifier: showTraktIdentifier,
                                           showTMDbIdentifier: nil,
                                           showTitle: showTitle,
                                           seasonNumber: seasonNumber,
                                           episodeNumber: episodeNumber,
                                           runtime: nil,
                                           behind: nil)
        let media = ToWatchWidgetMedia.episode(episode)
        try await performToWatchWidgetAction(action,
                                             media: media,
                                             actionHandler: actionHandler) {
            await actionHandler.refreshEpisode(showTraktIdentifier)
        }
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct MoviesToWatchRefreshWidgetActionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Update Movie To Watch"
    static let isDiscoverable = false
    static var allowedExecutionTargets: IntentExecutionTargets {
        .main
    }

    @Dependency
    private var actionHandler: ToWatchWidgetActionHandler

    @Parameter(title: "Action")
    var action: ToWatchWidgetAction

    @Parameter(title: "Movie Trakt ID")
    var movieTraktIdentifier: Int

    @Parameter(title: "Movie Title")
    var movieTitle: String

    @Parameter(title: "Movie Release Year")
    var movieReleaseYear: Int?

    init() {}

    init(action: ToWatchWidgetAction, movie: ToWatchWidgetMovie) {
        self.action = action
        movieTraktIdentifier = movie.movieTraktIdentifier
        movieTitle = movie.title
        movieReleaseYear = movie.releaseYear
    }

    func perform() async throws -> some IntentResult {
        guard action != .none else { return .result() }

        let movie = ToWatchWidgetMovie(movieTraktIdentifier: movieTraktIdentifier,
                                       movieTMDbIdentifier: nil,
                                       title: movieTitle,
                                       releaseYear: movieReleaseYear,
                                       runtime: nil)
        let media = ToWatchWidgetMedia.movie(movie)
        try await performToWatchWidgetAction(action,
                                             media: media,
                                             actionHandler: actionHandler) {
            await actionHandler.refreshMovies()
        }
        return .result()
    }
}
