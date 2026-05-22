//
//  HiddenTableViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 06/12/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Receiver

class HiddenTableViewController: UITableViewController {
    // Private

    private enum ViewControllerSegue: String {
        case comments
        case details
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

    private enum Section: Int {
        case empty
        case content
    }

    private enum Wrapper: Hashable {
        case media(MediaModel)
        case empty
    }

    private class HiddenDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private lazy var dataSource = HiddenDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .media(let media):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = media

            cell.delegate = self

            return cell
        case .empty:
            return tableView.dequeueReusableCell(withIdentifier: "empty")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        onShowsHiddenFromProgressMediaChangedReceiver.listen { [weak self] hiddenMediaList in
            guard let self = self else { return }
            self.refresh(with: hiddenMediaList)
        }.disposed(by: disposeBag)
    }

    func refresh(with hiddenMediaList: [MediaModel]) {
        if hiddenMediaList.isEmpty {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.empty])
            snapshot.appendItems([Wrapper.empty])
            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        } else {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.content])
            snapshot.appendItems(hiddenMediaList.removingDuplicates().map { Wrapper.media($0) })
            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
           let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(media))
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if let navigationController = segue.destination as? UINavigationController, let smartSearchBuilderViewController = navigationController.viewControllers.first as? SmartSearchBuilderViewController, let smartSearch = sender as? SmartSearch {
            smartSearchBuilderViewController.smartSearch = smartSearch
        }
    }
}

extension HiddenTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.media(let mediaModel) = item else { return }
        switch mediaModel {
        case .episode, .show, .movie, .season:
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel)
        case .list, .showProgress:
            fatalError()
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if dataSource.itemIdentifier(for: indexPath) == Wrapper.empty {
            return (tableView.frame.size.height * 0.7) - 100
        } else {
            return UITableView.automaticDimension
        }
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
        guard case Wrapper.media(let media) = item else { return nil }

        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.media(let media) = item else { return nil }

        return media.leadingSwipeActions(for: self)
    }
}

extension HiddenTableViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.media(let mediaModel) = item else { return }

        if action == .details {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel.show?.mediaModel)
        }
    }
}
