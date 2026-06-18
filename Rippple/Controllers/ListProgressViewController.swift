//
//  ListProgressViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 16/06/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Receiver
import UIKit

struct ListProgressResult {
    let watchedCount: Int
    let totalCount: Int
    let notWatchedItems: [WatchlistItem]

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(watchedCount) / Double(totalCount)
    }

    var percentage: Int {
        return Int((progress * 100).rounded())
    }
}

final class ListProgressContext {
    enum Status {
        case idle
        case loading
        case content(ListProgressResult)
    }

    private let disposeBag = DisposeBag()
    private let statusReceiverPair = Receiver<Status>.make(with: .warm(upTo: 1))
    private var debouncedRefreshProgress: Debouncer!

    private var status = Status.idle {
        didSet {
            broadcast(status: status)
        }
    }

    private var items: [WatchlistItem]?

    private let operationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "List progress operation queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    init() {
        broadcast(status: status)

        debouncedRefreshProgress = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.refresh()
        }

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefreshProgress.call()
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefreshProgress.call()
        }.disposed(by: disposeBag)
    }

    var currentResult: ListProgressResult? {
        if case .content(let result) = status {
            return result
        }
        return nil
    }

    var onStatusChangedReceiver: Receiver<Status> {
        return statusReceiverPair.1
    }

    func update(items: [WatchlistItem]) {
        self.items = items
        refresh()
    }

    func reset() {
        operationQueue.cancelAllOperations()
        items = nil
        status = .idle
    }

    func refresh() {
        guard let items = items else { return }

        operationQueue.cancelAllOperations()
        if currentResult == nil {
            status = .loading
        }

        let operation = UpdateListProgressOperation(items: items)
        operation.completionBlock = { [weak self] in
            guard let self = self else { return }
            if operation.isCancelled { return }
            DispatchQueue.main.async {
                self.status = .content(operation.result)
            }
        }
        operationQueue.addOperation(operation)
    }

    private func broadcast(status: Status) {
        DispatchQueue.main.async {
            self.statusReceiverPair.0.broadcast(status)
        }
    }
}

final class ListProgressViewController: UITableViewController {
    private let list: List
    private let user: User?
    private let progressContext: ListProgressContext
    private let sorting: Sort

    private let disposeBag = DisposeBag()
    private var searchQuery = ""
    private let searchController = UISearchController(searchResultsController: nil)
    private let contextMenu = ContextMenuHelper()

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

    private enum Section {
        case content
    }

    init(list: List, user: User?, progressContext: ListProgressContext, sorting: Int) {
        self.list = list
        self.user = user
        self.progressContext = progressContext
        self.sorting = Sort(rawValue: sorting) ?? .rank

        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, WatchlistItem>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
            fatalError("Could not dequeue a media cell")
        }

        cell.media = MediaModel(item: item)
        cell.note = item.notes

        cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                cell.notesButton?.removeAction(action, for: event)
            }
        }
        if let notes = item.notes, notes.isEmpty == false {
            cell.notesButton?.toolTip = notes
            cell.notesButton?.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.displayNotes(for: item)
                UISelectionFeedbackGenerator().selectionChanged()
            },
            for: .touchUpInside)
        }

        cell.delegate = self

        return cell
    }

    private var sortedItems: [WatchlistItem] {
        let items = progressContext.currentResult?.notWatchedItems ?? [WatchlistItem]()
        let filteredItems = items.filter {
            guard searchQuery.isEmpty == false else { return true }
            if $0.title.localizedCaseInsensitiveContains(searchQuery) { return true }
            if String($0.releaseYear).localizedCaseInsensitiveContains(searchQuery) { return true }
            return false
        }

        switch sorting {
        case .rank:
            return filteredItems.sorted { $0.rank < $1.rank }
        case .listed:
            return filteredItems.sorted { $0.listedAt > $1.listedAt }
        case .title:
            return filteredItems.sorted { $0.title < $1.title }
        case .releaseDate:
            return filteredItems.sorted { $0.releaseDate > $1.releaseDate }
        case .runtime:
            return filteredItems.sorted { $0.runtime > $1.runtime }
        case .rating:
            return filteredItems.sorted { $0.rating > $1.rating }
        case .votes:
            return filteredItems.sorted { $0.votes > $1.votes }
        case .random:
            return filteredItems.shuffled()
        case .weightedRating:
            return filteredItems.sorted { $0.weightedRating > $1.weightedRating }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = list.name.emojiUnescapedString
        navigationItem.subtitle = "To Watch"

        tableView.allowsFocus = false
        tableView.keyboardDismissMode = .onDrag
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.dataSource = dataSource

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search Not Watched"
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        searchController.searchBar.barTintColor = nil
        searchController.searchBar.barStyle = .default
        searchController.searchBar.isTranslucent = true

        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = searchController

        progressContext.onStatusChangedReceiver.listen { [weak self] status in
            guard let self = self else { return }
            self.update(with: status)
        }.disposed(by: disposeBag)
    }

    @objc func refresh(_ sender: Any) {
        progressContext.refresh()
    }

    private func update(with status: ListProgressContext.Status) {
        switch status {
        case .idle:
            tableView.backgroundView = emptyView(text: "Progress will appear when the list has loaded.")
            updateDatasource(items: [])
            refreshControl?.endRefreshing()
        case .loading:
            tableView.backgroundView = loadingView()
            updateDatasource(items: [])
        case .content(let result):
            let items = sortedItems
            if result.notWatchedItems.isEmpty {
                tableView.backgroundView = emptyView(text: "Everything in this list is watched.")
            } else if items.isEmpty {
                tableView.backgroundView = emptyView(text: "Trying to search for something that's not there?\nTry something else...")
            } else {
                tableView.backgroundView = nil
            }
            updateDatasource(items: items)
            refreshControl?.endRefreshing()
        }
    }

    private func updateDatasource(items: [WatchlistItem]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, WatchlistItem>()
        snapshot.appendSections([.content])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func emptyView(text: String) -> UIView {
        let label = UILabel()
        label.text = text
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel

        let container = UIView()
        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }

    private func loadingView() -> UIView {
        let loading = UIActivityIndicatorView(style: .medium)
        loading.color = UIColor(asset: .globalTint)
        loading.startAnimating()

        let container = UIView()
        container.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loading.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])

        return container
    }
}

extension ListProgressViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        showDetails(for: MediaModel(item: item))
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
        contextMenu.cell = cell
        contextMenu.controller = self

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            self.contextMenu.previewViewController
        }, actionProvider: { _ in
            self.contextMenu.menu
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
        return MediaModel(item: item).trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if !list.user.isCurrentUser, CollaborationsManager.shared.collaborations.contains(list) == false { return nil }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        let remove = UIContextualAction(style: .normal,
                                        title: "Remove") { _, _, boolValue in
            self.remove(item: item, from: self.list)
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
                self.promptForNote(on: item)
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

    private func displayNotes(for item: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.listItem(note: item.notes ?? "",
                                                                  userId: list.user.identifiers.slug ?? user?.slug ?? "me",
                                                                  listId: list.identifiers.trakt!,
                                                                  itemId: item.id,
                                                                  canEdit: UserManager.shared.isCurrentVIP && (list.user.isCurrentUser || CollaborationsManager.shared.collaborations.contains(list)),
                                                                  user: list.user,
                                                                  listItem: item))
    }

    private func promptForNote(on item: WatchlistItem) {
        NotesManager.shared.showNotes(for: WatchlistType.listItem(note: item.notes ?? "",
                                                                  userId: list.user.identifiers.slug ?? user?.slug ?? "me",
                                                                  listId: list.identifiers.trakt!,
                                                                  itemId: item.id,
                                                                  canEdit: UserManager.shared.isCurrentVIP && (list.user.isCurrentUser || CollaborationsManager.shared.collaborations.contains(list)),
                                                                  user: list.user,
                                                                  listItem: item))
    }
}

extension ListProgressViewController {
    private func showDetails(for media: MediaModel) {
        guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else { return }
        mediaViewController.media = media
        navigationController?.show(mediaViewController, sender: self)
    }

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

extension ListProgressViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        if action == .details {
            switch item.type {
            case .movie, .show:
                showDetails(for: MediaModel(item: item))
            case .episode, .season:
                showDetails(for: MediaModel.show(item.show!))
            default:
                fatalError("Unhandled media type")
            }
        }
    }
}

extension ListProgressViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let result = progressContext.currentResult {
            update(with: .content(result))
        } else {
            updateDatasource(items: sortedItems)
        }
    }
}

private class UpdateListProgressOperation: Operation, @unchecked Sendable {
    private let progressDispatchGroup = DispatchGroup()
    private let resultLock = NSLock()

    private let items: [WatchlistItem]
    private var watchedCount = 0
    private var notWatchedItems = [WatchlistItem]()
    private var totalCount = 0

    fileprivate var result = ListProgressResult(watchedCount: 0,
                                                totalCount: 0,
                                                notWatchedItems: [])

    init(items: [WatchlistItem]) {
        self.items = items
    }

    override func cancel() {
        state = .isFinished

        super.cancel()
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool {
        true
    }

    override var isExecuting: Bool {
        state == .isExecuting
    }

    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        guard !isCancelled else {
            state = .isFinished
            return
        }

        state = .isExecuting

        for item in items {
            if isCancelled { break }
            process(item)
        }

        progressDispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }

            self.resultLock.lock()
            self.result = ListProgressResult(watchedCount: watchedCount,
                                             totalCount: totalCount,
                                             notWatchedItems: notWatchedItems)
            self.resultLock.unlock()

            self.state = .isFinished
        }
    }

    private func process(_ item: WatchlistItem) {
        switch item.type {
        case .movie:
            guard let movie = item.movie else { return }
            record(item: item, watched: movie.isWatched)
        case .episode:
            guard let episode = item.episode else { return }
            record(item: item, watched: episode.isWatched)
        case .show:
            guard let show = item.show else { return }
            if show.isWatchedAtLeastOnce == false {
                record(item: item, watched: false)
            } else {
                fetchProgress(for: show, item: item) { progress in
                    progress.aired > 0 && progress.completed >= progress.aired
                }
            }
        case .season:
            guard let show = item.show, let season = item.season else { return }
            if show.isWatchedAtLeastOnce == false {
                record(item: item, watched: false)
            } else {
                fetchProgress(for: show, item: item) { progress in
                    progress.isWatched(season: season)
                }
            }
        case .list, .officiallist, .unknown:
            break
        }
    }

    private func fetchProgress(for show: Show,
                               item: WatchlistItem,
                               isWatched: @escaping (ShowProgress) -> Bool) {
        progressDispatchGroup.enter()
        _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            let progress = await show.mediaModel.progress()

            if isCancelled {
                progressDispatchGroup.leave()
                return
            }

            if let progress = progress {
                record(item: item, watched: isWatched(progress))
            } else {
                record(item: item, watched: false)
            }
            progressDispatchGroup.leave()
        }
    }

    private func record(item: WatchlistItem, watched: Bool) {
        resultLock.lock()
        totalCount += 1
        if watched {
            watchedCount += 1
        } else {
            notWatchedItems.append(item)
        }
        resultLock.unlock()
    }
}
