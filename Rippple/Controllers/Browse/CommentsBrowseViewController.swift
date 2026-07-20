//
//  CommentsBrowseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/07/2023.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

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
            applyFeedType(reset: true)
        }
    }

    private var currentFilter = Filter(rawValue: UserDefaults.standard.integer(forKey: "ForYouViewController.currentFilter")) ?? .all {
        didSet {
            UserDefaults.standard.set(currentFilter.rawValue, forKey: "ForYouViewController.currentFilter")
            UserDefaults.standard.synchronize()

            updateNavigationTitle()

            if isViewLoaded, let button = filterBarButtonItem.customView as? UIButton {
                button.setImage(filterBarButtonItem.image?.withConfiguration(UIImage.SymbolConfiguration(scale: .large)),
                                for: .normal)
            }

            if feedType == .forYou {
                applyFeedType(reset: true)
            }
        }
    }

    private var currentMediaType = CommentMediaType(rawValue: UserDefaults.standard.string(forKey: "CommentsBrowseViewController.currentMediaType") ?? "") ?? .all {
        didSet {
            UserDefaults.standard.set(currentMediaType.rawValue, forKey: "CommentsBrowseViewController.currentMediaType")
            UserDefaults.standard.synchronize()
            applyFeedType(reset: true)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationItem.style = .browser
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        filterBarButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
        filterBarButtonItem.accessibilityLabel = "Filter Comments"
        filterBarButtonItem.accessibilityHint = "Choose comment filters"
        filterBarButtonItem.primaryAction = nil
        filterBarButtonItem.menu = filterMenu()
        navigationItem.rightBarButtonItems = [filterBarButtonItem]
        updateNavigationTitle()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            self.commentsViewController = commentsViewController
            applyFeedType(reset: false)
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

    private func applyFeedType(reset: Bool) {
        let listType: CommentsCoordinator.ListType
        switch feedType ?? .all {
        case .all:
            listType = .feed
        case .trending:
            listType = .trending
        case .forYou:
            listType = .forYou
        }

        commentsViewController?.coordinator = CommentsCoordinator(type: listType,
                                                                  mediaType: currentMediaType,
                                                                  forYouFilter: forYouFilter)
        updateNavigationTitle()

        if isViewLoaded {
            filterBarButtonItem.menu = filterMenu()
            navigationItem.rightBarButtonItems = [filterBarButtonItem]
        }

        if reset {
            commentsViewController?.coordinator.reset()
        }
    }

    private func updateNavigationTitle() {
        navigationItem.title = "Comments"

        let feedSubtitle: String
        switch feedType ?? .all {
        case .all:
            feedSubtitle = "Latest"
        case .trending:
            feedSubtitle = "Trending"
        case .forYou:
            switch currentFilter {
            case .all:
                feedSubtitle = "For You"
            case .becauseYouWatchedOnly:
                feedSubtitle = "Because You Watched"
            case .becauseYouFollowOnly:
                feedSubtitle = "Because You Follow"
            }
        }

        switch currentMediaType {
        case .all:
            navigationItem.subtitle = feedSubtitle
        case .movies:
            navigationItem.subtitle = "\(feedSubtitle) · Movies"
        case .shows:
            navigationItem.subtitle = "\(feedSubtitle) · Shows"
        case .seasons:
            navigationItem.subtitle = "\(feedSubtitle) · Seasons"
        case .episodes:
            navigationItem.subtitle = "\(feedSubtitle) · Episodes"
        }
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self = self else {
                completion([])
                return
            }

            let allMedia = UIAction(title: "Everything", state: self.currentMediaType == .all ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentMediaType = .all
            }

            let movies = UIAction(title: "Movies", state: self.currentMediaType == .movies ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentMediaType = .movies
            }

            let shows = UIAction(title: "Shows", state: self.currentMediaType == .shows ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentMediaType = .shows
            }

            let seasons = UIAction(title: "Seasons", state: self.currentMediaType == .seasons ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentMediaType = .seasons
            }

            let episodes = UIAction(title: "Episodes", state: self.currentMediaType == .episodes ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentMediaType = .episodes
            }

            let mediaTypes = UIMenu(title: "What do you want to see?",
                                    options: .displayInline,
                                    children: [allMedia, movies, shows, seasons, episodes])

            guard self.feedType == .forYou else {
                completion([mediaTypes])
                return
            }

            let allForYou = UIAction(title: "For You", state: self.forYouFilter == .all ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .all
            }

            let watched = UIAction(title: "Because You Watched", state: self.forYouFilter == .becauseYouWatchedOnly ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .becauseYouWatchedOnly
            }

            let follow = UIAction(title: "Because You Follow", state: self.forYouFilter == .becauseYouFollowOnly ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .becauseYouFollowOnly
            }

            let forYou = UIMenu(title: "For You",
                                options: .displayInline,
                                children: [allForYou, watched, follow])
            completion([mediaTypes, forYou])
        }

        return UIMenu(children: [deferredMenuElement])
    }
}
