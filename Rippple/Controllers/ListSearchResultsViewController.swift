//
//  ListSearchResultsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/03/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class ListSearchResultsViewController: UITableViewController {
    /// Public
    var service: TraktAPIService!
    var allowsLoggedOutRequests = false
    var onSubtitleChanged: ((String) -> Void)?
    private var request: Cancellable?
    private var requestID = UUID()

    private let disposeBag = DisposeBag()

    /// Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: NVActivityIndicatorView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error?

    private enum Section: Int {
        case loading
        case error
        case content
    }

    private enum Wrapper: Hashable {
        case list(List)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .list(let list):
            let cell = tableView.dequeueReusableCell(withIdentifier: "custom list") as! ListTableViewCell
            cell.list = list
            cell.delegate = self
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(service != nil, "Search results view controller must be fed with a service object!")

        navigationItem.style = .browser
        updateSubtitle("Loading...")
        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.dataSource = dataSource
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.separatorStyle = .none

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        fetch()
    }

    @IBAction func refresh(_ sender: Any) {
        fetch()
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut, !allowsLoggedOutRequests { return }
        request?.cancel()
        requestID = UUID()
        let identifier = requestID
        error = nil
        updateSubtitle("Loading...")
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        applySnapshot(snapshot)

        request = TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            let lists: Result<[Wrapper], Error> = Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try response.map([ListItem].self, using: TraktAPIProvider.decoder)
                    .compactMap { $0.list }.map { Wrapper.list($0) }.removingDuplicates()
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.requestID == identifier else { return }
                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                switch lists {
                case .success(let items):
                    self.updateSubtitle("\(items.count) result\(items.count == 1 ? "" : "s")")
                    snapshot.appendSections([.content])
                    snapshot.appendItems(items)
                case .failure(let error):
                    self.error = error
                    self.updateSubtitle("Error")
                    snapshot.appendSections([.error])
                }
                self.refreshControl?.endRefreshing()
                self.applySnapshot(snapshot)
            }
        }
    }

    private func applySnapshot(_ snapshot: NSDiffableDataSourceSnapshot<Section, Wrapper>) {
        let identifier = requestID
        let headerOffset = tableView.contentOffset.y + tableView.adjustedContentInset.top
        let isHeaderVisible = tableView.tableHeaderView.map { headerOffset < $0.bounds.height } ?? false
        dataSource.apply(snapshot, animatingDifferences: false) { [weak self] in
            guard let self = self, self.requestID == identifier, isHeaderVisible,
                  !self.tableView.isTracking, !self.tableView.isDragging, !self.tableView.isDecelerating else { return }
            // Section replacement can anchor the first row and scroll the filter header out of view.
            self.tableView.setContentOffset(CGPoint(x: self.tableView.contentOffset.x,
                                                    y: max(0, headerOffset) - self.tableView.adjustedContentInset.top),
                                            animated: false)
        }
    }

    private func updateSubtitle(_ subtitle: String) {
        navigationItem.subtitle = subtitle
        onSubtitleChanged?(subtitle)
    }

    private func openSearchResult(_ list: List) {
        if case .search(_, let query) = service {
            TraktAPIProvider.recordSearchSelection(query: query, type: .list, id: list.identifiers.trakt)
        }
        performSegue(withIdentifier: "list", sender: list)
    }

    @IBSegueAction
    func makeListViewController(coder: NSCoder, sender: Any?) -> ListViewController? {
        ListViewController(coder: coder,
                           list: sender as! List,
                           user: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "user",
           let list = sender as? List,
           let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.user(list.user))
        }
    }
}

extension ListSearchResultsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.list(let list) = item else { return }
        openSearchResult(list)
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
}

extension ListSearchResultsViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        guard let list = cell.list else { return }
        if action == .touch {
            openSearchResult(list)
        } else if action == .user {
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
