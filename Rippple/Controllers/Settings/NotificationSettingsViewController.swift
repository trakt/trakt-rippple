//
//  NotificationSettingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Receiver
import SwiftUI
import UIKit

enum NotificationSettingsUpdate {
    case changed
    case forced
}

let (onNotificationsSettingsChangedTransmitter, onNotificationsSettingsChangedReceiver) = Receiver<NotificationSettingsUpdate>.make(with: .hot)

struct NotificationSettingsView: View {
    var onTroubleshoot: () -> Void = {}
    var onSettingChanged: () -> Void = {}

    @State private var values = NotificationSetting.currentValues()

    var body: some View {
        Form {
            Section {
                Button(action: onTroubleshoot) {
                    HStack {
                        Text("Troubleshoot Notifications")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            } header: {
                Text("🛠️ Troubleshooting")
            } footer: {
                Text("Make sure you're not in a Focus mode that can \"hide\" Rippple's notifications.")
            }

            toggleSection(title: "📢 Rippple Updates",
                          footer: "Get a notification when Rippple is updated or when a new Weekly post is available. Blog posts includes Rippple Weekly Tracker. Delivered by realtime push notifications.",
                          settings: [.appUpdate, .blogPost])

            toggleSection(title: "🔔 Check-in",
                          footer: "Get a notification when checking in a movie that includes during or after-credits stinger.",
                          settings: [.stingerAlert])

            toggleSection(title: "🔔 Anticipated",
                          footer: "Get a notification when a Movie or Show was Anticipated and is released. Scheduled locally on this device.",
                          settings: [.anticipatedMovie, .anticipatedShow])

            toggleSection(title: "📢 Trending",
                          footer: "Get a notification when a Movie or Show becomes trending. Delivered by realtime push notifications.",
                          settings: [.trendingMovie, .trendingShow])

            toggleSection(title: "📢 Favorited",
                          footer: "Get a notification when a Movie or Show becomes most favorited. Delivered by realtime push notifications.",
                          settings: [.favoritedMovie, .favoritedShow])

            toggleSection(title: "✨ Smart Episode Releases",
                          settings: [.groupEpisodes, .reduceBasedOnProgress, .postponeNighttimeNotifications])

            toggleSection(title: "🔔 Watchlist",
                          footer: "Manual release notifications are scheduled locally on this device.",
                          settings: [.watchlistMovieRelease,
                                     .watchlistDVDMovieRelease,
                                     .watchlistStreamingMovieRelease,
                                     .watchlistShowPremiere,
                                     .watchlistSeasonPremiere,
                                     .watchlistShowFinale,
                                     .watchlistSeasonFinale,
                                     .watchlistEpisodeRelease])

            toggleSection(title: "🔔 To Watch",
                          footer: "Manual release notifications are scheduled locally on this device.",
                          settings: [.toWatchMovieRelease,
                                     .toWatchDVDMovieRelease,
                                     .toWatchStreamingMovieRelease,
                                     .toWatchShowPremiere,
                                     .toWatchSeasonPremiere,
                                     .toWatchShowFinale,
                                     .toWatchSeasonFinale,
                                     .toWatchEpisodeRelease])

            toggleSection(title: "📢 Comments",
                          footer: "Delivered by realtime push notifications.",
                          settings: [.commentNewLike, .commentNewReply, .commentNewMention])

            toggleSection(title: "📢 Activity",
                          footer: "Delivered by realtime push notifications.",
                          settings: [.activityNewFollower])
        }
        .navigationTitle("Notifications")
        .onAppear {
            values = NotificationSetting.currentValues()
        }
    }

    private func toggleSection(title: String, footer: String? = nil, settings: [NotificationSetting]) -> some View {
        Section {
            ForEach(settings) { setting in
                Toggle(isOn: binding(for: setting)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(setting.title)
                        if let subtitle = setting.subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        } header: {
            Text(title)
        } footer: {
            if let footer = footer {
                Text(footer)
            }
        }
    }

    private func binding(for setting: NotificationSetting) -> Binding<Bool> {
        Binding {
            values[setting, default: setting.isOn]
        } set: { newValue in
            values[setting] = newValue
            setting.isOn = newValue
            onSettingChanged()
        }
    }
}

private enum NotificationSetting: CaseIterable, Hashable, Identifiable {
    case appUpdate
    case blogPost
    case stingerAlert
    case anticipatedMovie
    case anticipatedShow
    case trendingMovie
    case trendingShow
    case favoritedMovie
    case favoritedShow
    case groupEpisodes
    case reduceBasedOnProgress
    case postponeNighttimeNotifications
    case watchlistMovieRelease
    case watchlistDVDMovieRelease
    case watchlistStreamingMovieRelease
    case watchlistShowPremiere
    case watchlistSeasonPremiere
    case watchlistShowFinale
    case watchlistSeasonFinale
    case watchlistEpisodeRelease
    case toWatchMovieRelease
    case toWatchDVDMovieRelease
    case toWatchStreamingMovieRelease
    case toWatchShowPremiere
    case toWatchSeasonPremiere
    case toWatchShowFinale
    case toWatchSeasonFinale
    case toWatchEpisodeRelease
    case commentNewLike
    case commentNewReply
    case commentNewMention
    case activityNewFollower

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .appUpdate:
            return "App Update"
        case .blogPost:
            return "New Weekly Post"
        case .stingerAlert:
            return "Credits Stinger Alert"
        case .anticipatedMovie:
            return "Anticipated Movie"
        case .anticipatedShow:
            return "Anticipated Show"
        case .trendingMovie:
            return "Trending Movie"
        case .trendingShow:
            return "Trending Show"
        case .favoritedMovie:
            return "Favorited Movie"
        case .favoritedShow:
            return "Favorited Show"
        case .groupEpisodes:
            return "Group Binge Releases"
        case .reduceBasedOnProgress:
            return "Reduce Based on Progress"
        case .postponeNighttimeNotifications:
            return "Postpone Nighttime Notifications"
        case .watchlistMovieRelease, .toWatchMovieRelease:
            return "Movie Released"
        case .watchlistDVDMovieRelease, .toWatchDVDMovieRelease:
            return "Movie DVD & Blu-Ray Released"
        case .watchlistStreamingMovieRelease, .toWatchStreamingMovieRelease:
            return "Movie Streaming Released"
        case .watchlistShowPremiere, .toWatchShowPremiere:
            return "TV show Premiere"
        case .watchlistSeasonPremiere, .toWatchSeasonPremiere:
            return "Season Premiere"
        case .watchlistShowFinale, .toWatchShowFinale:
            return "TV show Finale"
        case .watchlistSeasonFinale, .toWatchSeasonFinale:
            return "Season Finale"
        case .watchlistEpisodeRelease, .toWatchEpisodeRelease:
            return "Episode Released"
        case .commentNewLike:
            return "New Reaction"
        case .commentNewReply:
            return "New Reply"
        case .commentNewMention:
            return "New Mention"
        case .activityNewFollower:
            return "New Follower"
        }
    }

    var subtitle: String? {
        switch self {
        case .groupEpisodes:
            return "Group episodes from the same show that air at the same time into one notification."
        case .reduceBasedOnProgress:
            return "Only get regular episode notifications when you're caught up with the show."
        case .postponeNighttimeNotifications:
            return "Deliver at 9 AM for episodes airing between midnight and 9 AM."
        default:
            return nil
        }
    }

    var isOn: Bool {
        get {
            switch self {
            case .appUpdate:
                return ManualRemoteNotificationsManager.shared.appUpdate
            case .blogPost:
                return ManualRemoteNotificationsManager.shared.blogPost
            case .stingerAlert:
                return UserDefaults.standard.bool(forKey: "Stinger.alert.type")
            case .anticipatedMovie:
                return AnticipatedNotificationsManager.shared.anticipatedMovies
            case .anticipatedShow:
                return AnticipatedNotificationsManager.shared.anticipatedShows
            case .trendingMovie:
                return TrendingNotificationsManager.shared.trendingMovies
            case .trendingShow:
                return TrendingNotificationsManager.shared.trendingShows
            case .favoritedMovie:
                return RecommendedNotificationsManager.shared.recommendedMovies
            case .favoritedShow:
                return RecommendedNotificationsManager.shared.recommendedShows
            case .groupEpisodes:
                return EpisodeNotificationsManager.shared.groupEpisodes
            case .reduceBasedOnProgress:
                return EpisodeNotificationsManager.shared.reduceBasedOnProgress
            case .postponeNighttimeNotifications:
                return EpisodeNotificationsManager.shared.postponeNighttimeNotifications
            case .watchlistMovieRelease:
                return MovieNotificationsManager.shared.watchlistMovieRelease
            case .watchlistDVDMovieRelease:
                return DVDMovieNotificationsManager.shared.watchlistMovieRelease
            case .watchlistStreamingMovieRelease:
                return StreamingMovieNotificationsManager.shared.watchlistMovieRelease
            case .watchlistShowPremiere:
                return EpisodeNotificationsManager.shared.watchlistShowPremiere
            case .watchlistSeasonPremiere:
                return EpisodeNotificationsManager.shared.watchlistSeasonPremiere
            case .watchlistShowFinale:
                return EpisodeNotificationsManager.shared.watchlistShowFinale
            case .watchlistSeasonFinale:
                return EpisodeNotificationsManager.shared.watchlistSeasonFinale
            case .watchlistEpisodeRelease:
                return EpisodeNotificationsManager.shared.watchlistEpisodeRelease
            case .toWatchMovieRelease:
                return MovieNotificationsManager.shared.toWatchMovieRelease
            case .toWatchDVDMovieRelease:
                return DVDMovieNotificationsManager.shared.toWatchMovieRelease
            case .toWatchStreamingMovieRelease:
                return StreamingMovieNotificationsManager.shared.toWatchMovieRelease
            case .toWatchShowPremiere:
                return EpisodeNotificationsManager.shared.toWatchShowPremiere
            case .toWatchSeasonPremiere:
                return EpisodeNotificationsManager.shared.toWatchSeasonPremiere
            case .toWatchShowFinale:
                return EpisodeNotificationsManager.shared.toWatchShowFinale
            case .toWatchSeasonFinale:
                return EpisodeNotificationsManager.shared.toWatchSeasonFinale
            case .toWatchEpisodeRelease:
                return EpisodeNotificationsManager.shared.toWatchEpisodeRelease
            case .commentNewLike:
                return ActivityNotificationsManager.shared.commentNewLikes
            case .commentNewReply:
                return ActivityNotificationsManager.shared.commentNewReply
            case .commentNewMention:
                return ActivityNotificationsManager.shared.commentNewMention
            case .activityNewFollower:
                return ActivityNotificationsManager.shared.activityNewFollower
            }
        }
        nonmutating set {
            switch self {
            case .appUpdate:
                ManualRemoteNotificationsManager.shared.appUpdate = newValue
            case .blogPost:
                ManualRemoteNotificationsManager.shared.blogPost = newValue
            case .stingerAlert:
                UserDefaults.standard.set(newValue, forKey: "Stinger.alert.type")
                UserDefaults.standard.synchronize()
            case .anticipatedMovie:
                AnticipatedNotificationsManager.shared.anticipatedMovies = newValue
            case .anticipatedShow:
                AnticipatedNotificationsManager.shared.anticipatedShows = newValue
            case .trendingMovie:
                TrendingNotificationsManager.shared.trendingMovies = newValue
            case .trendingShow:
                TrendingNotificationsManager.shared.trendingShows = newValue
            case .favoritedMovie:
                RecommendedNotificationsManager.shared.recommendedMovies = newValue
            case .favoritedShow:
                RecommendedNotificationsManager.shared.recommendedShows = newValue
            case .groupEpisodes:
                EpisodeNotificationsManager.shared.groupEpisodes = newValue
            case .reduceBasedOnProgress:
                EpisodeNotificationsManager.shared.reduceBasedOnProgress = newValue
            case .postponeNighttimeNotifications:
                EpisodeNotificationsManager.shared.postponeNighttimeNotifications = newValue
            case .watchlistMovieRelease:
                MovieNotificationsManager.shared.watchlistMovieRelease = newValue
            case .watchlistDVDMovieRelease:
                DVDMovieNotificationsManager.shared.watchlistMovieRelease = newValue
            case .watchlistStreamingMovieRelease:
                StreamingMovieNotificationsManager.shared.watchlistMovieRelease = newValue
            case .watchlistShowPremiere:
                EpisodeNotificationsManager.shared.watchlistShowPremiere = newValue
            case .watchlistSeasonPremiere:
                EpisodeNotificationsManager.shared.watchlistSeasonPremiere = newValue
            case .watchlistShowFinale:
                EpisodeNotificationsManager.shared.watchlistShowFinale = newValue
            case .watchlistSeasonFinale:
                EpisodeNotificationsManager.shared.watchlistSeasonFinale = newValue
            case .watchlistEpisodeRelease:
                EpisodeNotificationsManager.shared.watchlistEpisodeRelease = newValue
            case .toWatchMovieRelease:
                MovieNotificationsManager.shared.toWatchMovieRelease = newValue
            case .toWatchDVDMovieRelease:
                DVDMovieNotificationsManager.shared.toWatchMovieRelease = newValue
            case .toWatchStreamingMovieRelease:
                StreamingMovieNotificationsManager.shared.toWatchMovieRelease = newValue
            case .toWatchShowPremiere:
                EpisodeNotificationsManager.shared.toWatchShowPremiere = newValue
            case .toWatchSeasonPremiere:
                EpisodeNotificationsManager.shared.toWatchSeasonPremiere = newValue
            case .toWatchShowFinale:
                EpisodeNotificationsManager.shared.toWatchShowFinale = newValue
            case .toWatchSeasonFinale:
                EpisodeNotificationsManager.shared.toWatchSeasonFinale = newValue
            case .toWatchEpisodeRelease:
                EpisodeNotificationsManager.shared.toWatchEpisodeRelease = newValue
            case .commentNewLike:
                ActivityNotificationsManager.shared.commentNewLikes = newValue
            case .commentNewReply:
                ActivityNotificationsManager.shared.commentNewReply = newValue
            case .commentNewMention:
                ActivityNotificationsManager.shared.commentNewMention = newValue
            case .activityNewFollower:
                ActivityNotificationsManager.shared.activityNewFollower = newValue
            }
        }
    }

    static func currentValues() -> [NotificationSetting: Bool] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.isOn) })
    }
}

final class NotificationSettingsViewController: RipppleHostingController<NotificationSettingsView> {
    private let disposeBag = DisposeBag()
    private lazy var uploadSettingsBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"),
                                                                   style: .plain,
                                                                   target: self,
                                                                   action: #selector(forceUploadSettings))
    private var lastTransmittedSettings = NotificationSetting.currentValues()

    private var hasPendingSettingsChanges: Bool {
        NotificationSetting.currentValues() != lastTransmittedSettings
    }

    init() {
        super.init(rootView: NotificationSettingsView())
        configureRootView()
        setupApplicationLifecycleListener()
    }

    @objc dynamic required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: NotificationSettingsView())
        configureRootView()
        setupApplicationLifecycleListener()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        transmitChangedSettingsIfNeeded()
    }

    private func configureRootView() {
        setRootView(NotificationSettingsView(onTroubleshoot: { [weak self] in
            guard let self = self else { return }
            self.showTroubleshooting()
        }, onSettingChanged: { [weak self] in
            guard let self = self else { return }
            self.updateUploadSettingsButton()
        }))

        navigationItem.rightBarButtonItem = uploadSettingsBarButtonItem
        updateUploadSettingsButton()
    }

    private func setupApplicationLifecycleListener() {
        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            guard case .didEnterBackground = applicationLifecycle else { return }
            self.transmitChangedSettingsIfNeeded()
        }.disposed(by: disposeBag)
    }

    private func transmitChangedSettingsIfNeeded() {
        guard hasPendingSettingsChanges else { return }
        lastTransmittedSettings = NotificationSetting.currentValues()
        updateUploadSettingsButton()
        onNotificationsSettingsChangedTransmitter.broadcast(.changed)
    }

    @objc private func forceUploadSettings() {
        lastTransmittedSettings = NotificationSetting.currentValues()
        updateUploadSettingsButton()
        onNotificationsSettingsChangedTransmitter.broadcast(.forced)
    }

    private func updateUploadSettingsButton() {
        uploadSettingsBarButtonItem.style = hasPendingSettingsChanges ? .prominent : .plain
        uploadSettingsBarButtonItem.accessibilityLabel = hasPendingSettingsChanges ? "Upload Changed Notification Settings" : "Upload Notification Settings"
    }

    private func showTroubleshooting() {
        guard let controller = storyboard?.instantiateViewController(withIdentifier: "notificationsTroubleshoot") else { return }
        navigationController?.pushViewController(controller, animated: true)
    }
}

#if DEBUG
#Preview("Notifications Settings") {
    NavigationStack {
        NotificationSettingsView()
    }
}
#endif
