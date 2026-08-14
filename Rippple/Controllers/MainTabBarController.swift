//
//  MainTabBarController.swift
//  Rippple
//
//  Created by Kevin Cador on 06/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import Receiver
import UIKit

final class MainTabBarController: UITabBarController {
    enum Tab: String, Codable, CaseIterable {
        case browse
        case shelf
        case comments
        case wall

        case purchase

        case toWatch
        case history
        case lists
        case search

        case watchlist
        case recommended
        case collection
        case watched
        case ratings

        case profile

        case calendar
    }

    private let disposeBag = DisposeBag()

    private var contextMenus = [TabBarContextMenuInteractionDelegate]()

    private let checkinView = CheckinView()

    private var profileAvatarURL: URL?
    private var profileAvatarDownloadTask: DownloadTask?
    private var profileTabImage = UIImage(systemName: "person.crop.circle")

    private var tabStore: [Tab: UITab] {
        var store = [Tab: UITab]()
        store[.browse] = UITab(title: "Browse",
                               image: UIImage(systemName: "sparkles.rectangle.stack"),
                               identifier: Tab.browse.rawValue,
                               viewControllerProvider: { _ in
                                   UIStoryboard(name: "Browse", bundle: nil).instantiateInitialViewController()!
                               })
        store[.shelf] = UITab(title: "Shelf",
                              image: UIImage(systemName: "square.grid.3x1.below.line.grid.1x2"),
                              identifier: Tab.shelf.rawValue,
                              viewControllerProvider: { _ in
                                  let browseViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(identifier: "standalone browse") as! BrowseViewController
                                  browseViewController.followsShelfConfig = true
                                  return StyledNavigationController(rootViewController: browseViewController)
                              })
        store[.comments] = UITab(title: "Comments",
                                 image: UIImage(systemName: "text.bubble"),
                                 identifier: Tab.comments.rawValue,
                                 viewControllerProvider: { _ in
                                     StyledNavigationController(rootViewController: CommentsTabViewController())
                                 })
        store[.purchase] = UITab(title: "Unlock",
                                 image: UIImage(systemName: "fireworks"),
                                 identifier: Tab.purchase.rawValue,
                                 viewControllerProvider: { _ in
                                     UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "subscribe in split")
                                 })
        store[.toWatch] = UITab(title: "To Watch",
                                image: UIImage(systemName: "checklist"),
                                identifier: Tab.toWatch.rawValue,
                                viewControllerProvider: { _ in
                                    UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "To Watch")
                                })
        store[.history] = UITab(title: "History",
                                image: UIImage(systemName: "memories"),
                                identifier: Tab.history.rawValue,
                                viewControllerProvider: { _ in
                                    UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Activities")
                                })
        store[.lists] = UITab(title: "Lists",
                              image: UIImage(systemName: "text.justify.left"),
                              identifier: Tab.lists.rawValue,
                              viewControllerProvider: { _ in
                                  UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Lists")
                              })
        store[.lists]?.isSpringLoaded = true
        store[.search] = UISearchTab(title: "Search",
                                     image: UIImage(systemName: "magnifyingglass"),
                                     identifier: Tab.search.rawValue,
                                     viewControllerProvider: { _ in
                                         UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Search")
                                     })
        store[.watchlist] = UITab(title: "Watchlist",
                                  image: UIImage(systemName: "bookmark"),
                                  identifier: Tab.watchlist.rawValue,
                                  viewControllerProvider: { _ in
                                      StyledNavigationController(rootViewController: UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "WatchlistViewController"))
                                  })
        store[.recommended] = UITab(title: "Favorites",
                                    image: UIImage(systemName: "star"),
                                    identifier: Tab.recommended.rawValue,
                                    viewControllerProvider: { _ in
                                        StyledNavigationController(rootViewController: UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "UserFavoritesViewController"))
                                    })
        store[.collection] = UITab(title: "Library",
                                   image: UIImage(systemName: "book"),
                                   identifier: Tab.collection.rawValue,
                                   viewControllerProvider: { _ in
                                       StyledNavigationController(rootViewController: UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "CollectionViewController"))
                                   })
        store[.watched] = UITab(title: "Watched",
                                image: UIImage(systemName: "checkmark"),
                                identifier: Tab.watched.rawValue,
                                viewControllerProvider: { _ in
                                    StyledNavigationController(rootViewController: UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "WatchedViewController"))
                                })
        store[.ratings] = UITab(title: "Ratings",
                                image: UIImage(systemName: "heart"),
                                identifier: Tab.ratings.rawValue,
                                viewControllerProvider: { _ in
                                    StyledNavigationController(rootViewController: UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "RatingsViewController"))
                                })
        store[.profile] = UITab(title: "Profile",
                                image: profileTabImage,
                                identifier: Tab.profile.rawValue,
                                viewControllerProvider: { _ in
                                    UIStoryboard(name: "Profile", bundle: nil).instantiateInitialViewController()!
                                })
        store[.calendar] = UITab(title: "Calendar",
                                 image: UIImage(systemName: "calendar.day.timeline.left"),
                                 identifier: Tab.calendar.rawValue,
                                 viewControllerProvider: { _ in
                                     UIStoryboard(name: "Calendar", bundle: nil).instantiateInitialViewController()!
                                 })
        store[.wall] = UITab(title: "Wall",
                             image: UIImage(systemName: "rectangle.grid.3x2"),
                             identifier: Tab.wall.rawValue,
                             viewControllerProvider: { _ in
                                 UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(withIdentifier: "wall")
                             })
        return store
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        updateTabBarMinimizeBehavior(neverMinimize: UserDefaults.standard.bool(forKey: "MainTabBarController.neverMinimize"))

        updateTabBar(animated: false)
        updateProfileTabImage(for: UserManager.shared.currentUser)

        if let userDefault = UserDefaults.standard.string(forKey: "MainTabBarController.selectedTab"),
           let tab = Tab(rawValue: userDefault),
           let uiTab = tabStore[tab],
           let index = tabs.firstIndex(of: uiTab) {
            selectedIndex = index
        }

        onTabBarChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateTabBar(animated: false)
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] settings in
            guard let self = self else { return }
            self.updateProfileTabImage(for: settings?.user)
        }.disposed(by: disposeBag)

        neverMinimizeTabBarReceiver.listen { [weak self] neverMinimize in
            guard let self = self else { return }
            self.updateTabBarMinimizeBehavior(neverMinimize: neverMinimize)
        }.disposed(by: disposeBag)

        updateWatchingItem()
        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _, _ in
            guard let self = self else { return }
            self.updateWatchingItem()
        }.disposed(by: disposeBag)

        delegate = self
    }

    private func updateProfileTabImage(for user: User?) {
        profileAvatarDownloadTask?.cancel()
        let avatarURL = user?.images?.avatar.full
        if avatarURL != profileAvatarURL {
            setProfileTabImage(UIImage(systemName: "person.crop.circle"))
        }
        profileAvatarURL = avatarURL

        guard let profileAvatarURL = profileAvatarURL else {
            return
        }

        let size = CGSize(width: 28, height: 28)
        let processor = RoundCornerImageProcessor(cornerRadius: size.height / 2.0,
                                                  targetSize: size)
        profileAvatarDownloadTask = KingfisherManager.shared.retrieveImage(with: profileAvatarURL,
                                                                           options: [.scaleFactor(traitCollection.displayScale), .processor(processor)]) { [weak self] result in
            guard case .success(let imageResult) = result else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                guard self.profileAvatarURL == profileAvatarURL else { return }
                self.setProfileTabImage(imageResult.image.withRenderingMode(.alwaysOriginal))
            }
        }
    }

    private func setProfileTabImage(_ image: UIImage?) {
        profileTabImage = image
        tabs.first(where: { $0.identifier == Tab.profile.rawValue })?.image = image
    }

    private func updateTabBarMinimizeBehavior(neverMinimize: Bool) {
        if neverMinimize {
            tabBarMinimizeBehavior = .never

            if #available(iOS 27.0, *) {
                prominentTabIdentifier = nil
            }
        } else {
            tabBarMinimizeBehavior = .onScrollDown

            if #available(iOS 27.0, *) {
                prominentTabIdentifier = Tab.search.rawValue
            }
        }
    }

    private func updateWatchingItem() {
        if WatchingManager.shared.watchingItem != nil {
            setBottomAccessory(UITabAccessory(contentView: checkinView),
                               animated: true)
        } else {
            setBottomAccessory(nil, animated: true)
        }
    }

    func resetDefault() {
        save(tabs: defaultTabBar)
        updateTabBar(animated: true)
    }

    fileprivate func updateTabBar(animated: Bool) {
        if customTabs == [Tab.browse] {
            isTabBarHidden = true
        } else {
            isTabBarHidden = false
        }
        let tabs: [UITab] = customTabs.map {
            tabStore[$0]!
        }
        if tabs == self.tabs { return }
        setTabs(tabs, animated: animated)
        contextMenus.removeAll()
        for item in tabBar.items! {
            updateContextMenu(for: item)
        }
    }

    @IBAction func unwindFromCommentComposer(segue: UIStoryboardSegue) {}

    private let defaultTabBar = [Tab.browse, Tab.toWatch, Tab.history, Tab.lists, Tab.search]

    private func updateContextMenu(for item: UITabBarItem) {
        guard let currentIndex = tabBar.items!.firstIndex(of: item) else { return }
        var tabPositions = customTabs
        if let control = item.value(forKey: "view") as? UIControl {
            let customizeTabs = UIAction(title: "Customize Tabs",
                                         image: UIImage(systemName: "slider.horizontal.3"),
                                         handler: { [weak self] _ in
                                             guard let self = self else { return }
                                             self.showTabBarCustomization()
                                         })
            var manageActions = [customizeTabs]
            switch tabPositions[safe: currentIndex] {
            case .purchase:
                break
            case .toWatch:
                let remove = UIAction(title: "Remove To Watch",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .history:
                let remove = UIAction(title: "Remove History",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .lists:
                let remove = UIAction(title: "Remove Lists",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .search:
                break
            case .profile:
                let remove = UIAction(title: "Remove Profile",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .watchlist:
                let remove = UIAction(title: "Remove Watchlist",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .recommended:
                let remove = UIAction(title: "Remove Favorites",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .collection:
                let remove = UIAction(title: "Remove Library",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .watched:
                let remove = UIAction(title: "Remove Watched",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .ratings:
                let remove = UIAction(title: "Remove Ratings",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .calendar:
                let remove = UIAction(title: "Remove Calendar",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .browse:
                let remove = UIAction(title: "Remove Browse",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)

                let hideTabBar = UIAction(title: "Hide Tab Bar",
                                          image: UIImage(systemName: "apps.iphone.badge.plus"),
                                          handler: { [weak self] _ in
                                              guard let self = self else { return }

                                              tabPositions = [Tab.browse]
                                              self.save(tabs: tabPositions)
                                              self.selectedIndex = 0
                                          })
                manageActions.append(hideTabBar)
            case .shelf:
                let remove = UIAction(title: "Remove Shelf",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .comments:
                let remove = UIAction(title: "Remove Comments",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .wall:
                let remove = UIAction(title: "Remove Wall",
                                      image: UIImage(systemName: "xmark.circle"),
                                      attributes: .destructive,
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          tabPositions.remove(at: currentIndex)
                                          self.save(tabs: tabPositions)
                                      })
                manageActions.append(remove)
            case .none:
                // if the current tab can't be found for some reason, stop the update
                return
            }

            var swapActions = [UIAction]()
            for (position, tab) in tabPositions.enumerated() where tabPositions[safe: currentIndex] != .search {
                if position == currentIndex { continue }
                switch tab {
                case .purchase:
                    continue
                case .toWatch:
                    let swapAction = UIAction(title: "Swap with To Watch",
                                              image: UIImage(systemName: "checklist"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .history:
                    let swapAction = UIAction(title: "Swap with History",
                                              image: UIImage(systemName: "memories"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .lists:
                    let swapAction = UIAction(title: "Swap with Lists",
                                              image: UIImage(systemName: "text.justify.left"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .search:
                    break
                case .profile:
                    let swapAction = UIAction(title: "Swap with Profile",
                                              image: UIImage(systemName: "person.crop.circle"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .watchlist:
                    let swapAction = UIAction(title: "Swap with Watchlist",
                                              image: UIImage(systemName: "bookmark"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .recommended:
                    let swapAction = UIAction(title: "Swap with Favorites",
                                              image: UIImage(systemName: "star"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .collection:
                    let swapAction = UIAction(title: "Swap with Library",
                                              image: UIImage(systemName: "book"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .watched:
                    let swapAction = UIAction(title: "Swap with Watched",
                                              image: UIImage(systemName: "checkmark"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .ratings:
                    let swapAction = UIAction(title: "Swap with Ratings",
                                              image: UIImage(systemName: "heart"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .calendar:
                    let swapAction = UIAction(title: "Swap with Calendar",
                                              image: UIImage(systemName: "calendar.day.timeline.left"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .browse:
                    let swapAction = UIAction(title: "Swap with Browse",
                                              image: UIImage(systemName: "sparkles.rectangle.stack"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .shelf:
                    let swapAction = UIAction(title: "Swap with Shelf",
                                              image: UIImage(systemName: "square.grid.3x1.below.line.grid.1x2"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .comments:
                    let swapAction = UIAction(title: "Swap with Comments",
                                              image: UIImage(systemName: "text.bubble"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                case .wall:
                    let swapAction = UIAction(title: "Swap with Wall",
                                              image: UIImage(systemName: "rectangle.grid.3x2"),
                                              handler: { [weak self] _ in
                                                  guard let self = self else { return }
                                                  tabPositions.swapAt(currentIndex, position)
                                                  self.save(tabs: tabPositions)
                                              })
                    swapActions.append(swapAction)
                }
            }
            var replaceActions = [UIAction]()
            for tab in Tab.allCases {
                if tabPositions.contains(tab) { continue }
                if tabPositions[safe: currentIndex] == .search { continue }

                switch tab {
                case .purchase:
                    continue
                case .toWatch:
                    let replaceAction = UIAction(title: "Replace with To Watch",
                                                 image: UIImage(systemName: "checklist"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .history:
                    let replaceAction = UIAction(title: "Replace with History",
                                                 image: UIImage(systemName: "memories"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .lists:
                    let replaceAction = UIAction(title: "Replace with Lists",
                                                 image: UIImage(systemName: "text.justify.left"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .search:
                    break
                case .profile:
                    let replaceAction = UIAction(title: "Replace with Profile",
                                                 image: UIImage(systemName: "person.crop.circle"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .watchlist:
                    let replaceAction = UIAction(title: "Replace with Watchlist",
                                                 image: UIImage(systemName: "bookmark"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .recommended:
                    let replaceAction = UIAction(title: "Replace with Favorites",
                                                 image: UIImage(systemName: "star"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .collection:
                    let replaceAction = UIAction(title: "Replace with Library",
                                                 image: UIImage(systemName: "book"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .watched:
                    let replaceAction = UIAction(title: "Replace with Watched",
                                                 image: UIImage(systemName: "checkmark"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .ratings:
                    let replaceAction = UIAction(title: "Replace with Ratings",
                                                 image: UIImage(systemName: "heart"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .calendar:
                    let replaceAction = UIAction(title: "Replace with Calendar",
                                                 image: UIImage(systemName: "calendar.day.timeline.left"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .wall:
                    let replaceAction = UIAction(title: "Replace with Wall",
                                                 image: UIImage(systemName: "rectangle.grid.3x2"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .shelf:
                    let replaceAction = UIAction(title: "Replace with Shelf",
                                                 image: UIImage(systemName: "square.grid.3x1.below.line.grid.1x2"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .comments:
                    let replaceAction = UIAction(title: "Replace with Comments",
                                                 image: UIImage(systemName: "text.bubble"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                case .browse:
                    let replaceAction = UIAction(title: "Replace with Browse",
                                                 image: UIImage(systemName: "sparkles.rectangle.stack"),
                                                 handler: { [weak self] _ in
                                                     guard let self = self else { return }
                                                     tabPositions.remove(at: currentIndex)
                                                     tabPositions.insert(tab, at: currentIndex)
                                                     self.save(tabs: tabPositions)
                                                     self.selectedIndex = currentIndex
                                                 })
                    replaceActions.append(replaceAction)
                }
            }

            let delegate = TabBarContextMenuInteractionDelegate(with: UIMenu(children: [UIMenu(options: .displayInline, children: manageActions),
                                                                                        UIMenu(options: .displayInline, children: swapActions),
                                                                                        UIMenu(options: .displayInline, children: replaceActions)]),
                                                                for: self)
            contextMenus.append(delegate)
            for interaction in control.interactions where interaction.isKind(of: UIContextMenuInteraction.self) {
                control.removeInteraction(interaction)
            }
            let interaction = UIContextMenuInteraction(delegate: delegate)
            control.addInteraction(interaction)
        }
    }

    private func showTabBarCustomization() {
        let storyboard = UIStoryboard(name: "Profile", bundle: nil)
        guard let viewController = storyboard.instantiateViewController(withIdentifier: "TabBarCustomization") as? TabBarCustomizationViewController else { return }

        let navigationController = StyledNavigationController(rootViewController: viewController)
        viewController.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                                          target: self,
                                                                          action: #selector(dismissTabBarCustomization))
        present(navigationController, animated: true)
    }

    @objc
    private func dismissTabBarCustomization() {
        dismiss(animated: true)
    }

    private func save(tabs: [Tab]) {
        if let encoded = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(encoded, forKey: "MainTabBarController.tab.positions")
            UserDefaults.standard.synchronize()
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    private var customTabs: [Tab] {
        guard let data = UserDefaults.standard.value(forKey: "MainTabBarController.tab.positions") as? Data,
              let decodedData = try? JSONDecoder().decode([Tab].self, from: data) else {
            return defaultTabBar
        }
        return decodedData
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelectTab tab: UITab) -> Bool {
        let viewController = tab.viewController!

        if selectedTab == tab {
            if tab.identifier == Tab.toWatch.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController {
                    if let toWatchViewController = navigationController.topViewController as? ToWatchViewController {
                        if toWatchViewController.currentType == .episodes {
                            toWatchViewController.currentType = .movies
                        } else {
                            toWatchViewController.currentType = .episodes
                        }
                    }
                }
            } else if tab.identifier == Tab.watchlist.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let watchlistViewController = navigationController.topViewController as? WatchlistViewController {
                    watchlistViewController.cycleFilter()
                }
            } else if tab.identifier == Tab.recommended.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let userFavoritesViewController = navigationController.topViewController as? UserFavoritesViewController {
                    userFavoritesViewController.cycleFilter()
                }
            } else if tab.identifier == Tab.collection.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let collectionViewController = navigationController.topViewController as? CollectionViewController {
                    collectionViewController.cycleFilter()
                }
            } else if tab.identifier == Tab.watched.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let watchedViewController = navigationController.topViewController as? WatchedViewController {
                    watchedViewController.cycleFilter()
                }
            } else if tab.identifier == Tab.ratings.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let ratingsViewController = navigationController.topViewController as? RatingsViewController {
                    ratingsViewController.cycleFilter()
                }
            } else if tab.identifier == Tab.calendar.rawValue {
                if let navigationController = viewController as? UINavigationController, let calendarViewController = navigationController.topViewController as? CalendarViewController {
                    calendarViewController.scrollToClosestToNow(animated: true)
                }
            } else if tab.identifier == Tab.search.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else if let navigationController = viewController as? UINavigationController,
                          let searchViewController = navigationController.topViewController as? SearchViewController {
                    searchViewController.focusSearchField()
                }
            } else if tab.identifier == Tab.browse.rawValue {
                if shouldScrollToTop(view: viewController.view) {
                    scrollToTop(view: viewController.view)
                } else {
                    if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.freeConfig {
                        // do nothing
                    } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.defaultConfig {
                        BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.showsConfig
                    } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.showsConfig {
                        BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.moviesConfig
                    } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.moviesConfig {
                        BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.newAndHot
                    } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.newAndHot {
                        BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.shelfConfig
                    } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.shelfConfig {
                        BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.defaultConfig
                    }
                }
            } else {
                scrollToTop(view: viewController.view)
            }
        }

        return true
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelectTab tab: UITab, previousTab: UITab?) {
        UserDefaults.standard.set(tab.identifier, forKey: "MainTabBarController.selectedTab")
        UserDefaults.standard.synchronize()

        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func shouldScrollToTop(view: UIView) -> Bool {
        if let scrollView = view as? UIScrollView {
            if (scrollView.adjustedContentInset.top + scrollView.contentOffset.y) == 0 {
                return false
            } else {
                return true
            }
        } else {
            for v in view.subviews {
                return shouldScrollToTop(view: v)
            }
            return false
        }
    }

    private func scrollToTop(view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
            return
        }
        for v in view.subviews {
            scrollToTop(view: v)
        }
    }
}

private final class TabBarContextMenuInteractionDelegate: NSObject, UIContextMenuInteractionDelegate {
    init(with menu: UIMenu, for tabBarController: MainTabBarController) {
        self.menu = menu
        self.tabBarController = tabBarController
    }

    private let menu: UIMenu
    private weak var tabBarController: MainTabBarController?

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: nil,
                                          actionProvider: { [weak self] _ in
                                              guard let self = self else { return nil }
                                              return self.menu
                                          })
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let view = interaction.view else { return nil }

        let parameters = UIPreviewParameters()
        return UITargetedPreview(view: view, parameters: parameters)
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let view = interaction.view else { return nil }
        guard let tabBarController = tabBarController else { return nil }

        tabBarController.updateTabBar(animated: true)

        guard view.window != nil else { return nil }

        let parameters = UIPreviewParameters()
        return UITargetedPreview(view: view, parameters: parameters)
    }
}
