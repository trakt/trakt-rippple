//
//  FollowersViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 22/01/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Moya

final class FollowersViewController: UITableViewController {

    // Public
    var user: User!

    // Private
    private var followers = [User]()

    // Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private weak var animationViewContainer: NVActivityIndicatorView!

    private var currentPage: PageInfo?

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error?

    // Standard Footer
    @IBOutlet private var footerView: UIView!

    private enum Section: Int {
        case loading
        case error
        case content
        case footer
    }

    private enum Wrapper: Hashable {
        case follower(User)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .follower(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell

            cell.user = user

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(user != nil, "View controller must be fed with a User object!")

        navigationItem.style = .browser

        if user.isCurrentUser {
            navigationItem.title = "Your Followers"
        } else {
            navigationItem.title = "\(user.username)'s Followers"
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "UserInListTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        navigationItem.largeTitleDisplayMode = .never

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()
    }

    func fetchNext() {
        guard let currentPage = currentPage else {
            self.currentPage = PageInfo.firstPage(with: 10)
            fetch(pageInfo: self.currentPage!)
            return
        }
        fetch(pageInfo: currentPage.nextPage)
    }

    func fetch(pageInfo: PageInfo) {
        print("Fetching page \(pageInfo.page) for Followers")

        TraktAPIProvider.provider.request(.followers(slug: user.slug), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let users = try response.map([Follow].self, using: TraktAPIProvider.decoder).map { $0.user }.removingDuplicates()

                    // Paging support
                    if let response = response.response,
                        let pageInfo = PageInfo(headers: response.allHeaderFields) {
                        self.currentPage = pageInfo
                    }
                    self.error = nil

                    self.followers.append(contentsOf: users)

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(self.followers.map { Wrapper.follower($0) })
                    if self.currentPage!.page < self.currentPage!.pageCount {
                        snapshot.appendSections([.loading])
                    }
                    snapshot.appendSections([.footer])
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("/followers request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(self.followers.map { Wrapper.follower($0) })
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case let .failure(error):
                print("/followers request failure \(error)")
                self.error = error

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.content])
                snapshot.appendItems(self.followers.map { Wrapper.follower($0) })
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

extension FollowersViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != 0 { fatalError() }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.follower(user) = item else { return }

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

        if section == dataSource.snapshot().indexOfSection(Section.footer), dataSource.snapshot().numberOfItems != 0 {
            return footerView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            fetchNext()
        }
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

        if section == dataSource.snapshot().indexOfSection(Section.footer), dataSource.snapshot().numberOfItems != 0 {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
