//
//  NotificationsTroubleshootViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import Combine
import Receiver
import SwiftUI
import UIKit
import UserNotifications

struct NotificationsTroubleshootView: View {
    @StateObject private var viewModel = NotificationsTroubleshootViewModel()

    var body: some View {
        RipppleForm {
            Section("Status") {
                TroubleshootStatusRow(title: "Rippple Settings",
                                      status: viewModel.appSettingsStatus)
                TroubleshootStatusRow(title: "Device Settings",
                                      status: viewModel.deviceSettingsStatus)
                TroubleshootStatusRow(title: "Token Registration",
                                      status: viewModel.tokenRegistrationStatus)
                TroubleshootStatusRow(title: "Push API",
                                      status: viewModel.pushAPIStatus,
                                      waitingSystemImageName: "arrow.clockwise.circle",
                                      actionAccessibilityLabel: "Repair mismatched server push data") {
                    viewModel.repairServerPushDataIfNeeded()
                }
                TroubleshootStatusRow(title: "Test Notification",
                                      status: viewModel.testNotificationStatus,
                                      waitingSystemImageName: "paperplane",
                                      actionAccessibilityLabel: "Send test notification") {
                    viewModel.sendTestNotification()
                }
            }

            Section("Push Identifiers") {
                ForEach(viewModel.remoteNotificationsDebugItems) { item in
                    RemoteNotificationsDebugItemCell(item: item)
                }
            }

            Section {
                ForEach(viewModel.pushDataDebugItems) { item in
                    PushDataDebugItemCell(item: item)
                }
            } header: {
                Text("Push Data")
            } footer: {
                Text("Compares this device's registration values with the values currently stored by the push API. Tap Push API to repair mismatches.")
            }

            Section {
                if viewModel.scheduledNotifications.isEmpty {
                    ScheduledNotificationEmptyCellView()
                } else {
                    ForEach(viewModel.scheduledNotifications) { notification in
                        ScheduledNotificationCellView(notification: notification)
                    }
                }
            } header: {
                Text("Scheduled Notifications")
            } footer: {
                Text("Pending local notifications currently scheduled on this device.")
            }
        }
        .navigationTitle("Troubleshooting")
        .onAppear {
            viewModel.viewAppeared()
        }
        .onDisappear {
            viewModel.viewDisappeared()
        }
    }
}

final class NotificationsTroubleshootViewController: RipppleHostingController<NotificationsTroubleshootView> {
    init() {
        super.init(rootView: NotificationsTroubleshootView())
        title = "Troubleshooting"
    }

    @objc dynamic required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NotificationsTroubleshootView())
        title = "Troubleshooting"
    }
}

private final class NotificationsTroubleshootViewModel: ObservableObject {
    @Published private(set) var appSettingsStatus: TroubleshootStatus = .waiting
    @Published private(set) var deviceSettingsStatus: TroubleshootStatus = .waiting
    @Published private(set) var tokenRegistrationStatus: TroubleshootStatus = .waiting
    @Published private(set) var pushAPIStatus: TroubleshootStatus = .waiting
    @Published private(set) var testNotificationStatus: TroubleshootStatus = .waiting
    @Published private(set) var remoteNotificationsDebugItems = [RemoteNotificationsDebugItem]()
    @Published private(set) var pushDataDebugItems = [PushDataDebugItem]()
    @Published private(set) var scheduledNotifications = [ScheduledNotification]()

    private let disposeBag = DisposeBag()
    private let testNotificationIdentifier = "TestNotification"
    private var remoteNotificationsPushInProgress = false
    private var remoteNotificationsPushCompleted = false
    private var shouldSendTestNotificationAfterRemotePush = false
    private var isVisible = false
    private var didRunInitialChecks = false
    private var serverPushInformation: PushInformationModel?
    private var testNotificationTimer: Timer?

    private lazy var scheduledNotificationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        setupReceivers()
        refreshRemoteNotificationsDebugItems()
        refreshPushDataDebugItems()
        refreshScheduledNotifications()
    }

    deinit {
        testNotificationTimer?.invalidate()
    }

    func viewAppeared() {
        isVisible = true
        refreshAppSettingsStatus()
        refreshNotificationSettings()
        refreshRemoteNotificationsDebugItems()
        refreshPushDataDebugItems()
        refreshScheduledNotifications()

        guard didRunInitialChecks == false else { return }
        didRunInitialChecks = true
        refreshServerPushData()
    }

    func viewDisappeared() {
        isVisible = false
    }

    func sendTestNotification() {
        testNotificationTimer?.invalidate()
        testNotificationTimer = nil
        shouldSendTestNotificationAfterRemotePush = false
        testNotificationStatus = .running
        scheduleTestNotificationAfterRemotePushFinishes()
    }

    func repairServerPushDataIfNeeded() {
        refreshServerPushData(repairMismatch: true)
    }

    private func setupReceivers() {
        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            DispatchQueue.main.async {
                self?.handle(applicationLifecycle)
            }
        }.disposed(by: disposeBag)

        pushTokenReceiveAndUpdatedReceiver.listen { [weak self] error in
            DispatchQueue.main.async {
                self?.pushTokenDidUpdate(with: error)
            }
        }.disposed(by: disposeBag)

        remoteNotificationsEndpointUpdatedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.refreshRemoteNotificationsDebugItems()
                self.refreshPushDataDebugItems()
            }
        }.disposed(by: disposeBag)

        testPushReceiver.listen { [weak self] _ in
            DispatchQueue.main.async {
                self?.testNotificationWasReceived()
            }
        }.disposed(by: disposeBag)
    }

    private func handle(_ applicationLifecycle: ApplicationLifecycle) {
        switch applicationLifecycle {
        case .didFinishLaunching:
            break
        case .didBecomeActive:
            guard isVisible else { return }
            refreshTokenRegistrationStatus()
            refreshNotificationSettings()
        case .didEnterBackground:
            break
        }

        refreshRemoteNotificationsDebugItems()
        refreshScheduledNotifications()
    }

    private func refreshAppSettingsStatus() {
        appSettingsStatus = notificationsAllDisabled ? .failure : .success
    }

    private var notificationsAllDisabled: Bool {
        return MovieNotificationsManager.shared.toWatchMovieRelease == false &&
            MovieNotificationsManager.shared.watchlistMovieRelease == false &&
            DVDMovieNotificationsManager.shared.toWatchMovieRelease == false &&
            DVDMovieNotificationsManager.shared.watchlistMovieRelease == false &&
            StreamingMovieNotificationsManager.shared.toWatchMovieRelease == false &&
            StreamingMovieNotificationsManager.shared.watchlistMovieRelease == false &&
            EpisodeNotificationsManager.shared.watchlistShowPremiere == false &&
            EpisodeNotificationsManager.shared.watchlistEpisodeRelease == false &&
            EpisodeNotificationsManager.shared.watchlistSeasonPremiere == false &&
            EpisodeNotificationsManager.shared.watchlistShowFinale == false &&
            EpisodeNotificationsManager.shared.watchlistSeasonFinale == false &&
            EpisodeNotificationsManager.shared.toWatchShowPremiere == false &&
            EpisodeNotificationsManager.shared.toWatchEpisodeRelease == false &&
            EpisodeNotificationsManager.shared.toWatchSeasonPremiere == false &&
            EpisodeNotificationsManager.shared.toWatchShowFinale == false &&
            EpisodeNotificationsManager.shared.toWatchSeasonFinale == false &&
            ActivityNotificationsManager.shared.activityNewFollower == false &&
            ActivityNotificationsManager.shared.commentNewLikes == false &&
            ActivityNotificationsManager.shared.commentNewMention == false &&
            ActivityNotificationsManager.shared.commentNewReply == false
    }

    private func refreshNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.apply(notificationSettings: settings)
            }
        }
    }

    private func apply(notificationSettings: UNNotificationSettings) {
        switch notificationSettings.authorizationStatus {
        case .notDetermined:
            deviceSettingsStatus = .warning
        case .denied:
            deviceSettingsStatus = .failure
            tokenRegistrationStatus = .blocked
        case .authorized, .provisional, .ephemeral:
            deviceSettingsStatus = .success
            refreshTokenRegistrationStatus()
        @unknown default:
            deviceSettingsStatus = .warning
        }
    }

    private func pushTokenDidUpdate(with error: Error?) {
        tokenRegistrationStatus = error == nil ? .success : .failure
        refreshRemoteNotificationsDebugItems()
    }

    private func refreshTokenRegistrationStatus() {
        let token = UserDefaults.standard.string(forKey: "Rippple.pushToken")
        tokenRegistrationStatus = token?.isEmpty == false ? .success : .waiting
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
        let pushInformation = currentPushInformation(endpointARN: endpointARN, traktSlug: traktSlug)
        let topicStates = remoteNotificationTopicStates()

        remoteNotificationsPushInProgress = true
        updateRemoteNotificationsPushStatus(.running)

        Task { [weak self] in
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
                    case .subscribed, .unsubscribed:
                        pushedTopicCount += 1
                    }
                }

                let skippedText = skippedTopicCount > 0 ? " \(skippedTopicCount) topic(s) were skipped because they are not configured." : ""
                let message = "Endpoint, push information, and \(pushedTopicCount) topic subscription update(s) were pushed.\(skippedText)"
                await MainActor.run { [self] in
                    self?.finishRemoteNotificationsPush(with: .success(message),
                                                        completed: true)
                    self?.refreshServerPushData()
                }
            } catch {
                await MainActor.run { [self] in
                    self?.finishRemoteNotificationsPush(with: .failure(error.localizedDescription),
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

    private func updateRemoteNotificationsPushStatus(_ status: RemoteNotificationsPushStatus) {
        pushAPIStatus = status.troubleshootStatus
        refreshRemoteNotificationsDebugItems()
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
            DispatchQueue.main.async {
                guard let self = self else { return }
                if error != nil {
                    self.testNotificationStatus = .failure
                } else {
                    guard self.testNotificationStatus != .success else { return }
                    self.testNotificationTimer?.invalidate()
                    self.testNotificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        self?.validateTestNotificationDelivery()
                    }
                    self.refreshScheduledNotifications()
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
                self.updateTestNotificationReceived(wasDelivered)
            }
        }
    }

    private func testNotificationWasReceived() {
        testNotificationTimer?.invalidate()
        testNotificationTimer = nil
        updateTestNotificationReceived(true)
        refreshRemoteNotificationsDebugItems()
        refreshScheduledNotifications()
    }

    private func updateTestNotificationReceived(_ testNotificationReceived: Bool?) {
        guard let testNotificationReceived = testNotificationReceived else {
            testNotificationStatus = .waiting
            return
        }
        testNotificationStatus = testNotificationReceived ? .success : .failure
    }

    private func refreshRemoteNotificationsDebugItems() {
        let endpoint = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
        let token = UserDefaults.standard.string(forKey: "Rippple.pushToken")

        remoteNotificationsDebugItems = [
            RemoteNotificationsDebugItem(subtitle: "Endpoint ARN",
                                         body: endpoint ?? "none",
                                         copyValue: endpoint),
            RemoteNotificationsDebugItem(subtitle: "Push token",
                                         body: token ?? "none",
                                         copyValue: token)
        ]
    }

    private func refreshServerPushData(repairMismatch: Bool = false) {
        guard RemoteNotificationsManager.shared.isConfigured,
              let endpointARN = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS") else {
            pushAPIStatus = .blocked
            serverPushInformation = nil
            refreshPushDataDebugItems()
            return
        }

        pushAPIStatus = .running

        Task { [weak self] in
            do {
                let pushInformation = try await RemoteNotificationsManager.shared.pushInformation(endpointARN: endpointARN)
                await MainActor.run { [self] in
                    guard let self = self else { return }
                    self.serverPushInformation = pushInformation
                    self.finishServerPushDataRefresh(repairMismatch: repairMismatch)
                }
            } catch {
                await MainActor.run { [self] in
                    guard let self = self else { return }
                    self.serverPushInformation = nil
                    self.finishServerPushDataRefresh(serverError: error.localizedDescription,
                                                     repairMismatch: repairMismatch)
                }
            }
        }
    }

    private func finishServerPushDataRefresh(serverError: String? = nil, repairMismatch: Bool) {
        refreshPushDataDebugItems(serverError: serverError)
        let needsRepair = serverError != nil || pushDataDebugItems.contains(where: { !$0.valuesMatch })
        pushAPIStatus = needsRepair ? .retry : .success
        guard repairMismatch, needsRepair else { return }
        remoteNotificationsPushCompleted = false
        forcePushRemoteNotificationsData()
    }

    private func refreshPushDataDebugItems(serverError: String? = nil) {
        guard let endpointARN = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS"),
              let traktSlug = UserManager.shared.currentUser?.slug else {
            pushDataDebugItems = []
            return
        }

        let local = currentPushInformation(endpointARN: endpointARN, traktSlug: traktSlug)
        let server = serverPushInformation
        let unavailableServerValue = serverError ?? "not fetched"

        pushDataDebugItems = [
            PushDataDebugItem(property: "Endpoint ARN", localValue: local.enpointARN, serverValue: server?.enpointARN ?? unavailableServerValue),
            PushDataDebugItem(property: "Trakt ID", localValue: local.traktId, serverValue: server?.traktId ?? unavailableServerValue),
            PushDataDebugItem(property: "commentNewLikes", localValue: String(local.commentNewLikes), serverValue: server.map { String($0.commentNewLikes) } ?? unavailableServerValue),
            PushDataDebugItem(property: "commentNewReply", localValue: String(local.commentNewReply), serverValue: server.map { String($0.commentNewReply) } ?? unavailableServerValue),
            PushDataDebugItem(property: "commentNewMention", localValue: String(local.commentNewMention), serverValue: server.map { String($0.commentNewMention) } ?? unavailableServerValue),
            PushDataDebugItem(property: "activityNewFollower", localValue: String(local.activityNewFollower), serverValue: server.map { String($0.activityNewFollower) } ?? unavailableServerValue)
        ]
    }

    private func currentPushInformation(endpointARN: String, traktSlug: String) -> PushInformationModel {
        return PushInformationModel(traktId: traktSlug,
                                    enpointARN: endpointARN,
                                    environement: endpointEnvironment(),
                                    premium: PurchaseManager.shared.purchased ? "VIP" : "non-VIP",
                                    commentNewLikes: ActivityNotificationsManager.shared.commentNewLikes,
                                    commentNewReply: ActivityNotificationsManager.shared.commentNewReply,
                                    commentNewMention: ActivityNotificationsManager.shared.commentNewMention,
                                    activityNewFollower: ActivityNotificationsManager.shared.activityNewFollower)
    }

    private func refreshScheduledNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pendingNotificationRequests in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.scheduledNotifications = pendingNotificationRequests
                    .sorted(by: self.scheduledNotificationSort)
                    .map { self.scheduledNotification(from: $0) }
            }
        }
    }

    private func scheduledNotification(from request: UNNotificationRequest) -> ScheduledNotification {
        let content = request.content

        return ScheduledNotification(identifier: request.identifier,
                                     title: content.title.isEmpty ? "New Notification" : content.title,
                                     subtitle: content.subtitle,
                                     body: content.body,
                                     date: scheduledNotificationDateDescription(for: request))
    }

    private func scheduledNotificationSort(_ lhs: UNNotificationRequest, _ rhs: UNNotificationRequest) -> Bool {
        let lhsDate = nextTriggerDate(for: lhs) ?? .distantFuture
        let rhsDate = nextTriggerDate(for: rhs) ?? .distantFuture

        if lhsDate != rhsDate {
            return lhsDate < rhsDate
        }

        return lhs.identifier < rhs.identifier
    }

    private func scheduledNotificationDateDescription(for request: UNNotificationRequest) -> String {
        guard let date = nextTriggerDate(for: request) else {
            if request.trigger == nil {
                return "Immediate"
            } else {
                return "Unknown"
            }
        }

        return scheduledNotificationDateFormatter.string(from: date)
    }

    private func nextTriggerDate(for request: UNNotificationRequest) -> Date? {
        if let trigger = request.trigger as? UNCalendarNotificationTrigger {
            return trigger.nextTriggerDate()
        } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
            return trigger.nextTriggerDate()
        } else {
            return nil
        }
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

private struct TroubleshootStatusRow: View {
    let title: String
    let status: TroubleshootStatus
    let waitingSystemImageName: String?
    let actionAccessibilityLabel: String?
    let action: (() -> Void)?

    init(title: String,
         status: TroubleshootStatus,
         waitingSystemImageName: String? = nil,
         actionAccessibilityLabel: String? = nil,
         action: (() -> Void)? = nil) {
        self.title = title
        self.status = status
        self.waitingSystemImageName = waitingSystemImageName
        self.actionAccessibilityLabel = actionAccessibilityLabel
        self.action = action
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            if status.isRunning {
                ProgressView()
                    .controlSize(.regular)
            }

            if let action = action, status.isRunning == false {
                Button(action: action) {
                    statusImage
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(actionAccessibilityLabel ?? title)
            } else {
                statusImage
            }
        }
    }

    private var statusImage: some View {
        Image(systemName: status.systemImageName(waitingSystemImageName: waitingSystemImageName))
            .font(.title3)
            .foregroundStyle(status.tint)
            .imageScale(.medium)
    }
}

private struct RemoteNotificationsDebugItem: Hashable, Identifiable {
    let subtitle: String
    let body: String
    let copyValue: String?

    var id: String {
        return subtitle
    }

    init(subtitle: String, body: String, copyValue: String? = nil) {
        self.subtitle = subtitle
        self.body = body
        self.copyValue = copyValue
    }
}

private struct RemoteNotificationsDebugItemCell: View {
    let item: RemoteNotificationsDebugItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)

                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let copyValue = item.copyValue {
                Button {
                    UIPasteboard.general.string = copyValue
                } label: {
                    Image(systemName: "doc.on.doc")
                        .imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Copy \(item.subtitle)")
            }
        }
    }
}

private struct PushDataDebugItem: Hashable, Identifiable {
    let property: String
    let localValue: String
    let serverValue: String

    var id: String {
        return property
    }

    var valuesMatch: Bool {
        return localValue == serverValue
    }
}

private struct PushDataDebugItemCell: View {
    let item: PushDataDebugItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.property)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: item.valuesMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(item.valuesMatch ? .green : .orange)
                    .accessibilityLabel(item.valuesMatch ? "Values match" : "Values differ")
            }

            LabeledContent("Device") {
                Text(item.localValue)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            .font(.footnote)

            LabeledContent("Server") {
                Text(item.serverValue)
                    .multilineTextAlignment(.trailing)
                    .textSelection(.enabled)
            }
            .font(.footnote)
        }
    }
}

private enum TroubleshootStatus: Equatable {
    case waiting
    case running
    case success
    case warning
    case failure
    case blocked
    case retry

    func systemImageName(waitingSystemImageName: String? = nil) -> String {
        switch self {
        case .waiting:
            return waitingSystemImageName ?? "circle"
        case .running:
            return "circle"
        case .success:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.octagon.fill"
        case .failure:
            return "exclamationmark.octagon.fill"
        case .blocked:
            return "exclamationmark.octagon.fill"
        case .retry:
            return "arrow.clockwise.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .waiting, .running, .blocked:
            return .gray
        case .success:
            return .green
        case .warning, .retry:
            return .orange
        case .failure:
            return .red
        }
    }

    var isRunning: Bool {
        return self == .running
    }
}

private struct ScheduledNotification: Hashable, Identifiable {
    let identifier: String
    let title: String
    let subtitle: String
    let body: String
    let date: String

    var id: String {
        identifier
    }
}

private struct ScheduledNotificationCellView: View {
    let notification: ScheduledNotification

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(notification.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(nil)

            if notification.subtitle.isEmpty == false {
                Text(notification.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }

            if notification.body.isEmpty == false {
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(nil)
            }

            Text(notification.date)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
        }
    }
}

private struct ScheduledNotificationEmptyCellView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No Scheduled Notifications")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text("There are currently no pending local notifications scheduled on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private enum RemoteNotificationsPushStatus {
    case waiting
    case running
    case success(String)
    case failure(String)

    var troubleshootStatus: TroubleshootStatus {
        switch self {
        case .waiting:
            return .waiting
        case .running:
            return .running
        case .success:
            return .success
        case .failure:
            return .retry
        }
    }
}

#if DEBUG
#Preview("Notifications Troubleshooting") {
    NavigationStack {
        NotificationsTroubleshootView()
    }
}
#endif
