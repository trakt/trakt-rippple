//
//  RecommendedNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/02/2021.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

final class RecommendedNotificationsManager {
    static let shared = RecommendedNotificationsManager()

    /// Settings
    var recommendedMovies: Bool {
        didSet {
            UserDefaults.standard.set(recommendedMovies, forKey: "RecommendedNotificationsManager.recommendedMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var recommendedShows: Bool {
        didSet {
            UserDefaults.standard.set(recommendedShows, forKey: "RecommendedNotificationsManager.recommendedShows")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        recommendedShows = UserDefaults.standard.bool(forKey: "RecommendedNotificationsManager.recommendedShows")
        recommendedMovies = UserDefaults.standard.bool(forKey: "RecommendedNotificationsManager.recommendedMovies")
    }
}
