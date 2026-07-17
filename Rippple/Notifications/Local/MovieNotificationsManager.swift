//
//  MovieNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/05/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UserNotifications

let (onMoviesNotificationsChangedTransmitter, onMoviesNotificationsChangedReceiver) = Receiver<[UNNotificationRequest]>.make(with: .warm(upTo: 1))

final class MovieNotificationsManager {
    static let shared = MovieNotificationsManager()

    private let disposeBag = DisposeBag()

    // Settings

    var watchlistMovieRelease: Bool {
        didSet {
            UserDefaults.standard.set(watchlistMovieRelease, forKey: "MovieNotificationsManager.watchlistMovieRelease")
            UserDefaults.standard.synchronize()
        }
    }

    var toWatchMovieRelease: Bool {
        didSet {
            UserDefaults.standard.set(toWatchMovieRelease, forKey: "MovieNotificationsManager.toWatchMovieRelease")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        watchlistMovieRelease = UserDefaults.standard.bool(forKey: "MovieNotificationsManager.watchlistMovieRelease")
        toWatchMovieRelease = UserDefaults.standard.bool(forKey: "MovieNotificationsManager.toWatchMovieRelease")
        debouncedRebuildNotifications = Debouncer(delay: 2.0) { [weak self] in
            guard let self = self else { return }
            self.rebuildNotifications()
        }
    }

    fileprivate let uuidPrefix = "movieRelease"

    private var debouncedRebuildNotifications: Debouncer!

    private var movieCalendarItems: [MovieCalendarItem]? {
        didSet {
            debouncedRebuildNotifications.call()
        }
    }

    private func rebuildNotifications() {
        guard let movieCalendarItems = movieCalendarItems else { return }

        var requests = [UNNotificationRequest]()
        for movieCalendarItem in movieCalendarItems {
            if movieCalendarItem.movie.isInToWatch {
                if MovieNotificationsManager.shared.toWatchMovieRelease {
                    if let request = scheduleNotification(for: movieCalendarItem, with: "Movie Release", subtitle: "") {
                        requests.append(request)
                    }
                    continue
                }
            } else if movieCalendarItem.movie.isWatchlisted {
                if MovieNotificationsManager.shared.watchlistMovieRelease {
                    if let request = scheduleNotification(for: movieCalendarItem, with: "Movie Release", subtitle: "") {
                        requests.append(request)
                    }
                    continue
                }
            }
        }
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getPendingNotificationRequests { pendingNotificationRequests in
            var identifiersToRemove = [String]()
            for pendingNotificationRequest in pendingNotificationRequests where requests.contains(where: { $0.identifier == pendingNotificationRequest.identifier }) == false && pendingNotificationRequest.isMovieNotification {
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
        onMoviesNotificationsChangedTransmitter.broadcast(requests)
    }

    func setup() {
        onNotificationsSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.fireNow()
        }.disposed(by: disposeBag)

        onAllMoviesToWatchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.call()
        }.disposed(by: disposeBag)

        onMoviesWatchlistedChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.call()
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.movieCalendarItems = nil
            onMoviesNotificationsChangedTransmitter.broadcast([])
        }.disposed(by: disposeBag)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(dayChanged),
                                               name: .NSCalendarDayChanged,
                                               object: nil)

        fetchCalendar()
    }

    @objc func dayChanged(_ notification: Notification) {
        fetchCalendar()
    }

    private func fetchCalendar() {
        TraktAPIProvider.provider.request(.moviesCalendar(startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, days: 7, filters: [String: String]()), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    self.movieCalendarItems = try response.map([MovieCalendarItem].self, using: TraktAPIProvider.decoder)

                } catch {
                    print("moviesCalendar request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("moviesCalendar request failure \(error)")
            }
        }
    }

    private func scheduleNotification(for movieCalendarItem: MovieCalendarItem, with title: String, subtitle: String) -> UNNotificationRequest? {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        if let country = movieCalendarItem.movie.country {
            let localizedCountry = Locale(identifier: "en_US").localizedCountry(for: country)
            content.body = "\(movieCalendarItem.movie.title) is released today in \(localizedCountry)."
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
    var isMovieNotification: Bool {
        return identifier.hasPrefix(MovieNotificationsManager.shared.uuidPrefix)
    }
}
