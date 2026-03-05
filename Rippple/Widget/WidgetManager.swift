//
//  WidgetManager.swift
//  Rippple
//
//  Created by Kevin Cador on 12/07/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation

import Receiver

import WidgetKit

final class WidgetManager {

    private let disposeBag = DisposeBag()

    private init() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    func setup() {
        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
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

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateLastWatched()
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.listen { [weak self] watchedItems in
            guard let self = self else { return }
            if let last = watchedItems.sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt }).first {
                if let movie = last.movie {
                    let media = movie.mediaModel
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
            }
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.skipRepeats().listen { [weak self] watchedItems in
            guard let self = self else { return }
            if let last = watchedItems.sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt }).first {
                if let show = last.show {
                    show.mediaModel.backdropURL { url in
                        let progress = WidgetModel(label: "Last Watched Show",
                                                         title: show.title,
                                                         subtitle: nil,
                                                         image: url,
                                                         behind: nil,
                                                         redacted: false,
                                                         deeplink: show.mediaModel.deeplink)
                        self.store(singleWidget: progress, with: WidgetType.lastWatchedShow.rawValue)
                    }
                }
            }
        }.disposed(by: disposeBag)

        onEpisodeToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
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
                        behindText = nil
                    }
                    var subtitle: String?
                    if let episodeToWatch = progress.nextEpisodeToWatch {
                        subtitle = episodeToWatch.localizedEpisodeNumber
                    }
                    if progress.toRewatchCount > 0 {
                        subtitle = "\(progress.toRewatchCount) to rewatch"
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

        #if !targetEnvironment(macCatalyst)
        if let alternateIconName = UIApplication.shared.alternateIconName, let identifier = AppIconIdentifier(rawValue: alternateIconName) {
            storeAppIconForWidget(appIcon: AppIcon(name: "", identifier: identifier))
        } else {
            storeAppIconForWidget(appIcon: AppIcon(name: "", identifier: .original))
        }
        #endif
    }

    public func storeAppIconForWidget(appIcon: AppIcon) {
        UserDefaults(suiteName: "group.tv.trakt.rippple")!.set(appIcon.identifier.rawValue, forKey: "WidgetManager.appIcon")
        WidgetCenter.shared.reloadTimelines(ofKind: "RipppleIcon")
    }

    static let shared = WidgetManager()

    private func updateLastWatched() {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(TraktAPIService.history(slug: "me", type: nil, id: nil, pageInfo: PageInfo.firstPage(with: 1), endDate: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

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
                                                        } else if let show = last.show {
                                                            show.mediaModel.backdropURL { url in
                                                                let progress = WidgetModel(label: "Last Watched",
                                                                                           title: show.title,
                                                                                           subtitle: last.episode?.localizedEpisodeNumber,
                                                                                           image: url,
                                                                                           behind: nil,
                                                                                           redacted: false,
                                                                                           deeplink: last.episode?.mediaModel(given: show).deeplink,
                                                                                           runtime: last.episode!.runtime,
                                                                                           endDate: last.watchDate)
                                                                self.store(singleWidget: progress, with: WidgetType.lastWatched.rawValue)
                                                            }
                                                        }
                                                    }
                                                } catch {
                                                    print("Last activity (/history) request JSON mapping failed! \(error)")
                                                }
                                            case let .failure(error):
                                                print("Last activity (/history) request failure \(error)")
                                            }
        }
    }

    private func decodeSingleWidgetModel(for key: String) -> WidgetModel? {
        if let encodedData = UserDefaults(suiteName: "group.tv.trakt.rippple")!.object(forKey: key) as? Data {
            if let progress = try? JSONDecoder().decode(WidgetModel.self, from: encodedData) {
                return progress
            }
        }
        return nil
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
