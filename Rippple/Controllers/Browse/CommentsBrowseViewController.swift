//
//  CommentsBrowseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

class CommentsBrowseViewController: UIViewController {

    private let disposeBag = DisposeBag()

    enum FeedType: Int {
        case all
        case trending
        case forYou
    }

    private enum Filter: Int {
        case all
        case becauseYouWatchedOnly
        case becauseYouFollowOnly
    }

    @IBOutlet var filterBarButtonItem: UIBarButtonItem!

    private var commentsViewController: CommentsViewController?

    var feedType: FeedType? {
        didSet {
            assert(feedType != nil, "Setting a nil feedtype is prohibited")
            guard let currentFeedType = feedType else { return }

            switch currentFeedType {
            case .all:
                commentsViewController?.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.feed)
                navigationItem.rightBarButtonItems = nil
                navigationItem.title = "Comments"
                navigationItem.subtitle = "Latest"
            case .trending:
                commentsViewController?.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.trending)
                navigationItem.rightBarButtonItems = nil
                navigationItem.title = "Comments"
                navigationItem.subtitle = "Trending"
            case .forYou:
                commentsViewController?.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.forYou)
                navigationItem.rightBarButtonItems = [filterBarButtonItem]
                if let currentFilter = currentFilter {
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
                } else {
                    navigationItem.title = "For You"
                }
            }
            commentsViewController?.coordinator.reset()
        }
    }

    private var currentFilter: Filter? {
        didSet {
            assert(currentFilter != nil, "Setting a nil filter is prohibited")
            guard let currentFilter = currentFilter else { return }

            UserDefaults.standard.set(currentFilter.rawValue, forKey: "ForYouViewController.currentFilter")
            UserDefaults.standard.synchronize()

            switch currentFilter {
            case .all:
                filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                ForYouManager.shared.currentFilter = .all
                navigationItem.title = "Comments"
                navigationItem.subtitle = "For You"
            case .becauseYouWatchedOnly:
                filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                ForYouManager.shared.currentFilter = .becauseYouWatchedOnly
                navigationItem.title = "Comments"
                navigationItem.subtitle = "Because You Watched"
            case .becauseYouFollowOnly:
                filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                ForYouManager.shared.currentFilter = .becauseYouFollowOnly
                navigationItem.title = "Comments"
                navigationItem.subtitle = "Because You Follow"
            }

            if let button = filterBarButtonItem.customView as? UIButton {
                button.setImage(filterBarButtonItem.image?.withConfiguration(UIImage.SymbolConfiguration(scale: .large)),
                                for: .normal)
            }

            commentsViewController?.coordinator.reset()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.style = .browser
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        filterBarButtonItem.primaryAction = nil
        filterBarButtonItem.menu = filterMenu()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {

            self.commentsViewController = commentsViewController

            if let feedType = feedType {
                switch feedType {
                case .all:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.feed)
                    navigationItem.rightBarButtonItems = nil
                    navigationItem.title = "Comments"
                    navigationItem.subtitle = "Latest"
                case .trending:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.trending)
                    navigationItem.rightBarButtonItems = nil
                    navigationItem.title = "Comments"
                    navigationItem.subtitle = "Trending"
                case .forYou:
                    navigationItem.rightBarButtonItems = [filterBarButtonItem]
                    if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "ForYouViewController.currentFilter")) {
                        switch filter {
                        case .all:
                            filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                            ForYouManager.shared.currentFilter = .all
                            navigationItem.title = "Comments"
                            navigationItem.subtitle = "For You"
                        case .becauseYouWatchedOnly:
                            filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                            ForYouManager.shared.currentFilter = .becauseYouWatchedOnly
                            navigationItem.title = "Comments"
                            navigationItem.subtitle = "Because You Watched"
                        case .becauseYouFollowOnly:
                            filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                            ForYouManager.shared.currentFilter = .becauseYouFollowOnly
                            navigationItem.title = "Comments"
                            navigationItem.subtitle = "Because You Follow"
                        }
                    }
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.forYou)
                }
            } else {
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.feed)
                navigationItem.rightBarButtonItems = nil
                navigationItem.title = "Comments"
                navigationItem.title = "Latest"
            }
        }
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let all = UIAction(title: "For You", image: nil, state: (ForYouManager.shared.currentFilter == .all ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .all
            }

            let watched = UIAction(title: "Because You Watched", image: nil, state: (ForYouManager.shared.currentFilter == .becauseYouWatchedOnly ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .becauseYouWatchedOnly
            }

            let follow = UIAction(title: "Because You Follow", image: nil, state: (ForYouManager.shared.currentFilter == .becauseYouFollowOnly ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .becauseYouFollowOnly
            }

            completion([UIMenu(title: "What do you want to see?", options: .displayInline, children: [all, watched, follow])])
        }

        return UIMenu(children: [deferredMenuElement])
    }
}
