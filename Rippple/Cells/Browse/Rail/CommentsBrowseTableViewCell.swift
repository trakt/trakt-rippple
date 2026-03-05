//
//  CommentsBrowseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 13/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

class CommentsBrowseTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    weak var presentingViewController: UIViewController?

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()

    private var items: [HistoryItem]? {
        didSet {
            collectionView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "HistoryBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "history cell")

        fetchHistory()

        onLastWatchedEpisodeActivitiesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetchHistory()
        }.disposed(by: disposeBag)

        onLastWatchedMovieActivitiesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetchHistory()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60 * 60 * 1 {
                    self.fetchHistory()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

    }

    private func fetchHistory() {
        TraktAPIProvider.provider.request(.history(slug: "me",
                                                   type: nil,
                                                   id: nil,
                                                   pageInfo: PageInfo.firstPage(with: 20),
                                                   endDate: nil), callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.items = fetchedActivities
                    }
                } catch {
                    print("Error Fetching History \(error)")
                }
            case let .failure(error):
                print("Error Fetching History \(error)")
            }
        }
    }
}

extension CommentsBrowseTableViewCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return (items?.count ?? 0) + 3
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row < 3 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history cell", for: indexPath) as! HistoryBrowseCollectionViewCell

            switch indexPath.row {
            case 0:
                cell.content = .emoji(label: "All", emoji: "💬")
            case 1:
                cell.content = .emoji(label: "Trending", emoji: "🔥")
            case 2:
                cell.content = .emoji(label: "For You", emoji: "🫵")
            default:
                cell.content = .emoji(label: "Error", emoji: "😵")
            }

            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "history cell", for: indexPath) as! HistoryBrowseCollectionViewCell

            cell.content = .media(media: MediaModel(item: items![indexPath.row - 3])!)

            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let presentingViewController = presentingViewController else {
            return
        }

        if indexPath.row < 3 {
            switch indexPath.row {
            case 0:
                presentingViewController.performSegue(withIdentifier: "Comments", sender: CommentsBrowseViewController.FeedType.all)
            case 1:
                presentingViewController.performSegue(withIdentifier: "Comments", sender: CommentsBrowseViewController.FeedType.trending)
            case 2:
                if UserManager.shared.currentUser == nil {
                    onNeedsToShowLoginTransmitter.broadcast(true)
                    return
                }
                presentingViewController.performSegue(withIdentifier: "Comments", sender: CommentsBrowseViewController.FeedType.forYou)
            default:
                presentingViewController.performSegue(withIdentifier: "Comments", sender: CommentsBrowseViewController.FeedType.all)
            }
        } else {
            presentingViewController.performSegue(withIdentifier: "Media Comments", sender: MediaModel(item: items![indexPath.row - 3]))
        }
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        if indexPath.row < 3 { return nil }

        if let cell = collectionView.cellForItem(at: indexPath) {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        return nil
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
        guard let presentingViewController = presentingViewController else { return }
        presentingViewController.navigationController?.show(controller, sender: self)
    }
}
