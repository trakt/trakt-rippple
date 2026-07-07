//
//  DeeplinkParser.swift
//  Rippple
//
//  Created by Kevin Cador on 29/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation
import SafariServices

enum DeeplinkType: Equatable {
    case show(id: String)
    case season(showId: String, season: Int)
    case episode(showId: String, season: Int, episode: Int)
    case movie(id: String)
    case comment(id: Int64)
    case user(id: String)
    case people(slug: String)
    case notificationsSettings
    case whatsNew
    case whereToWatchSettings
    case appIconSettings

    case tmdbShow(id: String)
    case tmdbSeason(showId: String, season: Int)
    case tmdbEpisode(showId: String, season: Int, episode: Int)
    case tmdbPeople(peopleId: String)
    case tmdbMovie(id: String)

    case browseThisWeek

    case search(query: String?)

    case toWatchMovies
    case toWatchEpisodes
    case history
    case calendar
    case list(userSlug: String, listSlug: String)
    case migrate(components: URLComponents)

    static func == (lhs: DeeplinkType, rhs: DeeplinkType) -> Bool {
        switch (lhs, rhs) {
        case (.user(let left), .user(let right)): return left == right
        case (.show(let left), .show(let right)): return left == right
        case (.season(let left1, let left2), .season(let right1, let right2)): return left1 == right1 && left2 == right2
        case (.episode(let left1, let left2, let left3), .episode(let right1, let right2, let right3)): return left1 == right1 && left2 == right2 && left3 == right3
        case (.comment(let left), .comment(let right)): return left == right
        case (.people(let left), .people(let right)): return left == right
        case (.notificationsSettings, .notificationsSettings): return true
        case (.whatsNew, .whatsNew): return true
        case (.whereToWatchSettings, .whereToWatchSettings): return true
        case (.tmdbShow(let left), .tmdbShow(let right)): return left == right
        case (.tmdbPeople(let left), .tmdbPeople(let right)): return left == right
        case (.tmdbMovie(let left), .tmdbMovie(let right)): return left == right
        case (.tmdbEpisode(let left1, let left2, let left3), .tmdbEpisode(let right1, let right2, let right3)): return left1 == right1 && left2 == right2 && left3 == right3
        case (.tmdbSeason(let left1, let left2), .tmdbSeason(let right1, let right2)): return left1 == right1 && left2 == right2
        case (.browseThisWeek, .browseThisWeek): return true
        case (.appIconSettings, .appIconSettings): return true
        case (.toWatchMovies, .toWatchMovies): return true
        case (.toWatchEpisodes, .toWatchEpisodes): return true
        case (.history, .history): return true
        case (.calendar, .calendar): return true
        case (.list(let left1, let left2), .list(let right1, let right2)): return left1 == right1 && left2 == right2
        case (.migrate, .migrate): return true
        default: return false
        }
    }
}

final class DeeplinkParser {
    static let shared = DeeplinkParser()
    private init() {}

    func parseDeepLink(_ url: URL) -> DeeplinkType? {
        let url = cleanDeeplink(url)

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            return nil
        }
        var pathComponents = components.path.components(separatedBy: "/")
        pathComponents.removeFirst() // the first component is empty

        switch host {
        case "tmdb":
            if pathComponents.first == "shows" {
                // episode
                // tmdb/shows/[1]/seasons/[3]/episode/[5]
                if pathComponents.count == 6 {
                    let showId = pathComponents[1]
                    if let season = Int(pathComponents[3]),
                       let episode = Int(pathComponents[5]) {
                        return DeeplinkType.tmdbEpisode(showId: showId, season: season, episode: episode)
                    }
                }
                // season
                // tmdb/shows/[1]/seasons/[3]
                if pathComponents.count == 4 {
                    let showId = pathComponents[1]
                    if let season = Int(pathComponents[3]) {
                        return DeeplinkType.tmdbSeason(showId: showId, season: season)
                    }
                }
                // show
                // tmdb/shows/[1]
                if pathComponents.count == 2 {
                    let showId = pathComponents[1]
                    return DeeplinkType.tmdbShow(id: showId)
                }
            }
            if pathComponents.first == "people" {
                // episode
                // tmdb/people/[1]
                if pathComponents.count == 2 {
                    let peopleId = pathComponents[1]
                    return DeeplinkType.tmdbPeople(peopleId: peopleId)
                }
            }
            if pathComponents.first == "movies" {
                // movie
                // tmdb/movies/[1]
                if pathComponents.count == 2 {
                    let movieId = pathComponents[1]
                    return DeeplinkType.tmdbMovie(id: movieId)
                }
            }
        case "shows":
            // episode
            // shows/[0]/seasons/[2]/episode/[4]
            if pathComponents.count == 5 {
                if let showId = pathComponents.first,
                   let season = Int(pathComponents[2]),
                   let episode = Int(pathComponents[4]) {
                    return DeeplinkType.episode(showId: showId, season: season, episode: episode)
                }
            }
            // season
            // shows/[0]/seasons/[2]
            if pathComponents.count == 3 {
                if let showId = pathComponents.first,
                   let season = Int(pathComponents[2]) {
                    return DeeplinkType.season(showId: showId, season: season)
                }
            }
            // show
            // shows/[0]
            if let showId = pathComponents.first {
                return DeeplinkType.show(id: showId)
            }
        case "movies":
            if let movieId = pathComponents.first {
                return DeeplinkType.movie(id: movieId)
            }
        case "comments":
            if let component = pathComponents.first,
               let commentId = Int64(component) {
                return DeeplinkType.comment(id: commentId)
            }
        case "users":
            // list
            // users/[0]/lists/[2]
            if pathComponents.count == 3,
               pathComponents[1] == "lists",
               let userSlug = pathComponents.first,
               let listSlug = pathComponents.last {
                return DeeplinkType.list(userSlug: userSlug, listSlug: listSlug)
            }
            // user
            // users/[0]
            if let userId = pathComponents.first {
                return DeeplinkType.user(id: userId)
            }
        case "people":
            if let slug = pathComponents.first {
                return DeeplinkType.people(slug: slug)
            }
        case "settings":
            if let notifications = pathComponents.first, notifications == "notifications" {
                return DeeplinkType.notificationsSettings
            }
            if let whereToWatch = pathComponents.first, whereToWatch == "wheretowatch" {
                return DeeplinkType.whereToWatchSettings
            }
            if let notifications = pathComponents.first, notifications == "appicon" {
                return DeeplinkType.appIconSettings
            }
        case "whatsnew":
            return DeeplinkType.whatsNew
        case "search":
            return DeeplinkType.search(query: pathComponents.first)
        case "ripppleapp.writeas.com", "writeas.com", "write.as":
            return .browseThisWeek
        case "towatch":
            // movies
            // towatch/movies
            if pathComponents.first == "movies" {
                return DeeplinkType.toWatchMovies
            }
            return DeeplinkType.toWatchEpisodes
        case "history":
            return .history
        case "calendar":
            return .calendar
        case "migrate":
            return .migrate(components: components)
        default:
            break
        }
        return nil
    }

    private func cleanDeeplink(_ url: URL) -> URL {
        // https://app.trakt.tv/comments/158545 -> ripl://comments/158545
        // ripl://app.trakt.tv/comments/158545 -> ripl://comments/158545

        let absoluteString = url.absoluteString

        if absoluteString.hasPrefix("https://rippple.app/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "https://rippple.app/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("ripl://rippple.app/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "ripl://rippple.app/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("https://app.trakt.tv/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "https://app.trakt.tv/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("https://trakt.tv/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "https://trakt.tv/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("ripl://app.trakt.tv/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "ripl://app.trakt.tv/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("ripl://trakt.tv/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "ripl://trakt.tv/", with: "ripl://")) {
            return cleanUrl
        }

        if absoluteString.hasPrefix("ripl://trakt/"),
           let cleanUrl = URL(string: absoluteString.replacingOccurrences(of: "ripl://trakt/", with: "ripl://")) {
            return cleanUrl
        }

        return url
    }
}
