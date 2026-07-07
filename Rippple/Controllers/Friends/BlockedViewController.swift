//
//  BlockedViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 07/03/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class BlockedViewController: UITableViewController {
    /// Empty
    @IBOutlet private var emptyView: UIView!

    private let disposeBag = DisposeBag()

    private enum Section: Int {
        case content
    }

    private enum Wrapper: Hashable {
        case blocked(User)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .blocked(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell

            cell.user = user

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser

        navigationItem.title = "Blocked Users"

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "UserInListTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        navigationItem.largeTitleDisplayMode = .never

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        dataSource.apply(snapshot, animatingDifferences: false)

        onUsersHiddenFromCommentsChangedReceiver.listen { [weak self] users in
            guard let self = self else { return }

            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.content])
            snapshot.appendItems(users.map { Wrapper.blocked($0) })
            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }.disposed(by: disposeBag)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            let type = sender as! CommentsCoordinator.ListType
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }
    }
}

extension BlockedViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.blocked(let user) = item else { return }

        let nextType = CommentsCoordinator.ListType.user(user)

        performSegue(withIdentifier: "user", sender: nextType)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return emptyView
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return 100
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}
