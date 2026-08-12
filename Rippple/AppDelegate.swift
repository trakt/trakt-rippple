//
//  AppDelegate.swift
//  Rippple
//
//  Created by Kevin Cador on 04/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import AlamofireNetworkActivityIndicator
import BackgroundTasks
import NVActivityIndicatorView
import Receiver
import SwiftUI
import UIKit

// Push management
import UserNotifications

enum ApplicationLifecycle {
    case didFinishLaunching
    case didBecomeActive(Double)
    case didEnterBackground
}

let (applicationLifecycleTransmitter, applicationLifecycleReceiver) = Receiver<ApplicationLifecycle>.make(with: .hot)
let (pushTokenReceiveAndUpdatedTransmitter, pushTokenReceiveAndUpdatedReceiver) = Receiver<Error?>.make(with: .hot)
let (remoteNotificationsEndpointUpdatedTransmitter, remoteNotificationsEndpointUpdatedReceiver) = Receiver<String>.make(with: .warm(upTo: 1))
let (testPushTransmitter, testPushReceiver) = Receiver<String>.make(with: .hot)
let (commandTransmitter, commandReceiver) = Receiver<UIKeyCommand>.make(with: .hot)

enum RipppleAppearance {
    static let switchTintColor = UIColor(dynamicProvider: { _ in
        UIColor(asset: .globalTint).darker(amount: 0.3)
    })
}

private struct RipppleSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: ToggleStyleConfiguration) -> some View {
        Toggle(configuration)
            .toggleStyle(.switch)
            .tint(Color(uiColor: RipppleAppearance.switchTintColor))
    }
}

struct RipppleHostedView<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .toggleStyle(RipppleSwitchToggleStyle())
    }
}

struct RipppleList<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        SwiftUI.List {
            Group {
                content
            }
            .listRowBackground(Color(uiColor: .ripppleGroupedCardBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .ripppleGroupedViewBackground))
    }
}

struct RipppleForm<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        Form {
            Group {
                content
            }
            .listRowBackground(Color(uiColor: .ripppleGroupedCardBackground))
        }
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .ripppleGroupedViewBackground))
    }
}

@MainActor
class RipppleHostingController<Content: View>: UIHostingController<RipppleHostedView<Content>> {
    init(rootView: Content) {
        super.init(rootView: RipppleHostedView(content: rootView))
    }

    init?(coder aDecoder: NSCoder, rootView: Content) {
        super.init(coder: aDecoder, rootView: RipppleHostedView(content: rootView))
    }

    @objc dynamic required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ripppleViewBackground
    }

    func setRootView(_ rootView: Content) {
        self.rootView = RipppleHostedView(content: rootView)
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    private let disposeBag = DisposeBag()
    private var lastRegisteredPushInformation: PushInformationModel?
    private lazy var debouncedRegisterForPushNotifications = Debouncer(delay: 1.0) { [weak self] in
        guard SessionManager.shared.isLoggedIn else { return }
        guard let self = self else { return }
        self.registerForPushNotifications()
    }

    private lazy var debouncedUpdatePushInformation = Debouncer(delay: 1.0) { [weak self] in
        guard SessionManager.shared.isLoggedIn, let endpointARN = endpointARN else { return }
        guard let self = self else { return }
        self.updatePushInformation(endpointARN: endpointARN)
    }

    private lazy var debouncedRemovePushInformation = Debouncer(delay: 1.0) { [weak self] in
        guard SessionManager.shared.isLoggedOut, let endpointARN = endpointARN else { return }
        guard let self = self else { return }
        self.removePushInformation(endpointARN: endpointARN)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        UserDefaults.standard.register(defaults: ["MovieToWatchSettings.upcoming": true,
                                                  "EpisodeToWatchSettings.upcoming": true,
                                                  "GeneralSettings.dragging": true,
                                                  "GeneralSettings.actorEpisodeCountSpoilers": true,
                                                  "GeneralSettings.episodeImageSpoilers": true,
                                                  "Stinger.alert.type": true,
                                                  "GeneralSettings.comments": true,
                                                  "GeneralSettings.droppedshows": true,
                                                  "CalendarSettings.filtersShowToWatch": true,
                                                  "CalendarSettings.addTrendingShows": true,
                                                  "CalendarSettings.addAnticipatedShows": true,
                                                  "CalendarSettings.addTrendingMovies": true,
                                                  "CalendarSettings.addAnticipatedMovies": true,
                                                  "CalendarSettings.myShows": true,
                                                  "CalendarSettings.myMovies": true,
                                                  "CalendarSettings.hideHiddenMovies": true,
                                                  "CalendarSettings.hideHiddenShows": true,
                                                  "CalendarSettings.hideRecentlyWatchedMovies": false,
                                                  "CalendarSettings.hideRecentlyWatchedShows": false,
                                                  "EpisodeNotificationsManager.groupEpisodes": true,
                                                  "EpisodeNotificationsManager.reduceBasedOnProgress": true,
                                                  "EpisodeNotificationsManager.postponeNighttimeNotifications": true,
                                                  "EpisodeNotificationsManager.watchlistShowPremiere": true,
                                                  "EpisodeNotificationsManager.watchlistSeasonPremiere": true,
                                                  "EpisodeNotificationsManager.watchlistShowFinale": true,
                                                  "EpisodeNotificationsManager.watchlistSeasonFinale": true,
                                                  "EpisodeNotificationsManager.watchlistEpisodeRelease": true,
                                                  "EpisodeNotificationsManager.toWatchShowPremiere": true,
                                                  "EpisodeNotificationsManager.toWatchSeasonPremiere": true,
                                                  "EpisodeNotificationsManager.toWatchShowFinale": true,
                                                  "EpisodeNotificationsManager.toWatchSeasonFinale": true,
                                                  "EpisodeNotificationsManager.toWatchEpisodeRelease": true,
                                                  "MovieNotificationsManager.watchlistMovieRelease": true,
                                                  "MovieNotificationsManager.toWatchMovieRelease": true,
                                                  "ActivityNotificationsManager.commentNewLikes": true,
                                                  "ActivityNotificationsManager.commentNewReply": true,
                                                  "ActivityNotificationsManager.commentNewMention": true,
                                                  "ActivityNotificationsManager.activityNewFollower": true,
                                                  "DVDMovieNotificationsManager.watchlistMovieRelease": true,
                                                  "DVDMovieNotificationsManager.toWatchMovieRelease": true,
                                                  "StreamingMovieNotificationsManager.watchlistMovieRelease": true,
                                                  "StreamingMovieNotificationsManager.toWatchMovieRelease": true,
                                                  "TrendingNotificationsManager.trendingShows": true,
                                                  "TrendingNotificationsManager.trendingMovies": true,
                                                  "RecommendedNotificationsManager.recommendedShows": true,
                                                  "RecommendedNotificationsManager.recommendedMovies": true,
                                                  "AnticipatedNotificationsManager.anticipatedShows": true,
                                                  "AnticipatedNotificationsManager.anticipatedMovies": true,
                                                  "ManualRemoteNotificationsManager.appUpdate": true,
                                                  "ManualRemoteNotificationsManager.blogPost": true,
                                                  "ToWatchViewController.currentType": 1,
                                                  "CountryManager.displayInLists": true,
                                                  "AppManager.tintedAppearance": false,
                                                  "GeneralSettings.commentscount": 1])

        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        SessionManager.shared.wakeUp { _ in
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        let existingVersion = UserDefaults.standard.object(forKey: "CurrentVersionNumber") as? String
        let appVersionNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as! String

        if existingVersion != appVersionNumber {
            UserDefaults.standard.set(appVersionNumber, forKey: "CurrentVersionNumber")
            UserDefaults.standard.synchronize()
            // Check if we have a current user, if so, it means it's an old user that updated the app and not a new install
            if UserDefaults.standard.data(forKey: "Rippple.currentUser") != nil {
                DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://whatsnew")!)
            }
        }

        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://whatsnew")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://comments/160618")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://people/quentin-krog")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "https://app.trakt.tv/people/quentin-krog")!)

        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://tmdb/shows/97546")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://tmdb/shows/97546/seasons/3")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://tmdb/shows/97546/seasons/3/episodes/2")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://tmdb/people/58224")!)
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://tmdb/movies/502356")!)

        /*

         *Comments*
         ripl://comments/142442 -> Episode
         ripl://comments/161705 -> Season
         ripl://comments/157283 -> Show
         ripl://comments/160618 -> Movie
         ripl://comments/128216 -> List
         ripl://comments/140812 -> Reply

         *People, Shows, Movies, Users*
         ripl://people/quentin-krog -> Ok
         ripl://shows/star-trek-discovery -> Ok
         ripl://shows/star-trek-discovery/seasons/1/episodes/1 -> Ok
         ripl://movies/thor-ragnarok-2017 -> Ok
         ripl://users/kcador -> Ok

         *TMDb*
         ripl://tmdb/shows/97546 -> Ok
         ripl://tmdb/shows/97546/seasons/3 -> Ok
         ripl://tmdb/shows/97546/seasons/3/episodes/2 -> Ok
         ripl://tmdb/people/58224 -> Ok
         ripl://tmdb/movies/502356 -> Ok

         *Rippple*
         ripl://whatsnew -> Ok
         ripl://settings/notifications -> Ok

         *Search*
         ripl://search/[query]

         */

        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://search")!)

        AppManager.shared.setup()

        let view = UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
        view.tintColor = UIColor(asset: .globalTint)

        UISwitch.appearance().onTintColor = RipppleAppearance.switchTintColor
        UIProgressView.appearance().trackTintColor = UIColor(asset: .globalTint).withAlphaComponent(0.25)
        NVActivityIndicatorView.DEFAULT_COLOR = UIColor(asset: .globalTint)

        UserManager.shared.startManaging()

        ImagesManager.shared.setup()

        NetworkActivityIndicatorManager.shared.isEnabled = true

        ProductManager.shared.reloadProducts()
        PurchaseManager.shared.setup()

        TraktStatusCheckManager.shared.setup()

        LikeManager.shared.startManaging()
        ReactionsManager.shared.startManaging()

        ToWatchSearchManager.shared.setup()
        HiddenMediaManager.shared.setup()

        ProgressManager.shared.setup()
        PinnedShowsManager.shared.setup()
        PinnedMoviesManager.shared.setup()
        EpisodeToWatchManager.shared.setup()
        MovieToWatchManager.shared.setup()
        // Make sure the config manager is running when the ShelfManager is used.
        _ = BrowseConfigManager.shared.shelfConfig
        ShelfManager.shared.setup()

        AnticipatedNotificationsManager.shared.setup()
        EpisodeNotificationsManager.shared.setup()
        MovieNotificationsManager.shared.setup()
        DVDMovieNotificationsManager.shared.setup()
        StreamingMovieNotificationsManager.shared.setup()

        NotificationCenterManager.shared.setup()

        // Remote push setup config
        RemoteNotificationsManager.shared.configure()
        if RemoteNotificationsManager.shared.isConfigured {
            if SessionManager.shared.isLoggedIn {
                registerForPushNotifications()
            }

            onSettingsChangedReceiver.hotOnly().listen { [weak self] _ in
                guard let self = self else { return }
                if SessionManager.shared.isLoggedIn {
                    self.debouncedRegisterForPushNotifications.call()
                } else if SessionManager.shared.isLoggedOut {
                    self.debouncedRemovePushInformation.call()
                }
            }.disposed(by: disposeBag)

            onNotificationsSettingsChangedReceiver.listen { [weak self] update in
                guard let self = self else { return }
                switch update {
                case .changed:
                    self.debouncedUpdatePushInformation.call()
                case .forced:
                    guard SessionManager.shared.isLoggedIn, let endpointARN = endpointARN else { return }
                    self.updatePushInformation(endpointARN: endpointARN, force: true)
                }
            }.disposed(by: disposeBag)

            // Placed here because they need remote push setup first
            TrendingNotificationsManager.shared.setup()
            RecommendedNotificationsManager.shared.setup()
            ManualRemoteNotificationsManager.shared.setup()
        }

        // End remote push stuff

        WidgetManager.shared.setup()
        SavedFiltersManager.shared.setup()
        RecentSearchManager.shared.setup()
        OpenActionManager.shared.setup()

        WatchlistManager.shared.setup()
        CompletedShowsManager.shared.setup()
        DroppedShowsManager.shared.setup()
        WatchedManager.shared.setup()
        SyncWatchedManager.shared.setup()
        UserFavoritesManager.shared.setup()
        CollectionManager.shared.setup()
        FollowManager.shared.setup()
        OwnCommentsManager.shared.setup()
        ListsManager.shared.setup()
        CollaborationsManager.shared.setup()

        NotesManager.shared.setup()

        FilterManager.shared.setup()

        #if !targetEnvironment(macCatalyst)
        LiveActivityManager.shared.setup()
        #endif

        CalendarManager.shared.setup()

        BGTaskScheduler.shared.register(forTaskWithIdentifier: "tv.trakt.towatch.refresh", using: nil) { task in
            #if !targetEnvironment(macCatalyst)
            Task {
                await LiveActivityManager.shared.stopActivityIfNeeded()
            }
            #endif

            // If purchase not active or badge turned off, complete quickly
            guard UserDefaults.standard.integer(forKey: "Badge.mode") >= 1 else {
                // Reschedule next refresh
                AppManager.shared.scheduleNewBackgroundRefresh()

                task.setTaskCompleted(success: true)

                return
            }

            MovieToWatchManager.shared.forcedUserRefresh()
            EpisodeToWatchManager.shared.forcedUserRefresh()

            let timeout: DispatchTime = .now() + 20
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: timeout) {
                // Reschedule next refresh
                AppManager.shared.scheduleNewBackgroundRefresh()

                task.setTaskCompleted(success: true)
            }
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ubiquitousKeyValueStoredidChangeExternally),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil)
        NSUbiquitousKeyValueStore.default.synchronize()

        applicationLifecycleTransmitter.broadcast(.didFinishLaunching)

        let menuConfiguration = UIMainMenuSystem.Configuration()

        menuConfiguration.findingConfiguration.style = .search
        menuConfiguration.newScenePreference = .removed
        menuConfiguration.documentPreference = .removed
        menuConfiguration.printingPreference = .removed
        menuConfiguration.findingPreference = .included
        menuConfiguration.inspectorPreference = .removed
        menuConfiguration.toolbarPreference = .removed
        menuConfiguration.textFormattingPreference = .included
        menuConfiguration.sidebarPreference = .included

        UIMainMenuSystem.shared.setBuildConfiguration(menuConfiguration) { builder in
            builder.insertElements([UIKeyCommand(title: "Reload",
                                                 image: UIImage(systemName: "arrow.clockwise"),
                                                 action: #selector(self.refreshAll(_:)),
                                                 input: "R",
                                                 modifierFlags: .command,
                                                 discoverabilityTitle: "Reload")],
                                   beforeMenu: .close)
        }

        return true
    }

    private var showsSmartSearch = SmartSearch.smartSearches(for: .show) {
        didSet {
            if showsSmartSearch != oldValue {
                onShowSmartSearchChangedTransmitter.broadcast(1)
            }
        }
    }

    private var moviesSmartSearch = SmartSearch.smartSearches(for: .movie) {
        didSet {
            if moviesSmartSearch != oldValue {
                onMovieSmartSearchChangedTransmitter.broadcast(1)
            }
        }
    }

    @objc private func ubiquitousKeyValueStoredidChangeExternally() {
        showsSmartSearch = SmartSearch.smartSearches(for: .show)
        moviesSmartSearch = SmartSearch.smartSearches(for: .movie)
    }
}

private var endpointARN: String? {
    get {
        return UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
    }
    set(newEndpointARN) {
        UserDefaults.standard.set(newEndpointARN, forKey: "Rippple.endpointArnForSNS")
        UserDefaults.standard.synchronize()
        if let newEndpointARN = newEndpointARN {
            remoteNotificationsEndpointUpdatedTransmitter.broadcast(newEndpointARN)
        }
    }
}

private var token: String? {
    get {
        return UserDefaults.standard.string(forKey: "Rippple.pushToken")
    }
    set(newToken) {
        UserDefaults.standard.set(newToken, forKey: "Rippple.pushToken")
        UserDefaults.standard.synchronize()
    }
}

extension AppDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        if !RemoteNotificationsManager.shared.isConfigured {
            // Do nothing, remote push is not configured
            pushTokenReceiveAndUpdatedTransmitter.broadcast(NSError(domain: "Rippple", code: 0, userInfo: nil))
            return
        }
        guard SessionManager.shared.isLoggedIn else { return }

        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }

        let latestToken = tokenParts.joined()

        if let endpointARN = endpointARN,
           let token = token,
           latestToken == token {
            updateEndpoint(endpointARN: endpointARN)
            updatePushInformation(endpointARN: endpointARN,
                                  force: true,
                                  deduplicateRegistration: true)
        } else {
            saveToken(newToken: latestToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
        pushTokenReceiveAndUpdatedTransmitter.broadcast(error)
    }

    private func saveToken(newToken: String) {
        token = newToken

        let customUserData = endpointCustomUserData()

        Task { [weak self] in
            do {
                let createdEndpointARN = try await RemoteNotificationsManager.shared.createEndpoint(
                    token: newToken,
                    customUserData: customUserData
                )
                await MainActor.run {
                    guard let self = self else { return }
                    print("🎉 endpoint ARN from remote notifications API: \(createdEndpointARN)")
                    endpointARN = createdEndpointARN
                    self.updatePushInformation(endpointARN: createdEndpointARN)
                }
            } catch {
                await MainActor.run {
                    print("💀 Remote notifications create endpoint Error: \(error)")
                    pushTokenReceiveAndUpdatedTransmitter.broadcast(error)
                }
            }
        }
    }

    private func updateEndpoint(endpointARN: String) {
        let customUserData = endpointCustomUserData()

        Task {
            do {
                try await RemoteNotificationsManager.shared.updateEndpoint(endpointARN: endpointARN, customUserData: customUserData)
            } catch {
                print("💀 Remote notifications update endpoint Error: \(error)")
            }
        }
    }

    private func updatePushInformation(endpointARN: String,
                                       force: Bool = false,
                                       deduplicateRegistration: Bool = false) {
        guard let traktSlug = UserManager.shared.currentUser?.slug else { return }

        let pushInfo = PushInformationModel(traktId: traktSlug,
                                            enpointARN: endpointARN,
                                            environement: endpointEnvironment(),
                                            premium: PurchaseManager.shared.purchased ? "VIP" : "non-VIP",
                                            commentNewLikes: ActivityNotificationsManager.shared.commentNewLikes,
                                            commentNewReply: ActivityNotificationsManager.shared.commentNewReply,
                                            commentNewMention: ActivityNotificationsManager.shared.commentNewMention,
                                            activityNewFollower: ActivityNotificationsManager.shared.activityNewFollower)

        if deduplicateRegistration {
            guard lastRegisteredPushInformation != pushInfo else { return }
            lastRegisteredPushInformation = pushInfo
        }

        Task {
            do {
                let savedPushInformation = try await RemoteNotificationsManager.shared.savePushInformation(pushInfo, force: force)
                await MainActor.run {
                    if savedPushInformation {
                        print("🎉 Push information was saved through remote notifications API.")
                    }
                    pushTokenReceiveAndUpdatedTransmitter.broadcast(nil)
                }
            } catch {
                await MainActor.run {
                    print("💀 Remote notifications save push information Error: \(error)")
                    pushTokenReceiveAndUpdatedTransmitter.broadcast(error)
                }
            }
        }
    }

    private func removePushInformation(endpointARN: String) {
        Task {
            do {
                try await RemoteNotificationsManager.shared.removePushInformation(endpointARN: endpointARN)
                print("🎉 Push information was removed through remote notifications API.")
            } catch {
                print("💀 Remote notifications remove push information Error: \(error)")
            }
        }
    }

    private func endpointCustomUserData() -> String {
        return "\(UserManager.shared.currentUser?.slug ?? ""), \(endpointEnvironment()), \(Bundle.main.releaseVersionNumber!), \(Bundle.main.buildVersionNumber!)"
    }

    private func endpointEnvironment() -> String {
        return Bundle.main.isSimulator() ? "Simulator" : "App Store"
    }
}

extension Bundle {
    func isSimulator() -> Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}

extension AppDelegate {
    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .providesAppNotificationSettings]) { granted, _ in
            print("Permission granted: \(granted)")

            guard granted else { return }
            self.getNotificationSettings()
        }
    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            print("Notification settings: \(settings)")
            guard settings.authorizationStatus == .authorized else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }
}

extension UIView {
    #if targetEnvironment(macCatalyst)
    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1 // NSFocusRingTypeNone
    }
    #endif
}

extension AppDelegate {
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        print("canPerformAction \(action)")
        if UIApplication.shared.isModalDisplayed() { return false }
        if action == #selector(find(_:)) { return true }
        if action == #selector(refreshAll(_:)) { return true }
        return false
    }

    @objc private func refreshAll(_ sender: UIKeyCommand) {
        commandTransmitter.broadcast(sender)
    }

    override func find(_ sender: Any?) {
        ShortcutManager.shared.shouldHandle(shortcut: ShortcutManager.shared.searchAndKeyboardShortcutItem)
        if SessionManager.shared.isLoggedIn,
           DeeplinkManager.shared.shouldOpenDeeplink() {
            UIApplication.shared.switchToDeeplink()
        }
    }
}
