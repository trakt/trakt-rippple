//
//  EpisodeReleaseNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation

import Receiver

let (onEpisodesNotificationsChangedTransmitter, onEpisodesNotificationsChangedReceiver) = Receiver<[UNNotificationRequest]>.make(with: .warm(upTo: 1))

final class EpisodeNotificationsManager {

    static let shared = EpisodeNotificationsManager()

    // Settings

    var groupEpisodes: Bool { // group episodes from the same show that drop at the same time
        didSet {
            UserDefaults.standard.set(groupEpisodes, forKey: "EpisodeNotificationsManager.groupEpisodes")
            UserDefaults.standard.synchronize()
        }
    }

    var watchlistShowPremiere: Bool {
        didSet {
            UserDefaults.standard.set(watchlistShowPremiere, forKey: "EpisodeNotificationsManager.watchlistShowPremiere")
            UserDefaults.standard.synchronize()
        }
    }
    var watchlistSeasonPremiere: Bool {
        didSet {
            UserDefaults.standard.set(watchlistSeasonPremiere, forKey: "EpisodeNotificationsManager.watchlistSeasonPremiere")
            UserDefaults.standard.synchronize()
        }
    }
    var watchlistEpisodeRelease: Bool {
        didSet {
            UserDefaults.standard.set(watchlistEpisodeRelease, forKey: "EpisodeNotificationsManager.watchlistEpisodeRelease")
            UserDefaults.standard.synchronize()
        }
    }
    var toWatchShowPremiere: Bool {
        didSet {
            UserDefaults.standard.set(toWatchShowPremiere, forKey: "EpisodeNotificationsManager.toWatchShowPremiere")
            UserDefaults.standard.synchronize()
        }
    }
    var toWatchSeasonPremiere: Bool {
        didSet {
            UserDefaults.standard.set(toWatchSeasonPremiere, forKey: "EpisodeNotificationsManager.toWatchSeasonPremiere")
            UserDefaults.standard.synchronize()
        }
    }
    var toWatchEpisodeRelease: Bool {
        didSet {
            UserDefaults.standard.set(toWatchEpisodeRelease, forKey: "EpisodeNotificationsManager.toWatchEpisodeRelease")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private let disposeBag = DisposeBag()

    private var rebuildNotificationsTask: Task<Void, Never>?

    private var cachedCalendarItems: [ShowEpisodeCalendarItem]?
    private var lastCalendarFetchDate: Date?

    private init() {
        groupEpisodes = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.groupEpisodes")
        watchlistShowPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistShowPremiere")
        watchlistSeasonPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistSeasonPremiere")
        watchlistEpisodeRelease = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistEpisodeRelease")
        toWatchShowPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchShowPremiere")
        toWatchSeasonPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchSeasonPremiere")
        toWatchEpisodeRelease = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchEpisodeRelease")
    }

    fileprivate let uuidPrefix = "episodeRelease"

    private var toWatchShows: [Show]? {
        didSet {
            guard let toWatchShows = toWatchShows else { return }
            guard let watchlistedShows = watchlistedShows else { return }
            var list = [Int64]()
            list.append(contentsOf: toWatchShows.compactMap { $0.identifiers.trakt })
            list.append(contentsOf: watchlistedShows)
            list.removeDuplicates()
            list.sort()
            showList = list
        }
    }

    private var watchlistedShows: [Int64]? {
        didSet {
            guard let toWatchShows = toWatchShows else { return }
            guard let watchlistedShows = watchlistedShows else { return }
            var list = [Int64]()
            list.append(contentsOf: toWatchShows.compactMap { $0.identifiers.trakt })
            list.append(contentsOf: watchlistedShows)
            list.removeDuplicates()
            list.sort()
            showList = list
        }
    }

    private var showList = [Int64]() {
        didSet {
            if showList == oldValue { return }
            debouncedRebuildNotifications.call()
        }
    }

    private func rebuildNotifications() {
        // the ToWatch or Watchlist can be empty, this call  is debounced enough to not wait more than this!
        if toWatchShows == nil && watchlistedShows == nil { return }

        rebuildNotificationsTask?.cancel()
        scheduleNotifications()
    }

    @objc func dayChanged(_ notification: Notification) {
        debouncedRebuildNotifications.call()
    }

    func setup() {
        debouncedRebuildNotifications = Debouncer(delay: 2.0) { [weak self] in
            guard let self = self else { return }
            self.rebuildNotifications()
        }

        onNotificationsSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.fireNow()
        }.disposed(by: disposeBag)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(dayChanged),
                                               name: .NSCalendarDayChanged,
                                               object: nil)

        onShowsToWatchChangedReceiver.listen { [weak self] shows in
            guard let self = self else { return }
            self.toWatchShows = shows
        }.disposed(by: disposeBag)

        onShowsWatchlistedChangedReceiver.listen { [weak self] identifiers in
            guard let self = self else { return }
            self.watchlistedShows = identifiers
        }

        debouncedRebuildNotifications.call()
    }

    private var debouncedRebuildNotifications: Debouncer!

    private func fetchCalendar() async throws -> [ShowEpisodeCalendarItem] {
        if let cachedCalendarItems = cachedCalendarItems,
           let lastCalendarFetchDate = lastCalendarFetchDate,
           Calendar.current.isDate(lastCalendarFetchDate, inSameDayAs: .now) == true {
            return cachedCalendarItems
        }

        let result: [ShowEpisodeCalendarItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.showsCalendar(startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!, days: 7, filters: [String: String]()), callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let showEpisodeCalendarItems = try response.map([ShowEpisodeCalendarItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: showEpisodeCalendarItems)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }

        cachedCalendarItems = result
        lastCalendarFetchDate = Date()

        return result
    }

    private func scheduleNotifications() {
        guard let toWatchShows = toWatchShows else { return }

        rebuildNotificationsTask = Task { [weak self] in
            guard let self = self else { return }
            
            let backgroundTaskIdentifier = beginNotificationRebuildBackgroundTask()
            defer {
                endNotificationRebuildBackgroundTask(backgroundTaskIdentifier)
            }

            do {
                let showEpisodeCalendarItems = try await fetchCalendar().filter { $0.firstAired > .now }
                try Task.checkCancellation()

                var requests = [UNNotificationRequest]()

                for showEpisodeCalendarItem in showEpisodeCalendarItems where showEpisodeCalendarItem.episode.season != 0 {
                    try Task.checkCancellation()
                    // Never schedule local episode notifications for dropped or hidden shows.
                    if showEpisodeCalendarItem.show.isDropped || showEpisodeCalendarItem.show.isHiddenFromProgress || showEpisodeCalendarItem.show.isHiddenFromCalendar {
                        continue
                    }
                    // is in to watch
                    if toWatchShows.contains(showEpisodeCalendarItem.show) {
                        // check if show premiere
                        if toWatchShowPremiere && showEpisodeCalendarItem.episode.number == 1 && showEpisodeCalendarItem.episode.season == 1 {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "Series Premiere", subtitle: "")
                            requests.append(request)
                            continue
                        }
                        // check if season premiere
                        if toWatchSeasonPremiere && showEpisodeCalendarItem.episode.number == 1 && showEpisodeCalendarItem.episode.season > 1 {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "Season Premiere", subtitle: "")
                            requests.append(request)
                            continue
                        }
                        // check if user wants each episode
                        if toWatchEpisodeRelease {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "New Episode", subtitle: "")
                            requests.append(request)
                            continue
                        }
                    }
                    // is in watchlist
                    if showEpisodeCalendarItem.show.isWatchlisted {
                        // check if show premiere
                        if watchlistShowPremiere && showEpisodeCalendarItem.episode.number == 1 && showEpisodeCalendarItem.episode.season == 1 {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "Series Premiere", subtitle: "Watchlist")
                            requests.append(request)
                            continue
                        }
                        // check if season premiere
                        if watchlistSeasonPremiere && showEpisodeCalendarItem.episode.number == 1 && showEpisodeCalendarItem.episode.season > 1 {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "Season Premiere", subtitle: "Watchlist")
                            requests.append(request)
                            continue
                        }
                        // check if user wants each episode
                        if watchlistEpisodeRelease {
                            let request = self.scheduleNotification(for: showEpisodeCalendarItem, with: "New Episode", subtitle: "Watchlist")
                            requests.append(request)
                            continue
                        }
                    }
                }

                if groupEpisodes {
                    var groupedRequests = [UNNotificationRequest]()
                    for request in requests {
                        try Task.checkCancellation()
                        let filteredAndSortedRequests = requests.filter { otherRequest -> Bool in
                            return otherRequest.content.threadIdentifier == request.content.threadIdentifier && (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() == (otherRequest.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate()
                        }.sorted { firstRequest, secondRequest -> Bool in
                            return firstRequest.content.body < secondRequest.content.body
                        }

                        if filteredAndSortedRequests.count > 1 && request == filteredAndSortedRequests.first! {
                            for showEpisodeCalendarItem in showEpisodeCalendarItems where request.identifier == identifier(for: showEpisodeCalendarItem) {
                                let request = self.scheduleGroupNotification(for: showEpisodeCalendarItem, with: "New Episodes", subtitle: request.content.subtitle, and: filteredAndSortedRequests.count)
                                groupedRequests.append(request)
                                break
                            }
                        } else if filteredAndSortedRequests.count == 1 {
                            groupedRequests.append(request)
                        } else {
                            // do nothing, it's not the first episode of a group and it's not a single episode
                        }
                    }
                    requests = groupedRequests
                }

                // Clean then add
                let notificationCenter = UNUserNotificationCenter.current()
                let pendingNotifications = await notificationCenter.pendingNotificationRequests()
                try Task.checkCancellation()
                var identifiersToRemove = [String]()
                for pendingNotification in pendingNotifications where requests.contains(where: {  $0.identifier == pendingNotification.identifier }) == false && pendingNotification.isEpisodeNotification {
                    print("Removing notification: \(pendingNotification.identifier) - \(pendingNotification.content.title) - \(pendingNotification.content.body)")
                    identifiersToRemove.append(pendingNotification.identifier)
                }

                notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)

                for request in requests {
                    try Task.checkCancellation()
                    do {
                        try await notificationCenter.add(request)
                        print("Adding notification: \(request.identifier) - \(request.content.title) - \(request.content.body)")
                    } catch {
                        print("notificationCenter.add error: \(error)")
                    }
                }
                onEpisodesNotificationsChangedTransmitter.broadcast(requests)
            } catch is CancellationError {
                print("EpisodeNotificationsManager: scheduleNotififcations() cancelled for a new one.")
            } catch {
                print("Coudn't fetch calendar, don't do nothing: \(error)")
            }
        }
    }

    private func beginNotificationRebuildBackgroundTask() -> UIBackgroundTaskIdentifier? {
        return UIApplication.shared.beginBackgroundTask(withName: "EpisodeNotificationRebuild") { [weak self] in
            guard let self = self else { return }
            self.rebuildNotificationsTask?.cancel()
        }
    }

    private func endNotificationRebuildBackgroundTask(_ taskIdentifier: UIBackgroundTaskIdentifier?) {
        guard let taskIdentifier = taskIdentifier else { return }
        let identifier = UIBackgroundTaskIdentifier(rawValue: taskIdentifier.rawValue)
        if identifier != .invalid {
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }

    private func scheduleNotification(for showEpisodeItem: ShowEpisodeCalendarItem, with title: String, subtitle: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = "A new episode of \(showEpisodeItem.show.title) \(showEpisodeItem.episode.localizedEpisodeNumber) is airing now" + (showEpisodeItem.show.network == nil ? "." : " on \(showEpisodeItem.show.network!)")
        content.threadIdentifier = "\(showEpisodeItem.show.identifiers.trakt!)"
        content.userInfo = ["link": "ripl://shows/\(showEpisodeItem.show.identifiers.trakt!)/seasons/\(showEpisodeItem.episode.season)/episodes/\(showEpisodeItem.episode.number)"]

        let triggerDate = showEpisodeItem.firstAired

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                                     from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let uuidString = identifier(for: showEpisodeItem)
        return UNNotificationRequest(identifier: uuidString,
                                        content: content,
                                        trigger: trigger)
    }

    private func scheduleGroupNotification(for showEpisodeItem: ShowEpisodeCalendarItem, with title: String, subtitle: String, and groupCount: Int) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = "\(groupCount) new episodes of \(showEpisodeItem.show.title) \(showEpisodeItem.episode.localizedSeasonNumber) are now available" + (showEpisodeItem.show.network == nil ? "." : " on \(showEpisodeItem.show.network!)")
        content.threadIdentifier = "\(showEpisodeItem.show.identifiers.trakt!)"
        content.userInfo = ["link": "ripl://shows/\(showEpisodeItem.show.identifiers.trakt!)/seasons/\(showEpisodeItem.episode.season)/episodes/\(showEpisodeItem.episode.number)"]

        let triggerDate = showEpisodeItem.firstAired
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                                     from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let uuidString = identifier(for: showEpisodeItem)
        return UNNotificationRequest(identifier: uuidString,
                                        content: content,
                                        trigger: trigger)
    }

    private func identifier(for showEpisodeItem: ShowEpisodeCalendarItem) -> String {
        return uuidPrefix + "\(showEpisodeItem.episode.identifiers.trakt!)"
    }
}

extension UNNotificationRequest {
    var isEpisodeNotification: Bool {
        return self.identifier.hasPrefix(EpisodeNotificationsManager.shared.uuidPrefix)
    }
}
