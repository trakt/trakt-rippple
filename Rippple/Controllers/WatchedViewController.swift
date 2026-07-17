//
//  WatchedViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 13/04/2022.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

extension WatchedItem {
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

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter
    }()

    var releaseDate: Date {
        switch type {
        case .movie:
            return WatchedItem.dateFormatter.date(from: movie!.released ?? "1900-01-01") ?? Date.distantPast
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

final class WatchedViewController: UITableViewController {
    var user: User!

    required init?(coder aDecoder: NSCoder) {
        user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    // Private

    private enum ViewControllerSegue: String {
        case comments
        case details

        case hidden
        case pinned
        case completed
        case dropped
    }

    private enum Filter: Int {
        case movies
        case shows
    }

    private struct WatchedRequest: Equatable {
        let slug: String
        let type: WatchedType
        let extended: Extended?
    }

    private var watchedRequest = WatchedRequest(slug: "me", type: .movies, extended: .full) {
        didSet {
            reset()
        }
    }

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
                errorLabel.text = "An error occurred while fetching your watched list.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching your watched list..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.movies {
        didSet {
            if user.isCurrentUser {
                UserDefaults.standard.set(currentFilter.rawValue, forKey: "WatchedViewController.currentFilter")
                UserDefaults.standard.synchronize()
            }

            switch currentFilter {
            case .movies:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                if user.isCurrentUser {
                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.loading])
                    dataSource.apply(snapshot, animatingDifferences: false)
                    watchlistItems = watchedMovies
                } else {
                    watchedRequest = WatchedRequest(slug: user.slug, type: .movies, extended: .full)
                }
                navigationItem.title = "Watched Movies"
                navigationItem.subtitle = "Movies"
            case .shows:
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
                if user.isCurrentUser {
                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.loading])
                    dataSource.apply(snapshot, animatingDifferences: false)
                    if let watchedShows = watchedShows {
                        watchlistItems = Array(watchedShows).sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt })
                    } else {
                        watchlistItems = nil
                    }
                } else {
                    watchedRequest = WatchedRequest(slug: user.slug, type: .shows, extended: .fullnoseasons)
                }
                navigationItem.title = "Watched"
                navigationItem.subtitle = "Shows"
            }

            if !user.isCurrentUser {
                navigationItem.title = "\(user.username)'s Watched"
            }

            searchController.searchBar.placeholder = "Search \(navigationItem.title ?? "")"
        }
    }

    func cycleFilter() {
        switch currentFilter {
        case .movies:
            currentFilter = .shows
        case .shows:
            currentFilter = .movies
        }
    }

    private enum Sort: Int {
        case lastWatched
        case title
        case releaseDate
        case runtime
        case rating
        case votes
        case weightedRating
        case random
    }

    /// Sort
    private var currentSorting = Sort.lastWatched {
        didSet {
            UserDefaults.standard.set(currentSorting.rawValue, forKey: "WatchedViewController.currentSorting")
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
        case watchlist(WatchedItem)
        case stats([MediaModel])
        case sublist(String, CardType, String)
        case spacer(Float)

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

    private var watchedMovies: [WatchedItem]? {
        didSet {
            if user.isCurrentUser, currentFilter == .movies {
                watchlistItems = watchedMovies
            }
        }
    }

    private var watchedShows: [WatchedItem]? {
        didSet {
            if user.isCurrentUser, currentFilter == .shows {
                if let watchedShows = watchedShows {
                    watchlistItems = watchedShows.sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt })
                } else {
                    watchlistItems = nil
                }
            }
        }
    }

    private var watchlistItems: [WatchedItem]? {
        didSet {
            updateDatasource()
        }
    }

    private var sortedList: [WatchedItem] {
        guard let watchlistItems = watchlistItems else {
            return [WatchedItem]()
        }

        let filteredWatchlistItems = watchlistItems.filter { item -> Bool in
            switch currentFilter {
            case .movies:
                return item.movie != nil
            case .shows:
                return item.show != nil && item.episode == nil && item.season == nil
            }
        }

        switch currentSorting {
        case .lastWatched:
            return filteredWatchlistItems.sorted { $0.lastWatchedAt > $1.lastWatchedAt }
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
        let watchlistedItems = sortedList.removingDuplicates().filter {
            if searchQuery.isEmpty { return true }
            if searchQuery == "" { return true }
            if $0.title.localizedCaseInsensitiveContains(searchQuery) { return true }
            if String($0.releaseYear).localizedCaseInsensitiveContains(searchQuery) { return true }
            return false
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.stats(watchlistedItems.map { MediaModel(item: $0) })])
        if currentFilter == .shows, user.isCurrentUser, searchQuery.isEmpty {
            snapshot.appendItems([.spacer(5.001),
                                  .sublist("Pinned", .top, WatchedViewController.ViewControllerSegue.pinned.rawValue),
                                  .sublist("Hidden", .middle, WatchedViewController.ViewControllerSegue.hidden.rawValue),
                                  .sublist("Completed", .middle, WatchedViewController.ViewControllerSegue.completed.rawValue),
                                  .sublist("Dropped", .bottom, WatchedViewController.ViewControllerSegue.dropped.rawValue),
                                  .spacer(5.002)])
        }
        snapshot.appendItems(watchlistedItems.map { Wrapper.watchlist($0) })
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

            cell.dimmedIfWatched = false
            cell.media = MediaModel(item: watchlistItem)

            cell.delegate = self

            return cell
        case .stats(let mediaModels):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as? ListStatsTableViewCell else {
                fatalError("Could not dequeue a list stat cell")
            }

            cell.mediaItems = mediaModels

            return cell
        case .sublist(let name, let cardType, _):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "standard list") as? StandardListTableViewCell else {
                fatalError("Could not dequeue a StandardListTableViewCell for Watched")
            }
            cell.title.text = name
            cell.card.cardType = cardType
            cell.chevron.isHidden = false
            return cell
        case .spacer(let space):
            let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as! SpacerTableViewCell
            cell.space = space
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
            if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "WatchedViewController.currentFilter")) {
                currentFilter = filter
            }

            if let sort = Sort(rawValue: UserDefaults.standard.integer(forKey: "WatchedViewController.currentSorting")) {
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
        tableView.register(UINib(nibName: "StandardListTableViewCell", bundle: nil), forCellReuseIdentifier: "standard list")
        tableView.register(UINib(nibName: "SpacerTableViewCell", bundle: nil), forCellReuseIdentifier: "spacer")
        tableView.separatorStyle = .none

        tableView.dataSource = dataSource

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

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

        if user.isCurrentUser {
            onWatchedShowsChangedReceiver.listen { [weak self] _ in
                guard let self = self else { return }
                self.watchedShows = WatchedManager.shared.watchedShowsItems
                if self.currentFilter == .shows {
                    self.finishRefreshing()
                }
            }.disposed(by: disposeBag)

            onWatchedMoviesChangedReceiver.listen { [weak self] _ in
                guard let self = self else { return }
                self.watchedMovies = WatchedManager.shared.watchedMoviesItems
                if self.currentFilter == .movies {
                    self.finishRefreshing()
                }
            }.disposed(by: disposeBag)
        }
    }

    @objc func refresh(_ sender: Any) {
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
        retry(self)
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        if user.isCurrentUser {
            switch currentFilter {
            case .movies:
                WatchedManager.shared.refreshWatchedMovies()
            case .shows:
                WatchedManager.shared.refreshWatchedShows()
            }
            return
        }

        let request = watchedRequest
        TraktAPIProvider.fetchAllWatchedItems(slug: request.slug,
                                              type: request.type,
                                              extended: request.extended) { [weak self] result in
            guard let self = self, request == self.watchedRequest else { return }

            DispatchQueue.main.async {
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
            }

            switch result {
            case .success(let items):
                let results = Array(Set(items))
                DispatchQueue.main.async {
                    self.watchlistItems = results
                }
            case .failure(let error):
                print("Watched request failure \(error)")

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.error = error
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    private func finishRefreshing() {
        DispatchQueue.main.async {
            self.refreshControl?.isEnabled = true
            self.refreshControl?.endRefreshing()
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

            let filters = UIMenu(title: "What do you want to see?", options: .displayInline, children: [movies, shows])

            let added = UIAction(title: "Watch Date", image: nil, state: self.currentSorting == .lastWatched ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentSorting = .lastWatched
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

extension WatchedViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .watchlist(let watchedItem):
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel(item: watchedItem))
        case .sublist(_, _, let segueIdentifier):
            performSegue(withIdentifier: segueIdentifier, sender: nil)
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
        case .sublist:
            return UITableView.automaticDimension
        case .spacer:
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
        case .sublist:
            return nil
        case .spacer:
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
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.watchlist(let watchedItem) = item else { return nil }

        let share = UIContextualAction(style: .normal,
                                       title: "Share") { _, _, boolValue in
            guard let sharedURL = MediaModel(item: watchedItem).traktWebsiteMediaLink else { return }
            let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
            UIApplication.shared.present(activityViewController)
            boolValue(true)
        }
        share.backgroundColor = UIColor(resource: .ripppleGray).lighter()
        share.image = UIImage(systemName: "arrow.up.circle.fill")

        let comment = UIContextualAction(style: .normal,
                                         title: "Write") { [weak self] _, _, boolValue in
            guard let self = self else { return }
            let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController
            composer.mediaModel = MediaModel(item: watchedItem)
            self.present(composer, animated: true)
            boolValue(true)
        }
        comment.backgroundColor = UIColor(resource: .ripppleGray)
        comment.image = UIImage(systemName: "pencil.circle.fill")

        let recommend = UIContextualAction(style: .normal,
                                           title: "Favorite") { _, _, boolValue in
            SwiftMessages.show(message: "Adding to Favorites...", style: .loading)
            TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: WatchlistedItem(models: [MediaModel(item: watchedItem)])),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /* [weak self] */ result in
                //                                                    guard let self = self else { return }
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        DispatchQueue.main.async {
                            RecommendedManager.shared.refresh()
                            SwiftMessages.show(message: "⭐️ Added to Favorites")
                            print("Recommendation successful \(response)")
                        }

                    } catch {
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            }
            boolValue(false)
        }
        recommend.backgroundColor = UIColor(resource: .ripppleGray).darker()
        recommend.image = UIImage(systemName: "star.circle.fill")

        let configuration = UISwipeActionsConfiguration(actions: [share, comment, recommend])
        configuration.performsFirstActionWithFullSwipe = true

        return configuration
    }
}

extension WatchedViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.watchlist(let watchlistItem) = item else { return }

        if action == .details {
            switch watchlistItem.type {
            case .movie, .show:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel(item: watchlistItem))
            default:
                fatalError("Unhandled media type")
            }
        }
    }
}

extension WatchedViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateDatasource()
    }
}
