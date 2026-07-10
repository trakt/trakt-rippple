//
//  ToWatchStoriesTableViewCell.swift
//  ToWatchStoriesTableViewCell
//
//  Created by Kevin Cador on 20/07/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit

final class ToWatchStoriesTableViewCell: UITableViewCell {
    @IBOutlet var collectionView: UICollectionView!

    private enum Section: Hashable {
        case finales
        case inToWatch
        case others
    }

    private struct Item: Hashable {
        let media: MediaModel
    }

    private let disposeBag = DisposeBag()

    weak var presentingController: UIViewController?

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    private let contextMenu = ContextMenuHelper()

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.register(UINib(nibName: "ToWatchStoryCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "story")
        collectionView.allowsFocus = false

        collectionView.delegate = self

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "story", for: indexPath) as? ToWatchStoryCollectionViewCell else { return UICollectionViewCell() }
            cell.media = item.media
            return cell
        }
    }

    private var timer: Timer?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            timer?.invalidate()
        } else {
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1,
                                         repeats: true,
                                         block: { [weak self] _ in
                                             guard let self = self else { return }
                                             for cell in self.collectionView.visibleCells {
                                                 guard let cell = cell as? ToWatchStoryCollectionViewCell else { continue }
                                                 cell.updateLabel()
                                             }
                                         })
        }
    }

    var mediaModels = [MediaModel]() {
        didSet {
            let bingeableOnly = EpisodeToWatchSettings.shared.bingeableOnly
            let grouped = mediaModels.reduce(into: (finales: [MediaModel](), inToWatch: [MediaModel](), others: [MediaModel]())) { acc, item in
                switch item {
                case .show(let show):
                    if show.isInToWatch { acc.inToWatch.append(item) } else { acc.others.append(item) }
                case .episode(let episode, let show) where bingeableOnly && episode.isBingeableFinale && show.isInToWatch:
                    acc.finales.append(item)
                case .episode(_, let show):
                    if show.isInToWatch { acc.inToWatch.append(item) } else { acc.others.append(item) }
                case .season(_, let show):
                    if show.isInToWatch { acc.inToWatch.append(item) } else { acc.others.append(item) }
                case .showProgress(let show, _):
                    if show.isInToWatch { acc.inToWatch.append(item) } else { acc.others.append(item) }
                case .movie(let movie):
                    if movie.isInToWatch { acc.inToWatch.append(item) } else { acc.others.append(item) }
                case .list:
                    break
                }
            }

            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

            if !grouped.finales.isEmpty {
                snapshot.appendSections([.finales])
                snapshot.appendItems(grouped.finales.map { Item(media: $0) }, toSection: .finales)
            }
            if !grouped.inToWatch.isEmpty {
                snapshot.appendSections([.inToWatch])
                snapshot.appendItems(grouped.inToWatch.map { Item(media: $0) }, toSection: .inToWatch)
            }
            if !grouped.others.isEmpty {
                snapshot.appendSections([.others])
                snapshot.appendItems(grouped.others.map { Item(media: $0) }, toSection: .others)
            }

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let presentingController = presentingController else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        let selected = item.media

        switch selected {
        case .movie:
            presentingController.performSegue(withIdentifier: "details", sender: selected)
        case .show:
            presentingController.performSegue(withIdentifier: "details", sender: selected)
        case .episode:
            presentingController.performSegue(withIdentifier: "details", sender: selected)
        case .season:
            presentingController.performSegue(withIdentifier: "details", sender: selected)
        case .list:
            fatalError()
        case .showProgress(let show, let showProgress):
            guard let episode = showProgress.nextEpisodeToWatch else {
                presentingController.performSegue(withIdentifier: "seasons", sender: show)
                return
            }
            presentingController.performSegue(withIdentifier: "details", sender: MediaModel.episode(episode, show))
        }
    }
}

extension ToWatchStoriesTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as? ToWatchStoryCollectionViewCell
        contextMenu.cell = cell
        contextMenu.controller = presentingController

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            self.contextMenu.previewViewController
        }, actionProvider: { _ in
            self.contextMenu.menu
        })
    }

    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        presentingController?.navigationController?.show(controller, sender: self)
    }
}
