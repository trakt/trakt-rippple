//
//  Media.swift
//  Rippple
//
//  Created by Kevin Cador on 23/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation
import UIKit
import SafariServices

enum MediaModel: Equatable, Hashable, Codable {
    enum CodingKeys: Int, CodingKey {
        case type
        case movie
        case show
        case episode
        case season
        case list
        case showProgress
    }

    enum MediaModelError: Error {
        case decodingError
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let type = CodingKeys(intValue: try container.decode(Int.self, forKey: .type)) else {
            throw MediaModelError.decodingError
        }
        switch type {
        case .type:
            fatalError()
        case .movie:
            let movie = try container.decode(Movie.self, forKey: .movie)
            self = .movie(movie)
        case .show:
            let show = try container.decode(Show.self, forKey: .show)
            self = .show(show)
        case .episode:
            let show = try container.decode(Show.self, forKey: .show)
            let episode = try container.decode(Episode.self, forKey: .episode)
            self = .episode(episode, show)
        case .season:
            let show = try container.decode(Show.self, forKey: .show)
            let season = try container.decode(Season.self, forKey: .season)
            self = .season(season, show)
        case .list:
            let list = try container.decode(List.self, forKey: .list)
            self = .list(list)
        case .showProgress:
            let show = try container.decode(Show.self, forKey: .show)
            let progress = try container.decode(ShowProgress.self, forKey: .showProgress)
            self = .showProgress(show, progress)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .movie(let movie):
            try container.encode(CodingKeys.movie.intValue!, forKey: .type)
            try container.encode(movie, forKey: .movie)
        case .show(let show):
            try container.encode(CodingKeys.show.intValue!, forKey: .type)
            try container.encode(show, forKey: .show)
        case .episode(let episode, let show):
            try container.encode(CodingKeys.episode.intValue!, forKey: .type)
            try container.encode(show, forKey: .show)
            try container.encode(episode, forKey: .episode)
        case .season(let season, let show):
            try container.encode(CodingKeys.season.intValue!, forKey: .type)
            try container.encode(show, forKey: .show)
            try container.encode(season, forKey: .season)
        case .list(let list):
            try container.encode(CodingKeys.list.intValue!, forKey: .type)
            try container.encode(list, forKey: .list)
        case .showProgress(let show, let progress):
            try container.encode(CodingKeys.showProgress.intValue!, forKey: .type)
            try container.encode(show, forKey: .show)
            try container.encode(progress, forKey: .showProgress)
        }
    }

    static func == (lhs: MediaModel, rhs: MediaModel) -> Bool {
        switch (lhs, rhs) {
        case let (.movie(left), .movie(right)): return left == right
        case let (.show(left), .show(right)): return left == right
        case let (.episode(left, _), .episode(right, _)): return left == right
        case let (.season(left, _), .season(right, _)): return left == right
        case let (.list(left), .list(right)): return left == right
        case let (.showProgress(left, left2), .showProgress(right, right2)): return left == right && left2.nextEpisodeToWatch == right2.nextEpisodeToWatch && left2.toRewatchCount == right2.toRewatchCount
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .movie(let movie):
            hasher.combine(movie)
        case .show(let show):
            hasher.combine(show)
        case .episode(let episode, _):
            hasher.combine(episode)
        case .season(let season, _):
            hasher.combine(season)
        case .list(let list):
            hasher.combine(list)
        case .showProgress(let show, let progress):
            hasher.combine(show)
            hasher.combine(progress.nextEpisodeToWatch)
            hasher.combine(progress.toRewatchCount)
        }
    }

    var mediaTitle: String {
        switch self {
        case .movie(let movie):
            return "\(movie.title)\((movie.releaseYear != nil) ? " · \(movie.releaseYear!)" : "")"
        case .show(let show):
            return "\(show.title)\((show.releaseYear != nil) ? " · \(show.releaseYear!)" : "")"
        case .episode(let episode, let show):
            return "\(show.title) · \(episode.localizedEpisodeNumber)"
        case .season(let season, let show):
            return "\(show.title) · \(season.title ?? season.localizedSeasonNumber)"
        case .list(let list):
            return "\(list.name.emojiUnescapedString)"
        case .showProgress(let show, _):
            return "\(show.title)"
        }
    }

    var traktId: Int64 {
        switch self {
        case .movie(let movie):
            return movie.identifiers.trakt!
        case .show(let show):
            return show.identifiers.trakt!
        case .episode(let episode, _):
            return episode.identifiers.trakt!
        case .season(let season, _):
            return season.identifiers.trakt!
        case .list(let list):
            return list.identifiers.trakt!
        case .showProgress(let show, _):
            return show.identifiers.trakt!
        }
    }

    var tmdbId: Int64? {
        switch self {
        case .movie(let movie):
            return movie.identifiers.tmdb
        case .show(let show):
            return show.identifiers.tmdb
        case .episode(let episode, _):
            return episode.identifiers.tmdb
        case .season(let season, _):
            return season.identifiers.tmdb
        case .list:
            fatalError("Impossible to get a tmdb id for a trakt list, always")
        case .showProgress:
            fatalError("Impossible to get a tmdb id for a trakt show progress, doesn't make sense")
        }
    }

    case movie(Movie)
    case show(Show)
    case episode(Episode, Show)
    case season(Season, Show)
    case list(List)

    case showProgress(Show, ShowProgress)

    init(item: MediaItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .list, .officiallist:
            self = .list(item.list!)
        case .unknown:
            fatalError("Unknonw media type")
        }
    }

    init?(item: HistoryItem) {
        if let movie = item.movie {
            self = .movie(movie)
        } else if let show = item.show, let episode = item.episode {
            self = .episode(episode, show)
        } else {
            return nil
        }
    }

    init?(item: NoteItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .unknown:
            return nil
        }
    }

    init(item: WatchlistItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .list, .officiallist:
            self = .list(item.list!)
        case .unknown:
            fatalError("Unknonw media type")
        }
    }

    init(item: CollectionItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .list, .officiallist:
            self = .list(item.list!)
        case .unknown:
            fatalError("Unknonw media type")
        }
    }

    init(item: RatedItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .unknown:
            fatalError("Unknonw media type")
        }
    }

    init(item: WatchedItem) {
        switch item.type {
        case .movie:
            self = .movie(item.movie!)
        case .show:
            self = .show(item.show!)
        case .season:
            self = .season(item.season!, item.show!)
        case .episode:
            self = .episode(item.episode!, item.show!)
        case .list, .officiallist:
            self = .list(item.list!)
        case .unknown:
            fatalError("Unknonw media type")
        }
    }

    init?(item: WatchingItem) {
        if item.movie != nil {
            self = .movie(item.movie!)
        } else if item.episode != nil {
            self = .episode(item.episode!, item.show!)
        } else {
            return nil
        }
    }

    var movie: Movie? {
        if case let .movie(movie) = self {
            return movie
        } else {
            return nil
        }
    }

//    @available(*, deprecated, message: "Use other accessor instead")
    var show: Show? {
        if case let .show(show) = self {
            return show
        } else if case let .showProgress(show, _) = self {
            return show
        } else if case let .season(_, show) = self {
            return show
        } else if case let .episode(_, show) = self {
            return show
        } else {
            return nil
        }
    }

    var showShow: Show? {
        if case let .show(show) = self {
            return show
        } else {
            return nil
        }
    }

    var showProgressShow: Show? {
        if case let .showProgress(show, _) = self {
            return show
        } else {
            return nil
        }
    }

    var toRewatchCount: Int {
        if case let .showProgress(_, progress) = self {
            return progress.toRewatchCount
        } else {
            return 0
        }
    }

    var seasonShow: Show? {
        if case let .season(_, show) = self {
            return show
        } else {
            return nil
        }
    }

    var episodeShow: Show? {
        if case let .episode(_, show) = self {
            return show
        } else {
            return nil
        }
    }

    var season: Season? {
        if case let .season(season, _) = self {
            return season
        } else {
            return nil
        }
    }

//    @available(*, deprecated, message: "Use other accessor instead")
    var episode: Episode? {
        if case let .episode(episode, _) = self {
            return episode
        } else if case let .showProgress(_, progress) = self {
            return progress.nextEpisodeToWatch
        } else {
            return nil
        }
    }

    var episodeEpisode: Episode? {
        if case let .episode(episode, _) = self {
            return episode
        } else {
            return nil
        }
    }

    var showProgressEpisode: Episode? {
        if case let .showProgress(_, progress) = self {
            return progress.nextEpisodeToWatch
        } else {
            return nil
        }
    }

    var traktWebsiteMediaLink: URL? {
        switch self {
        case .movie(let movie):
            return URL(string: "https://trakt.tv/movies/\(movie.identifiers.slugOrTraktId)")
        case .show(let show):
            return URL(string: "https://trakt.tv/shows/\(show.identifiers.slugOrTraktId)")
        case .episode(let episode, let show):
            return URL(string: "https://trakt.tv/shows/\(show.identifiers.slugOrTraktId)/seasons/\(episode.season)/episodes/\(episode.number)")
        case .season(let season, let show):
            return URL(string: "https://trakt.tv/shows/\(show.identifiers.slugOrTraktId)/seasons/\(season.number)")
        case .list:
            fatalError()
        case .showProgress(let show, let progress):
            if let episode = progress.nextEpisodeToWatch {
                return URL(string: "https://trakt.tv/shows/\(show.identifiers.slugOrTraktId)/seasons/\(episode.season)/episodes/\(episode.number)")
            } else {
                return URL(string: "https://trakt.tv/shows/\(show.identifiers.slugOrTraktId)")
            }
        }
    }

    var ripppleappLink: URL? {
        switch self {
        case .movie(let movie):
            return URL(string: "https://rippple.app/movies/\(movie.identifiers.slugOrTraktId)")
        case .show(let show):
            return URL(string: "https://rippple.app/shows/\(show.identifiers.slugOrTraktId)")
        case .episode:
            fatalError()
        case .season:
            fatalError()
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var deeplink: URL? {
        switch self {
        case .movie(let movie):
            return URL(string: "ripl://movies/\(movie.identifiers.trakt!)")
        case .show(let show):
            return URL(string: "ripl://shows/\(show.identifiers.trakt!)")
        case .episode(let episode, let show):
            return URL(string: "ripl://shows/\(show.identifiers.trakt!)/seasons/\(episode.season)/episodes/\(episode.number)")
        case .season(let season, let show):
            return URL(string: "ripl://shows/\(show.identifiers.trakt!)/seasons/\(season.number)")
        case .list:
            fatalError()
        case .showProgress(let show, let progress):
            if let episode = progress.nextEpisodeToWatch {
                return URL(string: "ripl://shows/\(show.identifiers.trakt!)/seasons/\(episode.season)/episodes/\(episode.number)")
            } else {
                return URL(string: "ripl://shows/\(show.identifiers.trakt!)")
            }
        }
    }

    var tmdbURL: URL? {
        switch self {
        case .movie(let movie):
            if let tmdbID = movie.identifiers.tmdb {
                return URL(string: "https://www.themoviedb.org/movie/\(tmdbID)")
            } else {
                return nil
            }
        case .show(let show):
            if let tmdbID = show.identifiers.tmdb {
                return URL(string: "https://www.themoviedb.org/tv/\(tmdbID)")
            } else {
                return nil
            }
        case .episode(let episode, let show):
            if let tmdbID = show.identifiers.tmdb {
                return URL(string: "https://www.themoviedb.org/tv/\(tmdbID)/season/\(episode.season)/episode/\(episode.number)")
            } else {
                return nil
            }
        case .season(let season, let show):
            if let tmdbID = show.identifiers.tmdb {
                return URL(string: "https://www.themoviedb.org/tv/\(tmdbID)/season/\(season.number)")
            } else {
                return nil
            }
        case .list:
            fatalError()
        case .showProgress:
            return nil
        }
    }

    var imdbURL: URL? {
        switch self {
        case .movie(let movie):
            if let imdbID = movie.identifiers.imdb {
                return URL(string: "https://www.imdb.com/title/\(imdbID)")
            } else {
                return nil
            }
        case .show(let show):
            if let imdbID = show.identifiers.imdb {
                return URL(string: "https://www.imdb.com/title/\(imdbID)")
            } else {
                return nil
            }
        case .episode(let episode, _):
            if let imdbID = episode.identifiers.imdb {
                return URL(string: "https://www.imdb.com/title/\(imdbID)")
            } else {
                return nil
            }
        case .season(let season, _):
            if let imdbID = season.identifiers.imdb {
                return URL(string: "https://www.imdb.com/title/\(imdbID)")
            } else {
                return nil
            }
        case .list:
            fatalError()
        case .showProgress:
            return nil
        }
    }

    var homepageURL: URL? {
        switch self {
        case .movie(let movie):
            if let homepage = movie.homepage {
                return URL(string: homepage)
            } else {
                return nil
            }
        case .show(let show):
            if let homepage = show.homepage {
                return URL(string: homepage)
            } else {
                return nil
            }
        case .episode:
            return nil
        case .season:
            return nil
        case .list:
            fatalError()
        case .showProgress:
            return nil
        }
    }

    var trailerURL: URL? {
        switch self {
        case .movie(let movie):
            if let trailer = movie.trailer {
                return URL(string: trailer)
            } else {
                return nil
            }
        case .show(let show):
            if let trailer = show.trailer {
                return URL(string: trailer)
            } else {
                return nil
            }
        case .episode:
            return nil
        case .season:
            return nil
        case .list:
            fatalError()
        case .showProgress:
            return nil
        }
    }
}

extension Movie {

    var mediaModel: MediaModel {
        return MediaModel(item: MediaItem(movie: self, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil))
    }

}

extension Show {

    var mediaModel: MediaModel {
        return MediaModel(item: MediaItem(movie: nil, show: self, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil))
    }

}

extension Episode {

    func mediaModel(given show: Show) -> MediaModel {
        return MediaModel(item: MediaItem(movie: nil, show: show, episode: self, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil))
    }

}

extension Season {

    func mediaModel(given show: Show) -> MediaModel {
        return MediaModel(item: MediaItem(movie: nil, show: show, episode: nil, season: self, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil))
    }

}

extension MediaModel {

    private var checkinItem: CheckinItem? {
        if case let .movie(movie) = self {
            return CheckinItem(movie: movie)
        }
        if case let .episode(episode, _) = self {
            return CheckinItem(episode: episode)
        }
        return nil
    }

    func checkin() {
        guard let checkinItem = checkinItem else {
            return
        }

        SwiftMessages.show(message: "Checking In...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.checkin(item: checkinItem),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    // check-in already in progress
                                                    if moyaResponse.statusCode == 409 {
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "✌️ Check-in already in progress", style: .standout)
                                                        }
                                                    } else {
                                                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                        print("Check-in successful \(response)")

                                                        self.checkForStinger()

                                                        DispatchQueue.main.async {
                                                            WatchingManager.shared.refreshWatching()
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "▶️ Checked in")
                                                        }
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        AppManager.shared.isUserInteractionEnabled = true
                                                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    AppManager.shared.isUserInteractionEnabled = true
                                                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    private func checkForStinger() {
        guard case let .movie(movie) = self else { return } // not a movie

        if let tmdbId = movie.identifiers.tmdb {
            TmdbAPIProvider.provider.request(TmdbAPIService.movieKeywords(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let keywords = try response.map(Keywords.self, using: TraktAPIProvider.decoder).keywords.map { $0.name }

                        buildCheckinStingerNotification(for: keywords)
                    } catch {
                        print("Keywords (tmdb) request JSON mapping failed! \(error)")
                    }
                case let .failure(error):
                    print("Keywords (tmdb) request failure \(error)")
                }
            }
        }
    }

    private func buildCheckinStingerNotification(for keywords: [String]) {
        guard case let .movie(movie) = self else { return } // not a movie
        if UserDefaults.standard.bool(forKey: "Stinger.alert.type") == false { return } // user dosn't want it

        let identifier = "CheckinStingerNotification-\(movie.title)"

        let content = UNMutableNotificationContent()

        let stingerMap: [(String, String)] = [
            ("beforecreditsstinger", "before"),
            ("duringcreditsstinger", "during"),
            ("aftercreditsstinger", "after")
        ]

        let found = stingerMap
            .filter { keywords.contains($0.0) }
            .map { $0.1 }

        guard !found.isEmpty else { return }

        let joined = ListFormatter.localizedString(byJoining: found)

        content.title = "Watch out 👀"
        content.subtitle = found.count == 1 ? "\(found.first!.capitalized)-credits stinger" : "\(joined.capitalized)-credits stingers"
        content.body = "\(movie.title) includes \(joined)-credits stinger\(found.count > 1 ? "s" : "")."

        content.threadIdentifier = identifier
        content.userInfo = ["link": "ripl://movies/\(movie.identifiers.trakt!)"]
        content.interruptionLevel = .timeSensitive
        content.sound = nil

        let uuidString = identifier
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content,
                                            trigger: nil)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
            if error != nil {
                print("notificationCenter.add error: \(error!)")
            } else {
                print("Added :\(request.content.title)\n\(request.content.body)")
            }
        }
    }

    func cancelCheckin() {
        SwiftMessages.show(message: "Canceling Check-in...", style: .loading)

        let identifier = "CheckinStingerNotification"
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])

        TraktAPIProvider.provider.request(TraktAPIService.cancelCheckin,
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Cancel Check-in successful \(response)")

                                                            DispatchQueue.main.async {
                                                                WatchingManager.shared.refreshWatching(with: nil)
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "▶️ Check-in canceled")
                                                            }
                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
                }
    }

    func markWatchedWhenReleased() {
        if let movie = movie {
            if let released = movie.released {
                let dateFormatter = DateFormatter.init()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                guard let date = dateFormatter.date(from: released) else {
                    markMovieWatched(at: Date()) // does nothing if not a movie
                    return
                }
                markMovieWatched(at: date) // does nothing if not a movie
            } else {
                markMovieWatched(at: Date()) // does nothing if not a movie
            }
        }
        if let episode = episode {
            markEpisodeWatched(at: episode.firstAired ?? Date()) // does nothing if not an episode
        }

    }

    func markWatched() {
        markMovieWatched(at: Date()) // does nothing if not a movie
        markEpisodeWatched(at: Date()) // does nothing if not an episode
    }

    private func markEpisodeWatched(at date: Date?) {
        guard let episode = episode else {
            return
        }

        SwiftMessages.show(message: "Adding to History...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addEpisodeToHistory(id: episode.identifiers.trakt!, watchedAt: date),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Mark episode watched successful \(response)")

                    DispatchQueue.main.async {
                        onMarkWatchedTransmitter.broadcast(self)
                        SwiftMessages.show(message: "✅ Added to watched history")
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    private func markMovieWatched(at date: Date?) {
        guard let movie = movie else {
            return
        }

        SwiftMessages.show(message: "Adding to History...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addMovieToHistory(id: movie.identifiers.trakt!, watchedAt: date),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Mark movie watched successful \(response)")

                    DispatchQueue.main.async {
                        onMarkWatchedTransmitter.broadcast(self)
                        SwiftMessages.show(message: "✅ Added to watched history")
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                }
            }
        }
    }
}

extension MediaModel {
    private var watchlistItem: WatchlistedItem {
        if let movie = movie {
            return WatchlistedItem(movie: movie)
        }
        if let episode = episode {
            return WatchlistedItem(episode: episode)
        }
        if let season = season {
            return WatchlistedItem(season: season)
        }
        if let show = show {
            return WatchlistedItem(show: show)
        }

        fatalError()
    }

    func addToWatchlist() {
        SwiftMessages.show(message: "Adding to Watchlist...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addToWatchlist(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Add to watchlist successful \(response)")

                                                            DispatchQueue.main.async {
                                                                WatchlistManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "🕒 Added to Watchlist")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
    }
    }

    func addToCollection() {
        if show?.airedEpisodes == 0 {
            SwiftMessages.show(message: "🤨 No aired episode found")
            return
        }

        SwiftMessages.show(message: "Adding to Library...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addToCollection(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Library successful \(response)")

                                                            DispatchQueue.main.async {
                                                                CollectionManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "📚 Added to Library")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
        }
    }

    func removeFromWatchlist() {
        SwiftMessages.show(message: "Removing from Watchlist...", style: .loading)

                TraktAPIProvider.provider.request(TraktAPIService.removeFromWatchlist(item: watchlistItem),
                                                          callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
    //                                                        guard let self = self else { return }
                                                            switch result {
                                                            case let .success(moyaResponse):
                                                                do {
                                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                                    print("Add to watchlist successful \(response)")

                                                                    DispatchQueue.main.async {
                                                                        WatchlistManager.shared.refresh()
                                                                        AppManager.shared.isUserInteractionEnabled = true
                                                                        SwiftMessages.show(message: "🕒 Removed from Watchlist")
                                                                    }

                                                                } catch {
                                                                    DispatchQueue.main.async {
                                                                        AppManager.shared.isUserInteractionEnabled = true
                                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                                    }
                                                                }
                                                            case let .failure(error):
                                                                DispatchQueue.main.async {
                                                                    AppManager.shared.isUserInteractionEnabled = true
                                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                                }
                                                            }
            }
    }

    func addToRecommendations() {
        var item = watchlistItem

        if let show = show {
            item = show.mediaModel.watchlistItem
        }

        SwiftMessages.show(message: "Adding to Favorites...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: item),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Recommendation successful \(response)")

                                                            DispatchQueue.main.async {
                                                                RecommendedManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "⭐️ Added to Favorites")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                        }
                                                    }
        }
    }

    func removeFromRecommendations() {

        SwiftMessages.show(message: "Removing from Favorites...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.removeFromRecommendations(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                        guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Removed from recommendations successful \(response)")

                                                            DispatchQueue.main.async {
                                                                RecommendedManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "⭐️ Removed from Favorites")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                        }
                                                    }
            }
    }

    func removeFromCollection() {
        SwiftMessages.show(message: "Removing from Library...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.removeFromCollection(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { /*[weak self]*/ result in
//                                                        guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Removed from Library successful \(response)")

                                                            DispatchQueue.main.async {
                                                                CollectionManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "📚 Removed from Library")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                        }
                                                    }
            }
    }

    func add(to list: List) {
        if SessionManager.shared.isLoggedOut { return }

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            MediaModel.addShowsToWatchlistUndercover(medias: [self])
        }

        TraktAPIProvider.provider.request(.addToList(id: list.identifiers.trakt!,
                                                     item: watchlistItem), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Add to list successful \(response)")

                    if response.statusCode == 201 {
                        DispatchQueue.main.async {
                            onListChangedTransmitter.broadcast([list])
                            AppManager.shared.isUserInteractionEnabled = true
                            SwiftMessages.show(message: "✅ Added to list")
                        }
                    }

                } catch {
                    DispatchQueue.main.async {
                        AppManager.shared.isUserInteractionEnabled = true
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    AppManager.shared.isUserInteractionEnabled = true
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                }
            }
        }
    }

    static public func addShowsToWatchlistUndercover(medias: [MediaModel]) {
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now()+2) {
            let dispatchGroup = DispatchGroup()
            for media in medias where media.showShow != nil {
                dispatchGroup.enter()
                TraktAPIProvider.noRatingProvider.request(.addToWatchlist(item: WatchlistedItem(show: media.showShow!)),
                                                  callbackQueue: DispatchQueue.global(qos: .utility)) { _ in
                    dispatchGroup.leave()
                }
            }
            dispatchGroup.wait()
            WatchlistManager.shared.refresh()
        }
    }

    static public func removeShowFromToWatchListUndercover(media: MediaModel) {
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if SessionManager.shared.isLoggedOut { return }

            var updatedLists = [List]()
            guard let listed = await media.fetchListed() else { return }
            await withDiscardingTaskGroup { group in
                for list in listed where list.user.isCurrentUser && EpisodeToWatchSettings.shared.lists.contains(list) {
                    group.addTask {
                        if let item = await media.removeFromListUndercover(list: list) {
                            updatedLists.append(item)
                        }
                    }
                }
            }
            if updatedLists.count > 0 {
                onListChangedTransmitter.broadcast(updatedLists)
            }
        }
    }

    static public func removeMovieFromToWatchListUndercover(media: MediaModel) {
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if SessionManager.shared.isLoggedOut { return }

            var updatedLists = [List]()
            guard let listed = await media.fetchListed() else { return }
            await withDiscardingTaskGroup { group in
                for list in listed where list.user.isCurrentUser && MovieToWatchSettings.shared.lists.contains(list) {
                    group.addTask {
                        if let item = await media.removeFromListUndercover(list: list) {
                            updatedLists.append(item)
                        }
                    }
                }
            }
            if updatedLists.count > 0 {
                onListChangedTransmitter.broadcast(updatedLists)
            }
        }
    }

    static public func removeEpisodeFromAnyListUndercover(media: MediaModel) {
        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            if SessionManager.shared.isLoggedOut { return }

            var updatedLists = [List]()
            guard let listed = await media.fetchListed() else { return }
            await withDiscardingTaskGroup { group in
                for list in listed {
                    group.addTask {
                        if let item = await media.removeFromListUndercover(list: list) {
                            updatedLists.append(item)
                        }
                    }
                }
            }
            if updatedLists.count > 0 {
                onListChangedTransmitter.broadcast(updatedLists)
            }
        }
    }

    private func removeFromListUndercover(list: List) async -> List? {
        let result: List? = await withCheckedContinuation { continuation in
            var watchlistedItem: WatchlistedItem
            switch self {
            case .movie(let movie):
                watchlistedItem = WatchlistedItem(movie: movie)
            case .show(let show):
                watchlistedItem = WatchlistedItem(show: show)
            case .episode(let episode, _):
                watchlistedItem = WatchlistedItem(episode: episode)
            default:
                fatalError("Trying to remove something not supported.")
            }

            TraktAPIProvider.noRatingProvider.request(.removeFromList(slug: list.user.slug,
                                                                      id: list.identifiers.trakt!,
                                                                      item: watchlistedItem), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        _ = try response.map(RemoveListItemsResponse.self,
                                                 using: TraktAPIProvider.decoder)

                        if response.statusCode == 200 {
                            print("Removed \(watchlistedItem) from \(list)")
                            continuation.resume(returning: list)
                        } else {
                            print("Didn't remove \(watchlistedItem) from \(list)")
                            continuation.resume(returning: nil)
                        }
                    } catch {
                        print("List remove request JSON mapping failed! \(error)")
                        continuation.resume(returning: nil)
                    }
                case let .failure(error):
                    print("List remove request failure \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    func fetchListed() async -> [List]? {
        let service: TraktAPIService = {
            switch self {
            case .movie(let movie):
                return .movieListed(id: movie.identifiers.trakt!)
            case .show(let show):
                return .showListed(id: show.identifiers.trakt!)
            case .episode(let episode, let show):
                return .episodeListed(id: show.identifiers.trakt!,
                                      season: episode.season,
                                      episode: episode.number)
            case .season(let season, let show):
                return .seasonListed(id: show.identifiers.trakt!,
                                     season: season.number)
            case .list:
                fatalError("List not handled for fetching listed")
            case .showProgress:
                fatalError("showProgress not handled for fetching listed")
            }
        }()

        let result: [List]? = await withCheckedContinuation { continuation in
            TraktAPIProvider.noChacheProvider.request(service,
                                                    callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: lists)
                    } catch {
                        print("Listed request JSON mapping failed! \(error)")
                        continuation.resume(returning: nil)
                    }
                case let .failure(error):
                    print("Listed request failure \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }
}

extension MediaModel {

    private func writeComment(media: MediaModel) {
        let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController

        composer.mediaModel = media

        UIApplication.shared.present(composer)
    }

    private func listManagement(media: MediaModel) {
        let listViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Lists Action") as! ListActionViewController

        listViewController.media = media

        UIApplication.shared.present(listViewController)
    }

    public func hide(from section: HiddenSection) {
        switch self {
        case .movie:
            hideMovie(from: section)
        case .show:
            hideShow(from: section)
        case .episode:
            hideShow(from: section)
        case .season:
            hideSeason(from: section)
        case .list:
            fatalError()
        case .showProgress:
            hideShow(from: section)
        }
    }

    public func hideShow(from section: HiddenSection) {
        let traktId = show!.identifiers.trakt!
        let type = "Show"

        SwiftMessages.show(message: "Hiding \(type)...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.hideShow(section: section,
                                                                   id: traktId),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Hide \(type) successful \(response)")

                                                    DispatchQueue.main.async {
                                                        HiddenMediaManager.shared.refresh()
                                                        SwiftMessages.show(message: "🙈 \(type) hidden")
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    public func hideSeason(from section: HiddenSection) {
        let traktId = season!.identifiers.trakt!
        let type = "Season"

        SwiftMessages.show(message: "Hiding \(type)...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.hideSeason(section: section,
                                                                     id: traktId),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Hide \(type) successful \(response)")

                                                    DispatchQueue.main.async {
                                                        HiddenMediaManager.shared.refresh()
                                                        SwiftMessages.show(message: "🙈 \(type) hidden")
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    public func hideMovie(from section: HiddenSection) {
        let traktId = movie!.identifiers.trakt!
        let type = "Movie"

        SwiftMessages.show(message: "Hiding \(type)...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.hideMovie(section: section,
                                                                   id: traktId),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Hide \(type) successful \(response)")

                                                    DispatchQueue.main.async {
                                                        HiddenMediaManager.shared.refresh()
                                                        SwiftMessages.show(message: "🙈 \(type) hidden")
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    public func unhideShow() {
        SwiftMessages.show(message: "Unhiding Show...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.unhideShow(section: .progressWatched, id: show!.identifiers.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Unhide Show successful \(response)")

                                                    DispatchQueue.main.async {
                                                        HiddenMediaManager.shared.refresh()
                                                        SwiftMessages.show(message: "🐵 Show unhidden")
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    public func unhideSeason() {
        SwiftMessages.show(message: "Unhiding Season...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.unhideSeason(section: .progressWatched, id: season!.identifiers.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Unhide Season successful \(response)")

                                                    DispatchQueue.main.async {
                                                        HiddenMediaManager.shared.refresh()
                                                        AppManager.shared.isUserInteractionEnabled = true
                                                        SwiftMessages.show(message: "🐵 Season unhidden")
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        AppManager.shared.isUserInteractionEnabled = true
                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    AppManager.shared.isUserInteractionEnabled = true
                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    private func presentNextEpisode(media: MediaModel) {
        let nextEpisodeToWatchNavigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "next episode") as! UINavigationController

        if let nextEpisodeViewController = nextEpisodeToWatchNavigationController.topViewController as? MediaShowNextLoadingViewController {
            nextEpisodeViewController.media = media
        }

        UIApplication.shared.present(nextEpisodeToWatchNavigationController)
    }

    var rateMenu: UIMenu {
        var rateActions = [UIAction]()
        if userRating == nil {
            let ratings = ["😴 1 - I fell asleep", "😩 2 - Terrible", "👎 3 - Bad", "🙁 4 - Poor", "😐 5 - Meh", "😌 6 - Fair", "👍 7 - Good", "👏 8 - Great", "👌 9 - Superb", "💯 10 - Masterpiece"]
            for index in 1...10 {
                let rateAction = UIAction(title: ratings[index-1]) { _ in
                    rate(rating: index) { error in
                        if error == nil {
                            SwiftMessages.show(message: "🌟 Rating sent")
                            switch index {
                            case 1:
                                AppManager.shared.emitEmoji(emoji: "😴")
                            case 2:
                                AppManager.shared.emitEmoji(emoji: "😩")
                            case 3:
                                AppManager.shared.emitEmoji(emoji: "👎")
                            case 4:
                                AppManager.shared.emitEmoji(emoji: "🙁")
                            case 5:
                                AppManager.shared.emitEmoji(emoji: "😐")
                            case 6:
                                AppManager.shared.emitEmoji(emoji: "😌")
                            case 7:
                                AppManager.shared.emitEmoji(emoji: "👍")
                            case 8:
                                AppManager.shared.emitEmoji(emoji: "👏")
                            case 9:
                                AppManager.shared.emitEmoji(emoji: "👌")
                            case 10:
                                AppManager.shared.emitEmoji(emoji: "💯")
                            default:
                                fatalError()
                            }
                            AppManager.shared.isUserInteractionEnabled = true
                        } else {
                            SwiftMessages.show(message: "😓 Rating failed", style: .error(error!))
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                }
                rateActions.append(rateAction)
            }
        } else {
            let ratings = ["❌ 0 - Remove Rating", "😴 1 - I fell asleep", "😩 2 - Terrible", "👎 3 - Bad", "🙁 4 - Poor", "😐 5 - Meh", "😌 6 - Fair", "👍 7 - Good", "👏 8 - Great", "👌 9 - Superb", "💯 10 - Masterpiece"]
            for index in 0...10 {
                let rateAction = UIAction(title: ratings[index], state: userRating == index ? .on : .off) { _ in
                    rate(rating: index) { error in
                        if index == 0 {
                            if error == nil {
                                SwiftMessages.show(message: "🌟 Rating removed")
                                AppManager.shared.isUserInteractionEnabled = true
                            } else {
                                SwiftMessages.show(message: "😓 Rating removal failed", style: .error(error!))
                                AppManager.shared.isUserInteractionEnabled = true
                            }
                        } else {
                            if error == nil {
                                SwiftMessages.show(message: "🌟 Rating sent")
                                switch index {
                                case 1:
                                    AppManager.shared.emitEmoji(emoji: "😴")
                                case 2:
                                    AppManager.shared.emitEmoji(emoji: "😩")
                                case 3:
                                    AppManager.shared.emitEmoji(emoji: "👎")
                                case 4:
                                    AppManager.shared.emitEmoji(emoji: "🙁")
                                case 5:
                                    AppManager.shared.emitEmoji(emoji: "😐")
                                case 6:
                                    AppManager.shared.emitEmoji(emoji: "😌")
                                case 7:
                                    AppManager.shared.emitEmoji(emoji: "👍")
                                case 8:
                                    AppManager.shared.emitEmoji(emoji: "👏")
                                case 9:
                                    AppManager.shared.emitEmoji(emoji: "👌")
                                case 10:
                                    AppManager.shared.emitEmoji(emoji: "💯")
                                default:
                                    fatalError()
                                }
                                AppManager.shared.isUserInteractionEnabled = true
                            } else {
                                SwiftMessages.show(message: "😓 Rating failed", style: .error(error!))
                                AppManager.shared.isUserInteractionEnabled = true
                            }
                        }
                    }
                }
                rateActions.append(rateAction)
            }
        }
        switch self {
        case .movie:
            return UIMenu(title: (userRating != nil ? "Edit Rating" : "Rate"),
                                     image: UIImage(systemName: "heart"),
                                     children: rateActions)
        case .show:
            return UIMenu(title: (userRating != nil ? "Edit Show Rating" : "Rate Show"),
                                     image: UIImage(systemName: "heart"),
                                     children: rateActions)
        case .episode:
            return UIMenu(title: (userRating != nil ? "Edit Episode Rating" : "Rate Episode"),
                                     image: UIImage(systemName: "heart"),
                                     children: rateActions)
        case .season:
            return UIMenu(title: (userRating != nil ? "Edit Season Rating" : "Rate Season"),
                                     image: UIImage(systemName: "heart"),
                                     children: rateActions)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    func stopRewatchingShow() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        guard let show = show else { return }

        SwiftMessages.show(message: "Stopping Rewatch...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.undoResetProgress(id: show.identifiers.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Undo Reset show successful \(response)")

                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "⏪ Rewatching stopped", style: .content)
                                                        onRewatchingChangedTransmitter.broadcast(show)
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }

    func startRewatchingShow() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        guard let show = show else { return }

        SwiftMessages.show(message: "Starting Rewatch...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.resetProgress(id: show.identifiers.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    print("Reset show successful \(response)")

                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "⏪ Rewatching started")
                                                        onRewatchingChangedTransmitter.broadcast(show)
                                                    }

                                                } catch {
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                }
                                            }
        }
    }
}

extension MediaModel {
    // Fetch and return Sentiments analysis
    func fetchSentiments() async -> CommentsSentiments? {
        var service: TraktAPIService?
        switch self {
        case .movie(let movie):
            service = .movieSentiments(id: movie.identifiers.traktIdOrSlug)
        case .show(let show):
            service = .showSentiments(id: show.identifiers.traktIdOrSlug)
        case .episode(let episode, _):
            service = .episodeSentiments(id: episode.identifiers.trakt!)
        case .season:
            return nil
            // service = .seasonSentiments(id: show.identifiers.traktIdOrSlug,
            //                            season: season.number)
        case .list:
            fatalError("Case not handled, provide a plain movie, episode, season or show")
        case .showProgress:
            fatalError("Case not handled, provide a plain movie, episode, season or show")
        }
        guard let service = service else { return nil }

        let result: CommentsSentiments? = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let sentiments = try response.map(CommentsSentiments.self, using: TraktAPIProvider.decoder)
                        DispatchQueue.main.async {
                            continuation.resume(returning: sentiments)
                        }
                    } catch {
                        print("😓 Error Sentiment \(error)")
                        DispatchQueue.main.async {
                            continuation.resume(returning: nil)
                        }
                    }
                case let .failure(error):
                    print("😓 Error Sentiment \(error)")
                    DispatchQueue.main.async {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
        return result
    }
}
