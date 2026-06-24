//
//  AnticipatedNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 17/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation
import Receiver
import UserNotifications

final class AnticipatedNotificationsManager {
    static let shared = AnticipatedNotificationsManager()

    // Settings

    var anticipatedShows: Bool {
        didSet {
            UserDefaults.standard.set(anticipatedShows, forKey: "AnticipatedNotificationsManager.anticipatedShows")
            UserDefaults.standard.synchronize()
        }
    }

    var anticipatedMovies: Bool {
        didSet {
            UserDefaults.standard.set(anticipatedMovies, forKey: "AnticipatedNotificationsManager.anticipatedMovies")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private let disposeBag = DisposeBag()

    private init() {
        anticipatedShows = UserDefaults.standard.bool(forKey: "AnticipatedNotificationsManager.anticipatedShows")
        anticipatedMovies = UserDefaults.standard.bool(forKey: "AnticipatedNotificationsManager.anticipatedMovies")
    }

    fileprivate let uuidPrefixForShows = "anticipatedShow"
    fileprivate let uuidPrefixForMovies = "anticipatedMovie"

    func setup() {
        fetchAndBuildAnticipated()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(dayChanged),
                                               name: .NSCalendarDayChanged,
                                               object: nil)

        onNotificationsSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetchAndBuildAnticipated()
        }.disposed(by: disposeBag)
    }

    @objc func dayChanged(_ notification: Notification) {
        fetchAndBuildAnticipated()
    }

    private func fetchAndBuildAnticipated() {
        Task {
            do {
                let anticipatedMovies = anticipatedMovies ? try await fetchAnticipatedMovies() : [MediaItem]()
                rebuildMovieNotifications(with: anticipatedMovies)
            } catch {
                print("\(error)")
            }
            do {
                let anticipatedShows = anticipatedShows ? try await fetchAnticipatedShows() : [MediaItem]()
                let premiere = try await fetchPremiereCalendar(date: .now, days: 15)

                var anticipatedShowsWithPremiereDate = [MediaItem]()
                for p in premiere {
                    guard let anticipated = anticipatedShows.first(where: { $0.show == p.show })?.show else { continue }
                    let anticipatedShowWithPremiereDate = MediaItem(movie: nil,
                                                                    show: Show(officialTitle: anticipated.officialTitle,
                                                                               originalTitle: anticipated.originalTitle,
                                                                               releaseYear: anticipated.releaseYear,
                                                                               identifiers: anticipated.identifiers,
                                                                               commentCount: anticipated.commentCount,
                                                                               airedEpisodes: anticipated.airedEpisodes,
                                                                               tagline: anticipated.tagline,
                                                                               overview: anticipated.overview,
                                                                               runtime: anticipated.runtime,
                                                                               certification: anticipated.certification,
                                                                               genres: anticipated.genres,
                                                                               firstAired: p.firstAired,
                                                                               country: anticipated.country,
                                                                               network: anticipated.network,
                                                                               status: anticipated.status,
                                                                               airs: anticipated.airs,
                                                                               rating: anticipated.rating,
                                                                               votes: anticipated.votes,
                                                                               homepage: anticipated.homepage,
                                                                               trailer: anticipated.trailer,
                                                                               language: anticipated.language),
                                                                    episode: nil,
                                                                    season: nil,
                                                                    list: nil,
                                                                    watchers: nil,
                                                                    listedAt: nil,
                                                                    collectedAt: nil,
                                                                    lastCollectedAt: nil,
                                                                    hiddenAt: nil,
                                                                    notes: nil)
                    anticipatedShowsWithPremiereDate.append(anticipatedShowWithPremiereDate)
                }

                rebuildShowNotifications(with: anticipatedShowsWithPremiereDate)
            } catch {
                print("\(error)")
            }
        }
    }

    private func fetchAnticipatedMovies() async throws -> [MediaItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedMovies(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: 20)), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: movies)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchAnticipatedShows() async throws -> [MediaItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.anticipatedShows(filters: [String: String](), extended: .full, pageInfo: PageInfo.firstPage(with: 20)), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let movies = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: movies)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchPremiereCalendar(date: Date, days: Int) async throws -> [ShowEpisodeCalendarItem] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.premiereCalendar(startDate: date, days: days), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let showEpisodeCalendarItems = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: showEpisodeCalendarItems)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func rebuildMovieNotifications(with mediaItems: [MediaItem]) {
        var requests = [UNNotificationRequest]()
        let latestReleaseDate = Calendar.current.date(byAdding: .day, value: 15, to: .now) ?? .now

        for mediaItem in mediaItems {
            guard let movie = mediaItem.movie,
                  let releaseDate = releaseDate(for: movie),
                  releaseDate <= latestReleaseDate else { continue }
            if let request = scheduleNotification(for: mediaItem,
                                                  with: "",
                                                  subtitle: "") {
                requests.append(request)
            }
        }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getPendingNotificationRequests { pendingNotificationRequests in
            var identifiersToRemove = [String]()
            for pendingNotificationRequest in pendingNotificationRequests where requests.contains(where: { $0.identifier == pendingNotificationRequest.identifier }) == false && pendingNotificationRequest.isAnticipatedMovie {
                print("Removing notification: \(pendingNotificationRequest.identifier) - \(pendingNotificationRequest.content.title) - \(pendingNotificationRequest.content.body)")
                identifiersToRemove.append(pendingNotificationRequest.identifier)
            }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
        for request in requests {
            notificationCenter.add(request) { error in
                if error != nil {
                    print("notificationCenter.add error: \(error!)")
                } else {
                    print("Adding notification: \(request.identifier) - \(request.content.title) - \(request.content.body)")
                }
            }
        }
    }

    private func rebuildShowNotifications(with mediaItems: [MediaItem]) {
        var requests = [UNNotificationRequest]()

        for mediaItem in mediaItems {
            if let request = scheduleNotification(for: mediaItem,
                                                  with: "",
                                                  subtitle: "") {
                requests.append(request)
            }
        }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getPendingNotificationRequests { pendingNotificationRequests in
            var identifiersToRemove = [String]()
            for pendingNotificationRequest in pendingNotificationRequests where requests.contains(where: { $0.identifier == pendingNotificationRequest.identifier }) == false && pendingNotificationRequest.isAnticipatedShow {
                print("Removing notification: \(pendingNotificationRequest.identifier) - \(pendingNotificationRequest.content.title) - \(pendingNotificationRequest.content.body)")
                identifiersToRemove.append(pendingNotificationRequest.identifier)
            }

            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
        for request in requests {
            notificationCenter.add(request) { error in
                if error != nil {
                    print("notificationCenter.add error: \(error!)")
                } else {
                    print("Adding notification: \(request.identifier) - \(request.content.title) - \(request.content.body)")
                }
            }
        }
    }

    private func scheduleNotification(for mediaItem: MediaItem, with title: String, subtitle: String) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle

        if let movie = mediaItem.movie {
            content.title = "👀 Anticipated Movie"
            if let country = movie.country {
                let localizedCountry = Locale(identifier: "en_US").localizedCountry(for: country)
                content.body = "\(movie.title) is released today in \(localizedCountry)."
            } else {
                content.body = "\(movie.title) is released today."
            }
            content.threadIdentifier = "\(movie.identifiers.trakt!)"
            content.userInfo = ["link": "ripl://movies/\(movie.identifiers.trakt!)"]

            guard let date = releaseDate(for: movie) else { return nil }

            let triggerDate = Calendar.current.date(bySettingHour: 9,
                                                    minute: 0,
                                                    second: 0,
                                                    of: date)!
            if triggerDate <= .now { return nil }

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                             from: triggerDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let uuidString = identifier(for: mediaItem)
            return UNNotificationRequest(identifier: uuidString,
                                         content: content,
                                         trigger: trigger)
        } else if let show = mediaItem.show {
            guard let triggerDate = show.firstAired else { return nil }
            if triggerDate <= .now { return nil }

            content.title = "👀 Anticipated Show"
            if let network = show.network {
                content.body = "\(show.title) is released on \(network)"
            } else {
                content.body = "\(show.title) is released"
            }
            content.threadIdentifier = "\(show.identifiers.trakt!)"
            content.userInfo = ["link": "ripl://shows/\(show.identifiers.trakt!)"]

            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                             from: triggerDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let uuidString = identifier(for: mediaItem)
            return UNNotificationRequest(identifier: uuidString,
                                         content: content,
                                         trigger: trigger)
        } else {
            return nil
        }
    }

    private func identifier(for mediaItem: MediaItem) -> String {
        if mediaItem.movie != nil {
            return uuidPrefixForMovies + "\(mediaItem.movie!.identifiers.trakt!)"
        } else {
            return uuidPrefixForShows + "\(mediaItem.show!.identifiers.trakt!)"
        }
    }

    private func releaseDate(for movie: Movie) -> Date? {
        guard let released = movie.released else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: released)
    }
}

extension UNNotificationRequest {
    var isAnticipatedMovie: Bool {
        return identifier.hasPrefix(AnticipatedNotificationsManager.shared.uuidPrefixForMovies)
    }

    var isAnticipatedShow: Bool {
        return identifier.hasPrefix(AnticipatedNotificationsManager.shared.uuidPrefixForShows)
    }
}
