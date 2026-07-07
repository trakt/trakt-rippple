//
//  ListSearchResultsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/03/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class ListSearchResultsViewController: UITableViewController {
    /// Public
    var service: TraktAPIService!

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
        navigationItem.subtitle = "Loading..."
        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.dataSource = dataSource
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.separatorStyle = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        fetch()
    }

    @IBAction func refresh(_ sender: Any) {
        fetch()
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let searchResults = try response.map([ListItem].self, using: TraktAPIProvider.decoder).filter { $0.list != nil }.map { Wrapper.list($0.list!) }

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(searchResults.removingDuplicates())
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "\(searchResults.count) result\(searchResults.count < 2 ? "" : "s")"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("List request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "Error"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case .failure(let error):
                print("List request failure \(error)")
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
        if case Wrapper.list(let list) = item {
            performSegue(withIdentifier: "list", sender: list)
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
}

extension ListSearchResultsViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        guard let list = cell.list else { return }
        if action == .touch {
            performSegue(withIdentifier: "list", sender: list)
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
