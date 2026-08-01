//
//  ListViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/12/2019.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import SafariServices
import UIKit

extension String {
    var sortableString: String {
        if hasPrefix("The ") { return String(dropFirst("The ".count)) }
        if hasPrefix("A ") { return String(dropFirst("A ".count)) }
        if hasPrefix("An ") { return String(dropFirst("An ".count)) }
        return self
    }
}

extension WatchlistItem {
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

    var hasKnownReleaseDate: Bool {
        switch type {
        case .movie:
            return movie!.released != nil
        case .show:
            return show!.firstAired != nil
        case .season:
            return (season!.firstAired ?? show!.firstAired) != nil
        case .episode:
            return episode!.firstAired != nil
        case .list, .officiallist, .unknown:
            return false
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

    var lastWatchedAt: Date? {
        switch type {
        case .movie:
            guard let traktId = movie?.identifiers.trakt else { return nil }
            return SyncWatchedManager.shared.lastWatchedAt(for: .movies, traktId: traktId)
        case .show, .season:
            // Synced season data only retains whether a season was watched, so use the parent show's date.
            guard let traktId = show?.identifiers.trakt else { return nil }
            return SyncWatchedManager.shared.lastWatchedAt(for: .shows, traktId: traktId)
        case .episode:
            guard let traktId = episode?.identifiers.trakt else { return nil }
            return SyncWatchedManager.shared.lastWatchedAt(for: .episodes, traktId: traktId)
        case .list, .officiallist, .unknown:
            return nil
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

final class ListViewController: UITableViewController {
    // Private
    private var user: User?
    private var list: List!

    private let disposeBag = DisposeBag()

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
        case lastWatched
    }

    private var fetchTask: Task<Void, Never>?
    private let progressContext = ListProgressContext()

    private var watchlistItems: [WatchlistItem]? {
        didSet {
            if let watchlistItems = watchlistItems {
                progressContext.update(items: watchlistItems)
            } else {
                progressContext.reset()
            }
            updateDatasource()
        }
    }

    private let contextMenu = ContextMenuHelper()

    // Empty
    @IBOutlet var emptyLabel: UILabel!
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: UIView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching the list's content.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching the list's content..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    private let searchController = UISearchController(searchResultsController: nil)
    private var searchQuery = ""

    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.none {
        didSet {
            UserDefaults.standard.set(currentFilter.rawValue, forKey: "ListViewController.\(list.identifiers.trakt!).currentFilter")
            UserDefaults.standard.synchronize()

            filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            navigationItem.title = list.name.emojiUnescapedString

            switch currentFilter {
            case .none:
                navigationItem.subtitle = "All Items"
            case .movies:
                navigationItem.subtitle = "Movies"
            case .episodes:
                navigationItem.subtitle = "Episodes"
            case .shows:
                navigationItem.subtitle = "Shows"
            case .seasons:
                navigationItem.subtitle = "Seasons"
            }

            if watchlistItems != nil {
                updateDatasource()
            }
        }
    }

    /// Sort
    private var currentSorting = Sort.rank {
        didSet {
            UserDefaults.standard.set(currentSorting.rawValue, forKey: "ListViewController.\(list.identifiers.trakt!).currentSorting")
            UserDefaults.standard.synchronize()

            if watchlistItems != nil {
                updateDatasource()
            }
        }
    }

    init?(coder: NSCoder, list: List, user: User?) {
        self.list = list
        self.user = user

        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Section: Int {
        case loading
        case error
        case content
        case header
    }

    private enum Wrapper: Hashable {
        case header
        case item(WatchlistItem)
        case stats([MediaModel])

        static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
            switch (lhs, rhs) {
            case (.header, .header):
                return true
            case (.item(let lhs), .item(let rhs)):
                return lhs.id == rhs.id
            case (.stats(let lhs), .stats(let rhs)):
                return lhs == rhs
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .header:
                hasher.combine(0)
            case .item(let watchlist):
                hasher.combine(1)
                hasher.combine(watchlist.id)
            case .stats(let mediaModels):
                hasher.combine(2)
                hasher.combine(mediaModels)
            }
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
        case .lastWatched:
            return filteredWatchlistItems
                .map { (item: $0, watchedAt: $0.lastWatchedAt ?? Date.distantPast) }
                .sorted {
                    if $0.watchedAt == $1.watchedAt {
                        return $0.item.rank < $1.item.rank
                    }
                    return $0.watchedAt > $1.watchedAt
                }
                .map { $0.item }
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
            guard searchQuery.isEmpty == false else { return true }
            if $0.title.localizedCaseInsensitiveContains(searchQuery) { return true }
            if String($0.releaseYear).localizedCaseInsensitiveContains(searchQuery) { return true }
            return false
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.header])
        if searchQuery.isEmpty {
            snapshot.appendItems([Wrapper.header])
        }
        if watchlistItems == nil {
            snapshot.appendSections([.loading])
        } else {
            snapshot.appendItems([.stats(watchlistedItems.map { MediaModel(item: $0) })])
        }
        snapshot.appendSections([.content])
        snapshot.appendItems(watchlistedItems.map { Wrapper.item($0) })
        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private class WatchlistDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let item = itemIdentifier(for: indexPath) else { return false }
            guard case Wrapper.item(let watchlistItem) = item else { return false }
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

    private lazy var dataSource = WatchlistDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .header:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "light list") as? ListTableViewCell else {
                fatalError("Could not dequeue a list cell")
            }

            cell.user = self.user
            cell.list = self.list
            cell.delegate = self

            return cell
        case .item(let watchlistItem):
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
            cell.listProgressContext = progressContext
            cell.delegate = self

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser

        let loading = NVActivityIndicatorView(frame: CGRect(x: 0,
                                                            y: 0,
                                                            width: animationViewContainer.frame.width,
                                                            height: animationViewContainer.frame.height))
        loading.color = UIColor(asset: .globalTint)
        loading.type = .ballScaleMultiple
        loading.startAnimating()

        animationViewContainer.addSubview(loading)

        tableView.keyboardDismissMode = .onDrag
        tableView.separatorStyle = .none

        refreshControl?.isEnabled = false

        if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "ListViewController.\(list.identifiers.trakt!).currentFilter")) {
            currentFilter = filter
        }

        if let sort = Sort(rawValue: UserDefaults.standard.integer(forKey: "ListViewController.\(list.identifiers.trakt!).currentSorting")) {
            currentSorting = sort
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "LightListTableViewCell", bundle: nil), forCellReuseIdentifier: "light list")
        tableView.register(UINib(nibName: "ListStatsTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        tableView.dragDelegate = tableView as? CustomTableView
        tableView.dropDelegate = nil

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.header])
        snapshot.appendItems([Wrapper.header])
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        onListChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            for list in lists where list == self.list {
                self.list = list
                self.fetch()
            }
        }.disposed(by: disposeBag)

        filterButtonItem.primaryAction = nil
        filterButtonItem.menu = filterMenu()

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false

        searchController.searchBar.placeholder = "Search \(list.name.emojiUnescapedString)"
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        searchController.searchBar.barTintColor = nil
        searchController.searchBar.barStyle = .default
        searchController.searchBar.isTranslucent = true

        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = searchController

        fetch()

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        listUpdatedReceiver.listen { [weak self] changedList in
            guard let self = self else { return }
            if self.list == changedList {
                self.list = changedList
                var snapshot = self.dataSource.snapshot()
                snapshot.reloadSections([.header])
                self.dataSource.apply(snapshot)
            }
        }.disposed(by: disposeBag)

        onWatchlistTypeNotesChangedReceiver.listen { [weak self] watchlistType in
            guard let self = self else { return }
            if case .listItem(_, _, let listId, _, _, _, _) = watchlistType {
                if list.identifiers.trakt == listId {
                    self.fetch()
                }
            }
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.updateDatasourceIfSortingByLastWatched()
        }.disposed(by: disposeBag)

        onSyncWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.updateDatasourceIfSortingByLastWatched()
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.updateDatasourceIfSortingByLastWatched()
        }.disposed(by: disposeBag)

        buildMenu()

        emptyView.removeFromSuperview()
        loadingView.removeFromSuperview()
        errorView.removeFromSuperview()
    }

    private func buildMenu() {
        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu()),
                                              .fixedSpace(),
                                              filterButtonItem]
    }

    private func menu() -> UIMenu {
        let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }

            let alert = UIAlertController(title: "Delete \(self.list.name.emojiUnescapedString)?",
                                          message: "This can't be undone!",
                                          preferredStyle: .alert)

            let delete = UIAlertAction(title: "Yes, delete it", style: .destructive) { [weak self] _ in
                guard let self = self else { return }
                SwiftMessages.show(message: "Deleting List...", style: .loading)

                TraktAPIProvider.provider.request(.deleteList(id: self.list.identifiers.trakt!), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }

                    switch result {
                    case .success:
                        DispatchQueue.main.async {
                            self.navigationController?.popViewController(animated: true)
                            ListsManager.shared.refresh()
                            SwiftMessages.show(message: "👍 Your list has been deleted")
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            print("customLists request failure \(error)")
                            ListsManager.shared.refresh()
                            SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                        }
                    }
                }
            }
            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alert.addAction(delete)
            alert.addAction(cancel)

            self.present(alert, animated: true)
        }

        let edit = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "edit", sender: self.list)
        }

        let couchMoney = UIAction(title: "Open couchmoney.tv", image: UIImage(systemName: "sofa")) { _ in
            UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://couchmoney.tv/mylists")!))
        }

        let like = UIAction(title: "Like", image: UIImage(systemName: "hand.thumbsup")) { [weak self] _ in
            guard let self = self else { return }
            self.list.like()
            self.buildMenu()
        }

        let unlike = UIAction(title: "Unlike", image: UIImage(systemName: "hand.thumbsup.fill"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.list.like()
            self.buildMenu()
        }

        let browseAsGrid = UIAction(title: "Show in Grid", image: UIImage(systemName: "rectangle.grid.3x2")) { [weak self] _ in
            guard let self = self else { return }
            self.performSegue(withIdentifier: "grid", sender: self.list)
        }

        let savedFilter = list.savedFilter
        let shelved = savedFilter.isShelved

        let shelfOnTop = UIAction(title: "Shelf On Top",
                                  image: UIImage(systemName: "text.line.first.and.arrowtriangle.forward")) { _ in
            savedFilter.shelf(onTop: true)
            self.buildMenu()
        }
        let shelfUnder = UIAction(title: "Shelf Under",
                                  image: UIImage(systemName: "text.line.last.and.arrowtriangle.forward")) { _ in
            savedFilter.shelf(onTop: false)
            self.buildMenu()
        }

        let unshelf = UIAction(title: "Remove from Shelf",
                               image: UIImage(systemName: "minus.circle.fill"),
                               attributes: .destructive) { _ in
            savedFilter.unshelf()
            self.buildMenu()
        }

        let shelfActions = if shelved {
            UIMenu(options: .displayInline, children: [unshelf])
        } else {
            UIMenu(options: .displayInline, children: [shelfOnTop, shelfUnder])
        }

        var reorderMenu = [UIMenu]()
        if isListEditable {
            let reorder = UIAction(title: "Reorder Items",
                                   image: UIImage(systemName: "arrow.up.arrow.down")) { [weak self] _ in
                guard let self = self else { return }

                let listReorderingViewController = ListReorderingViewController(list: list,
                                                                                user: user,
                                                                                items: watchlistItems ?? []) { [weak self] in
                    guard let self = self else { return }
                    self.fetch()
                }
                let navigation = UINavigationController(rootViewController: listReorderingViewController)
                navigation.modalPresentationStyle = .pageSheet
                present(navigation, animated: true)
            }
            reorderMenu = [UIMenu(options: .displayInline, children: [reorder])]
        }

        if list.user.isCurrentUser {
            if let shareLink = list.shareLink,
               list.privacy != .me,
               list.privacy != .unknown {
                var title = "Share"
                switch list.privacy {
                case .all:
                    title = "Share"
                case .friends:
                    title = "Share with Friends"
                case .link:
                    title = "Share Link"
                case .me: // this should never happen (if)
                    title = "Share"
                case .unknown: // this should never happen (if)
                    title = "Share"
                }
                let share = UIAction(title: title,
                                     image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    guard let sharedURL = URL(string: shareLink) else { return }
                    let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
                    UIApplication.shared.present(activityViewController)
                }
                if list.name.localizedCaseInsensitiveContains("[couchmoney.tv]") {
                    return UIMenu(children: reorderMenu + [UIMenu(options: .displayInline, children: [couchMoney]), shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid]), share])
                } else {
                    return UIMenu(children: reorderMenu + [UIMenu(options: .displayInline, children: [edit, delete]), shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid]), share])
                }
            } else {
                if list.name.localizedCaseInsensitiveContains("[couchmoney.tv]") {
                    return UIMenu(children: reorderMenu + [couchMoney, shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid])])
                } else {
                    return UIMenu(children: reorderMenu + [edit, delete, shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid])])
                }
            }
        } else {
            if let shareLink = list.shareLink, list.privacy == .all {
                let share = UIAction(title: "Share",
                                     image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    guard let sharedURL = URL(string: shareLink) else { return }
                    let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
                    UIApplication.shared.present(activityViewController)
                }
                return UIMenu(children: reorderMenu + [list.liked ? unlike : like, shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid]), share])
            } else {
                return UIMenu(children: reorderMenu + [list.liked ? unlike : like, shelfActions, UIMenu(options: .displayInline, children: [browseAsGrid])])
            }
        }
    }

    deinit {
        fetchTask?.cancel()
    }

    @objc func refresh(_ sender: Any) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.header])
        snapshot.appendItems([Wrapper.header])
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)
        fetch()
    }

    @IBAction func retry(_ sender: Any) {
        error = nil
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.header])
        snapshot.appendItems([Wrapper.header])
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)
        fetch()
    }

    private func reset() {
        fetchTask?.cancel()
        watchlistItems = nil
        retry(self)
    }

    func fetch() {
        defer {
            DispatchQueue.main.async {
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
            }
        }

        fetchTask?.cancel()
        TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                           id: list.identifiers.trakt!,
                                           type: nil) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let results):
                self.watchlistItems = results.removingDuplicates()
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
        if let listFormViewController = (segue.destination as? UINavigationController)?.viewControllers.first as? ListFormViewController,
           let list = sender as? List {
            listFormViewController.list = list
            return
        }

        if let gridViewController = segue.destination as? GridViewController,
           let list = sender as? List {
            gridViewController.savedFilter = list.savedFilter
            return
        }

        if let commentsViewController = segue.destination as? CommentsViewController,
           let cell = sender as? MediaTableViewCell,
           let index = tableView.indexPath(for: cell) {
            let mediaItem = dataSource.itemIdentifier(for: index)
            switch mediaItem {
            case .item(let item):
                switch item.type {
                case .movie:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.movie(item.movie!)))
                case .show:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.show(item.show!)))
                case .episode:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.episode(item.episode!, item.show!)))
                case .season:
                    commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.season(item.season!, item.show!)))
                default:
                    fatalError("Unhandled media type fed to search results view controller")
                }
            default:
                fatalError("Unhandled media type fed to search results view controller")
            }
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if segue.identifier == "user",
                  let list = sender as? List,
                  let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.user(list.user))
        }
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let all = UIAction(title: "Everything", image: nil, state: self.currentFilter == .none ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .none
            }

            let movies = UIAction(title: "Movies",
                                  image: nil,
                                  state: self.currentFilter == .movies ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .movies
            }

            let shows = UIAction(title: "Shows",
                                 image: nil,
                                 state: self.currentFilter == .shows ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .shows
            }

            let seasons = UIAction(title: "Seasons",
                                   image: nil,
                                   state: self.currentFilter == .seasons ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .seasons
            }

            let episodes = UIAction(title: "Episodes",
                                    image: nil,
                                    state: self.currentFilter == .episodes ? .on : .off) { [weak self] _ in
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

            let lastWatched = UIAction(title: "Last Watched", image: nil, state: self.currentSorting == .lastWatched ? .on : .off) { [weak self] _ in
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

            let sorting = UIMenu(title: "Sort By", children: [rank, added, lastWatched, title, release, runtime, weightedRating, rating, votes, random])

            completion([filters, sorting])
        }

        return UIMenu(children: [deferredMenuElement])
    }

    private func updateDatasourceIfSortingByLastWatched() {
        guard currentSorting == .lastWatched, watchlistItems != nil else { return }
        updateDatasource()
    }

    private var isListEditable: Bool {
        list.user.isCurrentUser || CollaborationsManager.shared.collaborations.contains(list)
    }

    private func showProgress() {
        let progressViewController = ListProgressViewController(list: list,
                                                                user: user,
                                                                progressContext: progressContext,
                                                                sorting: currentSorting.rawValue)
        navigationController?.pushViewController(progressViewController, animated: true)
    }
}

extension ListViewController: ListStatsTableViewCellDelegate {
    func cell(_ cell: ListStatsTableViewCell, action: ListStatsTableViewCell.Action) {
        switch action {
        case .progress:
            showProgress()
        }
    }
}

extension ListViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .item(let watchlistItem):
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

        if section == dataSource.snapshot().indexOfSection(Section.content) {
            if watchlistItems != nil, dataSource.snapshot().numberOfItems(inSection: Section.content) == 0 {
                if list.itemCount == 0, list.user.isCurrentUser {
                    emptyLabel.text = "Your list seems to be empty.\nTry adding something in it: a movie,\na tv show, an episode or a season.\nOr don't. Do as you wish."
                } else if list.itemCount == 0 {
                    emptyLabel.text = "This list seems to be empty.\nI wouldn't like it but it's your call."
                } else if currentFilter == .none {
                    if searchQuery.isEmpty {
                        emptyLabel.text = "This list seems to be empty...\nDo you hear that? No. Nothing..."
                    } else {
                        emptyLabel.text = "Trying to search for something that's not there?\nTry something else..."
                    }
                } else {
                    emptyLabel.text = "There's nothing to see now.\nMaybe try another filter.\nYou never know what you could find."
                }

                return emptyView
            }
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

        if section == dataSource.snapshot().indexOfSection(Section.content) {
            if watchlistItems != nil, dataSource.snapshot().numberOfItems(inSection: Section.content) == 0 {
                return 100
            }
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.section == dataSource.snapshot().indexOfSection(Section.content) {
            let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
            contextMenu.cell = cell
            contextMenu.controller = self

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        }
        return nil
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
        guard case Wrapper.item(let watchlistItem) = item else { return nil }
        let media = MediaModel(item: watchlistItem)
        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if !list.user.isCurrentUser, CollaborationsManager.shared.collaborations.contains(list) == false { return nil }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.item(let watchlistItem) = item else { return nil }

        let remove = UIContextualAction(style: .normal,
                                        title: "Remove") { _, _, boolValue in
            self.remove(item: watchlistItem, from: self.list)
            boolValue(true)
        }
        remove.image = UIImage(systemName: "minus.circle.fill")
        remove.backgroundColor = .systemRed

        var actions = [UIContextualAction]()

        if list.name.localizedCaseInsensitiveContains("[couchmoney.tv]") == false {
            actions.append(remove)
        }

        if UserManager.shared.isCurrentVIP {
            let note = UIContextualAction(style: .normal,
                                          title: "Notes") { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.promptForNote(on: watchlistItem)
                boolValue(true)
            }
            note.image = UIImage(systemName: "note.text.badge.plus")
            note.backgroundColor = UIColor(resource: .ripppleGray)

            actions.append(note)
        }

        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func displayNotes(for watchlistItem: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.listItem(note: watchlistItem.notes ?? "",
                                                                  userId: list.user.identifiers.slug ?? user?.slug ?? "me",
                                                                  listId: list.identifiers.trakt!,
                                                                  itemId: watchlistItem.id,
                                                                  canEdit: UserManager.shared.isCurrentVIP && (list.user.isCurrentUser || CollaborationsManager.shared.collaborations.contains(list)),
                                                                  user: list.user,
                                                                  listItem: watchlistItem))
    }

    private func promptForNote(on watchlistItem: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.listItem(note: watchlistItem.notes ?? "",
                                                                  userId: list.user.identifiers.slug ?? user?.slug ?? "me",
                                                                  listId: list.identifiers.trakt!,
                                                                  itemId: watchlistItem.id,
                                                                  canEdit: UserManager.shared.isCurrentVIP && (list.user.isCurrentUser || CollaborationsManager.shared.collaborations.contains(list)),
                                                                  user: list.user,
                                                                  listItem: watchlistItem))
    }
}

extension ListViewController {
    private func remove(item: WatchlistItem, from list: List) {
        if SessionManager.shared.isLoggedOut { return }

        var watchlistedItem: WatchlistedItem
        if let episode = item.episode {
            watchlistedItem = WatchlistedItem(episode: episode)
        } else if let season = item.season {
            watchlistedItem = WatchlistedItem(season: season)
        } else if let show = item.show {
            watchlistedItem = WatchlistedItem(show: show)
        } else if let movie = item.movie {
            watchlistedItem = WatchlistedItem(movie: movie)
        } else {
            fatalError()
        }

        TraktAPIProvider.provider.request(.removeFromList(slug: list.user.slug,
                                                          id: list.identifiers.trakt!,
                                                          item: watchlistedItem), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if response.statusCode == 200 {
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: "❎ Removed from list")
                            onListChangedTransmitter.broadcast([list])
                            AppManager.shared.isUserInteractionEnabled = true
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("List items request JSON mapping failed! \(error)")
                        SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                        AppManager.shared.isUserInteractionEnabled = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("List items request failure \(error)")
                    SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                    AppManager.shared.isUserInteractionEnabled = true
                }
            }
        }
    }
}

extension ListViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.item(let watchlistItem) = item else { return }

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

extension ListViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        guard let list = cell.list else { return }
        if action == .user {
            if let type = list.type, type == "official" {
                let alert = UIAlertController(title: "Trakt Official List",
                                              message: "This is an official list created and maintained by Trakt.",
                                              preferredStyle: .alert)
                let okay = UIAlertAction(title: "Okay", style: .default) { [weak self] _ in
                    guard let self = self else { return }

                    self.dismiss(animated: true)
                }
                alert.addAction(okay)
                present(alert, animated: true)
            } else {
                performSegue(withIdentifier: "user", sender: list)
            }
        }
    }
}

extension ListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateDatasource()
    }
}

final class NoteTextFieldDelegate: NSObject, UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        return updatedText.count <= 255
    }
}

extension List {
    var savedFilter: SavedFilter {
        if let slug = user.identifiers.slug {
            return SavedFilter(section: "lists",
                               name: "\(name)",
                               path: "/users/\(slug)/lists/\(identifiers.trakt!)/items/movie,show,season,episode",
                               query: "",
                               limit: 250)
        } else {
            return SavedFilter(section: "lists",
                               name: "\(name)",
                               path: "/lists/\(identifiers.trakt!)/items/movie,show,season,episode",
                               query: "",
                               limit: 250)
        }
    }
}
