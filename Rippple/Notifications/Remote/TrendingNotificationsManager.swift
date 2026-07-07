//
//  TrendingNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 20/11/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation
import Receiver

final class TrendingNotificationsManager {
    static let shared = TrendingNotificationsManager()

    private let disposeBag = DisposeBag()
    private lazy var debouncedSyncRemoteNotificationTopics = Debouncer(delay: 1.0) { [weak self] in
        guard let self = self else { return }
        self.syncRemoteNotificationTopics()
    }

    private var endpointARN: String? {
        return UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
    }

    /// Settings
    var trendingMovies: Bool {
        didSet {
            UserDefaults.standard.set(trendingMovies, forKey: "TrendingNotificationsManager.trendingMovies")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    var trendingShows: Bool {
        didSet {
            UserDefaults.standard.set(trendingShows, forKey: "TrendingNotificationsManager.trendingShows")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    // ----

    private init() {
        trendingShows = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingShows")
        trendingMovies = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingMovies")
    }

    func setup() {
        debouncedSyncRemoteNotificationTopics.call()

        onSettingsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedSyncRemoteNotificationTopics.call()
        }.disposed(by: disposeBag)

        remoteNotificationsEndpointUpdatedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedSyncRemoteNotificationTopics.call()
        }.disposed(by: disposeBag)
    }

    private func syncRemoteNotificationTopics() {
        guard let endpointARN = endpointARN else { return }
        let canSubscribe = !SessionManager.shared.isLoggedOut

        syncSubscription(endpointARN: endpointARN, to: .trendingShows, isSubscribed: canSubscribe && trendingShows)
        syncSubscription(endpointARN: endpointARN, to: .trendingMovies, isSubscribed: canSubscribe && trendingMovies)
    }

    private func syncSubscription(endpointARN: String, to topic: RemoteNotificationTopic, isSubscribed: Bool) {
        guard topic.topicARN != nil else { return }

        Task {
            do {
                let result = try await RemoteNotificationsManager.shared.syncSubscription(endpointARN: endpointARN, to: topic, isSubscribed: isSubscribed)
                switch result {
                case .skipped:
                    break
                case .subscribed:
                    print("🎉 subscribed to topic \(topic)")
                case .unsubscribed:
                    print("🎉 unsubscribed from topic \(topic)")
                }
            } catch {
                print("💀 Remote notifications topic sync Error: \(error)")
            }
        }
    }
}
