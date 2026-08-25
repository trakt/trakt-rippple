//
//  ToWatchWidgetActionIntent.swift
//  Rippple
//
//  Created by Kevin Cador on 01/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import AppIntents
import Foundation
#if DEBUG || targetEnvironment(simulator)
import UserNotifications
#endif
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

#if DEBUG || targetEnvironment(simulator)
private actor ToWatchWidgetNotificationManager {
    enum State {
        case loading
        case success
        case error
    }

    static let shared = ToWatchWidgetNotificationManager()

    private static let timeToLive: Duration = .seconds(5)

    private var expirationTask: _Concurrency.Task<Void, Never>?

    func show(state: State, action: ToWatchWidgetAction, media: ToWatchWidgetMedia) async {
        expirationTask?.cancel()

        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "To Watch Widget"
        content.body = body(for: state, action: action, media: media)
        content.userInfo = ["link": deeplink(for: media).absoluteString]
        content.interruptionLevel = .active

        let request = UNNotificationRequest(identifier: ToWatchWidgetStorage.actionNotificationIdentifier,
                                            content: content,
                                            trigger: nil)
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Unable to show To Watch widget notification: \(error)")
        }

        expirationTask = _Concurrency.Task {
            try? await _Concurrency.Task.sleep(for: ToWatchWidgetNotificationManager.timeToLive)
            guard !_Concurrency.Task.isCancelled else { return }
            notificationCenter.removeDeliveredNotifications(withIdentifiers: [ToWatchWidgetStorage.actionNotificationIdentifier])
        }
    }

    private func body(for state: State, action: ToWatchWidgetAction, media: ToWatchWidgetMedia) -> String {
        let mediaDescription: String
        switch media {
        case .episode(let episode):
            mediaDescription = "\(episode.showTitle) \(episode.localizedEpisodeNumber)"
        case .movie(let movie):
            mediaDescription = movie.title
        }

        switch (state, action) {
        case (.loading, .checkIn):
            return "Checking in to \(mediaDescription)…"
        case (.success, .checkIn):
            return "Checked in to \(mediaDescription)."
        case (.error, .checkIn):
            return "Couldn’t check in to \(mediaDescription)."
        case (.loading, .markWatched):
            return "Marking \(mediaDescription) watched…"
        case (.success, .markWatched):
            return "Marked \(mediaDescription) watched."
        case (.error, .markWatched):
            return "Couldn’t mark \(mediaDescription) watched."
        case (_, .none):
            return mediaDescription
        }
    }

    private func deeplink(for media: ToWatchWidgetMedia) -> URL {
        switch media {
        case .episode(let episode):
            return episode.episodeDeeplink
        case .movie(let movie):
            return movie.deeplink
        }
    }
}
#endif

private func withToWatchWidgetActionNotifications(action: ToWatchWidgetAction,
                                                  media: ToWatchWidgetMedia,
                                                  operation: () async throws -> Void) async throws {
    #if DEBUG || targetEnvironment(simulator)
    await ToWatchWidgetNotificationManager.shared.show(state: .loading, action: action, media: media)
    #endif
    do {
        try await operation()
    } catch {
        #if DEBUG || targetEnvironment(simulator)
        await ToWatchWidgetNotificationManager.shared.show(state: .error, action: action, media: media)
        #endif
        throw error
    }
    #if DEBUG || targetEnvironment(simulator)
    await ToWatchWidgetNotificationManager.shared.show(state: .success, action: action, media: media)
    #endif
}

private func performToWatchWidgetAction(_ action: ToWatchWidgetAction,
                                        media: ToWatchWidgetMedia,
                                        description: String,
                                        refreshDescription: String,
                                        progress: Progress,
                                        actionHandler: ToWatchWidgetActionHandler,
                                        refresh: @Sendable () async -> Void) async throws {
    progress.totalUnitCount = 2
    progress.localizedDescription = description
    progress.localizedAdditionalDescription = "Performing action"

    try Task.checkCancellation()
    try await actionHandler.performAction(action, media)
    progress.completedUnitCount = 1
    progress.localizedAdditionalDescription = refreshDescription

    try Task.checkCancellation()
    await refresh()
    progress.completedUnitCount = 2
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct EpisodesToWatchRefreshWidgetActionIntent: LongRunningIntent, CancellableIntent, LiveActivityIntent {
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
        try await withToWatchWidgetActionNotifications(action: action, media: media) {
            try await performBackgroundTask {
                try await performToWatchWidgetAction(action,
                                                     media: media,
                                                     description: "Updating episode",
                                                     refreshDescription: "Updating episodes",
                                                     progress: progress,
                                                     actionHandler: actionHandler) {
                    await actionHandler.refreshEpisode(showTraktIdentifier)
                }
            } onCancel: { _ in }
        }
        return .result()
    }
}

@available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *)
struct MoviesToWatchRefreshWidgetActionIntent: LongRunningIntent, CancellableIntent, LiveActivityIntent {
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
        try await withToWatchWidgetActionNotifications(action: action, media: media) {
            try await performBackgroundTask {
                try await performToWatchWidgetAction(action,
                                                     media: media,
                                                     description: "Updating movie",
                                                     refreshDescription: "Updating movies",
                                                     progress: progress,
                                                     actionHandler: actionHandler) {
                    await actionHandler.refreshMovies()
                }
            } onCancel: { _ in }
        }
        return .result()
    }
}
