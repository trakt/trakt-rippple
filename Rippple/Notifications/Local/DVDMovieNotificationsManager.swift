//
//  DVDMovieNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 11/07/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onDVDMoviesNotificationsChangedTransmitter, onDVDMoviesNotificationsChangedReceiver) = Receiver<[UNNotificationRequest]>.make(with: .warm(upTo: 1))

final class DVDMovieNotificationsManager {
    static let shared = DVDMovieNotificationsManager()

    private let disposeBag = DisposeBag()

    // Settings

    var watchlistMovieRelease: Bool {
        didSet {
            UserDefaults.standard.set(watchlistMovieRelease, forKey: "DVDMovieNotificationsManager.watchlistMovieRelease")
            UserDefaults.standard.synchronize()
        }
    }

    var toWatchMovieRelease: Bool {
        didSet {
            UserDefaults.standard.set(toWatchMovieRelease, forKey: "DVDMovieNotificationsManager.toWatchMovieRelease")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        watchlistMovieRelease = UserDefaults.standard.bool(forKey: "DVDMovieNotificationsManager.watchlistMovieRelease")
        toWatchMovieRelease = UserDefaults.standard.bool(forKey: "DVDMovieNotificationsManager.toWatchMovieRelease")
    }

    fileprivate let uuidPrefix = "DVDMovieRelease"

    private var toWatchMovies: [Movie]? {
        didSet {
            rebuildNotifications()
        }
    }

    private var watchlistedMovies: [Movie]? {
        didSet {
            rebuildNotifications()
        }
    }

    private var movieCalendarItems: [MovieCalendarItem]? {
        didSet {
            rebuildNotifications()
        }
    }

    private func rebuildNotifications() {
        guard let movieCalendarItems = movieCalendarItems else { return }
        guard let watchlistedMovies = watchlistedMovies else { return }
        guard let toWatchMovies = toWatchMovies else { return }

        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pendingNotificationRequests in
            guard let self = self else { return }
            var identifiersToRemove = [String]()
            for pendingNotificationRequest in pendingNotificationRequests where pendingNotificationRequest.identifier.hasPrefix(self.uuidPrefix) {
                identifiersToRemove.append(pendingNotificationRequest.identifier)
            }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)

            var requests = [UNNotificationRequest]()
            for movieCalendarItem in movieCalendarItems {
                if toWatchMovies.contains(movieCalendarItem.movie) {
                    if DVDMovieNotificationsManager.shared.toWatchMovieRelease {
                        if let request = self.scheduleNotification(for: movieCalendarItem, with: "DVD & Blu-ray Release", subtitle: "") {
                            requests.append(request)
                        }
                        continue
                    }
                } else if watchlistedMovies.contains(movieCalendarItem.movie) {
                    if DVDMovieNotificationsManager.shared.watchlistMovieRelease {
                        if let request = self.scheduleNotification(for: movieCalendarItem, with: "DVD & Blu-ray Release", subtitle: "") {
                            requests.append(request)
                        }
                        continue
                    }
                }
            }
            let notificationCenter = UNUserNotificationCenter.current()
            for request in requests {
                notificationCenter.add(request) { error in
                    if error != nil {
                        print("notificationCenter.add error: \(error!)")
                    } else {
                        print("Added :\(request.content.title)\n\(request.content.body)")
                    }
                }
            }
            onDVDMoviesNotificationsChangedTransmitter.broadcast(requests)
        }
    }

    func setup() {
        onNotificationsSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.rebuildNotifications()
        }.disposed(by: disposeBag)

        onAllMoviesToWatchChangedReceiver.listen { [weak self] movies in
            guard let self = self else { return }
            self.toWatchMovies = movies
        }.disposed(by: disposeBag)

        onMoviesWatchlistedChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            TraktAPIProvider.fetchAllWatchlistItems(slug: "me",
                                                    type: .movies,
                                                    extended: .full,
                                                    sort: nil) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case .success(let watchlistItems):
                    self.watchlistedMovies = watchlistItems.map { $0.movie! }
                case .failure(let error):
                    print("watchlist request failure \(error)")
                }
            }
        }

        fetchCalendar()
    }

    private func fetchCalendar() {
        TraktAPIProvider.provider.request(.dvdMoviesCalendar(startDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())!, days: 15), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    self.movieCalendarItems = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)

                } catch {
                    print("dvdMoviesCalendar request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("dvdMoviesCalendar request failure \(error)")
            }
        }
    }

    private func scheduleNotification(for movieCalendarItem: MovieCalendarItem, with title: String, subtitle: String) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        if let country = movieCalendarItem.movie.country {
            let localizedCountry = Locale(identifier: "en_US").localizedCountry(for: country)
            content.body = "\(movieCalendarItem.movie.title) is released today in \(localizedCountry)"
        } else {
            content.body = "\(movieCalendarItem.movie.title) is released today."
        }
        content.threadIdentifier = "\(movieCalendarItem.movie.identifiers.trakt!)"

//        let triggerDate = Date().advanced(by: 10)
        let triggerDate = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: movieCalendarItem.released)!
        if triggerDate <= .now { return nil }

        content.userInfo = ["link": "ripl://movies/\(movieCalendarItem.movie.identifiers.trakt!)"]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let uuidString = uuidPrefix + "\(movieCalendarItem.movie.identifiers.trakt!)"
        return UNNotificationRequest(identifier: uuidString,
                                     content: content,
                                     trigger: trigger)
    }
}

extension UNNotificationRequest {
    var isDVDMovieNotification: Bool {
        return identifier.hasPrefix(DVDMovieNotificationsManager.shared.uuidPrefix)
    }
}
