//
//  WidgetManager.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit
import WidgetKit

final class WidgetManager {
    private let disposeBag = DisposeBag()

    private init() {
        WatchingControlWidgetStorage.publishProfileAvatarURL(UserManager.shared.currentUser?.images?.avatar.full)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setup() {
        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] watchingItem, _ in
            guard let self = self else { return }
            if let watchingItem = watchingItem {
                self.storeWatchingControlWidgetItem(watchingItem: watchingItem)
            }
            self.updateLastWatched()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateLastWatched()
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateLastWatched()
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            WatchingControlWidgetStorage.publishProfileAvatarURL(settings?.user.images?.avatar.full)
            self.updateLastWatched()
            self.refreshActivityPunchcard()
            WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshActivityPunchcard()
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshActivityPunchcard()
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { _ in
            let defaults = UserDefaults(suiteName: "group.tv.trakt.rippple")!
            let widgetKeys = [
                WidgetType.lastWatched.rawValue,
                WidgetType.lastWatchedMovie.rawValue,
                WidgetType.lastWatchedShow.rawValue,
                WidgetType.showsToWatch.rawValue,
                WidgetType.moviesToWatch.rawValue,
                WidgetType.showsComing.rawValue,
                WidgetType.moviesComing.rawValue,
                WidgetType.recommendedMovie.rawValue,
                WidgetType.trendingMovie.rawValue,
                WidgetType.recommendedShow.rawValue,
                WidgetType.trendingShow.rawValue,
                ToWatchWidgetStorage.episodeKey,
                ToWatchWidgetStorage.movieKey,
                UpcomingWidgetStorage.episodeKey,
                UpcomingWidgetStorage.movieKey,
                QuickAccessWidgetStorage.trendingMediaKey,
                QuickAccessWidgetStorage.trendingMoviesKey,
                QuickAccessWidgetStorage.trendingShowsKey,
                WatchingControlWidgetStorage.dataKey,
                WatchingControlWidgetStorage.profileAvatarURLKey,
                ActivityPunchcardWidgetStorage.dataKey
            ]
            for key in widgetKeys {
                defaults.removeObject(forKey: key)
            }
            defaults.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if let media = WatchedManager.shared.watchedMoviesMediaModels.first, let movie = media.movie {
                media.backdropURL { url in
                    let progress = WidgetModel(label: "Last Watched Movie",
                                               title: movie.title,
                                               subtitle: (movie.releaseYear != nil) ? "\(movie.releaseYear!)" : "",
                                               image: url,
                                               behind: nil,
                                               redacted: false,
                                               deeplink: media.deeplink)
                    self.store(singleWidget: progress, with: WidgetType.lastWatchedMovie.rawValue)
                }
            }
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.skipRepeats().listen { [weak self] _ in
            guard let self = self else { return }
            if let media = WatchedManager.shared.watchedShowsMediaModels.first, let show = media.show {
                media.backdropURL { url in
                    let progress = WidgetModel(label: "Last Watched Show",
                                               title: show.title,
                                               subtitle: nil,
                                               image: url,
                                               behind: nil,
                                               redacted: false,
                                               deeplink: media.deeplink)
                    self.store(singleWidget: progress, with: WidgetType.lastWatchedShow.rawValue)
                }
            }
        }.disposed(by: disposeBag)

        onEpisodeToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.storeEpisodesToWatchWidget(models: models)
            guard let model = models.first else {
                let progress = WidgetModel(label: "",
                                           title: "You did it!",
                                           subtitle: "We couldn't find episodes for you to watch.",
                                           image: nil,
                                           behind: nil,
                                           redacted: false,
                                           deeplink: nil)
                self.store(singleWidget: progress, with: WidgetType.showsToWatch.rawValue)
                return
            }
            switch model {
            case .showProgress(let show, let progress):
                show.mediaModel.backdropURL { url in
                    let behind = progress.behind
                    var behindText: String?
                    if behind > 0 {
                        behindText = "\(behind) behind"
                    }
                    if progress.toRewatchCount > 0 {
                        behindText = "\(progress.toRewatchCount) to rewatch"
                    }
                    var subtitle: String?
                    if let episodeToWatch = progress.nextEpisodeToWatch {
                        subtitle = episodeToWatch.localizedEpisodeNumber
                    }
                    let progress = WidgetModel(label: "Next Episode",
                                               title: show.title,
                                               subtitle: subtitle,
                                               image: url,
                                               behind: behindText,
                                               redacted: false,
                                               deeplink: model.deeplink)
                    self.store(singleWidget: progress, with: WidgetType.showsToWatch.rawValue)
                }
            default:
                break
            }
        }.disposed(by: disposeBag)

        onMovieToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.storeMoviesToWatchWidget(models: models)
            if let movie = models.first?.movie {
                movie.mediaModel.backdropURL { url in
                    var subtitle: String?
                    if let releaseYear = movie.releaseYear {
                        subtitle = "\(releaseYear)"
                    }
                    let progress = WidgetModel(label: "Next Movie",
                                               title: movie.title,
                                               subtitle: subtitle,
                                               image: url,
                                               redacted: false,
                                               deeplink: movie.mediaModel.deeplink)
                    self.store(singleWidget: progress, with: WidgetType.moviesToWatch.rawValue)
                }
            } else {
                let progress = WidgetModel(label: "",
                                           title: "You did it!",
                                           subtitle: "We couldn't find movies for you to watch.",
                                           image: nil,
                                           behind: nil,
                                           redacted: false,
                                           deeplink: nil)
                self.store(singleWidget: progress, with: WidgetType.moviesToWatch.rawValue)
            }
        }.disposed(by: disposeBag)

        nextEpisodesReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.storeUpcomingEpisodesWidget(models: models)
            guard let model = models.first else {
                let progress = WidgetModel(label: "",
                                           title: "TV not found",
                                           subtitle: "We couldn't find an episode coming for you.",
                                           image: nil,
                                           behind: nil,
                                           redacted: false,
                                           deeplink: nil)
                self.store(singleWidget: progress, with: WidgetType.showsComing.rawValue)
                return
            }
            model.backdropURL { url in
                let progress = WidgetModel(label: "Upcoming",
                                           title: model.show!.title,
                                           subtitle: model.episode!.localizedEpisodeNumber,
                                           image: url,
                                           redacted: false,
                                           deeplink: model.deeplink)
                self.store(singleWidget: progress, with: WidgetType.showsComing.rawValue)
            }
        }.disposed(by: disposeBag)

        calendarDataUpdatedReceiver.listen { [weak self] data in
            guard let self = self else { return }
            self.storeUpcomingMoviesWidget(releases: data.movies)
        }.disposed(by: disposeBag)

        nextMoviesReceiver.listen { [weak self] models in
            guard let self = self else { return }
            guard let model = models.first else {
                let progress = WidgetModel(label: "",
                                           title: "Movie not found",
                                           subtitle: "We couldn't find a movie coming for you.",
                                           image: nil,
                                           behind: nil,
                                           redacted: false,
                                           deeplink: nil)
                self.store(singleWidget: progress, with: WidgetType.moviesComing.rawValue)
                return
            }
            model.backdropURL { url in
                var subtitle: String?
                if let releaseYear = model.movie!.releaseYear {
                    subtitle = "\(releaseYear)"
                }
                let progress = WidgetModel(label: "Hot & Upcoming",
                                           title: model.movie!.title,
                                           subtitle: subtitle,
                                           image: url,
                                           behind: nil,
                                           redacted: false,
                                           deeplink: model.deeplink)
                self.store(singleWidget: progress, with: WidgetType.moviesComing.rawValue)
            }
        }.disposed(by: disposeBag)

        updateLastWatched()
        updateTrendingMedia()
    }

    static let shared = WidgetManager()

    private func updateLastWatched() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(TraktAPIService.history(slug: "me", type: nil, id: nil, pageInfo: PageInfo.firstPage(with: 4), endDate: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)
                    if WatchingManager.shared.watchingItem == nil {
                        WatchingControlWidgetStorage.publish(fetchedActivities.first.flatMap(self.watchingControlWidgetItem))
                        WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
                    }

                    if let last = fetchedActivities.first {
                        if let movie = last.movie {
                            movie.mediaModel.backdropURL { url in
                                let progress = WidgetModel(label: "Last Watched",
                                                           title: movie.title,
                                                           subtitle: (movie.releaseYear != nil) ? "\(movie.releaseYear!)" : "",
                                                           image: url,
                                                           behind: nil,
                                                           redacted: false,
                                                           deeplink: movie.mediaModel.deeplink,
                                                           runtime: movie.runtime,
                                                           endDate: last.watchDate)
                                self.store(singleWidget: progress, with: WidgetType.lastWatched.rawValue)
                            }
                        } else if let show = last.show, let episode = last.episode {
                            show.mediaModel.backdropURL { url in
                                let progress = WidgetModel(label: "Last Watched",
                                                           title: show.title,
                                                           subtitle: episode.localizedEpisodeNumber,
                                                           image: url,
                                                           behind: nil,
                                                           redacted: false,
                                                           deeplink: episode.mediaModel(given: show).deeplink,
                                                           runtime: episode.runtime,
                                                           endDate: last.watchDate)
                                self.store(singleWidget: progress, with: WidgetType.lastWatched.rawValue)
                            }
                        }
                    }
                } catch {
                    print("Last activity (/history) request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Last activity (/history) request failure \(error)")
            }
        }
    }

    private func updateTrendingMedia() {
        updateTrendingItems(service: .trendingMedia(filters: [:],
                                                    extended: .full,
                                                    pageInfo: PageInfo.firstPage(with: 5)),
                            description: "media",
                            publish: QuickAccessWidgetStorage.publishTrendingMedia)
        updateTrendingItems(service: .trendingMovies(filters: [:],
                                                     extended: .full,
                                                     pageInfo: PageInfo.firstPage(with: 5)),
                            description: "movies",
                            publish: QuickAccessWidgetStorage.publishTrendingMovies)
        updateTrendingItems(service: .trendingShows(filters: [:],
                                                    extended: .full,
                                                    pageInfo: PageInfo.firstPage(with: 5)),
                            description: "shows",
                            publish: QuickAccessWidgetStorage.publishTrendingShows)
    }

    private func updateTrendingItems(service: TraktAPIService,
                                     description: String,
                                     publish: @escaping ([QuickAccessWidgetItem]) -> Void) {
        TraktAPIProvider.provider.request(service,
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let mediaItems = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)
                    let widgetItems = mediaItems.compactMap { WidgetManager.quickAccessWidgetItem(from: $0) }
                    publish(widgetItems)
                    WidgetCenter.shared.reloadTimelines(ofKind: QuickAccessWidgetStorage.kind)
                } catch {
                    print("Trending \(description) request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Trending \(description) request failure \(error)")
            }
        }
    }

    private static func quickAccessWidgetItem(from mediaItem: MediaItem) -> QuickAccessWidgetItem? {
        if let movie = mediaItem.movie,
           let traktIdentifier = movie.identifiers.trakt.flatMap(Int.init(exactly:)),
           let deeplink = movie.mediaModel.deeplink {
            return QuickAccessWidgetItem(traktIdentifier: traktIdentifier,
                                         tmdbIdentifier: movie.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                         tmdbMediaType: "movie",
                                         title: movie.title,
                                         deeplink: deeplink)
        }
        if let show = mediaItem.show,
           let traktIdentifier = show.identifiers.trakt.flatMap(Int.init(exactly:)),
           let deeplink = show.mediaModel.deeplink {
            return QuickAccessWidgetItem(traktIdentifier: traktIdentifier,
                                         tmdbIdentifier: show.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                         tmdbMediaType: "tv",
                                         title: show.title,
                                         deeplink: deeplink)
        }
        return nil
    }

    private func storeWatchingControlWidgetItem(watchingItem: WatchingItem) {
        let item: WatchingControlWidgetItem?
        if let movie = watchingItem.movie,
           let traktIdentifier = movie.identifiers.trakt.flatMap(Int.init(exactly:)),
           let deeplink = movie.mediaModel.deeplink {
            item = WatchingControlWidgetItem(state: .currentlyWatching,
                                             traktIdentifier: traktIdentifier,
                                             tmdbIdentifier: movie.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                             tmdbMediaType: "movie",
                                             title: movie.title,
                                             subtitle: movie.releaseYear.map(String.init),
                                             deeplink: deeplink,
                                             showTraktIdentifier: nil,
                                             isCheckInActive: true,
                                             checkInStartDate: watchingItem.startDate,
                                             checkInEndDate: watchingItem.expireDate)
        } else if let show = watchingItem.show,
                  let episode = watchingItem.episode,
                  let episodeTraktIdentifier = episode.identifiers.trakt.flatMap(Int.init(exactly:)),
                  let showTraktIdentifier = show.identifiers.trakt.flatMap(Int.init(exactly:)),
                  let deeplink = episode.mediaModel(given: show).deeplink {
            item = WatchingControlWidgetItem(state: .currentlyWatching,
                                             traktIdentifier: episodeTraktIdentifier,
                                             tmdbIdentifier: show.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                             tmdbMediaType: "tv",
                                             title: show.title,
                                             subtitle: episode.localizedEpisodeNumber,
                                             deeplink: deeplink,
                                             showTraktIdentifier: showTraktIdentifier,
                                             isCheckInActive: true,
                                             checkInStartDate: watchingItem.startDate,
                                             checkInEndDate: watchingItem.expireDate)
        } else {
            item = nil
        }
        WatchingControlWidgetStorage.publish(item)
        WidgetCenter.shared.reloadTimelines(ofKind: WatchingControlWidgetStorage.kind)
    }

    private func watchingControlWidgetItem(from historyItem: HistoryItem) -> WatchingControlWidgetItem? {
        if let movie = historyItem.movie,
           let traktIdentifier = movie.identifiers.trakt.flatMap(Int.init(exactly:)),
           let deeplink = movie.mediaModel.deeplink {
            return WatchingControlWidgetItem(state: .lastWatched,
                                             traktIdentifier: traktIdentifier,
                                             tmdbIdentifier: movie.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                             tmdbMediaType: "movie",
                                             title: movie.title,
                                             subtitle: movie.releaseYear.map(String.init),
                                             deeplink: deeplink,
                                             showTraktIdentifier: nil,
                                             isCheckInActive: false,
                                             checkInStartDate: nil,
                                             checkInEndDate: nil)
        }
        if let show = historyItem.show,
           let episode = historyItem.episode,
           let episodeTraktIdentifier = episode.identifiers.trakt.flatMap(Int.init(exactly:)),
           let showTraktIdentifier = show.identifiers.trakt.flatMap(Int.init(exactly:)),
           let deeplink = episode.mediaModel(given: show).deeplink {
            return WatchingControlWidgetItem(state: .lastWatched,
                                             traktIdentifier: episodeTraktIdentifier,
                                             tmdbIdentifier: show.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                             tmdbMediaType: "tv",
                                             title: show.title,
                                             subtitle: episode.localizedEpisodeNumber,
                                             deeplink: deeplink,
                                             showTraktIdentifier: showTraktIdentifier,
                                             isCheckInActive: false,
                                             checkInStartDate: nil,
                                             checkInEndDate: nil)
        }
        return nil
    }

    func refreshActivityPunchcard() {
        ActivityPunchcardWidgetStorage.publish(SyncWatchedManager.shared.activityCountsByDay())
        WidgetCenter.shared.reloadTimelines(ofKind: ActivityPunchcardWidgetStorage.kind)
    }

    private func decodeSingleWidgetModel(for key: String) -> WidgetModel? {
        if let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple")!.object(forKey: key) as? Data {
            if let progress = try? JSONDecoder().decode(WidgetModel.self, from: encodedData) {
                return progress
            }
        }
        return nil
    }

    private func storeEpisodesToWatchWidget(models: [MediaModel]) {
        let episodes = models.compactMap(episodeToWatchWidgetModel)
        ToWatchWidgetStorage.publish(episodes)
        WidgetCenter.shared.reloadTimelines(ofKind: ToWatchWidgetStorage.kind)
    }

    private func episodeToWatchWidgetModel(from model: MediaModel) -> ToWatchWidgetEpisode? {
        guard case .showProgress(let show, let progress) = model,
              let episode = progress.nextEpisodeToWatch,
              let episodeTraktIdentifier = episode.identifiers.trakt.flatMap(Int.init(exactly:)),
              let showTraktIdentifier = show.identifiers.trakt.flatMap(Int.init(exactly:)) else { return nil }

        return ToWatchWidgetEpisode(episodeTraktIdentifier: episodeTraktIdentifier,
                                    showTraktIdentifier: showTraktIdentifier,
                                    showTMDbIdentifier: show.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                    showTitle: show.title,
                                    seasonNumber: episode.season,
                                    episodeNumber: episode.number,
                                    runtime: episode.runtime ?? show.runtime,
                                    behind: episodeBehindText(for: progress))
    }

    private func episodeBehindText(for progress: ShowProgress) -> String {
        if progress.toRewatchCount > 0 {
            return "\(progress.toRewatchCount) to rewatch"
        }
        if progress.behind > 0 {
            return "\(progress.behind) behind"
        }
        return "At least one behind"
    }

    private func storeMoviesToWatchWidget(models: [MediaModel]) {
        let movies = models.compactMap { model -> ToWatchWidgetMovie? in
            guard let movie = model.movie,
                  let movieTraktIdentifier = movie.identifiers.trakt.flatMap(Int.init(exactly:)) else { return nil }
            return ToWatchWidgetMovie(movieTraktIdentifier: movieTraktIdentifier,
                                      movieTMDbIdentifier: movie.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                      title: movie.title,
                                      releaseYear: movie.releaseYear,
                                      runtime: movie.runtime)
        }
        ToWatchWidgetStorage.publish(movies)
        WidgetCenter.shared.reloadTimelines(ofKind: ToWatchWidgetStorage.kind)
    }

    private func storeUpcomingEpisodesWidget(models: [MediaModel]) {
        let items = models.compactMap { model -> UpcomingWidgetItem? in
            guard case .episode(let episode, let show) = model,
                  let releaseDate = episode.firstAired,
                  let episodeTraktIdentifier = episode.identifiers.trakt.flatMap(Int.init(exactly:)),
                  let showTraktIdentifier = show.identifiers.trakt.flatMap(Int.init(exactly:)),
                  let deeplink = URL(string: "ripl://shows/\(showTraktIdentifier)/seasons/\(episode.season)/episodes/\(episode.number)") else { return nil }
            return UpcomingWidgetItem(traktIdentifier: episodeTraktIdentifier,
                                      tmdbIdentifier: show.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                      tmdbMediaType: "tv",
                                      title: show.title,
                                      metadata: episode.localizedEpisodeNumber,
                                      releaseDate: releaseDate,
                                      deeplink: deeplink)
        }
        UpcomingWidgetStorage.publishEpisodes(items)
        WidgetCenter.shared.reloadTimelines(ofKind: UpcomingWidgetStorage.kind)
    }

    private func storeUpcomingMoviesWidget(releases: [CalendarMovieRelease]) {
        let items = releases.compactMap { release -> UpcomingWidgetItem? in
            let movie = release.movie
            guard release.released >= Date.now,
                  let movieTraktIdentifier = movie.identifiers.trakt.flatMap(Int.init(exactly:)),
                  let deeplink = URL(string: "ripl://movies/\(movieTraktIdentifier)") else { return nil }
            return UpcomingWidgetItem(traktIdentifier: movieTraktIdentifier,
                                      tmdbIdentifier: movie.identifiers.tmdb.flatMap(Int.init(exactly:)),
                                      tmdbMediaType: "movie",
                                      title: movie.title,
                                      metadata: upcomingWidgetLabel(for: release.releaseType),
                                      releaseDate: release.released,
                                      deeplink: deeplink)
        }
        UpcomingWidgetStorage.publishMovies(items)
        WidgetCenter.shared.reloadTimelines(ofKind: UpcomingWidgetStorage.kind)
    }

    private func upcomingWidgetLabel(for releaseType: CalendarMovieRelease.ReleaseType) -> String {
        switch releaseType {
        case .premiere:
            return "Theatrical"
        case .physical:
            return "Physical"
        case .streaming:
            return "Digital"
        }
    }

    private func store(singleWidget model: WidgetModel, with key: String) {
        // do nothing if the current model is already
        if decodeSingleWidgetModel(for: key) == model { return }
        if let encoded = try? JSONEncoder().encode(model) {
            UserDefaults(suiteName: "group.tv.trakt.rippple")!.set(encoded, forKey: key)
            WidgetCenter.shared.getCurrentConfigurations { result in
                guard case .success(let widgets) = result else { return }

                for widget in widgets {
                    if let intent = widget.configuration as? MediaTypeIntent, intent.type?.identifier == WidgetType.custom.rawValue {
                        WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                    } else if let intent = widget.configuration as? MediaTypeIntent, intent.type?.identifier == key {
                        WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                    } else {
                        switch widget.kind {
                        case "LastWatchedLock":
                            if key == WidgetType.lastWatched.rawValue {
                                WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                            }
                        case "ShowToWatchLock":
                            if key == WidgetType.showsToWatch.rawValue {
                                WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                            }
                        case "MovieToWatchLock":
                            if key == WidgetType.moviesToWatch.rawValue {
                                WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                            }
                        case "UpcomingShowLock":
                            if key == WidgetType.showsComing.rawValue {
                                WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                            }
                        case "UpcomingMovieLock":
                            if key == WidgetType.moviesComing.rawValue {
                                WidgetCenter.shared.reloadTimelines(ofKind: widget.kind)
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }
    }
}
