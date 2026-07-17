//
//  PendingFollowingRequestsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2025.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class PendingFollowingRequestsViewController: UITableViewController {
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

    private let disposeBag = DisposeBag()

    private enum Wrapper: Hashable {
        case pending(User)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { tableView, _, item in
        switch item {
        case .pending(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell
            cell.user = user
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = "Pending Following Requests"

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "UserInListTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        navigationItem.largeTitleDisplayMode = .never

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        refresh()

        FollowManager.shared.onPendingFollowingChangedReceiver.listen { [weak self] _ in
            guard let self else { return }
            self.refresh()
        }.disposed(by: disposeBag)
    }

    private func refresh() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        fetch()
    }

    private func fetch() {
        TraktAPIProvider.provider.request(.pendingFollowing, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let users = try response.map([Follow].self, using: TraktAPIProvider.decoder).map { $0.user }.removingDuplicates()

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(users.map { Wrapper.pending($0) })
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("/users/requests/pendingFollowing request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case .failure(let error):
                print("/users/requests/pendingFollowing request failure \(error)")
                self.error = error

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            let type = sender as! CommentsCoordinator.ListType
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }
    }
}

extension PendingFollowingRequestsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.pending(let user) = item else { return }

        let nextType = CommentsCoordinator.ListType.user(user)
        performSegue(withIdentifier: "user", sender: nextType)
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
}
