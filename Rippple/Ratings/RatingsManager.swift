//
//  RatingsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 01/11/2018.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

final class RatingsManager {
    private let disposeBag = DisposeBag()

    private init() {
        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                self.refreshRatings {}
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.refreshRatings {}
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { settings in
            if settings != nil {
                self.refreshRatings {}
            } else {
                self.rated.removeAll()
            }
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.rated.removeAll()
        }.disposed(by: disposeBag)

        refreshRatings {}
    }

    static let shared = RatingsManager()

    let (onRatedItemsChangedTransmitter, onRatedItemsChangedReceiver) = Receiver<[RatedItem]>.make(with: .hot)

    fileprivate var rated = [RatedItem]() {
        didSet {
            onRatedItemsChangedTransmitter.broadcast(rated)
        }
    }

    func ratingFor(media: MediaModel) -> Int? {
        switch media {
        case .movie(let movie):
            return ratingFor(movie: movie)
        case .show(let show):
            return ratingFor(show: show)
        case .episode(let episode, let show):
            return ratingFor(episode: episode, show: show)
        case .season(let season, let show):
            return ratingFor(season: season, show: show)
        case .list:
            fatalError("No rating for list")
        case .showProgress(let show, let progress):
            if let episode = progress.nextEpisodeToWatch {
                return ratingFor(episode: episode, show: show)
            } else {
                return ratingFor(show: show)
            }
        }
    }

    fileprivate func ratingFor(movie: Movie) -> Int? {
        for ratedItem in rated {
            if let ratedMovie = ratedItem.movie,
               ratedMovie == movie {
                return ratedItem.rating
            }
        }

        return nil
    }

    fileprivate func ratingFor(show: Show) -> Int? {
        for ratedItem in rated {
            if ratedItem.episode == nil,
               ratedItem.season == nil,
               let ratedShow = ratedItem.show,
               ratedShow == show {
                return ratedItem.rating
            }
        }

        return nil
    }

    fileprivate func ratingFor(episode: Episode, show: Show) -> Int? {
        for ratedItem in rated {
            if let ratedShow = ratedItem.show,
               let ratedEpisode = ratedItem.episode,
               ratedShow == show,
               ratedEpisode == episode {
                return ratedItem.rating
            }
        }

        return nil
    }

    fileprivate func ratingFor(season: Season, show: Show) -> Int? {
        for ratedItem in rated {
            if ratedItem.episode == nil,
               let ratedShow = ratedItem.show,
               let ratedSeason = ratedItem.season,
               ratedShow == show,
               ratedSeason == season {
                return ratedItem.rating
            }
        }

        return nil
    }

    func rate(media: MediaModel, rating: Int, with completion: @escaping (_ error: Error?) -> Void) {
        func addRatingService(for media: MediaModel, and rating: Int) -> TraktAPIService {
            switch media {
            case .movie(let movie):
                return .rateMovie(id: movie.identifiers.trakt!, rating: rating)
            case .show(let show):
                return .rateShow(id: show.identifiers.trakt!, rating: rating)
            case .episode(let episode, _):
                return .rateEpisode(id: episode.identifiers.trakt!, rating: rating)
            case .season(let season, _):
                return .rateSeason(id: season.identifiers.trakt!, rating: rating)
            case .list:
                fatalError("List not supported yet")
            case .showProgress:
                fatalError()
            }
        }

        func removeRatingService(for media: MediaModel) -> TraktAPIService {
            switch media {
            case .movie(let movie):
                return .removeMovieRating(id: movie.identifiers.trakt!)
            case .show(let show):
                return .removeShowRating(id: show.identifiers.trakt!)
            case .episode(let episode, _):
                return .removeEpisodeRating(id: episode.identifiers.trakt!)
            case .season(let season, _):
                return .removeSeasonRating(id: season.identifiers.trakt!)
            case .list:
                fatalError("List not supported yet")
            case .showProgress:
                fatalError()
            }
        }

        if rating == 0 {
            // remove rating
            SwiftMessages.show(message: "Removing Rating...", style: .loading)

            TraktAPIProvider.provider.request(removeRatingService(for: media),
                                              callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        print("\(response)")

                        self.refreshRatings {
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        }
                    } catch {
                        print("Rate failed \(error)")
                        DispatchQueue.main.async {
                            completion(error)
                            self.onRatedItemsChangedTransmitter.broadcast(self.rated)
                        }
                    }
                case .failure(let error):
                    print("Rate failed \(error)")
                    DispatchQueue.main.async {
                        completion(error)
                        self.onRatedItemsChangedTransmitter.broadcast(self.rated)
                    }
                }
            }
        } else {
            // rating
            SwiftMessages.show(message: "Adding Rating...", style: .loading)

            TraktAPIProvider.provider.request(addRatingService(for: media, and: rating),
                                              callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        print("\(response)")

                        self.refreshRatings {
                            DispatchQueue.main.async {
                                completion(nil)
                            }
                        }
                    } catch {
                        print("Rate failed \(error)")
                        DispatchQueue.main.async {
                            completion(error)
                            self.onRatedItemsChangedTransmitter.broadcast(self.rated)
                        }
                    }
                case .failure(let error):
                    print("Rate failed \(error)")
                    DispatchQueue.main.async {
                        completion(error)
                        self.onRatedItemsChangedTransmitter.broadcast(self.rated)
                    }
                }
            }
        }
    }
}

private extension RatingsManager {
    private func refreshRatings(with completion: @escaping () -> Void) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(.rated(slug: "me", type: .all, extended: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let rated = try response.map([RatedItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.rated = rated
                        completion()
                    }
                } catch {
                    print("Rated Items request JSON mapping failed! \(error)")
                    DispatchQueue.main.async {
                        completion()
                    }
                }
            case .failure(let error):
                print("Rated Items request failure \(error)")
                DispatchQueue.main.async {
                    completion()
                }
            }
        }
    }
}

extension MediaModel {
    var userRating: Int? {
        return RatingsManager.shared.ratingFor(media: self)
    }

    var ratedItems: [RatedItem]? {
        switch self {
        case .movie(let movie):
            return RatingsManager.shared.rated.filter { $0.movie == movie }
        case .show(let show):
            return RatingsManager.shared.rated.filter { $0.show == show }
        case .episode(let episode, let show):
            return RatingsManager.shared.rated.filter { $0.show == show && $0.episode == episode }
        case .season(let season, let show):
            return RatingsManager.shared.rated.filter { $0.show == show && $0.season == season }
        case .list:
            return nil
        case .showProgress:
            return nil
        }
    }

    func rate(rating: Int, with completion: @escaping (_ error: Error?) -> Void) {
        RatingsManager.shared.rate(media: self, rating: rating, with: completion)
    }

    var rating: Double? {
        switch self {
        case .movie(let movie):
            return movie.rating
        case .show(let show):
            return show.rating
        case .episode(let episode, _):
            return episode.rating
        case .season(let season, _):
            return season.rating
        case .list:
            fatalError("No rating for list")
        case .showProgress:
            fatalError("No rating for progress")
        }
    }
}

extension Episode {
    func userRating(for show: Show) -> Int? {
        return RatingsManager.shared.ratingFor(episode: self, show: show)
    }
}

extension Show {
    var userRating: Int? {
        RatingsManager.shared.ratingFor(show: self)
    }
}
