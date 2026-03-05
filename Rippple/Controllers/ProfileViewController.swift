//
//  ProfileViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import Receiver

final class ProfileViewController: UIViewController {

    private let disposeBag = DisposeBag()

    private var commentsViewController: CommentsViewController?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = "Your Profile"

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.commentsViewController != nil { return }
            if UserManager.shared.currentUser == nil { return }
            self.performSegue(withIdentifier: "profileComments", sender: self)
        }.disposed(by: disposeBag)

        onNotificationCenterChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.updateBarItems()
            }
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive:
                DispatchQueue.main.async {
                    self.updateBarItems()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateBarItems()
    }

    private func updateBarItems() {
        let state = UIApplication.shared.applicationState
        if state != .active { return }

        guard Thread.isMainThread else { return }

        navigationItem.rightBarButtonItems = nil

        // on iPhone in the main tab bar (one icon each side
        if tabBarController != nil {
            let settingsAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                let settings = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Settings")
                self.present(settings, animated: true, completion: nil)
            })
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: nil,
                                                               image: UIImage(systemName: "gearshape"),
                                                               primaryAction: settingsAction,
                                                               menu: nil)
            let notificationsAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: "notifications", sender: nil)
            })
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil,
                                                                image: NotificationCenterManager.shared.newNotificationReceived ? UIImage(systemName: "bell.badge") : UIImage(systemName: "bell"),
                                                                primaryAction: notificationsAction,
                                                                menu: nil)
        } else if navigationController?.presentingViewController == nil {
            // everywhere it's not presented as a modal (eg: ipad slide over)
            navigationItem.leftBarButtonItem = nil
            let notificationsAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: "notifications", sender: nil)
            })
            navigationItem.rightBarButtonItems = nil
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: nil,
                                                                image: NotificationCenterManager.shared.newNotificationReceived ? UIImage(systemName: "bell.badge") : UIImage(systemName: "bell"),
                                                                primaryAction: notificationsAction,
                                                                menu: nil)
        } else {
            // presented as a modal
            let settingsAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                let settings = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Settings")
                self.present(settings, animated: true, completion: nil)
            })
            let notificationsAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: "notifications", sender: nil)
            })
            navigationItem.rightBarButtonItems = [UIBarButtonItem(title: nil,
                                                                  image: UIImage(systemName: "gearshape"),
                                                                  primaryAction: settingsAction,
                                                                  menu: nil),
                                                  .fixedSpace(),
                                                  UIBarButtonItem(title: nil,
                                                                  image: NotificationCenterManager.shared.newNotificationReceived ? UIImage(systemName: "bell.badge") : UIImage(systemName: "bell"),
                                                                  primaryAction: notificationsAction,
                                                                  menu: nil)]
        }
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "profileComments",
            UserManager.shared.currentUser == nil {
            return false
        }

        return true
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            self.commentsViewController = commentsViewController
            if let currentUser = UserManager.shared.currentUser {
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.user(currentUser))
            }
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
