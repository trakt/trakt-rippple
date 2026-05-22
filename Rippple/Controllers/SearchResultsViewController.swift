//
//  SearchResultsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/06/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import Receiver

import NVActivityIndicatorView

import Moya

class SearchResultsViewController: UITableViewController {

    var aSmartSearch: SmartSearch? {
        didSet {
            if let smartSearch = aSmartSearch {
                service = smartSearch.service
                title = smartSearch.name?.capitalized ?? "Smart Search"
            }
        }
    }
    @IBOutlet private var smartSearchHeader: UIView!

    var savedFilter: SavedFilter? {
        didSet {
            if let savedFilter = savedFilter {
                service = TraktAPIService.savedFilter(section: savedFilter.section,
                                                      path: savedFilter.path,
                                                      query: savedFilter.query,
                                                      pageInfo: PageInfo.firstPage(with: 50))
            }
        }
    }

    // Public
    var service: TraktAPIService? {
        didSet {
            refresh(self)
        }
    }

    // Private

    private enum ViewControllerSegue: String {
        case comments
        case details
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

    // Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private weak var animationViewContainer: NVActivityIndicatorView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error?

    private enum Section: Int {
        case loading
        case error
        case content
    }

    private enum Wrapper: Hashable {
        case media(MediaModel)
    }

    private class SearchResultsDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let item = self.itemIdentifier(for: indexPath) else { return false }
            guard case let Wrapper.media(media) = item else { return false }
            switch media {
            case .movie:
                return true
            case .show:
                return true
            case .episode:
                return true
            case .season:
                return true
            case .list:
                return false
            case .showProgress:
                return true
            }
        }
    }

    private lazy var dataSource = SearchResultsDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .media(let media):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = media

            cell.delegate = self

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."
        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.dataSource = dataSource
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        refresh(self)

        onMovieSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let aSmartSearch = self.aSmartSearch {
                    self.aSmartSearch = aSmartSearch.getLatest()
                }
            }
        }.disposed(by: disposeBag)

        onShowSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let aSmartSearch = self.aSmartSearch {
                    self.aSmartSearch = aSmartSearch.getLatest()
                }
            }
        }.disposed(by: disposeBag)

        if aSmartSearch != nil || savedFilter != nil {
            configureFloatingButton()
        }
    }

    private var menuButton: UIButton!
    private func configureFloatingButton() {
        if let smartSearch = aSmartSearch {
            if PurchaseManager.shared.purchased {
                let menu = UIMenu(title: "", children: [UIAction(title: "Edit Smart Search",
                                                                 handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "smartsearch", sender: smartSearch)
                }),
                                                        UIAction(title: "Delete Smart Search",
                                                                 attributes: .destructive,
                                                                 handler: { [weak self] _ in
                    guard let self = self else { return }
                    smartSearch.delete()
                    self.navigationController?.popViewController(animated: true)
                })])

                let barButton = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "pencil"),
                                                primaryAction: nil,
                                                menu: menu)
                navigationItem.rightBarButtonItems = [.init(image: UIImage(systemName: "ellipsis"),
                                                            menu: buildActions()),
                                                      .fixedSpace(),
                                                      barButton]
            } else {
                let menu = UIMenu(title: "", children: [UIAction(title: "Edit Smart Search",
                                                                 handler: { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "smartsearch", sender: smartSearch)
                })])

                let barButton = UIBarButtonItem(title: nil,
                                                image: UIImage(systemName: "pencil"),
                                                primaryAction: nil,
                                                menu: menu)
                navigationItem.rightBarButtonItems = [.init(image: UIImage(systemName: "ellipsis"),
                                                            menu: buildActions()),
                                                      .fixedSpace(),
                                                      barButton]
            }
        } else {
            navigationItem.rightBarButtonItems = [.init(image: UIImage(systemName: "ellipsis"),
                                                        menu: buildActions())]
        }
    }

    private func buildActions() -> UIMenu {
        guard let savedFilter = aSmartSearch?.savedFilter ?? savedFilter else { return UIMenu() }
        let shelved = savedFilter.isShelved

        let shelfOnTop = UIAction(title: "Shelf On Top",
                                  image: UIImage(systemName: "text.line.first.and.arrowtriangle.forward")) { [weak self] _ in
            guard let self = self else { return }
            savedFilter.shelf(onTop: true)
            self.configureFloatingButton()
        }
        let shelfUnder = UIAction(title: "Shelf Under",
                                  image: UIImage(systemName: "text.line.last.and.arrowtriangle.forward")) { [weak self] _ in
            guard let self = self else { return }
            savedFilter.shelf(onTop: false)
            self.configureFloatingButton()
        }

        let unshelf = UIAction(title: "Remove from Shelf",
                               image: UIImage(systemName: "minus.circle.fill"),
                               attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            savedFilter.unshelf()
            self.configureFloatingButton()
        }

        if shelved {
            return UIMenu(children: [unshelf])
        } else {
            return UIMenu(children: [shelfOnTop, shelfUnder])
        }
    }

    @IBAction func refresh(_ sender: Any) {
        navigationItem.subtitle = "Loading..."

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        if service != nil {
            fetch()
        }
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        guard let service = service else { return }

        TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    var searchResults: [MediaItem]
                    if case .popularMovies = service {
                        searchResults = try response.map([Movie].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                    } else if case .popularShows = service {
                        searchResults = try response.map([Show].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: nil, show: $0, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                    } else if case let .savedFilter(_, path, _, _) = service {
                        if path == "/shows/popular" {
                            searchResults = try response.map([Show].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: nil, show: $0, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                        } else if path == "/movies/popular" {
                            searchResults = try response.map([Movie].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                        } else {
                            searchResults = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).filter({ media in
                                media.movie != nil || media.season != nil || media.episode != nil || media.show != nil
                            })
                        }
                    } else {
                        searchResults = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).filter({ media in
                            media.movie != nil || media.season != nil || media.episode != nil || media.show != nil
                        })
                    }

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(searchResults.map { Wrapper.media(MediaModel(item: $0)) })
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "\(searchResults.count) result\(searchResults.count < 2 ? "" : "s")"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("Comments request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "Error"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case let .failure(error):
                print("Comments request failure \(error)")
                self.error = error

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.navigationItem.subtitle = "Error"
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
            let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(media))
        } else if let mediaViewController = segue.destination as? MediaViewController,
            let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if let navigationController = segue.destination as? UINavigationController, let smartSearchBuilderViewController = navigationController.viewControllers.first as? SmartSearchBuilderViewController, let smartSearch = sender as? SmartSearch {
            smartSearchBuilderViewController.smartSearch = smartSearch
        }
    }
}

extension SearchResultsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.media(mediaModel) = item else { return }

        performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return errorView
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return loadingView
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return emptyView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
        contextMenu.cell = cell
        contextMenu.controller = self

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            return self.contextMenu.previewViewController
        }, actionProvider: { _ in
            return self.contextMenu.menu
        })
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        navigationController?.show(controller, sender: self)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case let Wrapper.media(media) = item else { return nil }

        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case let Wrapper.media(media) = item else { return nil }

        return media.leadingSwipeActions(for: self)
    }
}

extension SearchResultsViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.media(mediaModel) = item else { return }

        if action == .details {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel)
        }
    }
}

extension MediaModel {

    func trailingSwipeActions(for viewController: UIViewController) -> UISwipeActionsConfiguration {
        let next = UIContextualAction(style: .normal,
                                         title: "Next") { _, _, boolValue in
            let nextEpisodeToWatchNavigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "next episode") as! UINavigationController

            if let nextEpisodeViewController = nextEpisodeToWatchNavigationController.topViewController as? MediaShowNextLoadingViewController {
                nextEpisodeViewController.media = self
            }

            UIApplication.shared.present(nextEpisodeToWatchNavigationController)
            boolValue(true)
        }
        next.image = UIImage(systemName: "chevron.right.circle.fill")
        next.backgroundColor = UIColor(resource: .ripppleGray)

        let checkin = UIContextualAction(style: .normal,
                                         title: "Check in") { _, _, boolValue in
            self.checkin()
            boolValue(true)
        }
        checkin.image = UIImage(systemName: "play.circle.fill")
        checkin.backgroundColor = UIColor(resource: .ripppleGray)

        let watched = UIContextualAction(style: .normal,
                                       title: "Watch Now") { _, _, boolValue in
            self.markWatched()
            boolValue(true)
        }
        watched.image = UIImage(systemName: "checkmark.circle.fill")
        watched.backgroundColor = UIColor(resource: .ripppleGray)

        let watchedRelease = UIContextualAction(style: .normal,
                                       title: "Watch on Release") { _, _, boolValue in
            self.markWatchedWhenReleased()
            boolValue(true)
        }
        watchedRelease.image = UIImage(systemName: "clock.badge.checkmark.fill")
        watchedRelease.backgroundColor = UIColor(resource: .ripppleGray)

        let more = UIContextualAction(style: .normal,
                                       title: "Watch on...") { [weak viewController] _, _, boolValue in
            guard let viewController = viewController else { return }
            guard let navigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Action Navigation Controller") as? UINavigationController else { return }

            let markWatchedActionViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Mark Watched") { coder -> MarkWatchedActionViewController? in
                return MarkWatchedActionViewController(coder: coder,
                                                       media: self)
            }

            navigationController.viewControllers = [markWatchedActionViewController]

            viewController.present(navigationController, animated: true)
            boolValue(true)
        }
        more.image = UIImage(systemName: "plus.circle.fill")
        more.backgroundColor = UIColor(resource: .ripppleGray)

        var actions = [UIContextualAction]()
        switch self {
        case .movie:
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.default") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(checkin)
                }
            } else {
                actions.append(checkin)
            }
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.secondary") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(watched)
                }
            } else {
                actions.append(watched)
            }
            actions.removeDuplicates()
            actions.append(more)
        case .show(let show):
            var pin: UIContextualAction
            if show.isPinned {
                pin = UIContextualAction(style: .normal,
                                                 title: "Unpin") { _, _, boolValue in
                    show.unpin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            } else {
                pin = UIContextualAction(style: .normal,
                                                 title: "Pin") { _, _, boolValue in
                    show.pin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            }

            actions = [next, pin, more]
        case .episode:
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.default") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(checkin)
                }
            } else {
                actions.append(checkin)
            }
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.secondary") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(watched)
                }
            } else {
                actions.append(watched)
            }
            actions.removeDuplicates()
            actions.append(more)
        case .season:
            actions = [more]
        case .list:
            actions = []
        case .showProgress:
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.default") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(checkin)
                }
            } else {
                actions.append(checkin)
            }
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.secondary") as? String {
                if swipeDefault == "checkin" {
                    actions.append(checkin)
                } else if swipeDefault == "watched" {
                    actions.append(watched)
                } else if swipeDefault == "watched_released" {
                    actions.append(watchedRelease)
                } else {
                    actions.append(watched)
                }
            } else {
                actions.append(watched)
            }
            actions.removeDuplicates()
            actions.append(more)
        }

        if actions.count == 2 {
            actions.last?.backgroundColor = UIColor(resource: .ripppleGray).darker()
        } else if actions.count == 3 {
            actions.first?.backgroundColor = UIColor(resource: .ripppleGray).lighter()
            actions.last?.backgroundColor = UIColor(resource: .ripppleGray).darker()
        }

        return UISwipeActionsConfiguration(actions: actions)
    }

    func leadingSwipeActions(for viewController: UIViewController) -> UISwipeActionsConfiguration {
        let addWatchlist = UIContextualAction(style: .normal,
                                         title: "Watchlist") { _, _, boolValue in
            self.addToWatchlist()
            boolValue(true)
        }
        addWatchlist.image = UIImage(systemName: "bookmark.circle.fill")
        addWatchlist.backgroundColor = UIColor(resource: .ripppleGray)

        let collect = UIContextualAction(style: .normal,
                                         title: "Collect") { _, _, boolValue in
            self.addToCollection()
            boolValue(true)
        }
        collect.image = UIImage(systemName: "book.circle.fill")
        collect.backgroundColor = UIColor(resource: .ripppleGray)

        let list = UIContextualAction(style: .normal,
                                         title: "List") { _, _, boolValue in
            let listViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Lists Action") as! ListActionViewController

            listViewController.media = self

            viewController.present(listViewController, animated: true)

            boolValue(true)
        }
        list.image = UIImage(systemName: "plusminus.circle.fill")
        list.backgroundColor = UIColor(resource: .ripppleGray)

        var actions = [UIContextualAction]()
        actions = [addWatchlist, collect, list]

        if actions.count == 2 {
            actions.last?.backgroundColor = UIColor(resource: .ripppleGray).darker()
        } else if actions.count == 3 {
            actions.first?.backgroundColor = UIColor(resource: .ripppleGray).lighter()
            actions.last?.backgroundColor = UIColor(resource: .ripppleGray).darker()
        }

        return UISwipeActionsConfiguration(actions: actions)
    }
}

extension SmartSearch {
    var savedFilter: SavedFilter {
        if case let .requestParameters(parameters, _) = service.task {
            return SavedFilter(section: contentType == .movie ? "movies" : "shows",
                               name: name ?? "Smart Search",
                               path: service.path,
                               query: parameters.compactMap { "\($0)=\($1)" }.sorted().joined(separator: "&"),
                               limit: nil)
        } else {
            return SavedFilter(section: contentType == .movie ? "movies" : "shows",
                               name: name ?? "Smart Search",
                               path: service.path,
                               query: "",
                               limit: nil)
        }
    }
}
