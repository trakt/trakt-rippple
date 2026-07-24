//
//  ListReorderingViewController.swift
//  Rippple
//
//  Modal list dedicated to editing Trakt item order only.
//

import UIKit

final class ListReorderingViewController: UITableViewController {
    enum Destination {
        case list(List, User?)
        case watchlist
        case favorites

        var title: String {
            switch self {
            case .list(let list, _):
                return list.name.emojiUnescapedString
            case .watchlist:
                return "Watchlist"
            case .favorites:
                return "Favorites"
            }
        }

        func reorderService(ids: [Int64]) -> TraktAPIService {
            switch self {
            case .list(let list, let user):
                let listId = list.identifiers.trakt!
                let userSlug = list.user.identifiers.slug ?? user?.slug ?? "me"
                return .reorderListItems(slug: userSlug, id: listId, ids: ids)
            case .watchlist:
                return .reorderWatchlistItems(ids: ids)
            case .favorites:
                return .reorderFavoriteItems(ids: ids)
            }
        }

        func handleSuccessfulReorder() {
            switch self {
            case .list(let list, _):
                ListItemsMarkerManager.shared.invalidate(listId: list.identifiers.trakt!)
            case .watchlist:
                WatchlistManager.shared.refresh()
            case .favorites:
                UserFavoritesManager.shared.refresh()
            }
        }
    }

    private enum Section: Int {
        case content
    }

    private enum Row: Hashable {
        case item(WatchlistItem)
    }

    private final class ReorderDiffableDataSource: UITableViewDiffableDataSource<Section, Row> {
        var canMoveRowAtIndexPath: ((IndexPath) -> Bool)?
        var didMoveRow: ((IndexPath, IndexPath) -> Void)?

        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            false
        }

        override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            canMoveRowAtIndexPath?(indexPath) ?? false
        }

        override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            didMoveRow?(sourceIndexPath, destinationIndexPath)
        }
    }

    private let destination: Destination
    private let onCommit: () -> Void

    private let rankedItems: [WatchlistItem]
    private let initialIDs: [Int64]

    private lazy var diffableDataSource = ReorderDiffableDataSource(tableView: tableView) { tableView, _, row in
        switch row {
        case .item(let watchlistItem):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }
            cell.dimmedIfWatched = false
            cell.media = MediaModel(item: watchlistItem)
            cell.note = watchlistItem.notes
            cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
                if let action = action {
                    cell.notesButton?.removeAction(action, for: event)
                }
            }
            cell.delegate = nil
            cell.menuButtonContainter?.isHiddenInStackView = true
            return cell
        }
    }

    init(destination: Destination, items: [WatchlistItem], onCommit: @escaping () -> Void) {
        self.destination = destination
        self.onCommit = onCommit
        let ranked = items.sorted { $0.rank < $1.rank }
        rankedItems = ranked
        initialIDs = ranked.map(\.id)
        super.init(style: .plain)
    }

    convenience init(list: List, user: User?, items: [WatchlistItem], onCommit: @escaping () -> Void) {
        self.init(destination: .list(list, user), items: items, onCommit: onCommit)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = destination.title
        navigationItem.subtitle = "Drag to reorder"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                           target: self,
                                                           action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                            target: self,
                                                            action: #selector(doneTapped))

        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.allowsSelection = false
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self
        tableView.dropDelegate = self

        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")

        diffableDataSource.canMoveRowAtIndexPath = { [weak self] indexPath in
            guard let self = self,
                  let contentSection = self.diffableDataSource.snapshot().indexOfSection(.content) else { return false }
            return indexPath.section == contentSection
        }
        diffableDataSource.didMoveRow = { [weak self] source, destination in
            guard let self = self else { return }
            self.handleMoveRow(from: source, to: destination)
        }

        applyItemsSnapshot()
    }

    private func applyItemsSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        snapshot.appendSections([.content])
        snapshot.appendItems(rankedItems.map { Row.item($0) }, toSection: .content)
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }

    private func watchlistItemsFromSnapshot() -> [WatchlistItem] {
        diffableDataSource.snapshot().itemIdentifiers(inSection: .content).compactMap { row in
            if case .item(let w) = row { return w }
            return nil
        }
    }

    private func handleMoveRow(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath != destinationIndexPath else { return }
        guard let contentSection = diffableDataSource.snapshot().indexOfSection(.content) else { return }
        guard sourceIndexPath.section == contentSection, destinationIndexPath.section == contentSection else { return }

        var snapshot = diffableDataSource.snapshot()
        var rows = snapshot.itemIdentifiers(inSection: .content)
        guard sourceIndexPath.row < rows.count else { return }

        let moved = rows.remove(at: sourceIndexPath.row)
        let targetRow = min(destinationIndexPath.row, rows.count)
        rows.insert(moved, at: targetRow)

        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .content))
        snapshot.appendItems(rows, toSection: .content)
        diffableDataSource.apply(snapshot, animatingDifferences: false)
    }

    private var hasOrderChanged: Bool {
        watchlistItemsFromSnapshot().map(\.id) != initialIDs
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func doneTapped() {
        let ids = watchlistItemsFromSnapshot().map(\.id)
        guard hasOrderChanged else {
            dismiss(animated: true)
            return
        }

        AppManager.shared.isUserInteractionEnabled = false
        TraktAPIProvider.noRatingProvider.request(destination.reorderService(ids: ids),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                AppManager.shared.isUserInteractionEnabled = true
                switch result {
                case .success:
                    self.destination.handleSuccessfulReorder()
                    self.onCommit()
                    self.dismiss(animated: true)
                    SwiftMessages.show(message: "👍 Order updated")
                case .failure(let error):
                    SwiftMessages.show(message: "😓 Couldn't update order", style: .error(error))
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView,
                            targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                            toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        guard let contentSection = diffableDataSource.snapshot().indexOfSection(.content) else { return sourceIndexPath }
        guard proposedDestinationIndexPath.section == contentSection else {
            let rowCount = diffableDataSource.snapshot().numberOfItems(inSection: .content)
            guard rowCount > 0 else { return sourceIndexPath }
            let boundedRow = min(max(proposedDestinationIndexPath.row, 0), rowCount - 1)
            return IndexPath(row: boundedRow, section: contentSection)
        }
        return proposedDestinationIndexPath
    }
}

extension ListReorderingViewController: UITableViewDragDelegate, UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let contentSection = diffableDataSource.snapshot().indexOfSection(.content),
              indexPath.section == contentSection else { return [] }
        guard let row = diffableDataSource.itemIdentifier(for: indexPath), case .item(let watchlistItem) = row else { return [] }

        let itemProvider = NSItemProvider(object: NSString(string: String(watchlistItem.id)))
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = watchlistItem
        dragItem.previewProvider = { [weak tableView] in
            guard let tableView,
                  let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return nil }
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            return UIDragPreview(view: cell.contentView, parameters: parameters)
        }
        return [dragItem]
    }

    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        session.localDragSession != nil
    }

    func tableView(_ tableView: UITableView,
                   dropSessionDidUpdate session: UIDropSession,
                   withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard session.localDragSession != nil else { return UITableViewDropProposal(operation: .cancel) }

        if let destinationIndexPath,
           let contentSection = diffableDataSource.snapshot().indexOfSection(.content),
           destinationIndexPath.section == contentSection {
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        return UITableViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let contentSection = diffableDataSource.snapshot().indexOfSection(.content) else { return }

        let rowCount = diffableDataSource.snapshot().numberOfItems(inSection: .content)
        guard rowCount > 0 else { return }

        var destinationIndexPath = coordinator.destinationIndexPath ?? IndexPath(row: rowCount - 1, section: contentSection)
        if destinationIndexPath.section != contentSection {
            destinationIndexPath = IndexPath(row: rowCount - 1, section: contentSection)
        } else {
            let boundedRow = min(max(destinationIndexPath.row, 0), rowCount - 1)
            destinationIndexPath = IndexPath(row: boundedRow, section: contentSection)
        }

        handleMoveRow(from: sourceIndexPath, to: destinationIndexPath)
        coordinator.drop(item.dragItem, toRowAt: destinationIndexPath)
    }
}
