//
//  SideBarViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 22/07/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

class SidebarViewController: UIViewController {
    private let disposeBag = DisposeBag()

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
    private var collectionView: UICollectionView!
    private var secondaryViewControllers = [UIViewController]()

    private let checkinView = CheckinView()

    private func subtitle(for list: List) -> String {
        return "\(list.itemCount ?? 0) \((list.itemCount ?? 0) <= 1 ? "item" : "items")"
    }

    private var lists = [List]() {
        didSet {
            var sectionSnapshot = dataSource.snapshot(for: .customLists)
            sectionSnapshot.deleteAll()

            sectionSnapshot.append([Item(title: Section.customLists.rawValue, subtitle: nil, image: nil)])

            var customListItems = [Item]()
            for list in lists {
                switch list.privacy {
                case .all:
                    customListItems.append(Item(title: list.name.emojiUnescapedString,
                                                subtitle: subtitle(for: list),
                                                image: UIImage(systemName: "globe")))
                case .me:
                    customListItems.append(Item(title: list.name.emojiUnescapedString,
                                                subtitle: subtitle(for: list),
                                                image: UIImage(systemName: "lock")))
                case .friends:
                    customListItems.append(Item(title: list.name.emojiUnescapedString,
                                                subtitle: subtitle(for: list),
                                                image: UIImage(systemName: "lock.open")))
                case .link:
                    customListItems.append(Item(title: list.name.emojiUnescapedString,
                                                subtitle: subtitle(for: list),
                                                image: UIImage(systemName: "link")))
                case .unknown:
                    customListItems.append(Item(title: list.name.emojiUnescapedString,
                                                subtitle: subtitle(for: list),
                                                image: UIImage()))
                }
            }

            sectionSnapshot.append(customListItems, to: sectionSnapshot.items[0])
            if UserDefaults.standard.bool(forKey: "ListsSideBarExpanded") {
                sectionSnapshot.expand([sectionSnapshot.items[0]])
            }
            dataSource.apply(sectionSnapshot, to: .customLists, animatingDifferences: true, completion: nil)
        }
    }

    private var likedLists = [List]() {
        didSet {
            var sectionSnapshot = dataSource.snapshot(for: .likedLists)
            sectionSnapshot.deleteAll()

            sectionSnapshot.append([Item(title: Section.likedLists.rawValue, subtitle: nil, image: nil)])

            var likedListItems = [Item]()
            for list in likedLists {
                switch list.privacy {
                case .all:
                    likedListItems.append(Item(title: list.name.emojiUnescapedString,
                                               subtitle: "by \(list.user.username) · \(subtitle(for: list))",
                                               image: UIImage(systemName: "globe")))
                case .me:
                    likedListItems.append(Item(title: list.name.emojiUnescapedString,
                                               subtitle: "by \(list.user.username) · \(subtitle(for: list))",
                                               image: UIImage(systemName: "lock")))
                case .friends:
                    likedListItems.append(Item(title: list.name.emojiUnescapedString,
                                               subtitle: "by \(list.user.username) · \(subtitle(for: list))",
                                               image: UIImage(systemName: "lock.open")))
                case .link:
                    likedListItems.append(Item(title: list.name.emojiUnescapedString,
                                               subtitle: "by \(list.user.username) · \(subtitle(for: list))",
                                               image: UIImage(systemName: "link")))
                case .unknown:
                    likedListItems.append(Item(title: list.name.emojiUnescapedString,
                                               subtitle: "by \(list.user.username) · \(subtitle(for: list))",
                                               image: UIImage()))
                }
            }

            sectionSnapshot.append(likedListItems, to: sectionSnapshot.items[0])
            if UserDefaults.standard.bool(forKey: "LikedListsSideBarExpanded") {
                sectionSnapshot.expand([sectionSnapshot.items[0]])
            }
            dataSource.apply(sectionSnapshot, to: .likedLists, animatingDifferences: true, completion: nil)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = nil

        configureHierarchy()
        configureDataSource()
        addNavigationButtons()

        PurchaseManager.shared.onPurchasedChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updatePurchasedState()
                self.collectionView.reloadData()
                self.updateSelection()
            }
        }.disposed(by: disposeBag)

        onCustomListsChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            self.lists = lists
        }.disposed(by: disposeBag)

        onLikedListsChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            self.likedLists = lists
        }.disposed(by: disposeBag)

        commandReceiver.listen { keyCommand in
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                ListsManager.shared.refresh()
            }
        }.disposed(by: disposeBag)

        updatePurchasedState()
        collectionView.reloadData()

        checkinView.isHidden = true

        WatchingManager.shared.onWatchingItemChangedReceiver.listen { [weak self] watchingItem, _ in
            guard let self = self else { return }
            if watchingItem != nil {
                checkinView.interactions.removeAll()

                let interaction = UIScrollEdgeElementContainerInteraction()
                interaction.scrollView = collectionView
                interaction.edge = .bottom
                checkinView.addInteraction(interaction)

                collectionView.bottomEdgeEffect.style = .soft
                collectionView.bottomEdgeEffect.isHidden = false

                checkinView.isHidden = false

                collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 48, right: 0)
                collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 48, right: 0)
            } else {
                checkinView.interactions.removeAll()
                collectionView.bottomEdgeEffect.isHidden = true

                checkinView.isHidden = true

                collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
                collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            }
        }.disposed(by: disposeBag)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateSelection()
    }

    private func updatePurchasedState() {
        let shelfViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(identifier: "standalone browse") as! BrowseViewController
        shelfViewController.followsShelfConfig = true
        let ratingsViewController: UIViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(identifier: "RatingsViewController")

        secondaryViewControllers = [
            UIStoryboard(name: "Browse", bundle: nil).instantiateInitialViewController()!,
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "To Watch"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Activities"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Lists"),
            UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Search"),
            StyledNavigationController(rootViewController: CommentsTabViewController()),
            UIStoryboard(name: "Calendar", bundle: nil).instantiateInitialViewController()!,
            StyledNavigationController(rootViewController: shelfViewController),
            UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(withIdentifier: "wall"),
            StyledNavigationController(rootViewController: ratingsViewController)
        ]
    }

    private func updateSelection() {
        let section = UserDefaults.standard.integer(forKey: "SidebarViewController.selectedIndex.section")
        let row = UserDefaults.standard.integer(forKey: "SidebarViewController.selectedIndex.row")
        var indexPath = IndexPath(row: row, section: section)

        if collectionView.cellForItem(at: indexPath) == nil {
            if let firstIndexPath = collectionView.indexPathsForVisibleItems.first {
                indexPath = firstIndexPath
            } else {
                return // do not select anything
            }
        }

        collectionView.selectItem(at: indexPath,
                                  animated: false,
                                  scrollPosition: UICollectionView.ScrollPosition.centeredVertically)
        if indexPath.section == 3 {
            // if it's a list, we check the number of lists
            if indexPath.row <= lists.count {
                collectionView(collectionView,
                               didSelectItemAt: indexPath)
            } else {
                collectionView(collectionView,
                               didSelectItemAt: IndexPath(row: 3, section: 0))
            }
        } else if indexPath.section == 4 {
            // if it's a liked list, we check the number of likedLists
            if indexPath.row <= likedLists.count {
                collectionView(collectionView,
                               didSelectItemAt: indexPath)
            } else {
                collectionView(collectionView,
                               didSelectItemAt: IndexPath(row: 3, section: 0))
            }
        } else {
            collectionView(collectionView,
                           didSelectItemAt: IndexPath(row: row, section: section))
        }
    }

    let column: UISplitViewController.Column = .secondary

    private func setSupplementaryView(index: Int) {
        if index < 0 {
            let indexPath = IndexPath(row: 0, section: 0)
            collectionView.selectItem(at: indexPath,
                                      animated: false,
                                      scrollPosition: UICollectionView.ScrollPosition.centeredVertically)
            splitViewController?.setViewController(secondaryViewControllers.first, for: column)
            return
        }

        if index >= secondaryViewControllers.count {
            splitViewController?.setViewController(secondaryViewControllers.last, for: column)
        } else {
            splitViewController?.setViewController(secondaryViewControllers[index], for: column)
        }
    }

    private func addNavigationButtons() {
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
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(settings(_:)) { return true }
        return false
    }

    @objc private func settings(_ sender: UIKeyCommand) {
        openSettings()
    }

    @objc private func openSettings() {
        let settings = UIStoryboard(name: "Profile", bundle: nil).instantiateViewController(identifier: "Settings")
        present(settings, animated: true, completion: nil)
    }
}

// MARK: - Layout

extension SidebarViewController {
    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { section, layoutEnvironment in
            var config = UICollectionLayoutListConfiguration(appearance: .sidebar)
            config.headerMode = section <= 1 ? .none : .firstItemInSection
            config.showsSeparators = false
            return NSCollectionLayoutSection.list(using: config, layoutEnvironment: layoutEnvironment)
        }
    }
}

// MARK: - Data

extension SidebarViewController {
    private func configureHierarchy() {
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: createLayout())
        collectionView.isScrollEnabled = true
        collectionView.delegate = self
        collectionView.dropDelegate = self

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        checkinView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(collectionView)
        collectionView.addSubview(checkinView)

        // Fixed height for the checkinView; adjust if you prefer a different height
        let checkinHeight: CGFloat = 48

        NSLayoutConstraint.activate([
            // Collection view constraints
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Checkin view constraints
            checkinView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            checkinView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            checkinView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            checkinView.heightAnchor.constraint(equalToConstant: checkinHeight)
        ])
    }

    private func configureDataSource() {
        // Configuring cells

        let headerRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var content = UIListContentConfiguration.header()
            content.text = item.title
//            content.textProperties.font = UIFont.preferredFont(forTextStyle: .headline)
            cell.contentConfiguration = content

            let background = UIBackgroundConfiguration.listCell()
            cell.backgroundConfiguration = background

            cell.accessories = [.outlineDisclosure()]
        }

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            #if targetEnvironment(macCatalyst)
            var content = UIListContentConfiguration.cell() // Mac
            if let tooltip = item.subtitle {
                let toolTipInteraction = UIToolTipInteraction(defaultToolTip: tooltip)
                cell.addInteraction(toolTipInteraction)
            }
            cell.tintColor = UIColor(asset: .safeGlobalTint)
            #else
            var content = UIListContentConfiguration.subtitleCell() // iPad
            content.secondaryText = item.subtitle
            #endif
            content.text = item.title
            content.image = item.image
            content.textProperties.adjustsFontSizeToFitWidth = false
            cell.contentConfiguration = content

            let background = UIBackgroundConfiguration.listCell()
            cell.backgroundConfiguration = background

            cell.accessories = []
        }

        // Creating the datasource

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, item: Item) -> UICollectionViewCell? in
            if indexPath.item == 0 && indexPath.section > 1 {
                return collectionView.dequeueConfiguredReusableCell(using: headerRegistration, for: indexPath, item: item)
            } else {
                return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: item)
            }
        }

        dataSource.sectionSnapshotHandlers.willExpandItem = { item in
            let indexPath = self.dataSource.indexPath(for: item)
            if indexPath?.section == 2 { UserDefaults.standard.set(true, forKey: "LibrarySideBarExpanded") }
            if indexPath?.section == 3 { UserDefaults.standard.set(true, forKey: "ListsSideBarExpanded") }
            if indexPath?.section == 4 { UserDefaults.standard.set(true, forKey: "LikedListsSideBarExpanded") }
            UserDefaults.standard.synchronize()
        }

        dataSource.sectionSnapshotHandlers.willCollapseItem = { item in
            let indexPath = self.dataSource.indexPath(for: item)
            if indexPath?.section == 2 { UserDefaults.standard.set(false, forKey: "LibrarySideBarExpanded") }
            if indexPath?.section == 3 { UserDefaults.standard.set(false, forKey: "ListsSideBarExpanded") }
            if indexPath?.section == 4 { UserDefaults.standard.set(false, forKey: "LikedListsSideBarExpanded") }
            UserDefaults.standard.synchronize()
        }

        // Creating and applying snapshots

        let sections: [Section] = [.tabs, .moreTabs, .lists, .customLists, .likedLists]
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        dataSource.apply(snapshot, animatingDifferences: false)

        for section in sections {
            switch section {
            case .tabs:
                var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                sectionSnapshot.append(tabsItems)
                dataSource.apply(sectionSnapshot, to: section)
            case .moreTabs:
                var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                sectionSnapshot.append(moreTabsItems)
                dataSource.apply(sectionSnapshot, to: section)
            case .lists:
                let headerItem = Item(title: section.rawValue, subtitle: nil, image: nil)
                var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                sectionSnapshot.append([headerItem])
                sectionSnapshot.append(listItems, to: headerItem)
                if UserDefaults.standard.bool(forKey: "LibrarySideBarExpanded") {
                    sectionSnapshot.expand([headerItem])
                }
                dataSource.apply(sectionSnapshot, to: section)
            case .customLists:
                let headerItem = Item(title: section.rawValue, subtitle: nil, image: nil)
                var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                sectionSnapshot.append([headerItem])
                if UserDefaults.standard.bool(forKey: "ListsSideBarExpanded") {
                    sectionSnapshot.expand([headerItem])
                }
                dataSource.apply(sectionSnapshot, to: section)
            case .likedLists:
                let headerItem = Item(title: section.rawValue, subtitle: nil, image: nil)
                var sectionSnapshot = NSDiffableDataSourceSectionSnapshot<Item>()
                sectionSnapshot.append([headerItem])
                if UserDefaults.standard.bool(forKey: "LikedListsSideBarExpanded") {
                    sectionSnapshot.expand([headerItem])
                }
                dataSource.apply(sectionSnapshot, to: section)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension SidebarViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, canFocusItemAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 2 && indexPath.row == 0 { return false }
        if indexPath.section == 3 && indexPath.row == 0 { return false }
        if indexPath.section == 4 && indexPath.row == 0 { return false }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer {
            UserDefaults.standard.synchronize()
        }

        UserDefaults.standard.set(indexPath.section, forKey: "SidebarViewController.selectedIndex.section")
        UserDefaults.standard.set(indexPath.row, forKey: "SidebarViewController.selectedIndex.row")

        if indexPath.section == 0 {
            guard secondaryViewControllers.indices.contains(indexPath.row) else { return }
            if let navigationController = splitViewController?.viewController(for: column) as? UINavigationController,
               navigationController == secondaryViewControllers[indexPath.row] {
                handleReselection(of: navigationController, secondaryViewControllerIndex: indexPath.row)
            } else {
                setSupplementaryView(index: indexPath.row)
            }
        } else if indexPath.section == 1 {
            let secondaryViewControllerIndex = tabsItems.count + indexPath.row
            guard secondaryViewControllers.indices.contains(secondaryViewControllerIndex) else { return }
            if let navigationController = splitViewController?.viewController(for: column) as? UINavigationController,
               navigationController == secondaryViewControllers[secondaryViewControllerIndex] {
                handleReselection(of: navigationController, secondaryViewControllerIndex: secondaryViewControllerIndex)
            } else {
                setSupplementaryView(index: secondaryViewControllerIndex)
            }
        } else if indexPath.section == 2 {
            if indexPath.row == 1 {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set("watchlist", forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            } else if indexPath.row == 2 {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set("recommended", forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            } else if indexPath.row == 3 {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set("collection", forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            } else if indexPath.row == 4 {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set("watched", forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            } else { // 5
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set("collaborations", forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            }
            let listsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Lists")
            guard let navigationController = listsViewController as? UINavigationController else { return }
            navigationController.topViewController?.loadViewIfNeeded()
            splitViewController?.setViewController(listsViewController, for: column)
            navigationController.topViewController?.navigationItem.hidesBackButton = true
        } else if indexPath.section == 3 {
            let listIndex = indexPath.row - 1
            guard lists.indices.contains(listIndex) else { return }
            let list = lists[listIndex]
            if let encoded = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set(encoded, forKey: "CustomListsViewController.customList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.standardList")
            }
            let listsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Lists")
            guard let navigationController = listsViewController as? UINavigationController else { return }
            navigationController.topViewController?.loadViewIfNeeded()
            splitViewController?.setViewController(listsViewController, for: column)
            navigationController.topViewController?.navigationItem.hidesBackButton = true
        } else if indexPath.section == 4 {
            let listIndex = indexPath.row - 1
            guard likedLists.indices.contains(listIndex) else { return }
            let list = likedLists[listIndex]
            if let encoded = try? JSONEncoder().encode(list) {
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set(encoded, forKey: "CustomListsViewController.customList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.standardList")
            }
            let listsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "Lists")
            guard let navigationController = listsViewController as? UINavigationController else { return }
            navigationController.topViewController?.loadViewIfNeeded()
            splitViewController?.setViewController(listsViewController, for: column)
            navigationController.topViewController?.navigationItem.hidesBackButton = true
        }
    }

    private func handleReselection(of navigationController: UINavigationController, secondaryViewControllerIndex: Int) {
        switch secondaryViewControllerIndex {
        case 0:
            if shouldScrollToTop(view: navigationController.view) {
                scrollToTop(view: navigationController.view)
            } else {
                cycleBrowseConfig()
            }
        case 1:
            if shouldScrollToTop(view: navigationController.view) {
                scrollToTop(view: navigationController.view)
            } else if let toWatchViewController = navigationController.topViewController as? ToWatchViewController {
                switch toWatchViewController.currentType {
                case .episodes:
                    toWatchViewController.currentType = .movies
                case .movies:
                    toWatchViewController.currentType = .episodes
                }
            } else {
                navigationController.popToRootViewController(animated: true)
            }
        case 4:
            ShortcutManager.shared.shouldHandle(shortcut: ShortcutManager.shared.searchAndKeyboardShortcutItem)
            if SessionManager.shared.isLoggedIn,
               DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
            }
        case 6:
            if let calendarViewController = navigationController.topViewController as? CalendarViewController {
                calendarViewController.scrollToClosestToNow(animated: true)
            } else {
                navigationController.popToRootViewController(animated: true)
            }
        case 9:
            if shouldScrollToTop(view: navigationController.view) {
                scrollToTop(view: navigationController.view)
            } else if let ratingsViewController = navigationController.topViewController as? RatingsViewController {
                ratingsViewController.cycleFilter()
            } else {
                navigationController.popToRootViewController(animated: true)
            }
        default:
            navigationController.popToRootViewController(animated: true)
        }
    }

    private func cycleBrowseConfig() {
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

    private func shouldScrollToTop(view: UIView) -> Bool {
        if let scrollView = view as? UIScrollView {
            return (scrollView.adjustedContentInset.top + scrollView.contentOffset.y) != 0
        } else {
            for subview in view.subviews {
                return shouldScrollToTop(view: subview)
            }
            return false
        }
    }

    private func scrollToTop(view: UIView) {
        if let scrollView = view as? UIScrollView {
            scrollView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
            return
        }
        for subview in view.subviews {
            scrollToTop(view: subview)
        }
    }
}

// MARK: - Structs and sample data

struct Item: Hashable {
    let title: String?
    let subtitle: String?
    let image: UIImage?
    private let identifier = UUID()
}

let tabsItems = [Item(title: "Browse", subtitle: nil, image: UIImage(systemName: "sparkles.rectangle.stack")),
                 Item(title: "To Watch", subtitle: nil, image: UIImage(systemName: "checklist")),
                 Item(title: "History", subtitle: nil, image: UIImage(systemName: "memories")),
                 Item(title: "Lists", subtitle: nil, image: UIImage(systemName: "text.justify.left")),
                 Item(title: "Search", subtitle: nil, image: UIImage(systemName: "magnifyingglass"))]

let moreTabsItems = [Item(title: "Comments", subtitle: nil, image: UIImage(systemName: "text.bubble")),
                     Item(title: "Calendar", subtitle: nil, image: UIImage(systemName: "calendar.day.timeline.left")),
                     Item(title: "Shelf", subtitle: nil, image: UIImage(systemName: "square.grid.3x1.below.line.grid.1x2")),
                     Item(title: "Wall", subtitle: nil, image: UIImage(systemName: "rectangle.grid.3x2")),
                     Item(title: "Ratings", subtitle: nil, image: UIImage(systemName: "heart"))]

let listItems = [Item(title: "Watchlist", subtitle: nil, image: UIImage(systemName: "bookmark")),
                 Item(title: "Favorites", subtitle: nil, image: UIImage(systemName: "star")),
                 Item(title: "Library", subtitle: nil, image: UIImage(systemName: "book")),
                 Item(title: "Watched", subtitle: nil, image: UIImage(systemName: "checkmark")),
                 Item(title: "Collaborations", subtitle: nil, image: UIImage(systemName: "person.2"))]

private enum Section: String {
    case tabs
    case moreTabs
    case lists = "Your Lists"
    case customLists = "Custom Lists"
    case likedLists = "Liked Lists"
}

extension SidebarViewController: UICollectionViewDropDelegate {
    func collectionView(_ collectionView: UICollectionView, shouldSpringLoadItemAt indexPath: IndexPath, with context: UISpringLoadedInteractionContext) -> Bool {
        if indexPath.section == 2 && indexPath.row == 5 {
            return true
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        for item in session.items where item.itemProvider.canLoadObject(ofClass: NSURL.self) {
            return true
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        for visibleCell in collectionView.visibleCells {
            visibleCell.isSelected = false
        }
        guard let destinationIndexPath = destinationIndexPath else { return UICollectionViewDropProposal(operation: .cancel) }
        if destinationIndexPath.row == 0 {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        if destinationIndexPath.section == 0 {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        if destinationIndexPath.section == 1 {
            return UICollectionViewDropProposal(operation: .cancel)
        }

        // Watched (can't drop)
        if destinationIndexPath.section == 2 && destinationIndexPath.row == 4 {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Collaborations (can't drop)
        if destinationIndexPath.section == 2 && destinationIndexPath.row == 5 {
            return UICollectionViewDropProposal(operation: .cancel)
        }
        // Liked Lists section header row (can't drop)
        if destinationIndexPath.section == 4 && destinationIndexPath.row == 0 {
            return UICollectionViewDropProposal(operation: .cancel)
        }

        collectionView.cellForItem(at: destinationIndexPath)?.isSelected = true
        return UICollectionViewDropProposal(operation: .copy)
    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        for visibleCell in collectionView.visibleCells {
            visibleCell.isSelected = false
        }

        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        if destinationIndexPath.section == 2 {
            if destinationIndexPath.row == 1 {
                addToWatchlist(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
            } else if destinationIndexPath.row == 2 {
                addToRecommendations(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
            } else {
                addToCollection(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
            }
        }
        if destinationIndexPath.section == 3 {
            add(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel }, to: lists[destinationIndexPath.row - 1])
        }
        if destinationIndexPath.section == 4 {
            // Do nothing, can't add to liked lists
        }
    }

    private func add(models: [MediaModel], to list: List) {
        SwiftMessages.show(message: "Adding to List...", style: .loading)

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            MediaModel.addShowsToWatchlistUndercover(medias: models)
        }

        TraktAPIProvider.provider.request(.addToList(id: list.identifiers.trakt!,
                                                     item: WatchlistedItem(models: models)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Add to list successful \(response)")

                    DispatchQueue.main.async {
                        onListChangedTransmitter.broadcast([list])
                        SwiftMessages.show(message: "✅ Added \(models.count) to list")
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                }
            }
        }
    }

    private func addToCollection(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Library...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToCollection(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Library successful \(response)")

                    DispatchQueue.main.async {
                        CollectionManager.shared.refresh()
                        SwiftMessages.show(message: "📚 Added \(models.count) to Library")
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    private func addToRecommendations(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Favorites...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Recommendation successful \(response)")

                    DispatchQueue.main.async {
                        UserFavoritesManager.shared.refresh()
                        SwiftMessages.show(message: "⭐️ Added \(models.count) to Favorites")
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    private func addToWatchlist(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Watchlist...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToWatchlist(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Add to watchlist successful \(response)")

                    DispatchQueue.main.async {
                        WatchlistManager.shared.refresh()
                        SwiftMessages.show(message: "🕒 Added \(models.count) to Watchlist")
                    }

                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                }
            }
        }
    }
}
