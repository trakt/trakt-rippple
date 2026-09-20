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
        let query = (searchTerm ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty == false {
            let results = try await WidgetSearchLoader().search(query: query)
            try Task.checkCancellation()
            let items = results.compactMap { result -> MediaType? in
                guard let item = result.media else { return nil }
                let media = MediaType(identifier: "\(WidgetType.custom.rawValue):\(result.type):\(item.ids.trakt)",
                                      display: item.title,
                                      subtitle: result.subtitle,
                                      image: nil)
                media.traktId = NSNumber(value: item.ids.trakt)
                media.traktType = result.type
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
