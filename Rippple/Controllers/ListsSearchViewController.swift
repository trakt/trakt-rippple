//
//  ListsSearchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class ListsSearchViewController: UITableViewController, UISearchResultsUpdating {
    var onSubtitleChanged: ((String) -> Void)?
    private(set) var subtitle = "0 results"
    var onSelectList: ((List) -> Void)?
    var onSelectBrowse: ((BrowseListsViewController.Category) -> Void)?
    weak var listDelegate: ListTableViewCellDelegate?
    var additionalLists = [List]() {
        didSet {
            if isViewLoaded { applySnapshot(reloadLists: true) }
        }
    }

    private enum Section: Hashable {
        case browse, local, remote
    }

    private enum Item: Hashable {
        case browse(BrowseListsViewController.Category)
        case list(List)
        case header(String, String)
        case message(String)
        case loading
        case retry
    }

    private let disposeBag = DisposeBag()
    private var curatedLists = [List]()
    private var likedLists = [List]()
    private var collaborations = [List]()
    private var remoteLists = [List]()
    private var query = ""
    private var isLoading = false
    private var hasError = false
    private var request: Cancellable?
    private var requestID = UUID()
    private var pendingSearch: DispatchWorkItem?

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Item>(tableView: tableView) { [weak self] tableView, indexPath, item in
        guard let self = self else { return nil }
        switch item {
        case .browse(let tab):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath) as! SearchTableViewCell
            cell.setup(with: "\(tab.rawValue) Lists")
            cell.card.cardType = tab == .trending ? .top : tab == .official ? .bottom : .middle
            cell.shouldShowActivityIndicator = false
            return cell
        case .list(let list):
            let cell = tableView.dequeueReusableCell(withIdentifier: "custom list", for: indexPath) as! ListTableViewCell
            cell.user = nil
            cell.list = list
            cell.isEditingMode = false
            cell.delegate = self
            return cell
        case .header(let title, let subtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header", for: indexPath) as! ActivityHeaderTableViewCell
            cell.title.text = title
            cell.subtitle?.text = subtitle
            return cell
        case .message(let message):
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath) as! EmptyTableViewCell
            cell.emoji.text = "🔎"
            cell.title.text = message
            cell.subtitle.text = "Try searching for a different list name."
            cell.body.text = nil
            cell.action.isHidden = true
            return cell
        case .loading:
            let cell = self.statusCell("Searching lists…")
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
            return cell
        case .retry:
            let cell = self.statusCell("Couldn’t load lists. Tap to retry.")
            cell.selectionStyle = .default
            return cell
        }
    }

    deinit {
        pendingSearch?.cancel()
        request?.cancel()
    }

    override func loadView() {
        tableView = TintedPlainTableView(frame: .zero, style: .plain)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.separatorStyle = .none
        tableView.tableHeaderView = TintedView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 15))
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        tableView.sectionHeaderHeight = .leastNonzeroMagnitude
        tableView.estimatedSectionHeaderHeight = 0
        tableView.sectionHeaderTopPadding = 0
        tableView.sectionFooterHeight = 8
        tableView.register(UINib(nibName: "SearchTableViewCell", bundle: nil), forCellReuseIdentifier: "search")
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.dataSource = dataSource
        curatedLists = ListsManager.shared.lists
        collaborations = CollaborationsManager.shared.collaborations

        onCustomListsChangedReceiver.listen { [weak self] lists in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.curatedLists = lists
                self.applySnapshot(reloadLists: true)
            }
        }.disposed(by: disposeBag)
        onLikedListsChangedReceiver.listen { [weak self] lists in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.likedLists = lists
                self.applySnapshot(reloadLists: true)
            }
        }.disposed(by: disposeBag)
        onCollaborationsChangedReceiver.listen { [weak self] lists in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.collaborations = lists
                self.applySnapshot(reloadLists: true)
            }
        }.disposed(by: disposeBag)
        onUserLoggedOutReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cancelSearch()
                self.remoteLists = []
                self.curatedLists = []
                self.likedLists = []
                self.collaborations = []
                self.additionalLists = []
                self.isLoading = false
                self.hasError = false
                self.applySnapshot()
            }
        }.disposed(by: disposeBag)
        applySnapshot()
    }

    func updateSearchResults(for searchController: UISearchController) {
        loadViewIfNeeded()
        let newQuery = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard newQuery != query else { return }
        cancelSearch()
        query = newQuery
        hasError = false
        isLoading = !query.isEmpty
        remoteLists = query.isEmpty ? [] : remoteLists.filter { $0.name.localizedCaseInsensitiveContains(query) }
        applySnapshot()
        guard !query.isEmpty else { return }
        let pending = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.fetchLists()
        }
        pendingSearch = pending
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: pending)
    }

    private func cancelSearch() {
        pendingSearch?.cancel()
        pendingSearch = nil
        requestID = UUID()
        request?.cancel()
        request = nil
    }

    private func fetchLists() {
        cancelSearch()
        guard !query.isEmpty else { return }
        let requestedQuery = query
        let identifier = requestID
        isLoading = true
        hasError = false
        applySnapshot()
        request = TraktAPIProvider.noRatingProvider.request(.search(type: .list, query: requestedQuery), callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let decoded: Result<[List], Error> = Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try response.map([ListItem].self, using: TraktAPIProvider.decoder).compactMap { $0.list }
                    .filter { $0.name.localizedCaseInsensitiveContains(requestedQuery) }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.requestID == identifier, self.query == requestedQuery else { return }
                self.isLoading = false
                switch decoded {
                case .success(let lists): self.remoteLists = lists
                case .failure: self.hasError = true
                }
                self.applySnapshot(reloadLists: true)
            }
        }
    }

    private func applySnapshot(reloadLists: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.browse])
        snapshot.appendItems(BrowseListsViewController.Category.allCases.map { .browse($0) }, toSection: .browse)
        var seen = Set<Identifiers>()
        let localLists = SessionManager.shared.isLoggedOut ? [] : (additionalLists + curatedLists + likedLists + collaborations)
            .filter { seen.insert($0.identifiers).inserted }
        let matches = localLists.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
        if !matches.isEmpty {
            snapshot.appendSections([.local])
            snapshot.appendItems([.header("Your Lists", "\(matches.count) list\(matches.count == 1 ? "" : "s")")], toSection: .local)
            snapshot.appendItems(matches.map { .list($0) }, toSection: .local)
        }
        if !query.isEmpty {
            snapshot.appendSections([.remote])
            seen = Set(matches.map { $0.identifiers })
            let remote = remoteLists.filter { seen.insert($0.identifiers).inserted }
            let headerSubtitle = isLoading ? "Loading..." : "\(remote.count) list\(remote.count == 1 ? "" : "s")"
            snapshot.appendItems([.header("Lists on Trakt", headerSubtitle)], toSection: .remote)
            snapshot.appendItems(remote.map { .list($0) }, toSection: .remote)
            if isLoading {
                snapshot.appendItems([.loading], toSection: .remote)
            } else if hasError {
                snapshot.appendItems([.retry], toSection: .remote)
            } else if remote.isEmpty {
                snapshot.appendItems([.message(matches.isEmpty ? "No Matching Lists" : "No Additional Matching Lists")], toSection: .remote)
            }
        }
        let count = snapshot.itemIdentifiers.reduce(0) { count, item in
            if case .list = item { return count + 1 }
            return count
        }
        subtitle = isLoading ? "Loading..." : "\(count) result\(count == 1 ? "" : "s")"
        onSubtitleChanged?(subtitle)
        if reloadLists {
            let existingItems = Set(dataSource.snapshot().itemIdentifiers)
            snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { item in
                if case .list = item { return existingItems.contains(item) }
                return false
            })
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func statusCell(_ text: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = text
        content.textProperties.color = .secondaryLabel
        content.textProperties.numberOfLines = 0
        cell.contentConfiguration = content
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .browse(let tab): onSelectBrowse?(tab)
        case .list(let list): selectList(list)
        case .retry: fetchLists()
        default: break
        }
    }

    private func selectList(_ list: List) {
        if !query.isEmpty {
            TraktAPIProvider.recordSearchSelection(query: query, type: .list, id: list.identifiers.trakt)
        }
        onSelectList?(list)
    }
}

extension ListsSearchViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        if action == .touch, let list = cell.list {
            selectList(list)
        } else {
            listDelegate?.cell(cell, action: action)
        }
    }
}
