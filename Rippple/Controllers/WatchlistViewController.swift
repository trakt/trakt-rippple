//
//  WatchlistViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class WatchlistViewController: UITableViewController {
    var user: User!

    required init?(coder aDecoder: NSCoder) {
        user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    // Private

    private enum ViewControllerSegue: String {
        case comments
        case details
    }

    private enum Filter: Int {
        case none
        case movies
        case shows
        case seasons
        case episodes
    }

    private var service: TraktAPIService = .watchlist(type: nil, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000)) {
        didSet {
            reset()
        }
    }

    private var cancellable: Cancellable?

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

    private var noteTextFieldDelegate = NoteTextFieldDelegate()

    // Search
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchQuery = ""

    /// Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: NVActivityIndicatorView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching your watchlist.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching your watchlist..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.none {
        didSet {
            if user.isCurrentUser {
                UserDefaults.standard.set(currentFilter.rawValue, forKey: "WatchlistViewController.currentFilter")
                UserDefaults.standard.synchronize()
            }

            switch currentFilter {
            case .none:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .watchlist(slug: user.slug, type: nil, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000))
                navigationItem.title = "Watchlist"
                navigationItem.subtitle = "All Items"
            case .movies:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .watchlist(slug: user.slug, type: .movies, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000))
                navigationItem.title = "Watchlist"
                navigationItem.subtitle = "Movies"
            case .episodes:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .watchlist(slug: user.slug, type: .episodes, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000))
                navigationItem.title = "Watchlist"
                navigationItem.subtitle = "Episodes"
            case .shows:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .watchlist(slug: user.slug, type: .shows, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000))
                navigationItem.title = "Watchlist"
                navigationItem.subtitle = "Shows"
            case .seasons:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .watchlist(slug: user.slug, type: .seasons, extended: .full, sort: nil, pageInfo: .firstPage(with: 1000))
                navigationItem.title = "Watchlist"
                navigationItem.subtitle = "Seasons"
            }

            if !user.isCurrentUser {
                navigationItem.title = "\(user.username)'s Watchlist"
            }

            searchController.searchBar.placeholder = "Search \(navigationItem.title ?? "")"
        }
    }

    private enum Sort: Int {
        case rank
        case listed
        case title
        case releaseDate
        case runtime
        case rating
        case votes
        case weightedRating
        case random
    }

    /// Sort
    private var currentSorting = Sort.rank {
        didSet {
            UserDefaults.standard.set(currentSorting.rawValue, forKey: "WatchlistViewController.currentSorting")
            UserDefaults.standard.synchronize()

            if watchlistItems != nil {
                updateDatasource()
            }
        }
    }

    private func configureFloatingButton() {
        if user.isCurrentUser {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu()),
                                                  .fixedSpace(),
                                                  filterButtonItem]
        } else {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "rectangle.grid.3x2"),
                                                                  primaryAction: UIAction { [weak self] _ in
                                                                      guard let self = self else { return }
                                                                      self.performSegue(withIdentifier: "grid", sender: nil)
                                                                  }),
                                                  .fixedSpace(),
                                                  filterButtonItem]
        }
    }

    private func menu() -> UIMenu {
        let browseAsGrid = UIAction(title: "Show in Grid",
                                    image: UIImage(systemName: "rectangle.grid.3x2")) { [weak self] _ in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "grid", sender: nil)
        }
        let reorder = UIAction(title: "Reorder Items",
                               image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
            guard let self = self else { return }
            let listReorderingViewController = ListReorderingViewController(destination: .watchlist,
                                                                            items: self.watchlistItems ?? []) { [weak self] in
                guard let self = self else { return }
                self.fetch()
            }
            let navigation = UINavigationController(rootViewController: listReorderingViewController)
            navigation.modalPresentationStyle = .pageSheet
            self.present(navigation, animated: true)
        }

        return UIMenu(children: [UIMenu(options: .displayInline, children: [reorder]), UIMenu(options: .displayInline, children: [browseAsGrid])])
    }

    private enum Section: Hashable {
        case loading
        case error
        case content
        case released
        case unreleased
    }

    private enum Wrapper: Hashable {
        case watchlist(WatchlistItem)
        case stats([MediaModel])
        case header(String, String) // title, subtitle (count)

        func hash(into hasher: inout Hasher) {
            switch self {
            case .watchlist(let watchlist):
                hasher.combine(watchlist)
            case .header(let title, let subtitle):
                hasher.combine(title)
                hasher.combine(subtitle)
            default:
                break
            }
        }
    }

    private class WatchlistDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let item = itemIdentifier(for: indexPath) else { return false }
            guard case Wrapper.watchlist(let watchlistItem) = item else { return false }
            let media = MediaModel(item: watchlistItem)
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

    private var watchlistItems: [WatchlistItem]? {
        didSet {
            updateDatasource()
        }
    }

    private var sortedList: [WatchlistItem] {
        guard let watchlistItems = watchlistItems else {
            return [WatchlistItem]()
        }

        let filteredWatchlistItems = watchlistItems.filter { item -> Bool in
            switch currentFilter {
            case .none:
                return true
            case .movies:
                return item.movie != nil
            case .episodes:
                return item.episode != nil
            case .shows:
                return item.show != nil && item.episode == nil && item.season == nil
            case .seasons:
                return item.season != nil
            }
        }

        switch currentSorting {
        case .rank:
            return filteredWatchlistItems.sorted { $0.rank < $1.rank }
        case .listed:
            return filteredWatchlistItems.sorted { $0.listedAt > $1.listedAt }
        case .title:
            return filteredWatchlistItems.sorted { $0.title < $1.title }
        case .releaseDate:
            return filteredWatchlistItems.sorted { $0.releaseDate > $1.releaseDate }
        case .runtime:
            return filteredWatchlistItems.sorted { $0.runtime > $1.runtime }
        case .rating:
            return filteredWatchlistItems.sorted { $0.rating > $1.rating }
        case .votes:
            return filteredWatchlistItems.sorted { $0.votes > $1.votes }
        case .random:
            return filteredWatchlistItems.shuffled()
        case .weightedRating:
            return filteredWatchlistItems.sorted { $0.weightedRating > $1.weightedRating }
        }
    }

    private func updateDatasource() {
        let watchlistedItems = sortedList.filter {
            if searchQuery.isEmpty { return true }
            if searchQuery == "" { return true }
            if $0.title.localizedCaseInsensitiveContains(searchQuery) { return true }
            if String($0.releaseYear).localizedCaseInsensitiveContains(searchQuery) { return true }
            return false
        }

        let now = Date.now

        // Group items by released/unreleased (items without a known date go to unreleased)
        let releasedItems = watchlistedItems.filter { item in
            item.hasKnownReleaseDate && item.releaseDate <= now
        }

        let unreleasedItems = watchlistedItems.filter { item in
            !item.hasKnownReleaseDate || item.releaseDate > now
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.stats(watchlistedItems.map { MediaModel(item: $0) })])

        // Add released section first (if it has items) - items you can watch now
        if !releasedItems.isEmpty {
            snapshot.appendSections([.released])
            snapshot.appendItems([.header("Released", "\(releasedItems.count) item\(releasedItems.count == 1 ? "" : "s")")], toSection: .released)
            snapshot.appendItems(releasedItems.map { Wrapper.watchlist($0) }, toSection: .released)
        }

        // Add unreleased section (if it has items) - upcoming items
        if !unreleasedItems.isEmpty {
            snapshot.appendSections([.unreleased])
            snapshot.appendItems([.header("Unreleased", "\(unreleasedItems.count) item\(unreleasedItems.count == 1 ? "" : "s")")], toSection: .unreleased)
            snapshot.appendItems(unreleasedItems.map { Wrapper.watchlist($0) }, toSection: .unreleased)
        }

        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private lazy var dataSource = WatchlistDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .watchlist(let watchlistItem):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = MediaModel(item: watchlistItem)
            cell.note = watchlistItem.notes

            cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
                if let action = action {
                    cell.notesButton?.removeAction(action, for: event)
                }
            }
            if let notes = watchlistItem.notes, notes.isEmpty == false {
                cell.notesButton?.toolTip = notes
                cell.notesButton?.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    self.displayNotes(for: watchlistItem)
                    UISelectionFeedbackGenerator().selectionChanged()
                },
                for: .touchUpInside)
            }

            cell.delegate = self

            return cell
        case .stats(let mediaModels):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as? ListStatsTableViewCell else {
                fatalError("Could not dequeue a list stat cell")
            }

            cell.mediaItems = mediaModels

            return cell
        case .header(let title, let subtitle):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "header") as? ActivityHeaderTableViewCell else {
                fatalError("Could not dequeue a header cell")
            }
            cell.title.text = title.emojiUnescapedString
            cell.subtitle?.text = subtitle
            cell.chevron?.isHidden = true
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        while user == nil {
            user = UserManager.shared.currentUser
        }

        refreshControl?.isEnabled = false

        navigationItem.style = .browser

        if user.isCurrentUser {
            if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "WatchlistViewController.currentFilter")) {
                currentFilter = filter
            }

            if let sort = Sort(rawValue: UserDefaults.standard.integer(forKey: "WatchlistViewController.currentSorting")) {
                currentSorting = sort
            }

            if tabBarController != nil, navigationController?.viewControllers.first == self {
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
        } else {
            currentFilter = Filter.none
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ListStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        onWatchlistChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetch()
        }.disposed(by: disposeBag)

        onWatchlistTypeNotesChangedReceiver.listen { [weak self] watchlistType in
            guard let self = self else { return }
            if case .watchlistItem = watchlistType {
                self.fetch()
            }
        }.disposed(by: disposeBag)

        filterButtonItem.primaryAction = nil
        filterButtonItem.menu = filterMenu()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false

        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        searchController.searchBar.barTintColor = nil
        searchController.searchBar.barStyle = .default
        searchController.searchBar.isTranslucent = true

        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = searchController

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

        configureFloatingButton()
    }

    deinit {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    @objc func refresh(_ sender: Any) {
        WatchlistManager.shared.refresh()
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)
        fetch()
    }

    @IBAction func retry(_ sender: Any) {
        error = nil
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)
        fetch()
    }

    private func reset() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
        retry(self)
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        defer {
            DispatchQueue.main.async {
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
            }
        }

        guard case .watchlist(let slug, let type, let extended, let sort, _) = service else { return }
        TraktAPIProvider.fetchAllWatchlistItems(slug: slug,
                                                type: type,
                                                extended: extended,
                                                sort: sort) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let items):
                DispatchQueue.main.async {
                    self.watchlistItems = Array(Set(items))
                }
            case .failure(let error):
                print("Watchlist request failure \(error)")
                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.error = error
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
           let cell = sender as? MediaTableViewCell,
           let index = tableView.indexPath(for: cell) {
            guard let item = dataSource.itemIdentifier(for: index) else { return }
            guard case Wrapper.watchlist(let watchlistItem) = item else { return }

            switch watchlistItem.type {
            case .movie:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.movie(watchlistItem.movie!)))
            case .show:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.show(watchlistItem.show!)))
            case .episode:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.episode(watchlistItem.episode!, watchlistItem.show!)))
            case .season:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.season(watchlistItem.season!, watchlistItem.show!)))
            default:
                fatalError("Unhandled media type fed to search results view controller")
            }
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if let gridViewController = segue.destination as? GridViewController {
            gridViewController.savedFilter = SavedFilter(section: "watchlist",
                                                         name: "Watchlist",
                                                         path: "/sync/watchlist",
                                                         query: "",
                                                         limit: 250)
            return
        }
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let all = UIAction(title: "Everything", image: nil, state: self.currentFilter == .none ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .none
            }

            let movies = UIAction(title: "Movies", image: nil, state: self.currentFilter == .movies ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .movies
            }

            let shows = UIAction(title: "Shows", image: nil, state: self.currentFilter == .shows ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .shows
            }

            let seasons = UIAction(title: "Seasons", image: nil, state: self.currentFilter == .seasons ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .seasons
            }

            let episodes = UIAction(title: "Episodes", image: nil, state: self.currentFilter == .episodes ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .episodes
            }

            let filters = UIMenu(title: "What do you want to see?", options: .displayInline, children: [all, movies, shows, seasons, episodes])

            let rank = UIAction(title: "Rank", image: nil, state: self.currentSorting == .rank ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .rank
            }

            let added = UIAction(title: "Recently Added", image: nil, state: self.currentSorting == .listed ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .listed
            }

            let title = UIAction(title: "Title", image: nil, state: self.currentSorting == .title ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .title
            }

            let release = UIAction(title: "Release Date", image: nil, state: self.currentSorting == .releaseDate ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .releaseDate
            }

            let runtime = UIAction(title: "Runtime", image: nil, state: self.currentSorting == .runtime ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .runtime
            }

            let weightedRating = UIAction(title: "Weighted Ratings", image: nil, state: self.currentSorting == .weightedRating ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .weightedRating
            }

            let rating = UIAction(title: "Ratings", image: nil, state: self.currentSorting == .rating ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .rating
            }

            let votes = UIAction(title: "Votes", image: nil, state: self.currentSorting == .votes ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .votes
            }

            let random = UIAction(title: "Random", image: nil, state: self.currentSorting == .random ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .random
            }

            let sorting = UIMenu(title: "Sort By", children: [rank, added, title, release, runtime, weightedRating, rating, votes, random])

            completion([filters, sorting])
        }
        return UIMenu(children: [deferredMenuElement])
    }
}

extension WatchlistViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .watchlist(let watchlistItem):
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel(item: watchlistItem))
        default:
            return
        }
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
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return UITableView.automaticDimension }

        switch item {
        case .stats:
            return UITableView.automaticDimension
        case .watchlist:
            return UITableView.automaticDimension
        case .header:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        switch item {
        case .stats:
            return nil
        case .watchlist:
            let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
            contextMenu.cell = cell
            contextMenu.controller = self

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        case .header:
            return nil
        }
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
        guard case Wrapper.watchlist(let watchlistItem) = item else { return nil }
        let media = MediaModel(item: watchlistItem)
        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if !user.isCurrentUser { return nil }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.watchlist(let watchlistItem) = item else { return nil }
        let media = MediaModel(item: watchlistItem)

        let remove = UIContextualAction(style: .normal,
                                        title: "Remove") { _, _, boolValue in
            media.removeFromWatchlist()
            boolValue(true)
        }
        remove.image = UIImage(systemName: "minus.circle.fill")
        remove.backgroundColor = .systemRed

        if UserManager.shared.isCurrentVIP {
            let note = UIContextualAction(style: .normal,
                                          title: "Notes") { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.promptForNote(on: watchlistItem)
                boolValue(true)
            }
            note.image = UIImage(systemName: "note.text.badge.plus")
            note.backgroundColor = UIColor(resource: .ripppleGray)

            let configuration = UISwipeActionsConfiguration(actions: [remove, note])
            configuration.performsFirstActionWithFullSwipe = false
            return configuration
        }

        let configuration = UISwipeActionsConfiguration(actions: [remove])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func displayNotes(for watchlistItem: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.watchlistItem(note: watchlistItem.notes ?? "",
                                                                       itemId: watchlistItem.id,
                                                                       canEdit: UserManager.shared.isCurrentVIP && user.isCurrentUser,
                                                                       user: user,
                                                                       listItem: watchlistItem))
    }

    private func promptForNote(on watchlistItem: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.watchlistItem(note: watchlistItem.notes ?? "",
                                                                       itemId: watchlistItem.id,
                                                                       canEdit: UserManager.shared.isCurrentVIP && user.isCurrentUser,
                                                                       user: user,
                                                                       listItem: watchlistItem))
    }
}

extension WatchlistViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.watchlist(let watchlistItem) = item else { return }

        if action == .details {
            switch watchlistItem.type {
            case .movie, .show:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel(item: watchlistItem))
            case .episode, .season:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel.show(watchlistItem.show!))
            default:
                fatalError("Unhandled media type")
            }
        }
    }
}

extension WatchlistViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateDatasource()
    }
}
