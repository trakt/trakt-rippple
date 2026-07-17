//
//  CommentsTabViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 25/04/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class CommentsTabViewController: UIViewController {
    private enum FeedType: Int {
        case all
        case trending
        case forYou
    }

    private enum Filter: Int {
        case all
        case becauseYouWatchedOnly
        case becauseYouFollowOnly
    }

    private let orderBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "line.horizontal.3.decrease"),
                                                     style: .plain,
                                                     target: nil,
                                                     action: nil)
    private let filterBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis"),
                                                      style: .plain,
                                                      target: nil,
                                                      action: nil)

    private var commentsViewController: CommentsViewController?

    private var feedType = FeedType(rawValue: UserDefaults.standard.integer(forKey: "CommentsTabViewController.currentSorting")) ?? .all {
        didSet {
            UserDefaults.standard.set(feedType.rawValue, forKey: "CommentsTabViewController.currentSorting")
            UserDefaults.standard.synchronize()
            applyFeedType(reset: true)
        }
    }

    private var currentFilter = Filter(rawValue: UserDefaults.standard.integer(forKey: "ForYouViewController.currentFilter")) ?? .all {
        didSet {
            UserDefaults.standard.set(currentFilter.rawValue, forKey: "ForYouViewController.currentFilter")
            UserDefaults.standard.synchronize()
            applyFilter()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        view.backgroundColor = .systemBackground

        configureProfileBarButtonItem()
        configureBarButtonItems()
        embedCommentsViewController()
        applyFeedType(reset: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.style = .browser
    }

    private func embedCommentsViewController() {
        let commentsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "CommentsViewController") as! CommentsViewController
        commentsViewController.coordinator = CommentsCoordinator(type: .feed)
        self.commentsViewController = commentsViewController

        addChild(commentsViewController)
        commentsViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(commentsViewController.view)
        NSLayoutConstraint.activate([
            commentsViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            commentsViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            commentsViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            commentsViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        commentsViewController.didMove(toParent: self)
    }

    private func configureProfileBarButtonItem() {
        #if targetEnvironment(macCatalyst)
        navigationItem.leftBarButtonItem = nil
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            navigationItem.leftBarButtonItem = nil
            return
        }

        let profileButton = ProfileButton()
        let profileAction = UIAction(handler: { [weak self] _ in
            guard let self = self else { return }
            let profileViewController = UIStoryboard(name: "Profile", bundle: nil).instantiateInitialViewController()!
            self.present(profileViewController, animated: true)
            UISelectionFeedbackGenerator().selectionChanged()
        })
        profileButton.addAction(profileAction, for: .touchUpInside)
        profileButton.setImage(UIImage(imageLiteralResourceName: "bg_placeholder_avatar_small"), for: .normal)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
        #endif
    }

    private func configureBarButtonItems() {
        orderBarButtonItem.primaryAction = nil
        orderBarButtonItem.menu = orderMenu()
        filterBarButtonItem.primaryAction = nil
        filterBarButtonItem.menu = forYouFilterMenu()
        updateRightBarButtonItems(animated: false)
    }

    private func applyFeedType(reset: Bool) {
        switch feedType {
        case .all:
            commentsViewController?.coordinator = CommentsCoordinator(type: .feed)
            navigationItem.title = "Comments"
            navigationItem.subtitle = "Latest"
        case .trending:
            commentsViewController?.coordinator = CommentsCoordinator(type: .trending)
            navigationItem.title = "Comments"
            navigationItem.subtitle = "Trending"
        case .forYou:
            commentsViewController?.coordinator = CommentsCoordinator(type: .forYou)
            applyFilter()
        }

        orderBarButtonItem.menu = orderMenu()
        filterBarButtonItem.menu = forYouFilterMenu()
        updateRightBarButtonItems(animated: reset)

        if reset {
            commentsViewController?.coordinator.reset()
        }
    }

    private func applyFilter() {
        ForYouManager.shared.currentFilter = forYouFilter

        switch currentFilter {
        case .all:
            navigationItem.title = "Comments"
            navigationItem.subtitle = "For You"
        case .becauseYouWatchedOnly:
            navigationItem.title = "Comments"
            navigationItem.subtitle = "Because You Watched"
        case .becauseYouFollowOnly:
            navigationItem.title = "Comments"
            navigationItem.subtitle = "Because You Follow"
        }

        filterBarButtonItem.menu = forYouFilterMenu()
    }

    private func applyForYouFilter(_ filter: Filter) {
        let shouldReset = feedType == .forYou
        currentFilter = filter
        if shouldReset {
            commentsViewController?.coordinator.reset()
        } else {
            feedType = .forYou
        }
    }

    private var forYouFilter: ForYouManager.Filter {
        switch currentFilter {
        case .all:
            return .all
        case .becauseYouWatchedOnly:
            return .becauseYouWatchedOnly
        case .becauseYouFollowOnly:
            return .becauseYouFollowOnly
        }
    }

    private func updateRightBarButtonItems(animated: Bool) {
        if feedType == .forYou {
            navigationItem.setRightBarButtonItems([filterBarButtonItem, .fixedSpace(), orderBarButtonItem],
                                                  animated: animated)
        } else {
            navigationItem.setRightBarButtonItems([orderBarButtonItem], animated: animated)
        }
    }

    private func orderMenu() -> UIMenu {
        let latest = UIAction(title: "Latest",
                              state: feedType == .all ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.feedType = .all
        }

        let trending = UIAction(title: "Trending",
                                state: feedType == .trending ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.feedType = .trending
        }

        let forYou = UIAction(title: "For You",
                              state: feedType == .forYou ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.feedType = .forYou
        }

        return UIMenu(children: [latest, trending, forYou])
    }

    private func forYouFilterMenu() -> UIMenu {
        let all = UIAction(title: "For You",
                           state: currentFilter == .all ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.applyForYouFilter(.all)
        }

        let watched = UIAction(title: "Because You Watched",
                               state: currentFilter == .becauseYouWatchedOnly ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.applyForYouFilter(.becauseYouWatchedOnly)
        }

        let follow = UIAction(title: "Because You Follow",
                              state: currentFilter == .becauseYouFollowOnly ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.applyForYouFilter(.becauseYouFollowOnly)
        }

        return UIMenu(title: "What do you want to see?", children: [all, watched, follow])
    }
}
