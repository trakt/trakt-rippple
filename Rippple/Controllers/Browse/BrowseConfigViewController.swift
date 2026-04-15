//
//  BrowseConfigViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 16/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

let (onBrowseConfigChangedTransmitter, onBrowseConfigChangedReceiver) = Receiver<String>.make(with: .warm(upTo: 1))

final class BrowseConfigManager {

    private let disposeBag = DisposeBag()

    private init() {
        PurchaseManager.shared.onPurchasedChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.loadCurrent()
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.loadCurrent()
        }.disposed(by: disposeBag)

        onShelfChangedReceiver.listen { [weak self] shelf in
            guard let self = self else { return }
            shelfProxy = shelf
            self.loadCurrent()
        }.disposed(by: disposeBag)

        loadCurrent()
    }

    private func loadCurrent() {
        if let model = UserDefaults.standard.string(forKey: "BrowseConfigManager.currentConfig") {
            do {
                let jsonString = "[\(model.components(separatedBy: .newlines).joined(separator: ","))]"
                let jsonData = jsonString.data(using: .utf8)!
                var moduleTypes = try JSONDecoder().decode([BrowseViewController.ModuleType].self, from: jsonData)
                let first = moduleTypes.remove(at: 0)
                switch first.module {
                case "Browse":
                    currentConfig = defaultConfig
                    return
                case "Movies":
                    currentConfig = moviesConfig
                    return
                case "TV Shows":
                    currentConfig = showsConfig
                    return
                case "This Week":
                    currentConfig = newAndHot
                    return
                case "Shelf":
                    currentConfig = shelfConfig
                    return
                default:
                    currentConfig = showsConfig
                    return
                }
            } catch {
                print("\(error)")
                currentConfig = defaultConfig
                return
            }
        }
        // fallback on default anyway
        currentConfig = defaultConfig
    }

    static let shared = BrowseConfigManager()

    var currentConfig: String! {
        didSet {
            UserDefaults.standard.set(currentConfig, forKey: "BrowseConfigManager.currentConfig")
            UserDefaults.standard.synchronize()
            if UserManager.shared.currentUser == nil {
                onBrowseConfigChangedTransmitter.broadcast(freeConfig)
            } else {
                onBrowseConfigChangedTransmitter.broadcast(currentConfig)
            }
        }
    }

    private var shelfProxy = ""
    var shelfConfig: String {
        return """
            { "module": "Shelf", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            \(shelfProxy)
            """
    }

    let freeConfig = """
            { "module": "Browse", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "movies,shows", "name": "", "path": "/all/trending", "query": "" } }
            { "module": "Comments", "filter": { "section": "comments", "name": "Comments", "path": "", "query": "" } }
            { "module": "Services", "filter": { "section": "services", "name": "Streaming On", "path": "", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Trending TV Shows", "path": "/shows/trending", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Trending Movies", "path": "/movies/trending", "query": "" } }
            { "module": "T1", "filter": { "section": "shows", "name": "Most Watched TV Shows this month", "path": "/shows/watched/monthly", "query": "" } }
            { "module": "T1", "filter": { "section": "movies", "name": "Most Watched Movies this month", "path": "/movies/watched/monthly", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Anticipated TV Shows", "path": "/shows/anticipated", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Anticipated Movies", "path": "/movies/anticipated", "query": "" } }
            """

    let defaultConfig = """
            { "module": "Browse", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "movies,shows", "name": "", "path": "/all/trending", "query": "" } }
            { "module": "Comments", "filter": { "section": "comments", "name": "Comments", "path": "", "query": "" } }
            { "module": "ToWatch", "filter": { "section": "episodes_to_watch", "name": "Up Next", "path": "", "query": "" } }
            { "module": "L3", "filter": { "section": "watchlist", "name": "Your Watchlist", "path": "/sync/watchlist", "query": "", "limit": 50 } }
            { "module": "Services", "filter": { "section": "services", "name": "Streaming On", "path": "", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Trending TV Shows", "path": "/shows/trending", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Trending Movies", "path": "/movies/trending", "query": "" } }
            { "module": "T1", "filter": { "section": "shows", "name": "Most Watched TV Shows", "path": "/shows/watched/monthly", "query": "" } }
            { "module": "T1", "filter": { "section": "movies", "name": "Most Watched Movies", "path": "/movies/watched/monthly", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Anticipated TV Shows", "path": "/shows/anticipated", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Anticipated Movies", "path": "/movies/anticipated", "query": "" } }
            { "module": "L2", "filter": { "section": "shows", "name": "TV Shows Recommendations", "path": "/recommendations/shows", "query": "" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Movies Recommendations", "path": "/recommendations/movies", "query": "" } }
            { "module": "History", "filter": { "section": "History", "name": "History", "path": "", "query": "" } }
            { "module": "In Review", "filter": { "section": "in_review", "name": "", "path": "", "query": "" } }
            """

    let moviesConfig = """
            { "module": "Movies", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "movies", "name": "", "path": "/movies/trending", "query": "", "limit": 10 } }
            { "module": "Genres", "filter": { "section": "genres-movies", "name": "By Genres", "path": "", "query": "" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Box Office", "path": "/movies/boxoffice", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Anticipated Movies", "path": "/movies/anticipated", "query": "" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Academy Awards Best Picture Winners", "path": "/lists/832943/items", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "2025 Academy Awards Nominees and Winners", "path": "/lists/30484958/items", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "2025 Golden Globes Nominees and Winners", "path": "/lists/30156306/items", "query": "" } }
            { "module": "L3", "filter": { "section": "lists", "name": "Rotten Tomatoes Best of 2024", "path": "/users/lish408/lists/rotten-tomatoes-best-of-2024/items", "query": "" } }
            { "module": "L3", "filter": { "section": "lists", "name": "IMDb Top 250 Movies", "path": "/lists/2142753/items", "query": "" } }
            { "module": "T1", "filter": { "section": "movies", "name": "Most Favorited Movies", "path": "/movies/recommended/monthly", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "Marvel Cinematic Universe", "path": "/lists/1248149/items/shows,movies", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "DC Extended Universe", "path": "/lists/1257909/items", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "Disney Animated Feature Films", "path": "/lists/1406012/items", "query": "" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Disney+", "path": "/movies/trending", "query": "watchnow=disney_plus" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Netflix", "path": "/movies/trending", "query": "watchnow=netflix" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Apple TV", "path": "/movies/trending", "query": "watchnow=apple_tv_plus" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Amazon Prime", "path": "/movies/trending", "query": "watchnow=amazon_prime_video" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on HBO Max", "path": "/movies/trending", "query": "watchnow=hbo_max" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Paramount+", "path": "/movies/trending", "query": "watchnow=paramountplusessential,paramount_plus_premium" } }
            { "module": "L1", "filter": { "section": "movies", "name": "Movies on Hulu", "path": "/movies/trending", "query": "watchnow=us-hulu" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Movies Recommendations", "path": "/recommendations/movies", "query": "" } }
            """

    let showsConfig = """
            { "module": "TV Shows", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "shows", "name": "", "path": "/shows/trending", "query": "", "limit": 10 } }
            { "module": "Genres", "filter": { "section": "genres-shows", "name": "By Genres", "path": "", "query": "" } }
            { "module": "ToWatch", "filter": { "section": "episodes_to_watch", "name": "Up Next", "path": "", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Anticipated TV Shows", "path": "/shows/anticipated", "query": "" } }
            { "module": "L3", "filter": { "section": "lists", "name": "Rotten Tomatoes 2024 Best TV Shows", "path": "/users/lish408/lists/rotten-tomatoes-the-best-tv-of-2024/items", "query": "" } }
            { "module": "L1", "filter": { "section": "lists", "name": "Rolling Stone's 100 Greatest TV Shows", "path": "/lists/2748259/items", "query": "" } }
            { "module": "L2", "filter": { "section": "lists", "name": "IMDb Top 250 TV Shows", "path": "/lists/2143363/items", "query": "" } }
            { "module": "T1", "filter": { "section": "shows", "name": "Most Favorited TV Shows", "path": "/shows/recommended/monthly", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Netflix", "path": "/shows/trending", "query": "watchnow=netflix" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Disney+", "path": "/shows/trending", "query": "watchnow=disney_plus" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Prime Video", "path": "/shows/trending", "query": "watchnow=amazon_prime_video" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Apple TV", "path": "/shows/trending", "query": "watchnow=apple_tv_plus" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on HBO Max", "path": "/shows/trending", "query": "watchnow=hbo_max" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Paramount+", "path": "/shows/trending", "query": "watchnow=paramountplusessential,paramount_plus_premium" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows on Hulu", "path": "/shows/trending", "query": "watchnow=us-hulu" } }
            { "module": "L2", "filter": { "section": "shows", "name": "TV Shows Recommendations", "path": "/recommendations/shows", "query": "" } }
            """

    func serviceConfiguration(for filter: SavedFilter) -> String {
        return """
            { "module": \"\(filter.name)\", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "shows", "name": "", "path": "/shows/trending", "query": \"\(filter.query)\", "limit": 10 } }
            { "module": "L1", "filter": { "section": "shows", "name": "Most Watched Shows", "path": "/shows/watched/monthly", "query": \"\(filter.query)\" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Most Watched Movies", "path": "/movies/watched/monthly", "query": \"\(filter.query)\" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Popular Shows", "path": "/shows/popular", "query": \"\(filter.query)\" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Popular Movies", "path": "/movies/popular", "query": \"\(filter.query)\" } }
            { "module": "L3", "filter": { "section": "search", "name": "Action & Adventure", "path": "/search/movie,show", "query": "genres=action,adventure&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "Drama & Romance", "path": "/search/movie,show", "query": "genres=drama,romance&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "Science Fiction & Fantasy", "path": "/search/movie,show", "query": "genres=science-fiction,fantasy&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "Comedy & Family", "path": "/search/movie,show", "query": "genres=comedy,family&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "Crime & Mystery", "path": "/search/movie,show", "query": "genres=crime,mystery&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "Animation & Children", "path": "/search/movie,show", "query": "genres=animation,children&\(filter.query)" } }
            { "module": "L3", "filter": { "section": "search", "name": "And More", "path": "/search/movie,show", "query": "genres=-action,-adventure,-animation,-children,-comedy,-family,-science-fiction,-fantasy,-drama,-romance&\(filter.query)" } }
            """
    }

    let newAndHot = """
            { "module": "This Week", "filter": { "section": "", "name": "", "path": "", "query": "" } }
            { "module": "C1", "filter": { "section": "movies,shows", "name": "Popular Trailers", "path": "/users/kcador/lists/27798292/items", "query": "" } }
            { "module": "L2", "filter": { "section": "movies", "name": "Anticipated Movies", "path": "/users/kcador/lists/27798170/items", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Anticipated Shows", "path": "/users/kcador/lists/27798248/items", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Returning Favorites", "path": "/users/kcador/lists/27798281/items", "query": "" } }
            { "module": "L1", "filter": { "section": "shows", "name": "Shows Status Changes", "path": "/users/kcador/lists/27798283/items", "query": "" } }
            { "module": "T1", "filter": { "section": "shows", "name": "Most Watched Movies", "path": "/users/kcador/lists/27798291/items", "query": "" } }
            { "module": "T1", "filter": { "section": "movies", "name": "Most Watched Shows", "path": "/users/kcador/lists/27798288/items", "query": "" } }
            """

    func genreConfiguration(for filter: SavedFilter) -> String {
        if filter.path.localizedCaseInsensitiveContains("show") {
            return """
                { "module": \"\(filter.name)\", "filter": { "section": "", "name": "", "path": "", "query": "" } }
                { "module": "C1", "filter": { "section": "shows", "name": "", "path": "/shows/trending", "query": \"\(filter.query)\" }, "limit": 10 }
                { "module": "L1", "filter": { "section": "shows", "name": "Most Watched \(filter.name) TV Shows", "path": "/shows/watched/monthly", "query": \"\(filter.query)\" } }
                { "module": "L1", "filter": { "section": "shows", "name": "Most Popular \(filter.name) TV Shows", "path": "/shows/popular", "query": \"\(filter.query)\" } }
                { "module": "L2", "filter": { "section": "shows", "name": "Most Anticipated \(filter.name) TV Shows", "path": "/shows/anticipated", "query": \"\(filter.query)\" } }
                """
        } else {
            return """
                { "module": \"\(filter.name)\", "filter": { "section": "", "name": "", "path": "", "query": "" } }
                { "module": "C1", "filter": { "section": "movies", "name": "", "path": "/movies/trending", "query": \"\(filter.query)\", "limit": 10 } }
                { "module": "L1", "filter": { "section": "movies", "name": "Most Watched \(filter.name) Movies", "path": "/movies/watched/monthly", "query": \"\(filter.query)\" } }
                { "module": "L1", "filter": { "section": "movies", "name": "Most Popular \(filter.name) Movies", "path": "/movies/popular", "query": \"\(filter.query)\" } }
                { "module": "L2", "filter": { "section": "movies", "name": "Most Anticipated \(filter.name) Movies", "path": "/movies/anticipated", "query": \"\(filter.query)\" } }
                """
        }
    }
}
