//
//  EpisodeNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit
import UserNotifications

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

    var reduceBasedOnProgress: Bool {
        didSet {
            UserDefaults.standard.set(reduceBasedOnProgress, forKey: "EpisodeNotificationsManager.reduceBasedOnProgress")
            UserDefaults.standard.synchronize()
        }
    }

    var postponeNighttimeNotifications: Bool {
        didSet {
            UserDefaults.standard.set(postponeNighttimeNotifications, forKey: "EpisodeNotificationsManager.postponeNighttimeNotifications")
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

    var watchlistShowFinale: Bool {
        didSet {
            UserDefaults.standard.set(watchlistShowFinale, forKey: "EpisodeNotificationsManager.watchlistShowFinale")
            UserDefaults.standard.synchronize()
        }
    }

    var watchlistSeasonFinale: Bool {
        didSet {
            UserDefaults.standard.set(watchlistSeasonFinale, forKey: "EpisodeNotificationsManager.watchlistSeasonFinale")
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

    var toWatchShowFinale: Bool {
        didSet {
            UserDefaults.standard.set(toWatchShowFinale, forKey: "EpisodeNotificationsManager.toWatchShowFinale")
            UserDefaults.standard.synchronize()
        }
    }

    var toWatchSeasonFinale: Bool {
        didSet {
            UserDefaults.standard.set(toWatchSeasonFinale, forKey: "EpisodeNotificationsManager.toWatchSeasonFinale")
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
        reduceBasedOnProgress = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.reduceBasedOnProgress")
        postponeNighttimeNotifications = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.postponeNighttimeNotifications")
        watchlistShowPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistShowPremiere")
        watchlistSeasonPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistSeasonPremiere")
        watchlistShowFinale = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistShowFinale")
        watchlistSeasonFinale = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistSeasonFinale")
        watchlistEpisodeRelease = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.watchlistEpisodeRelease")
        toWatchShowPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchShowPremiere")
        toWatchSeasonPremiere = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchSeasonPremiere")
        toWatchShowFinale = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchShowFinale")
        toWatchSeasonFinale = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchSeasonFinale")
        toWatchEpisodeRelease = UserDefaults.standard.bool(forKey: "EpisodeNotificationsManager.toWatchEpisodeRelease")
    }

    fileprivate let uuidPrefix = "episodeRelease"

    private func rebuildNotifications() {
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

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.rebuildNotificationsTask?.cancel()
            self.cachedCalendarItems = nil
            self.lastCalendarFetchDate = nil
            onEpisodesNotificationsChangedTransmitter.broadcast([])
        }.disposed(by: disposeBag)

        onShowsToWatchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.call()
        }.disposed(by: disposeBag)

        onShowsWatchlistedChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRebuildNotifications.call()
        }.disposed(by: disposeBag)

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

        cachedCalendarItems = result
        lastCalendarFetchDate = Date()

        return result
    }

    private func scheduleNotifications() {
        rebuildNotificationsTask = Task { [weak self] in
            guard let self = self else { return }

            let backgroundTaskIdentifier = beginNotificationRebuildBackgroundTask()
            defer {
                endNotificationRebuildBackgroundTask(backgroundTaskIdentifier)
            }

            do {
                let showEpisodeCalendarItems = try await fetchCalendar()
                try Task.checkCancellation()

                var requests = [UNNotificationRequest]()
                var showBehindStatus = [Int64: Bool]()
                let reduceBasedOnProgress = self.reduceBasedOnProgress
                let groupEpisodes = self.groupEpisodes
                let postponeNighttimeNotifications = self.postponeNighttimeNotifications

                for showEpisodeCalendarItem in showEpisodeCalendarItems where showEpisodeCalendarItem.episode.season != 0 {
                    try Task.checkCancellation()
                    // Never schedule local episode notifications for dropped or hidden shows.
                    if shouldExcludeFromEpisodeNotifications(showEpisodeCalendarItem.show) {
                        continue
                    }

                    let event = EpisodeNotificationEvent(episode: showEpisodeCalendarItem.episode)
                    guard let source = notificationSource(for: showEpisodeCalendarItem.show) else { continue }
                    guard shouldScheduleNotification(for: event, source: source) else { continue }

                    if reduceBasedOnProgress && event.isStandardEpisode {
                        let isBehind = await self.isBehind(show: showEpisodeCalendarItem.show, showBehindStatus: &showBehindStatus)
                        try Task.checkCancellation()
                        if isBehind && shouldKeepStandardEpisodeInGroupedBulk(for: showEpisodeCalendarItem,
                                                                              in: showEpisodeCalendarItems,
                                                                              source: source,
                                                                              groupEpisodes: groupEpisodes) == false {
                            continue
                        }
                    }

                    if let request = self.scheduleNotification(for: showEpisodeCalendarItem,
                                                               event: event,
                                                               postponeNighttimeNotifications: postponeNighttimeNotifications) {
                        requests.append(request)
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
                                if let request = self.scheduleGroupNotification(for: showEpisodeCalendarItem,
                                                                                with: "New Episodes",
                                                                                and: filteredAndSortedRequests.count,
                                                                                postponeNighttimeNotifications: postponeNighttimeNotifications) {
                                    groupedRequests.append(request)
                                }
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
                for pendingNotification in pendingNotifications where requests.contains(where: { $0.identifier == pendingNotification.identifier }) == false && pendingNotification.isEpisodeNotification {
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

    private func notificationSource(for show: Show) -> EpisodeNotificationSource? {
        if show.isInToWatch {
            return .toWatch
        } else if show.isWatchlisted {
            return .watchlist
        } else {
            return nil
        }
    }

    private func shouldScheduleNotification(for event: EpisodeNotificationEvent, source: EpisodeNotificationSource) -> Bool {
        switch source {
        case .toWatch:
            return (toWatchShowPremiere && event.isSeriesPremiere) ||
                (toWatchSeasonPremiere && event.isSeasonPremiere) ||
                (toWatchShowFinale && event.isSeriesFinale) ||
                (toWatchSeasonFinale && event.isSeasonFinale) ||
                toWatchEpisodeRelease
        case .watchlist:
            return (watchlistShowPremiere && event.isSeriesPremiere) ||
                (watchlistSeasonPremiere && event.isSeasonPremiere) ||
                (watchlistShowFinale && event.isSeriesFinale) ||
                (watchlistSeasonFinale && event.isSeasonFinale) ||
                watchlistEpisodeRelease
        }
    }

    private func shouldKeepStandardEpisodeInGroupedBulk(for showEpisodeItem: ShowEpisodeCalendarItem,
                                                        in showEpisodeItems: [ShowEpisodeCalendarItem],
                                                        source: EpisodeNotificationSource,
                                                        groupEpisodes: Bool) -> Bool {
        guard groupEpisodes else { return false }
        guard let showId = showEpisodeItem.show.identifiers.trakt else { return false }

        let releaseDate = showEpisodeItem.firstAired
        var eligibleEpisodeCount = 0
        var containsPremiereOrFinale = false

        for otherShowEpisodeItem in showEpisodeItems where otherShowEpisodeItem.episode.season != 0 {
            guard otherShowEpisodeItem.show.identifiers.trakt == showId else { continue }
            guard shouldExcludeFromEpisodeNotifications(otherShowEpisodeItem.show) == false else { continue }
            guard otherShowEpisodeItem.firstAired == releaseDate else { continue }

            let event = EpisodeNotificationEvent(episode: otherShowEpisodeItem.episode)
            guard shouldScheduleNotification(for: event, source: source) else { continue }

            eligibleEpisodeCount += 1
            if event.isPremiereOrFinale {
                containsPremiereOrFinale = true
            }
        }

        return eligibleEpisodeCount > 1 && containsPremiereOrFinale
    }

    private func shouldExcludeFromEpisodeNotifications(_ show: Show) -> Bool {
        return show.isDropped || show.isHiddenFromProgress || show.isHiddenFromCalendar
    }

    private func isBehind(show: Show, showBehindStatus: inout [Int64: Bool]) async -> Bool {
        guard let showId = show.identifiers.trakt else { return false }

        if let isBehind = showBehindStatus[showId] { return isBehind }

        guard let progress = await show.mediaModel.progress() else {
            showBehindStatus[showId] = false
            return false
        }

        let isBehind = progress.behind > 0
        showBehindStatus[showId] = isBehind
        return isBehind
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

    private func scheduleNotification(for showEpisodeItem: ShowEpisodeCalendarItem,
                                      event: EpisodeNotificationEvent,
                                      postponeNighttimeNotifications: Bool) -> UNNotificationRequest? {
        let delivery = EpisodeNotificationDelivery(firstAired: showEpisodeItem.firstAired,
                                                   postponeNighttimeNotifications: postponeNighttimeNotifications)
        let triggerDate = notificationTriggerDate(for: showEpisodeItem, delivery: delivery)
        if triggerDate <= .now { return nil }

        let content = UNMutableNotificationContent()
        content.title = event.title
        content.body = "\(showEpisodeItem.show.title) \(showEpisodeItem.episode.localizedEpisodeNumber) \(delivery.bodyText)" + networkSuffix(for: showEpisodeItem.show)
        content.threadIdentifier = "\(showEpisodeItem.show.identifiers.trakt!)"
        content.userInfo = ["link": "ripl://shows/\(showEpisodeItem.show.identifiers.trakt!)/seasons/\(showEpisodeItem.episode.season)/episodes/\(showEpisodeItem.episode.number)",
                            "reduce_based_on_progress": reduceBasedOnProgress,
                            "postpone_nighttime_notifications": postponeNighttimeNotifications,
                            "notification_delivery": delivery.rawValue,
                            "episode_event": event.rawValue]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let uuidString = identifier(for: showEpisodeItem)
        return UNNotificationRequest(identifier: uuidString,
                                     content: content,
                                     trigger: trigger)
    }

    private func scheduleGroupNotification(for showEpisodeItem: ShowEpisodeCalendarItem,
                                           with title: String,
                                           and groupCount: Int,
                                           postponeNighttimeNotifications: Bool) -> UNNotificationRequest? {
        let delivery = EpisodeNotificationDelivery(firstAired: showEpisodeItem.firstAired,
                                                   postponeNighttimeNotifications: postponeNighttimeNotifications)
        let triggerDate = notificationTriggerDate(for: showEpisodeItem, delivery: delivery)
        if triggerDate <= .now { return nil }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "\(groupCount) new episodes of \(showEpisodeItem.show.title) \(showEpisodeItem.episode.localizedSeasonNumber) \(delivery.groupedBodyText)" + networkSuffix(for: showEpisodeItem.show)
        content.threadIdentifier = "\(showEpisodeItem.show.identifiers.trakt!)"
        content.userInfo = ["link": "ripl://shows/\(showEpisodeItem.show.identifiers.trakt!)/seasons/\(showEpisodeItem.episode.season)/episodes/\(showEpisodeItem.episode.number)",
                            "reduce_based_on_progress": reduceBasedOnProgress,
                            "postpone_nighttime_notifications": postponeNighttimeNotifications,
                            "notification_delivery": delivery.rawValue,
                            "episode_event": EpisodeNotificationEvent(episode: showEpisodeItem.episode).rawValue]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second],
                                                         from: triggerDate)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let uuidString = identifier(for: showEpisodeItem)
        return UNNotificationRequest(identifier: uuidString,
                                     content: content,
                                     trigger: trigger)
    }

    private func networkSuffix(for show: Show) -> String {
        guard let network = show.network else { return "." }
        return " on \(network)."
    }

    private func notificationTriggerDate(for showEpisodeItem: ShowEpisodeCalendarItem, delivery: EpisodeNotificationDelivery) -> Date {
        return delivery.triggerDate(for: showEpisodeItem.firstAired)
    }

    private func identifier(for showEpisodeItem: ShowEpisodeCalendarItem) -> String {
        return uuidPrefix + "\(showEpisodeItem.episode.identifiers.trakt!)"
    }
}

private enum EpisodeNotificationSource {
    case toWatch
    case watchlist
}

private enum EpisodeNotificationEvent: String {
    case newEpisode = "new_episode"
    case seriesPremiere = "series_premiere"
    case seasonPremiere = "season_premiere"
    case midSeasonPremiere = "mid_season_premiere"
    case midSeasonFinale = "mid_season_finale"
    case seasonFinale = "season_finale"
    case seriesFinale = "series_finale"

    init(episode: Episode) {
        switch episode.episodeType {
        case .seriesPremiere?:
            self = .seriesPremiere
        case .seasonPremiere?:
            self = .seasonPremiere
        case .midSeasonPremiere?:
            self = .midSeasonPremiere
        case .midSeasonFinale?:
            self = .midSeasonFinale
        case .seasonFinale?:
            self = .seasonFinale
        case .seriesFinale?:
            self = .seriesFinale
        case .standard?, .unknown?, nil:
            if episode.season == 1, episode.number == 1 {
                self = .seriesPremiere
            } else if episode.season > 1, episode.number == 1 {
                self = .seasonPremiere
            } else {
                self = .newEpisode
            }
        }
    }

    var title: String {
        switch self {
        case .newEpisode:
            return "New Episode"
        case .seriesPremiere:
            return "Series Premiere"
        case .seasonPremiere:
            return "Season Premiere"
        case .midSeasonPremiere:
            return "Mid Season Premiere"
        case .midSeasonFinale:
            return "Mid Season Finale"
        case .seasonFinale:
            return "Season Finale"
        case .seriesFinale:
            return "Series Finale"
        }
    }

    var isSeriesPremiere: Bool {
        return self == .seriesPremiere
    }

    var isSeasonPremiere: Bool {
        return self == .seasonPremiere
    }

    var isSeriesFinale: Bool {
        return self == .seriesFinale
    }

    var isSeasonFinale: Bool {
        return self == .seasonFinale || self == .midSeasonFinale
    }

    var isStandardEpisode: Bool {
        return self == .newEpisode
    }

    var isPremiereOrFinale: Bool {
        return isStandardEpisode == false
    }
}

private enum EpisodeNotificationDelivery: String {
    case realtime
    case postponed

    init(firstAired: Date, postponeNighttimeNotifications: Bool) {
        guard postponeNighttimeNotifications else {
            self = .realtime
            return
        }

        let hour = Calendar.current.component(.hour, from: firstAired)
        self = (0..<6).contains(hour) ? .postponed : .realtime
    }

    var bodyText: String {
        switch self {
        case .realtime:
            return "is airing now"
        case .postponed:
            return "was released overnight"
        }
    }

    var groupedBodyText: String {
        switch self {
        case .realtime:
            return "are now available"
        case .postponed:
            return "were released overnight"
        }
    }

    func triggerDate(for firstAired: Date) -> Date {
        switch self {
        case .realtime:
            return firstAired
        case .postponed:
            return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: firstAired) ?? firstAired
        }
    }
}

extension UNNotificationRequest {
    var isEpisodeNotification: Bool {
        return identifier.hasPrefix(EpisodeNotificationsManager.shared.uuidPrefix)
    }
}
