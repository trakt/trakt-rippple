//
//  CollectionViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/09/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

extension CollectionItem {
    var title: String {
        switch type {
        case .movie:
            return movie!.title.sortableString
        case .show, .season, .episode:
            return show!.title.sortableString
        case .list, .officiallist:
            return ""
        case .unknown:
            return ""
        }
    }

    var releaseYear: Int {
        switch type {
        case .movie:
            return movie!.releaseYear ?? 1900
        case .show:
            return show!.releaseYear ?? 1900
        case .season:
            return show!.releaseYear ?? 1900
        case .episode:
            return show!.releaseYear ?? 1900
        case .list, .officiallist:
            return 1900
        case .unknown:
            return 1900
        }
    }

    var releaseDate: Date {
        switch type {
        case .movie:
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return dateFormatter.date(from: movie!.released ?? "1900-01-01") ?? Date.distantPast
        case .show:
            return show!.firstAired ?? Date.distantPast
        case .season:
            return season!.firstAired ?? (show!.firstAired ?? Date.distantPast)
        case .episode:
            return episode!.firstAired ?? Date.distantPast
        case .list, .officiallist:
            return Date.distantPast
        case .unknown:
            return Date.distantPast
        }
    }

    var runtime: Int {
        switch type {
        case .movie:
            return movie!.runtime ?? 0
        case .show:
            return (show!.runtime ?? 0) * (show!.airedEpisodes ?? 0)
        case .season:
            return (show!.runtime ?? 0) * (season!.airedEpisodes ?? 0)
        case .episode:
            return episode!.runtime ?? 0
        case .list, .officiallist:
            return 0
        case .unknown:
            return 0
        }
    }

    var rating: Double {
        switch type {
        case .movie:
            return movie!.rating ?? 0
        case .show:
            return show!.rating ?? 0
        case .season:
            return season!.rating ?? 0
        case .episode:
            return episode!.rating ?? 0
        case .list, .officiallist:
            return 0
        case .unknown:
            return 0
        }
    }

    var weightedRating: Double {
        switch type {
        case .movie:
            let m = 3000.0
            let C = 6.5
            let v = Double(movie!.votes ?? 0)
            let R = movie!.rating ?? 0
            return (v / (v + m)) * R + (m / (v + m)) * C
        case .show:
            let m = 3000.0
            let C = 6.5
            let v = Double(show!.votes ?? 0)
            let R = show!.rating ?? 0
            return (v / (v + m)) * R + (m / (v + m)) * C
        case .season:
            let m = 3000.0
            let C = 6.5
            let v = Double(season!.votes ?? 0)
            let R = season!.rating ?? 0
            return (v / (v + m)) * R + (m / (v + m)) * C
        case .episode:
            let m = 3000.0
            let C = 6.5
            let v = Double(episode!.votes ?? 0)
            let R = episode!.rating ?? 0
            return (v / (v + m)) * R + (m / (v + m)) * C
        case .list, .officiallist:
            return 0
        case .unknown:
            return 0
        }
    }

    var votes: Int {
        switch type {
        case .movie:
            return movie!.votes ?? 0
        case .show:
            return show!.votes ?? 0
        case .season:
            return season!.votes ?? 0
        case .episode:
            return episode!.votes ?? 0
        case .list, .officiallist:
            return 0
        case .unknown:
            return 0
        }
    }
}

final class CollectionViewController: UITableViewController {
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
        case movies
        case shows
        case episodes
    }

    private var service: TraktAPIService = .collection(type: .movies, extended: .full, sort: nil, pageInfo: PageInfo.firstPage(with: 1000)) {
        didSet {
            reset()
        }
    }

    private var fetchTask: Task<Void, Never>?

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

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
                errorLabel.text = "An error occurred while fetching your collection.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching your collection..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.movies {
        didSet {
            if user.isCurrentUser {
                UserDefaults.standard.set(currentFilter.rawValue, forKey: "CollectionViewController.currentFilter")
                UserDefaults.standard.synchronize()
            }

            switch currentFilter {
            case .movies:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .collection(slug: user.slug, type: .movies, extended: .full, sort: nil, pageInfo: PageInfo.firstPage(with: 1000))
                navigationItem.title = "Library"
                navigationItem.subtitle = "Movies"
            case .shows:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .collection(slug: user.slug, type: .shows, extended: .full, sort: nil, pageInfo: PageInfo.firstPage(with: 1000))
                navigationItem.title = "Library"
                navigationItem.subtitle = "Shows"
            case .episodes:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                service = .collection(slug: user.slug, type: .episodes, extended: .full, sort: nil, pageInfo: PageInfo.firstPage(with: 1000))
                navigationItem.title = "Library"
                navigationItem.subtitle = "Episodes"
            }

            if !user.isCurrentUser {
                navigationItem.title = "\(user.username)'s Library"
            }

            searchController.searchBar.placeholder = "Search \(navigationItem.title ?? "")"
        }
    }

    func cycleFilter() {
        let cycle: [Filter] = [.movies, .shows, .episodes]
        guard let currentIndex = cycle.firstIndex(of: currentFilter) else {
            currentFilter = cycle[0]
            return
        }

        currentFilter = cycle[(currentIndex + 1) % cycle.count]
    }

    private enum Sort: Int {
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
    private var currentSorting = Sort.listed {
        didSet {
            UserDefaults.standard.set(currentSorting.rawValue, forKey: "CollectionViewController.currentSorting")
            UserDefaults.standard.synchronize()

            if watchlistItems != nil {
                updateDatasource()
            }
        }
    }

    private enum Section: Int {
        case loading
        case error
        case content
    }

    private enum Wrapper: Hashable {
        case watchlist(CollectionItem)
        case stats([MediaModel])

        func hash(into hasher: inout Hasher) {
            switch self {
            case .watchlist(let watchlist):
                hasher.combine(watchlist)
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

    private var watchlistItems: [CollectionItem]? {
        didSet {
            updateDatasource()
        }
    }

    private var sortedList: [CollectionItem] {
        guard let watchlistItems = watchlistItems else {
            return [CollectionItem]()
        }

        let filteredWatchlistItems = watchlistItems.filter { item -> Bool in
            switch currentFilter {
            case .movies:
                return item.movie != nil
            case .shows:
                return item.show != nil && item.episode == nil && item.season == nil
            case .episodes:
                return item.episode != nil
            }
        }

        switch currentSorting {
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

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.stats(watchlistedItems.map { MediaModel(item: $0) })])
        snapshot.appendItems(watchlistedItems.map { Wrapper.watchlist($0) })
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func updateNotes(for collectionItem: CollectionItem, for cell: MediaTableViewCell) {
        if user?.isCurrentUser == false { return }
        let notes = collectionItem.note
        cell.note = notes
        cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                cell.notesButton?.removeAction(action, for: event)
            }
        }
        if let notes = notes, notes.isEmpty == false {
            cell.notesButton?.toolTip = notes
            cell.notesButton?.addAction(UIAction { _ in
                NotesManager.shared.showNotes(for: collectionItem)
                UISelectionFeedbackGenerator().selectionChanged()
            }, for: .touchUpInside)
        }
    }

    private lazy var dataSource = WatchlistDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .watchlist(let collectionItem):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = MediaModel(item: collectionItem)

            cell.delegate = self

            updateNotes(for: collectionItem, for: cell)

            return cell
        case .stats(let mediaModels):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as? ListStatsTableViewCell else {
                fatalError("Could not dequeue a list stat cell")
            }

            cell.mediaItems = mediaModels

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
            if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "CollectionViewController.currentFilter")) {
                currentFilter = filter
            }

            if let sort = Sort(rawValue: UserDefaults.standard.integer(forKey: "CollectionViewController.currentSorting")) {
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
            currentFilter = Filter.movies
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ListStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        onMovieCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.currentFilter == .movies {
                self.fetch()
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.currentFilter == .shows {
                self.fetch()
            }
        }.disposed(by: disposeBag)

        onEpisodeCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.currentFilter == .episodes {
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

        onNotesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            for indexPathsForVisibleRow in self.tableView.indexPathsForVisibleRows ?? [] {
                let item = self.dataSource.itemIdentifier(for: indexPathsForVisibleRow)
                switch item {
                case .watchlist(let collectionItem):
                    if let cell = self.tableView.cellForRow(at: indexPathsForVisibleRow) as? MediaTableViewCell {
                        self.updateNotes(for: collectionItem, for: cell)
                    }
                default: break
                    // do nothing
                }
            }
        }.disposed(by: disposeBag)
    }

    deinit {
        fetchTask?.cancel()
    }

    @objc func refresh(_ sender: Any) {
        CollectionManager.shared.refresh()
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
        fetchTask?.cancel()
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

        fetchTask?.cancel()
        guard case .collection(let slug, let type, let extended, let sort, _) = service else { return }
        TraktAPIProvider.fetchAllCollectionItems(slug: slug,
                                                 type: type,
                                                 extended: extended,
                                                 sort: sort) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let results):
                DispatchQueue.main.async {
                    self.watchlistItems = Array(Set(results))
                }
            case .failure(let error):
                print("Comments request JSON mapping failed! \(error)")

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
            default:
                fatalError("Unhandled media type fed to search results view controller")
            }
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        }
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let movies = UIAction(title: "Movies", image: nil, state: self.currentFilter == .movies ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .movies
            }

            let shows = UIAction(title: "Shows", image: nil, state: self.currentFilter == .shows ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .shows
            }

            let episodes = UIAction(title: "Episodes", image: nil, state: self.currentFilter == .episodes ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .episodes
            }

            let filters = UIMenu(title: "What do you want to see?", options: .displayInline, children: [movies, shows, episodes])

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

            let sorting = UIMenu(title: "Sort By", children: [added, title, release, runtime, weightedRating, rating, votes, random])

            completion([filters, sorting])
        }
        return UIMenu(children: [deferredMenuElement])
    }
}

extension CollectionViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .watchlist(let collectionItem):
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel(item: collectionItem))
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
        guard case Wrapper.watchlist(let collectionItem) = item else { return nil }
        let media = MediaModel(item: collectionItem)

        let remove = UIContextualAction(style: .normal,
                                        title: "Remove") { _, _, boolValue in
            media.removeFromCollection()
            boolValue(true)
        }
        remove.image = UIImage(systemName: "minus.circle.fill")
        remove.backgroundColor = .systemRed

        let notes = UIContextualAction(style: .normal, title: "Notes") { _, _, boolValue in
            NotesManager.shared.showNotes(for: collectionItem)
            boolValue(true)
        }
        notes.backgroundColor = UIColor(resource: .ripppleGray)
        notes.image = UIImage(systemName: "note.text")

        let configuration = UISwipeActionsConfiguration(actions: [notes, remove])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}

extension CollectionViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.watchlist(let watchlistItem) = item else { return }

        if action == .details {
            switch watchlistItem.type {
            case .movie, .show:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel(item: watchlistItem))
            case .episode:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel(item: watchlistItem))
            default:
                fatalError("Unhandled media type")
            }
        }
    }
}

extension CollectionViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateDatasource()
    }
}
