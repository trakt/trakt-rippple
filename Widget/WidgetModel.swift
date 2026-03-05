//
//  WidgetModel.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation

enum WidgetType: String {
    case lastWatched = "widget.lastWatched"
    case lastWatchedMovie = "widget.lastWatchedMovie"
    case lastWatchedShow = "widget.lastWatchedShow"
    case showsToWatch = "widget.showsToWatch"
    case moviesToWatch = "widget.moviesToWatch"
    case showsComing = "widget.showsComing"
    case moviesComing = "widget.moviesComing"

    case recommendedMovie = "widget.recommendedMovie"
    case trendingMovie = "widget.trendingMovie"
    case recommendedShow = "widget.recommendedShow"
    case trendingShow = "widget.trendingShow"

    case custom = "widget.custom"
}

struct WidgetModel: Identifiable, Codable, Equatable, Hashable {
    var label: String?
    var title: String?
    var subtitle: String?
    var image: URL?
    var behind: String?
    var redacted = false
    var deeplink: URL?

    var progress: Double?
    var runtime: Int?
    var endDate: Date?

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(subtitle)
        hasher.combine(image)
        hasher.combine(behind)
        hasher.combine(redacted)
        hasher.combine(deeplink)
        hasher.combine(label)

        hasher.combine(progress)
        hasher.combine(runtime)
        hasher.combine(endDate)
    }

    var id: Int {
        return hashValue
    }
}
