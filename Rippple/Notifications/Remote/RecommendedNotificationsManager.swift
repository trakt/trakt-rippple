//
//  RecommendedNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/02/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Foundation
import Receiver

final class RecommendedNotificationsManager {
    static let shared = RecommendedNotificationsManager()

    private let disposeBag = DisposeBag()
    private lazy var debouncedSyncRemoteNotificationTopics = Debouncer(delay: 1.0) { [weak self] in
        guard let self = self else { return }
        self.syncRemoteNotificationTopics()
    }

    private var endpointARN: String? {
        return UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
    }

    /// Settings
    var recommendedMovies: Bool {
        didSet {
            UserDefaults.standard.set(recommendedMovies, forKey: "RecommendedNotificationsManager.recommendedMovies")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    var recommendedShows: Bool {
        didSet {
            UserDefaults.standard.set(recommendedShows, forKey: "RecommendedNotificationsManager.recommendedShows")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    // ----

    private init() {
        recommendedShows = UserDefaults.standard.bool(forKey: "RecommendedNotificationsManager.recommendedShows")
        recommendedMovies = UserDefaults.standard.bool(forKey: "RecommendedNotificationsManager.recommendedMovies")
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

        syncSubscription(endpointARN: endpointARN, to: .recommendedShows, isSubscribed: canSubscribe && recommendedShows)
        syncSubscription(endpointARN: endpointARN, to: .recommendedMovies, isSubscribed: canSubscribe && recommendedMovies)
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
