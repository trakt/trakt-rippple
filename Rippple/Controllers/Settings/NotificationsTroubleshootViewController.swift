//
//  NotificationsTroubleshootViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Receiver
import UIKit
import UserNotifications

final class NotificationsTroubleshootViewController: UITableViewController {
    private let disposeBag = DisposeBag()
    private let testNotificationIdentifier = "TestNotification"
    private var remoteNotificationsPushStatus: RemoteNotificationsPushStatus = .waiting
    private var remoteNotificationsPushInProgress = false
    private var remoteNotificationsPushCompleted = false
    private var shouldSendTestNotificationAfterRemotePush = false
    private let pushAPIActivityIndicator = UIActivityIndicatorView(style: .medium)

    @IBOutlet var appSettings: UIImageView!
    @IBOutlet var deviceSettings: UIImageView!
    @IBOutlet var tokenRegistration: UIImageView!
    @IBOutlet var testNotification: UIImageView!
    @IBOutlet var pushAPI: UIImageView!
    @IBOutlet var pushAPICell: UITableViewCell!
    @IBOutlet var remoteNotificationsDebugLabel: UILabel!

    private var pushAPIStatusLabel: UILabel? {
        return pushAPICell.contentView.subviews.compactMap { $0 as? UILabel }.first
    }

    private var notificationsAllDisabled: Bool {
        return MovieNotificationsManager.shared.toWatchMovieRelease == false &&
            MovieNotificationsManager.shared.watchlistMovieRelease == false &&
            EpisodeNotificationsManager.shared.watchlistShowPremiere == false &&
            EpisodeNotificationsManager.shared.watchlistEpisodeRelease == false &&
            EpisodeNotificationsManager.shared.watchlistSeasonPremiere == false &&
            EpisodeNotificationsManager.shared.toWatchShowPremiere == false &&
            EpisodeNotificationsManager.shared.toWatchEpisodeRelease == false &&
            EpisodeNotificationsManager.shared.toWatchSeasonPremiere == false &&
            ActivityNotificationsManager.shared.activityNewFollower == false &&
            ActivityNotificationsManager.shared.commentNewLikes == false &&
            ActivityNotificationsManager.shared.commentNewMention == false &&
            ActivityNotificationsManager.shared.commentNewReply == false
    }

    private var notificationSettings: UNNotificationSettings? {
        didSet {
            DispatchQueue.main.async {
                guard let notificationSettings = self.notificationSettings else { return }
                switch notificationSettings.authorizationStatus {
                case .notDetermined:
                    self.deviceSettings.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.deviceSettings.tintColor = .systemOrange
                case .denied:
                    self.deviceSettings.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.deviceSettings.tintColor = .systemRed
                    self.tokenRegistration.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.tokenRegistration.tintColor = .systemGray
                case .authorized:
                    self.deviceSettings.image = UIImage(systemName: "checkmark.circle.fill")
                    self.deviceSettings.tintColor = .systemGreen
                    UIApplication.shared.registerForRemoteNotifications()
                case .provisional:
                    self.deviceSettings.image = UIImage(systemName: "checkmark.circle.fill")
                    self.deviceSettings.tintColor = .systemGreen
                    UIApplication.shared.registerForRemoteNotifications()
                case .ephemeral:
                    self.deviceSettings.image = UIImage(systemName: "checkmark.circle.fill")
                    self.deviceSettings.tintColor = .systemGreen
                    UIApplication.shared.registerForRemoteNotifications()
                @unknown default:
                    self.deviceSettings.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.deviceSettings.tintColor = .systemOrange
                }
            }
        }
    }

    private var pushTokenError: Error? {
        didSet {
            DispatchQueue.main.async {
                if self.pushTokenError == nil {
                    self.tokenRegistration.image = UIImage(systemName: "checkmark.circle.fill")
                    self.tokenRegistration.tintColor = .systemGreen
                } else {
                    self.tokenRegistration.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.tokenRegistration.tintColor = .systemRed
                }
            }
        }
    }

    private var testNotificationError: Error? {
        didSet {
            DispatchQueue.main.async {
                if self.testNotificationError != nil {
                    self.testNotification.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.testNotification.tintColor = .systemRed
                }
            }
        }
    }

    private var testNotificationTimer: Timer?

    private var testNotificationReceived: Bool? {
        didSet {
            DispatchQueue.main.async {
                guard let testNotificationReceived = self.testNotificationReceived else {
                    self.testNotification.image = UIImage(systemName: "circle")
                    self.testNotification.tintColor = .systemGray
                    return
                }
                if testNotificationReceived == true {
                    self.testNotification.image = UIImage(systemName: "checkmark.circle.fill")
                    self.testNotification.tintColor = .systemGreen
                } else {
                    self.testNotification.image = UIImage(systemName: "exclamationmark.octagon.fill")
                    self.testNotification.tintColor = .systemRed
                }
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive:
                self.pushTokenError = nil
                self.tokenRegistration.image = UIImage(systemName: "circle")
                self.tokenRegistration.tintColor = .systemGray

                self.testNotificationTimer?.invalidate()
                self.testNotificationTimer = nil
                self.testNotificationReceived = nil
                self.scheduleTestNotificationAfterRemotePushFinishes()

                UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                    guard let self = self else { return }
                    self.notificationSettings = settings
                }
            case .didEnterBackground:
                break
            }
            self.refreshRemoteNotificationsDebugCell()
        }.disposed(by: disposeBag)

        pushTokenReceiveAndUpdatedReceiver.listen { [weak self] error in
            guard let self = self else { return }
            self.pushTokenError = error
            self.refreshRemoteNotificationsDebugCell()
            if error == nil {
                self.forcePushRemoteNotificationsDataIfNeeded()
            }
        }.disposed(by: disposeBag)

        remoteNotificationsEndpointUpdatedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.forcePushRemoteNotificationsDataIfNeeded()
        }.disposed(by: disposeBag)

        testPushReceiver.listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.testNotificationTimer?.invalidate()
                self.testNotificationTimer = nil
                self.testNotificationReceived = true
                self.refreshRemoteNotificationsDebugCell()
            }
        }.disposed(by: disposeBag)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 96
        remoteNotificationsDebugLabel.textColor = .secondaryLabel
        remoteNotificationsDebugLabel.font = .preferredFont(forTextStyle: .footnote)
        remoteNotificationsDebugLabel.adjustsFontForContentSizeCategory = true
        remoteNotificationsDebugLabel.numberOfLines = 0
        remoteNotificationsDebugLabel.lineBreakMode = .byCharWrapping
        remoteNotificationsDebugLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        setupPushAPIActivityIndicator()
        pushAPICell.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                                action: #selector(retryRemoteNotificationsPush)))
        refreshRemoteNotificationsDebugCell()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if onlyOnce {
            appSettings.tintColor = .systemGray
            deviceSettings.tintColor = .systemGray
            tokenRegistration.tintColor = .systemGray
            testNotification.tintColor = .systemGray
            updatePushAPIStatusIcon()
        }
    }

    private var onlyOnce = true

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if notificationsAllDisabled {
            appSettings.image = UIImage(systemName: "exclamationmark.octagon.fill")
            appSettings.tintColor = .systemRed
        } else {
            appSettings.image = UIImage(systemName: "checkmark.circle.fill")
            appSettings.tintColor = .systemGreen
        }

        if onlyOnce {
            onlyOnce = false

            UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                guard let self = self else { return }
                self.notificationSettings = settings
            }

            forcePushRemoteNotificationsDataIfNeeded(sendTestNotificationWhenFinished: true)
        }
    }

    private func forcePushRemoteNotificationsDataIfNeeded(sendTestNotificationWhenFinished: Bool = false) {
        DispatchQueue.main.async {
            guard self.isViewLoaded, self.view.window != nil else { return }
            if sendTestNotificationWhenFinished {
                self.shouldSendTestNotificationAfterRemotePush = true
            }
            self.forcePushRemoteNotificationsData()
        }
    }

    private func forcePushRemoteNotificationsData() {
        guard remoteNotificationsPushInProgress == false else { return }
        guard remoteNotificationsPushCompleted == false else {
            sendPendingTestNotificationAfterRemotePushIfNeeded()
            return
        }

        guard RemoteNotificationsManager.shared.isConfigured else {
            finishRemoteNotificationsPush(with: .failure("Remote notifications API is not configured for this build."),
                                          completed: false)
            return
        }

        guard let endpointARN = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS") else {
            finishRemoteNotificationsPush(with: .failure("Missing SNS endpoint ARN. Waiting for endpoint registration to finish."),
                                          completed: false)
            return
        }

        guard UserDefaults.standard.string(forKey: "Rippple.pushToken") != nil else {
            finishRemoteNotificationsPush(with: .failure("Missing push token. Waiting for token registration to finish."),
                                          completed: false)
            return
        }

        guard let traktSlug = UserManager.shared.currentUser?.slug else {
            finishRemoteNotificationsPush(with: .failure("There is no signed-in Trakt user to push remote notification settings for."),
                                          completed: false)
            return
        }

        let customUserData = endpointCustomUserData()
        let pushInformation = PushInformationModel(traktId: traktSlug,
                                                   enpointARN: endpointARN,
                                                   environement: endpointEnvironment(),
                                                   premium: PurchaseManager.shared.purchased ? "VIP" : "non-VIP",
                                                   commentNewLikes: ActivityNotificationsManager.shared.commentNewLikes,
                                                   commentNewReply: ActivityNotificationsManager.shared.commentNewReply,
                                                   commentNewMention: ActivityNotificationsManager.shared.commentNewMention,
                                                   activityNewFollower: ActivityNotificationsManager.shared.activityNewFollower)
        let topicStates = remoteNotificationTopicStates()

        remoteNotificationsPushInProgress = true
        updateRemoteNotificationsPushStatus(.running)

        Task { [weak self] in
            guard let self = self else { return }

            do {
                try await RemoteNotificationsManager.shared.updateEndpoint(endpointARN: endpointARN,
                                                                           customUserData: customUserData)
                try await RemoteNotificationsManager.shared.savePushInformation(pushInformation, force: true)

                var pushedTopicCount = 0
                var skippedTopicCount = 0
                for topicState in topicStates {
                    let result = try await RemoteNotificationsManager.shared.syncSubscription(endpointARN: endpointARN,
                                                                                              to: topicState.topic,
                                                                                              isSubscribed: topicState.isSubscribed,
                                                                                              force: true)
                    switch result {
                    case .skipped:
                        skippedTopicCount += 1
                    case .subscribed:
                        pushedTopicCount += 1
                    case .unsubscribed:
                        pushedTopicCount += 1
                    }
                }

                let skippedText = skippedTopicCount > 0 ? " \(skippedTopicCount) topic(s) were skipped because they are not configured." : ""
                let message = "Endpoint, push information, and \(pushedTopicCount) topic subscription update(s) were pushed.\(skippedText)"
                await MainActor.run {
                    self.finishRemoteNotificationsPush(with: .success(message),
                                                       completed: true)
                }
            } catch {
                await MainActor.run {
                    self.finishRemoteNotificationsPush(with: .failure(error.localizedDescription),
                                                       completed: false)
                }
            }
        }
    }

    private func finishRemoteNotificationsPush(with status: RemoteNotificationsPushStatus, completed: Bool) {
        remoteNotificationsPushInProgress = false
        if completed {
            remoteNotificationsPushCompleted = true
        }
        updateRemoteNotificationsPushStatus(status)
        sendPendingTestNotificationAfterRemotePushIfNeeded()
    }

    private func scheduleTestNotificationAfterRemotePushFinishes() {
        guard remoteNotificationsPushInProgress else {
            scheduleTestNotification()
            return
        }
        shouldSendTestNotificationAfterRemotePush = true
    }

    private func sendPendingTestNotificationAfterRemotePushIfNeeded() {
        guard shouldSendTestNotificationAfterRemotePush else { return }
        shouldSendTestNotificationAfterRemotePush = false
        scheduleTestNotification()
    }

    private func updateRemoteNotificationsPushStatus(_ status: RemoteNotificationsPushStatus) {
        remoteNotificationsPushStatus = status
        updatePushAPIStatusIcon()
        refreshRemoteNotificationsDebugCell()
    }

    @objc private func retryRemoteNotificationsPush() {
        guard case .failure = remoteNotificationsPushStatus else { return }
        remoteNotificationsPushCompleted = false
        forcePushRemoteNotificationsData()
    }

    private func updatePushAPIStatusIcon() {
        DispatchQueue.main.async {
            guard self.isViewLoaded else { return }
            switch self.remoteNotificationsPushStatus {
            case .waiting:
                self.pushAPIActivityIndicator.stopAnimating()
                self.pushAPI.isHidden = false
                self.pushAPI.image = UIImage(systemName: "circle")
                self.pushAPI.tintColor = .systemGray
            case .running:
                self.pushAPIActivityIndicator.startAnimating()
                self.pushAPI.isHidden = false
                self.pushAPI.image = UIImage(systemName: "circle")
                self.pushAPI.tintColor = .systemGray
            case .success:
                self.pushAPIActivityIndicator.stopAnimating()
                self.pushAPI.isHidden = false
                self.pushAPI.image = UIImage(systemName: "checkmark.circle.fill")
                self.pushAPI.tintColor = .systemGreen
            case .failure:
                self.pushAPIActivityIndicator.stopAnimating()
                self.pushAPI.isHidden = false
                self.pushAPI.image = UIImage(systemName: "arrow.clockwise.circle.fill")
                self.pushAPI.tintColor = .systemOrange
            }
        }
    }

    private func setupPushAPIActivityIndicator() {
        pushAPIActivityIndicator.translatesAutoresizingMaskIntoConstraints = false
        pushAPIActivityIndicator.hidesWhenStopped = true
        pushAPIActivityIndicator.color = .systemGray
        pushAPIActivityIndicator.isUserInteractionEnabled = false

        guard let pushAPIStatusLabel = pushAPIStatusLabel else { return }

        let labelToIconConstraints = pushAPICell.contentView.constraints.filter { constraint in
            let firstView = constraint.firstItem as? UIView
            let secondView = constraint.secondItem as? UIView
            return (firstView === pushAPIStatusLabel && secondView === pushAPI) ||
                (firstView === pushAPI && secondView === pushAPIStatusLabel)
        }
        NSLayoutConstraint.deactivate(labelToIconConstraints)

        pushAPIStatusLabel.setContentHuggingPriority(.required, for: .horizontal)
        pushAPIStatusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        pushAPIActivityIndicator.setContentHuggingPriority(.required, for: .horizontal)
        pushAPIActivityIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        pushAPICell.contentView.addSubview(pushAPIActivityIndicator)
        NSLayoutConstraint.activate([
            pushAPIActivityIndicator.leadingAnchor.constraint(equalTo: pushAPIStatusLabel.trailingAnchor,
                                                              constant: 8),
            pushAPIActivityIndicator.centerYAnchor.constraint(equalTo: pushAPIStatusLabel.centerYAnchor),
            pushAPIActivityIndicator.trailingAnchor.constraint(lessThanOrEqualTo: pushAPI.leadingAnchor,
                                                               constant: -8)
        ])
        pushAPIActivityIndicator.stopAnimating()
    }

    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "👍 You're good to go"
        content.body = "This is what a notification from Rippple will look like. Okay, the next one should be about a comment, a movie, an episode or something like that. But you see the point, right?"

        let request = UNNotificationRequest(identifier: testNotificationIdentifier,
                                            content: content,
                                            trigger: nil)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [testNotificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [testNotificationIdentifier])
        notificationCenter.add(request) { [weak self] error in
            guard let self = self else { return }
            if error != nil {
                self.testNotificationError = error
            } else {
                DispatchQueue.main.async {
                    guard self.testNotificationReceived != true else { return }
                    self.testNotificationTimer?.invalidate()
                    self.testNotificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.validateTestNotificationDelivery()
                    }
                }
            }
        }
    }

    private func validateTestNotificationDelivery() {
        let notificationIdentifier = testNotificationIdentifier
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] deliveredNotifications in
            let wasDelivered = deliveredNotifications.contains { $0.request.identifier == notificationIdentifier }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.testNotificationTimer?.invalidate()
                self.testNotificationTimer = nil
                self.testNotificationReceived = wasDelivered
            }
        }
    }

    private func refreshRemoteNotificationsDebugCell() {
        DispatchQueue.main.async {
            guard self.isViewLoaded else { return }
            self.remoteNotificationsDebugLabel.text = self.remoteNotificationsDebugText()
            guard self.tableView.window != nil else { return }
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
        }
    }

    private func remoteNotificationsDebugText() -> String {
        let endpoint = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
        let token = UserDefaults.standard.string(forKey: "Rippple.pushToken")
        let topics = remoteNotificationTopicStates().map { $0.topic }
        let cacheStatus = RemoteNotificationsManager.shared.cacheStatus(endpointARN: endpoint, topics: topics)
        let topicCache = cacheStatus.subscriptions
            .filter { $0.topic != .test }
            .map { "\(topicDisplayName($0.topic)): \(subscriptionCacheDescription($0))" }
            .joined(separator: "\n")

        var debugText = [
            "Remote API",
            "Status: \(RemoteNotificationsManager.shared.isConfigured ? "configured" : "not configured")",
            "Automatic push: \(remoteNotificationsPushStatus.debugDescription)",
            "",
            "Endpoint",
            "ARN: \(endpoint ?? "none")",
            "Push token: \(token ?? "none")",
            "",
            "Cache",
            "Push information: \(cacheDescription(cacheStatus.pushInformationCached))"
        ]

        if topicCache.isEmpty {
            debugText.append("Topic subscriptions: none")
        } else {
            debugText.append("")
            debugText.append("Topic subscriptions")
            debugText.append(topicCache)
        }

        return debugText.joined(separator: "\n")
    }

    private func remoteNotificationTopicStates() -> [(topic: RemoteNotificationTopic, isSubscribed: Bool)] {
        let canSubscribe = !SessionManager.shared.isLoggedOut
        var topicStates: [(topic: RemoteNotificationTopic, isSubscribed: Bool)] = [
            (.trendingShows, canSubscribe && TrendingNotificationsManager.shared.trendingShows),
            (.trendingMovies, canSubscribe && TrendingNotificationsManager.shared.trendingMovies),
            (.recommendedShows, canSubscribe && RecommendedNotificationsManager.shared.recommendedShows),
            (.recommendedMovies, canSubscribe && RecommendedNotificationsManager.shared.recommendedMovies),
            (.manualBlogPost, canSubscribe && ManualRemoteNotificationsManager.shared.blogPost),
            (.manualUpdate, canSubscribe && ManualRemoteNotificationsManager.shared.appUpdate)
        ]

        if UserManager.shared.currentUser?.slug == "kcador" {
            topicStates.append((.test, canSubscribe))
        }

        return topicStates
    }

    private func cacheDescription(_ isCached: Bool?) -> String {
        guard let isCached = isCached else { return "not available" }
        return isCached ? "cached" : "missing"
    }

    private func subscriptionCacheDescription(_ cacheStatus: RemoteNotificationsSubscriptionCacheStatus) -> String {
        guard cacheStatus.topicARNConfigured else { return "not configured" }
        guard let isSubscribed = cacheStatus.isSubscribed else { return "missing" }
        return isSubscribed ? "subscribed" : "unsubscribed"
    }

    private func topicDisplayName(_ topic: RemoteNotificationTopic) -> String {
        switch topic {
        case .trendingShows:
            return "Trending shows"
        case .trendingMovies:
            return "Trending movies"
        case .recommendedShows:
            return "Recommended shows"
        case .recommendedMovies:
            return "Recommended movies"
        case .manualBlogPost:
            return "Blog posts"
        case .manualUpdate:
            return "App updates"
        case .test:
            return "Test"
        }
    }

    private func endpointCustomUserData() -> String {
        return "\(UserManager.shared.currentUser?.slug ?? ""), \(endpointEnvironment()), \(Bundle.main.releaseVersionNumber!), \(Bundle.main.buildVersionNumber!)"
    }

    private func endpointEnvironment() -> String {
        return Bundle.main.isSimulator() ? "Simulator" : "App Store"
    }
}

private enum RemoteNotificationsPushStatus {
    case waiting
    case running
    case success(String)
    case failure(String)

    var debugDescription: String {
        switch self {
        case .waiting:
            return "waiting"
        case .running:
            return "running..."
        case .success(let message):
            return "success - \(message)"
        case .failure(let message):
            return "failed - \(message)"
        }
    }
}
