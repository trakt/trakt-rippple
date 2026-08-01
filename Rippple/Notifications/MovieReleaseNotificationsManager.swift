//
//  MovieReleaseNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/05/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import UserNotifications

//
// import Moya

// let (onEpisodeToWatchChangedTransmitter, onEpisodeToWatchChangedReceiver) = Receiver<[MediaModel]>.make(with: .warm(upTo: 1))
// let (onEpisodeToWatchStatusChangedTransmitter, onEpisodeToWatchStatusChangedReceiver) = Receiver<EpisodeToWatchManager.Status>.make(with: .warm(upTo: 1))

final class ToWatchMovieReleaseNotificationsManager {
    static let shared = ToWatchMovieReleaseNotificationsManager()

    private let disposeBag = DisposeBag()

    private init() {}

    private let uuidPrefix = "movieRelease"

    private var movies: [Movie]? {
        didSet {
            fetchCalendar()
        }
    }

    func setup() {
        onAllMoviesToWatchChangedReceiver.listen { [weak self] movies in
            guard let self = self else { return }
            self.movies = movies
        }.disposed(by: disposeBag)
    }

    private func fetchCalendar() {
        TraktAPIProvider.provider.request(.moviesCalendar(startDate: Date(), days: 14), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let decoder = JSONDecoder()
                    let formatter = DateFormatter()
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.dateFormat = "yyyy-MM-dd"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)
                    decoder.dateDecodingStrategy = .formatted(formatter)

                    let movieCalendarItems = try response.map([MovieCalendarItem].self, using: decoder)

                    UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pendingNotificationRequests in
                        guard let self = self else { return }
                        var identifiersToRemove = [String]()
                        for pendingNotificationRequest in pendingNotificationRequests where pendingNotificationRequest.identifier.hasPrefix(self.uuidPrefix) {
                            identifiersToRemove.append(pendingNotificationRequest.identifier)
                        }
                        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                    }

                    for movieCalendarItem in movieCalendarItems where self.movies!.contains(movieCalendarItem.movie) {
                        self.scheduleNotification(for: movieCalendarItem)
                    }
                } catch {
                    print("moviesCalendar request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("moviesCalendar request failure \(error)")
            }
        }
    }

    private func scheduleNotification(for movieCalendarItem: MovieCalendarItem) {
        let content = UNMutableNotificationContent()
        content.body = "\(movieCalendarItem.movie.title) is released today."

        print("scheduleNotification for movie \(movieCalendarItem.movie.title)")

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: movieCalendarItem.released)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components,
                                                    repeats: true)
        let uuidString = uuidPrefix + "\(movieCalendarItem.movie.identifiers.trakt!)"
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content,
                                            trigger: trigger)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { error in
            if error != nil {
                // Handle any errors.
            }
        }
    }
}
