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

    @IBOutlet var appSettings: UIImageView!
    @IBOutlet var deviceSettings: UIImageView!
    @IBOutlet var tokenRegistration: UIImageView!
    @IBOutlet var testNotification: UIImageView!

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
                self.scheduleTestNotification()

                UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
                    guard let self = self else { return }
                    self.notificationSettings = settings
                }
            case .didEnterBackground:
                break
            }
            self.tableView.footerView(forSection: 0)?.textLabel?.text = self.tableView(self.tableView, titleForFooterInSection: 0)
        }.disposed(by: disposeBag)

        pushTokenReceiveAndUpdatedReceiver.listen { [weak self] error in
            guard let self = self else { return }
            self.pushTokenError = error
            DispatchQueue.main.async {
                self.tableView.footerView(forSection: 0)?.textLabel?.text = self.tableView(self.tableView, titleForFooterInSection: 0)
            }
        }.disposed(by: disposeBag)

        testPushReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.testNotificationTimer?.invalidate()
            self.testNotificationTimer = nil
            self.testNotificationReceived = true
            self.tableView.footerView(forSection: 0)?.textLabel?.text = self.tableView(self.tableView, titleForFooterInSection: 0)
        }.disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if onlyOnce {
            appSettings.tintColor = .systemGray
            deviceSettings.tintColor = .systemGray
            tokenRegistration.tintColor = .systemGray
            testNotification.tintColor = .systemGray
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

            scheduleTestNotification()
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        let endpoint = UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
        let token = UserDefaults.standard.string(forKey: "Rippple.pushToken")
        return "endpoint: \(endpoint ?? "none")\ntoken: \(token ?? "none")"
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    #endif

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            if notificationsAllDisabled {
                let alertController = UIAlertController(title: "Something's off",
                                                        message: "It seems like you disabled all notifications in the previous screen.",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "I understand", style: .cancel) { _ in
                    self.navigationController?.popViewController(animated: true)
                }
                alertController.addAction(cancel)
                present(alertController, animated: true)
            }
        } else if indexPath.row == 1 {
            guard let notificationSettings = notificationSettings else { return }
            switch notificationSettings.authorizationStatus {
            case .denied:
                let alertController = UIAlertController(title: "Something's off",
                                                        message: "Currently, notifications are off for Rippple. To change this, head to your device settings.",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancel)
                let settings = UIAlertAction(title: "Open Settings", style: .default) { _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                alertController.addAction(settings)
                present(alertController, animated: true)
            case .authorized:
                break
            case .provisional:
                break
            default:
                let alertController = UIAlertController(title: "What just happened?",
                                                        message: "We don't know what's up, but your device notifications authorization status for Rippple is in an unknown state. Try to open the settings and disable/enable notifications to try to solve the issue",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancel)
                let settings = UIAlertAction(title: "Open Settings", style: .default) { _ in
                    guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
                    if UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                alertController.addAction(settings)
                present(alertController, animated: true)
            }
        } else if indexPath.row == 2 {
            if let pushTokenError = pushTokenError {
                let alertController = UIAlertController(title: "Where's your yoken?",
                                                        message: "Something wrong happened with the token we need to use on our server to push activities to you. Don't worry it's not lost. You can try to restart the app or try again later. If the problem persists, you'll need to contact us. (\(pushTokenError.localizedDescription))",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Okay", style: .cancel)
                alertController.addAction(cancel)
                present(alertController, animated: true)
            }
        } else if indexPath.row == 3 {
            if let testNotificationError = testNotificationError {
                let alertController = UIAlertController(title: "Don't wait for it",
                                                        message: "Looks like we couldn't even schedule the test notification. (\(testNotificationError.localizedDescription))",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Okay", style: .cancel)
                alertController.addAction(cancel)
                present(alertController, animated: true)
            } else if testNotificationReceived == false {
                let alertController = UIAlertController(title: "Something's wrong",
                                                        message: "We're still waiting for that test notification to show up but it didn't in the expected time. So maybe you shouldn't wait either and try again later.",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Okay", style: .cancel)
                alertController.addAction(cancel)
                present(alertController, animated: true)
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 100
    }
    #endif

    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "👍 You're good to go"
        content.body = "This is what a notification from Rippple will look like. Okay, the next one should be about a comment, a movie, an episode or something like that. But you see the point, right?"

        let uuidString = "TestNotification"
        let request = UNNotificationRequest(identifier: uuidString,
                                            content: content,
                                            trigger: nil)

        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { [weak self] error in
            guard let self = self else { return }
            if error != nil {
                self.testNotificationError = error
            } else {
                DispatchQueue.main.async {
                    self.testNotificationTimer?.invalidate()
                    self.testNotificationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                        guard let self = self else { return }
                        self.testNotificationReceived = false
                    }
                }
            }
        }
    }
}
