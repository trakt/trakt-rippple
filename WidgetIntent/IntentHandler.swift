//
//  IntentHandler.swift
//  WidgetIntent
//
//  Created by Kevin Cador on 11/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Intents

class IntentHandler: INExtension, MediaTypeIntentHandling {
    func provideTypeOptionsCollection(for intent: MediaTypeIntent, searchTerm: String?) async throws -> INObjectCollection<MediaType> {
        if let searchTerm = searchTerm, !searchTerm.isEmpty {
            let data = try await TMDBItemLoader().loadItems(from: URL(string: "https://api.themoviedb.org/3/search/multi?api_key=\(TmdbAPIConfiguration.apiKey)&query=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)")!)
            let items = data.results
                .filter { $0.mediaType == "tv" || $0.mediaType == "movie" }
                .map {
                    var subtitle = $0.mediaType == "tv" ? "TV show" : "Movie"
                    if let firstAirDate = $0.firstAirDate, firstAirDate.isEmpty == false {
                        subtitle += " · \(firstAirDate.prefix(4))"
                    }
                    if let releaseDate = $0.releaseDate, releaseDate.isEmpty == false {
                        subtitle += " · \(releaseDate.prefix(4))"
                    }
                    if let originCountry = $0.originCountry?.first {
                        let locale = Locale(identifier: "en_US")
                        if let country = locale.localizedString(forRegionCode: originCountry) {
                            subtitle += " · \(country)"
                        }
                    }

                    let media = MediaType(identifier: WidgetType.custom.rawValue,
                                          display: $0.title ?? $0.name!,
                                          subtitle: subtitle,
                                          image: nil)
                    media.tmdbId = NSNumber(value: $0.id)
                    media.tmdbType = $0.mediaType
                    return media
                }
            return INObjectCollection(items: items)
        } else {
            let watchedSection = INObjectSection(title: "Last Watched",
                                                 items: [MediaType(identifier: WidgetType.lastWatched.rawValue,
                                                                   display: "Last Watched or Watching"),
                                                         MediaType(identifier: WidgetType.lastWatchedMovie.rawValue,
                                                                   display: "Last Watched Movie"),
                                                         MediaType(identifier: WidgetType.lastWatchedShow.rawValue,
                                                                   display: "Last Watched Episode")])
            let toWatchSection = INObjectSection(title: "Next To Watch",
                                                 items: [MediaType(identifier: WidgetType.showsToWatch.rawValue,
                                                                   display: "Episode To Watch"),
                                                         MediaType(identifier: WidgetType.moviesToWatch.rawValue,
                                                                   display: "Movie To Watch")])
            let upcomingSection = INObjectSection(title: "Upcoming",
                                                  items: [MediaType(identifier: WidgetType.showsComing.rawValue,
                                                                    display: "Upcoming Episode"),
                                                          MediaType(identifier: WidgetType.moviesComing.rawValue,
                                                                    display: "Upcoming Movie")])

            let trendingSection = INObjectSection(title: "Trending",
                                                  items: [MediaType(identifier: WidgetType.trendingShow.rawValue,
                                                                    display: "Most Trending Show"),
                                                          MediaType(identifier: WidgetType.trendingMovie.rawValue,
                                                                    display: "Most Trending Movie")])

            let recommendedSection = INObjectSection(title: "Favorited",
                                                     items: [MediaType(identifier: WidgetType.recommendedShow.rawValue,
                                                                       display: "Most Favorited Show"),
                                                             MediaType(identifier: WidgetType.recommendedMovie.rawValue,
                                                                       display: "Most Favorited Movie")])

            return INObjectCollection(sections: [watchedSection, toWatchSection, upcomingSection, trendingSection, recommendedSection])
        }
    }

    func defaultType(for intent: MediaTypeIntent) -> MediaType? {
        return MediaType(identifier: WidgetType.lastWatched.rawValue, display: "Last Watched or Watching")
    }

    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.

        return self
    }
}

struct TMDbResults: Codable {
    let results: [TMDbResult]
}

struct TMDbResult: Codable {
    let mediaType: String // movie, tv or person

    let title: String? // movie
    let name: String? // tv or person

    let firstAirDate: String? // first air for tv
    let releaseDate: String? // release date for movies

    let originCountry: [String]? // for tv only

    let id: Int64

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case title
        case name
        case id
        case firstAirDate = "first_air_date"
        case releaseDate = "release_date"
        case originCountry = "origin_country"
    }
}

struct TMDBItemLoader {
    var session = URLSession.shared

    func loadItems(from url: URL) async throws -> TMDbResults {
        let (data, _) = try await session.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(TMDbResults.self, from: data)
    }
}
