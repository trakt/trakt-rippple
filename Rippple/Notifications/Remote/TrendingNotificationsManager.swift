//
//  TrendingNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 20/11/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

final class TrendingNotificationsManager {
    static let shared = TrendingNotificationsManager()

    /// Settings
    var trendingMovies: Bool {
        didSet {
            UserDefaults.standard.set(trendingMovies, forKey: "TrendingNotificationsManager.trendingMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var trendingShows: Bool {
        didSet {
            UserDefaults.standard.set(trendingShows, forKey: "TrendingNotificationsManager.trendingShows")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        trendingShows = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingShows")
        trendingMovies = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingMovies")
    }
}
