//
//  ManualRemoteNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/04/2024.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

final class ManualRemoteNotificationsManager {
    static let shared = ManualRemoteNotificationsManager()

    private let disposeBag = DisposeBag()
    private lazy var debouncedSyncRemoteNotificationTopics = Debouncer(delay: 1.0) { [weak self] in
        guard let self = self else { return }
        self.syncRemoteNotificationTopics()
    }

    private var endpointARN: String? {
        return UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
    }

    /// Settings
    var appUpdate: Bool {
        didSet {
            UserDefaults.standard.set(appUpdate, forKey: "ManualRemoteNotificationsManager.appUpdate")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    var blogPost: Bool {
        didSet {
            UserDefaults.standard.set(blogPost, forKey: "ManualRemoteNotificationsManager.blogPost")
            UserDefaults.standard.synchronize()
            syncRemoteNotificationTopics()
        }
    }

    // ----

    private init() {
        appUpdate = UserDefaults.standard.bool(forKey: "ManualRemoteNotificationsManager.appUpdate")
        blogPost = UserDefaults.standard.bool(forKey: "ManualRemoteNotificationsManager.blogPost")
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

        syncSubscription(endpointARN: endpointARN, to: .manualBlogPost, isSubscribed: canSubscribe && blogPost)
        syncSubscription(endpointARN: endpointARN, to: .manualUpdate, isSubscribed: canSubscribe && appUpdate)

        if canSubscribe, UserManager.shared.currentUser?.slug == "kcador" {
            syncSubscription(endpointARN: endpointARN, to: .test, isSubscribed: true)
        }
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
