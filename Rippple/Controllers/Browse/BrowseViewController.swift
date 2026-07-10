//
//  BrowseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 16/06/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import SafariServices
import SwiftUI
import UIKit

final class BrowseViewController: UITableViewController {
    struct ModuleType: Codable, Equatable, Hashable {
        let module: String
        let filter: SavedFilter
        let buttonStyle: ShelfBrowseActionButtonStyle?

        init(module: String, filter: SavedFilter, buttonStyle: ShelfBrowseActionButtonStyle? = nil) {
            self.module = module
            self.filter = filter
            self.buttonStyle = buttonStyle
        }
    }

    var model: String! = BrowseConfigManager.shared.currentConfig {
        didSet {
            let scrollToTop = !onlyActionButtonStyleChanged(from: oldValue, to: model)
            Task {
                await reloadData(scrollToTop: scrollToTop)
            }
        }
    }

    var followsShelfConfig = false {
        didSet {
            if followsShelfConfig {
                model = BrowseConfigManager.shared.shelfConfig
            }
        }
    }

    private var displayedRootModule: String? {
        guard let model else { return nil }

        do {
            let jsonString = "[\(model.components(separatedBy: .newlines).joined(separator: ","))]"
            let jsonData = jsonString.data(using: .utf8)!
            return try JSONDecoder().decode([ModuleType].self, from: jsonData).first?.module
        } catch {
            return nil
        }
    }

    private var isDisplayingShelf: Bool {
        displayedRootModule == "Shelf"
    }

    private var isDisplayingNewAndHot: Bool {
        displayedRootModule == "This Week"
    }

    private func onlyActionButtonStyleChanged(from oldModel: String?, to newModel: String?) -> Bool {
        guard let oldModel, let newModel else { return false }

        do {
            let oldModules = try modules(from: oldModel)
            let newModules = try modules(from: newModel)
            guard oldModules.count == newModules.count else { return false }

            var buttonStyleChanged = false
            for (oldModule, newModule) in zip(oldModules, newModules) {
                guard oldModule.module == newModule.module,
                      oldModule.filter == newModule.filter else {
                    return false
                }
                if oldModule.buttonStyle != newModule.buttonStyle {
                    buttonStyleChanged = true
                }
            }
            return buttonStyleChanged
        } catch {
            return false
        }
    }

    private func modules(from model: String) throws -> [ModuleType] {
        let jsonString = "[\(model.components(separatedBy: .newlines).joined(separator: ","))]"
        let jsonData = jsonString.data(using: .utf8)!
        return try JSONDecoder().decode([ModuleType].self, from: jsonData)
    }

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()

    @IBOutlet var loadingView: UIView!
    @IBOutlet var animationViewContainer: NVActivityIndicatorView!

    @IBOutlet var menuBarButtonItem: UIBarButtonItem?

    enum Section: Hashable {
        case content
        case loading
        case empty
    }

    enum Wrapper: Hashable {
        case empty
        case loading
        case header(String, SavedFilter, ModuleType)
        case content(String, SavedFilter, ModuleType)
        case inReview
        case weeklyTrackerLink
    }

    private class BrowseViewDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private lazy var dataSource = BrowseViewDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, wrapper in
        guard let self = self else { return nil }

        switch wrapper {
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        case .header(let title, let savedFilter, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = title
            cell.title.textColor = .label

            if (savedFilter.path.isEmpty ||
                self.isDisplayingNewAndHot ||
                (savedFilter.section == "movies,shows" &&
                    !["/media/trending", "/all/trending"].contains(savedFilter.path))) &&
                savedFilter.section != "episodes_to_watch" &&
                savedFilter.section != "movies_to_watch" &&
                savedFilter.section != "pinned_to_watch" &&
                savedFilter.section != "unpinned_to_watch" &&
                savedFilter.section != "History" {
                cell.chevron?.isHidden = true
            } else {
                cell.chevron?.isHidden = false
            }

            if self.isDisplayingShelf {
                if cell.gestureRecognizers?.contains(where: { $0 is BrowseLongPressGestureRecognizer }) != true {
                    let longPress = BrowseLongPressGestureRecognizer(target: self, action: #selector(self.headerLongPressed(_:)))
                    longPress.minimumPressDuration = 0.5
                    cell.addGestureRecognizer(longPress)
                }
            }

            return cell
        case .empty:
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = "🪴"
            cell.title.text = "Your Shelf is Empty"
            cell.subtitle.text = ""
            cell.subtitle.isHidden = true
            cell.body.text = "Add something to your Shelf, find it back here. \nYou build your Shelf the way you want to, \nyou're in charge!"
            cell.action.isHidden = true
            return cell
        case .content(let identifier, let filter, let moduleType):
            if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? BrowseTableViewCell {
                cell.presentingViewController = self
                cell.actionButtonStyle = moduleType.buttonStyle ?? .none
                cell.savedFilter = filter
                return cell
            } else if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? GenresBrowseTableViewCell {
                cell.presentingViewController = self
                cell.service = filter.section == "genres-shows" ? .tvGenres : .movieGenres
                return cell
            } else if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? CommentsBrowseTableViewCell {
                cell.presentingViewController = self
                cell.loadItems()
                return cell
            } else if let cell = tableView.dequeueReusableCell(withIdentifier: identifier) as? ServicesBrowseTableViewCell {
                cell.presentingViewController = self
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
                cell.emoji.text = "🚧"
                cell.title.text = "This shouldn't happen"
                cell.subtitle.text = ""
                cell.subtitle.isHidden = true
                cell.body.text = "Your shelf is broken.\nIt's not you it's me.\nPlease contact by builder."
                cell.action.isHidden = true
                return cell
            }
        case .inReview:
            let cell = tableView.dequeueReusableCell(withIdentifier: "inReview") ?? UITableViewCell(style: .default, reuseIdentifier: "inReview")
            cell.selectionStyle = .none
            cell.contentConfiguration = UIHostingConfiguration {
                InReviewView()
            }.margins(.vertical, 16)
                .margins(.horizontal, 12)
            return cell
        case .weeklyTrackerLink:
            return tableView.dequeueReusableCell(withIdentifier: "browse link")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, do not show a left bar button item.
        navigationItem.leftBarButtonItem = nil
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
        }
        #endif

        // not the first thing in the navigation controller, remove the profile
        if navigationController?.viewControllers.first != self {
            navigationItem.leftBarButtonItem = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource.defaultRowAnimation = .fade

        navigationItem.style = .browser
        title = "Browse"
        if menuBarButtonItem != nil {
            navigationItem.subtitle = "Loading..."
        }
        configureProfileBarButtonItem()

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "BrowseHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.register(UINib(nibName: "L1BrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "L1")
        tableView.register(UINib(nibName: "L2BrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "L2")
        tableView.register(UINib(nibName: "L3BrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "L3")
        tableView.register(UINib(nibName: "CarouselBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "C1")
        tableView.register(UINib(nibName: "TopBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "T1")
        tableView.register(ListBrowseTableViewCell.self, forCellReuseIdentifier: "List")
        tableView.register(UINib(nibName: "ToWatchBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "ToWatch")
        tableView.register(UINib(nibName: "HistoryBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "History")
        tableView.register(UINib(nibName: "GenresBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "Genres")
        tableView.register(UINib(nibName: "CommentsBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "Comments")
        tableView.register(UINib(nibName: "ServicesBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "Services")
        tableView.register(UINib(nibName: "BrowseLinkCardViewCell", bundle: nil), forCellReuseIdentifier: "browse link")
        tableView.register(UINib(nibName: "LandscapeBrowseTableViewCell", bundle: nil), forCellReuseIdentifier: "G1")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "inReview")

        tableView.dataSource = dataSource
        tableView.delegate = self

        tableView.separatorStyle = .none

        Task {
            await reloadData()
        }

        menuBarButtonItem?.primaryAction = nil
        menuBarButtonItem?.menu = menu()

        onBrowseConfigChangedReceiver.skipRepeats().listen { [weak self] model in
            guard let self = self else { return }
            if self.followsShelfConfig {
                return
            }

            // Only change Browse config if it's the main browse, not if it's a sub browse
            if menuBarButtonItem == nil { return }
            self.model = model
            self.menuBarButtonItem?.menu = menu()
        }.disposed(by: disposeBag)

        onShelfChangedReceiver.skipRepeats().listen { [weak self] shelf in
            guard let self = self else { return }
            if !self.followsShelfConfig { return }
            self.model = BrowseConfigManager.shared.shelfConfiguration(for: shelf)
        }.disposed(by: disposeBag)

        onUserLoggedOutReceiver.listen { _ in
            BrowseTableViewCell.removeAllCachedItems()
            CommentsBrowseTableViewCell.removeAllCachedItems()
            InReviewBrowseCache.removeAll()
        }.disposed(by: disposeBag)

        configureSearchButton()

        PurchaseManager.shared.onPurchasedChangedReceiver.skipRepeats().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.updatePurchaseState()
            }
        }.disposed(by: disposeBag)

        onWatchlistChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if model.localizedStandardContains("/sync/watchlist") {
                DispatchQueue.main.async {
                    var snapshot = self.dataSource.snapshot()
                    for s in snapshot.itemIdentifiers {
                        switch s {
                        case .content(_, let filter, _):
                            if filter.path == "/sync/watchlist" {
                                BrowseTableViewCell.removeCachedItems(for: filter)
                                snapshot.reloadItems([s])
                            }
                        default:
                            break
                        }
                    }
                    self.dataSource.apply(snapshot)
                }
            }
        }.disposed(by: disposeBag)

        onRecommendedChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if model.localizedStandardContains("/sync/favorites") {
                DispatchQueue.main.async {
                    var snapshot = self.dataSource.snapshot()
                    for s in snapshot.itemIdentifiers {
                        switch s {
                        case .content(_, let filter, _):
                            if filter.path == "/sync/favorites" {
                                BrowseTableViewCell.removeCachedItems(for: filter)
                                snapshot.reloadItems([s])
                            }
                        default:
                            break
                        }
                    }
                    self.dataSource.apply(snapshot)
                }
            }
        }.disposed(by: disposeBag)

        onListChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                var snapshot = self.dataSource.snapshot()
                for list in lists where self.model.localizedStandardContains("/lists/\(list.identifiers.trakt!)") {
                    for s in snapshot.itemIdentifiers {
                        switch s {
                        case .content(_, let filter, _):
                            if filter.path.localizedStandardContains("/lists/\(list.identifiers.trakt!)") {
                                BrowseTableViewCell.removeCachedItems(for: filter)
                                snapshot.reloadItems([s])
                            }
                        default:
                            break
                        }
                    }
                }
                self.dataSource.apply(snapshot)
            }
        }.disposed(by: disposeBag)

        onMovieCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if model.localizedStandardContains("/collection/movies") {
                DispatchQueue.main.async {
                    var snapshot = self.dataSource.snapshot()
                    for s in snapshot.itemIdentifiers {
                        switch s {
                        case .content(_, let filter, _):
                            if filter.path == "/users/me/collection/movies" {
                                BrowseTableViewCell.removeCachedItems(for: filter)
                                snapshot.reloadItems([s])
                            }
                        default:
                            break
                        }
                    }
                    self.dataSource.apply(snapshot)
                }
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if model.localizedStandardContains("/collection/shows") {
                DispatchQueue.main.async {
                    var snapshot = self.dataSource.snapshot()
                    for s in snapshot.itemIdentifiers {
                        switch s {
                        case .content(_, let filter, _):
                            if filter.path == "/users/me/collection/shows" {
                                BrowseTableViewCell.removeCachedItems(for: filter)
                                snapshot.reloadItems([s])
                            }
                        default:
                            break
                        }
                    }
                    self.dataSource.apply(snapshot)
                }
            }
        }.disposed(by: disposeBag)

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture))
        swipeRight.direction = .right
        navigationController?.navigationBar.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture))
        swipeLeft.direction = .left
        navigationController?.navigationBar.addGestureRecognizer(swipeLeft)
    }

    private func updatePurchaseState() {
        menuBarButtonItem?.primaryAction = nil
        menuBarButtonItem?.menu = menu()
        menuBarButtonItem?.style = .plain
        menuBarButtonItem?.image = UIImage(systemName: "line.3.horizontal.decrease")
    }

    @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if view.window == nil { return }
        if let swipeGesture = gesture as? UISwipeGestureRecognizer {
            switch swipeGesture.direction {
            case .right:
                let trans = CATransition()
                trans.type = .push
                trans.subtype = .fromLeft
                trans.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                trans.duration = 0.3
                view.layer.add(trans, forKey: nil)

                if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.freeConfig {
                    // do nothing
                } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.defaultConfig {
                    BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.shelfConfig
                } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.showsConfig {
                    BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.defaultConfig
                } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.moviesConfig {
                    BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.showsConfig
                } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.newAndHot {
                    BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.moviesConfig
                } else if BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.shelfConfig {
                    BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.newAndHot
                }
            case .left:
                let trans = CATransition()
                trans.type = .push
                trans.subtype = .fromRight
                trans.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                trans.duration = 0.3
                view.layer.add(trans, forKey: nil)

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
            default:
                break
            }
        }
    }

    @objc private func headerLongPressed(_ gesture: UILongPressGestureRecognizer) {
        // Only act on the initial press
        guard gesture.state == .began else { return }

        if !isDisplayingShelf { return }

        // Determine which header cell was long-pressed
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location),
              case .header(_, _, let moduleType) = dataSource.itemIdentifier(for: indexPath) else { return }

        let hosting = RipppleHostingController(rootView: ShelfRowQuickConfigView(row: moduleType))
        hosting.modalPresentationStyle = .formSheet
        present(hosting, animated: true, completion: nil)
    }

    @objc func refresh(_ sender: Any) {
        BrowseTableViewCell.removeAllCachedItems()
        CommentsBrowseTableViewCell.removeAllCachedItems()
        GenresBrowseTableViewCell.removeAllCachedItems()
        InReviewBrowseCache.removeAll()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.dataSource.applySnapshotUsingReloadData(self.dataSource.snapshot()) {
                self.refreshControl?.endRefreshing()
            }
        }
    }

    private func menu() -> UIMenu {
        let home = UIAction(title: "Home", image: nil, state: (BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.defaultConfig || BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.freeConfig) ? .on : .off) { _ in
            BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.defaultConfig
        }

        let tv = UIAction(title: "TV Shows", image: nil, state: BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.showsConfig ? .on : .off) { _ in
            BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.showsConfig
        }

        let movie = UIAction(title: "Movies", image: nil, state: BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.moviesConfig ? .on : .off) { _ in
            BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.moviesConfig
        }

        let new = UIAction(title: "This Week", image: nil, state: BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.newAndHot ? .on : .off) { _ in
            BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.newAndHot
        }

        let shelf = UIAction(title: "Shelf", image: nil, state: BrowseConfigManager.shared.currentConfig == BrowseConfigManager.shared.shelfConfig ? .on : .off) { _ in
            BrowseConfigManager.shared.currentConfig = BrowseConfigManager.shared.shelfConfig
        }

        return UIMenu(title: "What do you want to browse?",
                      children: [home, tv, movie, new, shelf])
    }

    private func reloadData(scrollToTop: Bool = true) async {
        if scrollToTop {
            tableView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
        }

        let firstLoad = dataSource.snapshot().numberOfItems == 0
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        if firstLoad {
            snapshot.appendSections([.loading])
            snapshot.appendItems([.loading])
            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false, completion: nil)
            }
        }

        snapshot.deleteAllItems()

        do {
            // print("JSON browse: \n\(jsonString)")
            var moduleTypes = try modules(from: model)

            let first = moduleTypes.remove(at: 0)
            let isShelf = first.module == "Shelf"
            if isShelf, menuBarButtonItem == nil {
                navigationItem.title = "Shelf"
                navigationItem.subtitle = nil
            } else {
                navigationItem.subtitle = first.module == "Browse" ? "Home" : first.module
            }

            snapshot.appendSections([.content])
            for moduleType in moduleTypes {
                let filter = moduleType.filter
                if moduleType.module == "In Review" {
                    snapshot.appendItems([.inReview])
                    continue
                }
                if moduleType.module == "C1" {
                    if moduleTypes.first != moduleType {
                        snapshot.appendItems([.header(filter.name, filter, moduleType)])
                    }
                    snapshot.appendItems([.content(moduleType.module, filter, moduleType)])
                    if isDisplayingNewAndHot {
                        snapshot.appendItems([.weeklyTrackerLink])
                    }
                } else {
                    snapshot.appendItems([.header(filter.name, filter, moduleType)])
                    snapshot.appendItems([.content(moduleType.module, filter, moduleType)])
                }
            }

            if isShelf, moduleTypes.isEmpty {
                snapshot.appendItems([.empty])
            }

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        } catch {
            print("\(error)")
        }

        if navigationItem.title == "Shelf" || navigationItem.subtitle == "Shelf" {
            let customizeShelf = UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"),
                                                 primaryAction: UIAction { [weak self] _ in
                                                     guard let self = self else { return }
                                                     if PurchaseManager.shared.purchased {
                                                         if self.menuBarButtonItem == nil {
                                                             self.present(RipppleHostingController(rootView: ShelfConfigView()), animated: true)
                                                         } else {
                                                             self.performSegue(withIdentifier: "customizeShelf", sender: nil)
                                                         }
                                                     } else {
                                                         UIApplication.shared.switchToPurchase()
                                                     }
                                                 })
            if let menuBarButtonItem = menuBarButtonItem {
                navigationItem.setRightBarButtonItems([customizeShelf, .fixedSpace(), menuBarButtonItem],
                                                      animated: true)
            } else {
                navigationItem.setRightBarButtonItems([customizeShelf], animated: true)
            }
        } else if let menuBarButtonItem = menuBarButtonItem {
            navigationItem.setRightBarButtonItems([menuBarButtonItem], animated: true)
        }
    }

    private var searchButton: UIButton?
    private func configureSearchButton() {
        var configuration = UIButton.Configuration.prominentGlass()

        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "text.magnifyingglass")

        searchButton = UIButton()
        guard let searchButton = searchButton else { return }
        searchButton.tintColor = UIColor(asset: .safeGlobalTint)
        searchButton.configuration = configuration
        searchButton.preferredBehavioralStyle = .pad

        searchButton.showsMenuAsPrimaryAction = true
        searchButton.isPointerInteractionEnabled = true

        searchButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }

            var structureMenu = UIMenu()
            var structureActions = [UIAction]()

            if tabBarController?.isTabBarHidden == true {
                structureActions.append(UIAction(title: "Reset Default Tabs",
                                                 image: UIImage(systemName: "arrow.counterclockwise"),
                                                 handler: { _ in
                                                     if let tabBarController = self.tabBarController as? MainTabBarController {
                                                         tabBarController.resetDefault()
                                                     }
                                                 }))
                structureMenu = UIMenu(options: .displayInline,
                                       children: structureActions)
            }

            var navigationMenu = UIMenu()
            var navigationActions = [UIAction]()

            let toWatch = UIAction(title: "To Watch",
                                   image: UIImage(systemName: "checklist"),
                                   handler: { _ in
                                       self.performSegue(withIdentifier: "to watch", sender: nil)
                                   })
            navigationActions.append(toWatch)

            let history = UIAction(title: "History",
                                   image: UIImage(systemName: "memories"),
                                   handler: { _ in
                                       self.performSegue(withIdentifier: "history", sender: nil)
                                   })
            navigationActions.append(history)

            let lists = UIAction(title: "Lists",
                                 image: UIImage(systemName: "text.justify.left"),
                                 handler: { _ in
                                     self.performSegue(withIdentifier: "lists", sender: nil)
                                 })
            navigationActions.append(lists)

            let calendar = UIAction(title: "Calendar",
                                    image: UIImage(systemName: "calendar.day.timeline.left"),
                                    handler: { _ in
                                        self.performSegue(withIdentifier: "calendar", sender: nil)
                                    })
            navigationActions.append(calendar)

            let search = UIAction(title: "Search",
                                  image: UIImage(systemName: "magnifyingglass"),
                                  handler: { _ in
                                      self.performSegue(withIdentifier: "search", sender: nil)
                                  })
            navigationActions.append(search)

            navigationMenu = UIMenu(options: .displayInline,
                                    children: navigationActions)

            searchButton.menu = UIMenu(children: [structureMenu, navigationMenu])

        }, for: .menuActionTriggered)

        searchButton.menu = UIMenu()

        searchButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchButton)

        NSLayoutConstraint.activate([
            searchButton.rightAnchor.constraint(equalTo: view.safeAreaLayoutGuide.rightAnchor, constant: -20),
            searchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            searchButton.widthAnchor.constraint(equalToConstant: 60),
            searchButton.heightAnchor.constraint(equalToConstant: 60)
        ])

        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 60, right: 0)
    }

    private func configureProfileBarButtonItem() {
        if menuBarButtonItem != nil { return }
        if tabBarController == nil { return }
        if navigationController?.viewControllers.first != self { return }

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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let searchButton = searchButton {
            view.bringSubviewToFront(searchButton)
        }

        searchButton?.isHidden = true
        if tabBarController?.isTabBarHidden == true {
            searchButton?.isHidden = false

            tableView.bottomEdgeEffect.style = .soft
        }
    }

    func showBrowse(with filter: SavedFilter) {
        let browseViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(identifier: "standalone browse") as! BrowseViewController
        browseViewController.model = browseModel(for: filter)
        show(browseViewController, sender: self)
    }

    private func browseModel(for filter: SavedFilter) -> String {
        if filter.query.localizedStandardContains("watchnow") {
            return BrowseConfigManager.shared.serviceConfiguration(for: filter)
        } else {
            return BrowseConfigManager.shared.genreConfiguration(for: filter)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController,
           let media = sender as? MediaSegueObject {
            mediaViewController.media = media.media
            if let zoomSourceView = media.zoomSourceView {
                mediaViewController.preferredTransition = .zoom { _ in
                    zoomSourceView
                }
            }
        }

        if let mediaViewController = segue.destination as? MediaViewController,
           let media = sender as? MediaModel {
            mediaViewController.media = media
        }

        if let gridViewController = segue.destination as? GridViewController,
           let savedFilter = sender as? SavedFilter {
            gridViewController.savedFilter = savedFilter
        }

        if let commentsBrowseViewController = segue.destination as? CommentsBrowseViewController,
           let feedType = sender as? CommentsBrowseViewController.FeedType {
            commentsBrowseViewController.feedType = feedType
        }

        if let commentsViewController = segue.destination as? CommentsViewController,
           let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: .media(media))
        }

        if let browseViewController = segue.destination as? BrowseViewController,
           let filter = sender as? SavedFilter {
            browseViewController.model = browseModel(for: filter)
        }

        if segue.identifier == "search" {
            segue.destination.preferredTransition = .zoom { _ in
                self.searchButton?.imageView
            }
        }

        if let seasonsViewController = segue.destination as? SeasonsViewController {
            if let show = sender as? Show {
                seasonsViewController.show = show
            } else {
                fatalError()
            }
        }

        if let toWatchViewController = segue.destination as? ToWatchViewController {
            _ = toWatchViewController.view
            if segue.identifier == "movies to watch" {
                toWatchViewController.currentType = .movies
            } else if segue.identifier == "episodes to watch" {
                toWatchViewController.currentType = .episodes
            }
        }
    }
}

extension BrowseViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if case .weeklyTrackerLink = dataSource.itemIdentifier(for: indexPath) {
            present(SFSafariViewController(url: URL(string: "https://write.as/ripppleapp/")!),
                    animated: true,
                    completion: nil)
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        guard case .header(_, let savedFilter, _) = dataSource.itemIdentifier(for: indexPath) else { return }
        if savedFilter.section == "episodes_to_watch" || savedFilter.section == "pinned_to_watch" || savedFilter.section == "unpinned_to_watch" {
            performSegue(withIdentifier: "episodes to watch", sender: nil)
            return
        }
        if savedFilter.section == "movies_to_watch" {
            performSegue(withIdentifier: "movies to watch", sender: nil)
            return
        }
        if savedFilter.section == "History" {
            performSegue(withIdentifier: "history", sender: nil)
            return
        }
        if savedFilter.path.isEmpty { return }
        if isDisplayingNewAndHot { return }
        if savedFilter.section == "movies,shows",
           !["/media/trending", "/all/trending"].contains(savedFilter.path) { return }
        performSegue(withIdentifier: "grid", sender: savedFilter)
    }
}

final class BrowseLongPressGestureRecognizer: UILongPressGestureRecognizer {}
