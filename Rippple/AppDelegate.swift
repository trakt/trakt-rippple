//
//  AppDelegate.swift
//  Rippple
//
//  Created by Kevin Cador on 04/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import AlamofireNetworkActivityIndicator
import Receiver

import BackgroundTasks

// Push management
import UserNotifications
import AWSCore
import AWSSNS
import AWSDynamoDB

import NVActivityIndicatorView

enum ApplicationLifecycle {
    case didFinishLaunching
    case didBecomeActive(Double)
    case didEnterBackground
}

let (applicationLifecycleTransmitter, applicationLifecycleReceiver) = Receiver<ApplicationLifecycle>.make(with: .hot)
let (pushTokenReceiveAndUpdatedTransmitter, pushTokenReceiveAndUpdatedReceiver) = Receiver<Error?>.make(with: .hot)
let (arnUpdatedTransmitter, arnUpdatedReceiver) = Receiver<String>.make(with: .warm(upTo: 1))
let (testPushTransmitter, testPushReceiver) = Receiver<String>.make(with: .hot)
let (commandTransmitter, commandReceiver) = Receiver<UIKeyCommand>.make(with: .hot)

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let disposeBag = DisposeBag()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        UserDefaults.standard.register(defaults: ["MovieToWatchSettings.upcoming": true,
                                                  "EpisodeToWatchSettings.upcoming": true,
                                                  "GeneralSettings.dragging": true,
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
                                                  "EpisodeNotificationsManager.groupEpisodes": true,
                                                  "EpisodeNotificationsManager.watchlistShowPremiere": true,
                                                  "EpisodeNotificationsManager.watchlistSeasonPremiere": true,
                                                  "EpisodeNotificationsManager.watchlistEpisodeRelease": true,
                                                  "EpisodeNotificationsManager.toWatchShowPremiere": true,
                                                  "EpisodeNotificationsManager.toWatchSeasonPremiere": true,
                                                  "EpisodeNotificationsManager.toWatchEpisodeRelease": true,
                                                  "MovieNotificationsManager.watchlistMovieRelease": true,
                                                  "MovieNotificationsManager.toWatchMovieRelease": true,
                                                  "ActivityNotificationsManager.commentNewLikes": true,
                                                  "ActivityNotificationsManager.commentNewReply": true,
                                                  "ActivityNotificationsManager.commentNewMention": true,
                                                  "ActivityNotificationsManager.activityNewFollower": true,
                                                  "DVDMovieNotificationsManager.watchlistMovieRelease": true,
                                                  "DVDMovieNotificationsManager.toWatchMovieRelease": true,
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
        // DeeplinkManager.shared.registerDeeplink(url: URL(string: "https://trakt.tv/people/quentin-krog")!)

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

        UISwitch.appearance().onTintColor = UIColor(dynamicProvider: { _ in
            UIColor(asset: .globalTint).darker(amount: 0.3)
        })
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

        NotificationCenterManager.shared.setup()

        // AWS setup Config
        if let identityPoolId = AWSConfiguration.identityPoolId {
            let credentialsProvider = AWSCognitoCredentialsProvider(regionType: .USEast1,
                                                                    identityPoolId: identityPoolId)

            let configuration = AWSServiceConfiguration(region: .USEast1,
                                                        credentialsProvider: credentialsProvider)

            AWSServiceManager.default().defaultServiceConfiguration = configuration

            getNotificationSettings()

            if SessionManager.shared.isLoggedIn {
                self.registerForPushNotifications()
            }

            onSettingsChangedReceiver.listen { [weak self] _ in
                guard let self = self else { return }
                if SessionManager.shared.isLoggedIn {
                    self.registerForPushNotifications()
                    if let ARN = endpointARN {
                        self.updateDynamoDB(ARN: ARN)
                    }
                } else if SessionManager.shared.isLoggedOut {
                    if let ARN = endpointARN {
                        self.removeFromDynamoDB(ARN: ARN)
                    }
                }
            }.disposed(by: disposeBag)

            onNotificationsSettingsChangedReceiver.listen { [weak self] _ in
                guard let self = self else { return }
                if let ARN = endpointARN {
                    self.updateDynamoDB(ARN: ARN)
                }
            }.disposed(by: disposeBag)

            // Placed here because they need AWS setup first
            TrendingNotificationsManager.shared.setup()
            RecommendedNotificationsManager.shared.setup()
            ManualRemoteNotificationsManager.shared.setup()
        }

        // End AWS push stuff

        WidgetManager.shared.setup()
        SavedFiltersManager.shared.setup()
        RecentSearchManager.shared.setup()

        WatchlistManager.shared.setup()
        CompletedShowsManager.shared.setup()
        DroppedShowsManager.shared.setup()
        WatchedManager.shared.setup()
        RecommendedManager.shared.setup()
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
    set(newEndpointArnForSNS) {
        UserDefaults.standard.set(newEndpointArnForSNS, forKey: "Rippple.endpointArnForSNS")
        UserDefaults.standard.synchronize()
        if let newEndpointArnForSNS = newEndpointArnForSNS {
            arnUpdatedTransmitter.broadcast(newEndpointArnForSNS)
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
        if AWSServiceManager.default().defaultServiceConfiguration == nil {
            // Do nothing, AWS is not configured
            pushTokenReceiveAndUpdatedTransmitter.broadcast(NSError(domain: "Rippple", code: 0, userInfo: nil))
            return
        }

        let tokenParts = deviceToken.map { data -> String in
            return String(format: "%02.2hhx", data)
        }

        let latestToken = tokenParts.joined()

        if let endpointARN = endpointARN,
            let token = token,
            latestToken == token {
            updateARNOnAWS(ARN: endpointARN)
            updateDynamoDB(ARN: endpointARN)
        } else {
            saveTokenOnAWS(newToken: latestToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register: \(error)")
        pushTokenReceiveAndUpdatedTransmitter.broadcast(error)
    }

    private func saveTokenOnAWS(newToken: String) {
        token = newToken

        let sns = AWSSNS.default()

        guard let request = AWSSNSCreatePlatformEndpointInput() else { return }
        request.token = newToken
        guard let platformApplicationARN = AWSConfiguration.platformApplicationARN else { return }
        request.platformApplicationArn = platformApplicationARN

        var type = "App Store"
        if Bundle.main.isSimulator() {
            type = "Simulator"
        }
        request.customUserData = "\(UserManager.shared.currentUser?.slug ?? ""), \(type), \(Bundle.main.releaseVersionNumber!), \(Bundle.main.buildVersionNumber!)"

        sns.createPlatformEndpoint(request).continueWith(executor: AWSExecutor.mainThread(), block: { [weak self] task in
            guard let self = self else { return nil }
            if task.error != nil {
                print("💀 AWS SNS createPlatformEndpoint Error: \(String(describing: task.error))")
                pushTokenReceiveAndUpdatedTransmitter.broadcast(task.error)
            } else if let createEndpointResponse = task.result,
                let endpointArnForSNS = createEndpointResponse.endpointArn {
                print("🎉 endpointArn from AWS SNS: \(endpointArnForSNS)")
                endpointARN = endpointArnForSNS
                self.updateDynamoDB(ARN: endpointArnForSNS)
            } else {
                fatalError()
            }
            return nil
        })
    }

    private func updateARNOnAWS(ARN: String) {
        let sns = AWSSNS.default()

        guard let setAttributesRequest = AWSSNSSetEndpointAttributesInput() else { return }
        setAttributesRequest.endpointArn = ARN

        var type = "App Store"
        if Bundle.main.isSimulator() {
            type = "Simulator"
        }
        setAttributesRequest.attributes = ["CustomUserData": "\(UserManager.shared.currentUser?.slug ?? ""), \(type), \(Bundle.main.releaseVersionNumber!), \(Bundle.main.buildVersionNumber!)", "Enabled": "true"]
        sns.setEndpointAttributes(setAttributesRequest, completionHandler: { error in
            if let error = error {
                print("💀 AWS SNS setEndpointAttributes Error: \(error)")
            }
        })
    }

    private func updateDynamoDB(ARN: String) {
        let dynamoDbObjectMapper = AWSDynamoDBObjectMapper.default()

        guard let pushInfo = PushInformationModel() else { return }
        guard let traktSlug = UserManager.shared.currentUser?.slug else { return }

        pushInfo.enpointARN = ARN
        pushInfo.traktId = traktSlug

        pushInfo.environement = "App Store"
        if Bundle.main.isSimulator() {
            pushInfo.environement = "Simulator"
        }

        pushInfo.premium = PurchaseManager.shared.purchased ? "VIP" : "non-VIP"

        pushInfo.activityNewFollower = NSNumber(value: ActivityNotificationsManager.shared.activityNewFollower)
        pushInfo.commentNewMention = NSNumber(value: ActivityNotificationsManager.shared.commentNewMention)
        pushInfo.commentNewReply = NSNumber(value: ActivityNotificationsManager.shared.commentNewReply)
        pushInfo.commentNewLikes = NSNumber(value: ActivityNotificationsManager.shared.commentNewLikes)

        // Save a new item
        dynamoDbObjectMapper.save(pushInfo, completionHandler: { error in
            if let error = error {
                print("💀 Amazon DynamoDB Save Error: \(error)")
                pushTokenReceiveAndUpdatedTransmitter.broadcast(error)
            } else {
                print("🎉 An item was saved on DynmoDB.")
                pushTokenReceiveAndUpdatedTransmitter.broadcast(nil)
            }
        })
    }

    private func removeFromDynamoDB(ARN: String) {
        let dynamoDbObjectMapper = AWSDynamoDBObjectMapper.default()

        guard let pushInfo = PushInformationModel() else { return }

        pushInfo.enpointARN = ARN

        // Remove the item
        dynamoDbObjectMapper.remove(pushInfo, completionHandler: { error in
            if let error = error {
                print("💀 Amazon DynamoDB Remove Error: \(error)")
                return
            }
            print("🎉 An item was removed on DynmoDB.")
        })
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
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .providesAppNotificationSettings]) { (granted, _) in
            print("Permission granted: \(granted)")

            guard granted else { return }
            self.getNotificationSettings()
        }
    }

    func getNotificationSettings() {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
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
