//
//  PinnedShowsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 13/11/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Receiver

class PinnedShowsViewController: UITableViewController {

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
        case empty(String, String, String, String)
    }

    private class PinnedDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> { }

    private lazy var dataSource = PinnedDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .media(let media):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = media

            cell.delegate = self

            return cell
        case .empty(let emoji, let title, let subtitle, let body):
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = emoji
            cell.title.text = title
            cell.subtitle.text = subtitle
            cell.body.text = body
            cell.action.isHidden = true
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none

        onPinnedShowsToWatchChangedReceiver.listen { [weak self] pinnedShows in
            guard let self = self else { return }
            self.refresh(with: pinnedShows.map { $0.mediaModel })
        }.disposed(by: disposeBag)
    }

    func refresh(with hiddenMediaList: [MediaModel]) {
        if hiddenMediaList.isEmpty {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty("📌",
                                         "No Pinned Show",
                                         "There are currently no pinned show",
                                         "Pin a show and you will be able to find them here later.")])
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

extension PinnedShowsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.media(mediaModel) = item else { return }
        performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
        contextMenu.cell = cell
        contextMenu.controller = self

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            return self.contextMenu.previewViewController
        }, actionProvider: { _ in
            return self.contextMenu.menu
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
        guard case let Wrapper.media(media) = item else { return nil }

        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case let Wrapper.media(media) = item else { return nil }

        return media.leadingSwipeActions(for: self)
    }
}

extension PinnedShowsViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case let Wrapper.media(mediaModel) = item else { return }

        if action == .details {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: mediaModel)
        }
    }
}
