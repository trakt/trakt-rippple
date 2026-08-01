//
//  PeopleMediaTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/09/2019.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol PeopleMediaTableViewCellDelegate: AnyObject {
    func cell(_ cell: PeopleMediaTableViewCell, action: PeopleMediaTableViewCell.Action)
}

final class PeopleMediaTableViewCell: UITableViewCell {
    enum Action {
//        case showAll
        case showCast(Cast)
        case showCrew(Job)
        case showMedia(MediaItem)
    }

    weak var delegate: PeopleMediaTableViewCellDelegate?

    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var title: UILabel!

    @IBOutlet var moreButton: UIButton!

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()

    var isRecentlyWatched = false

    var casts: [Cast]? {
        didSet {
            collectionView.reloadData()
        }
    }

    var crews: [Job]? {
        didSet {
            collectionView.reloadData()
        }
    }

    var knownFor: [MediaItem]? {
        didSet {
            collectionView.reloadData()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.dragDelegate = self

        collectionView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collectionView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        collectionView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
    }

//    @IBAction func showAll(_ sender: Any) {
//        guard let delegate = delegate else { return }
//        delegate.cell(self, action: .showAll)
//    }
}

extension PeopleMediaTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if knownFor == nil {
            return CGSize(width: 95, height: 133 + 30)
        } else {
            return CGSize(width: 108, height: 133 + 30)
        }
    }
}

extension PeopleMediaTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell
        contextMenu.cell = cell
        contextMenu.controller = (delegate as! UIViewController)

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
        (delegate as! UIViewController).navigationController?.show(controller, sender: self)
    }
}

extension PeopleMediaTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView.register(UINib(nibName: "MediaCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "media")

        if let casts = casts {
            return casts.count
        } else if let crews = crews {
            return crews.count
        } else if let knownFor = knownFor {
            return knownFor.count
        }

        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "media", for: indexPath) as! MediaCollectionViewCell
        if let casts = casts {
            cell.isRecentlyWatched = isRecentlyWatched
            cell.cast = casts[indexPath.row]
        } else if let crews = crews {
            cell.crew = crews[indexPath.row]
        } else if let knownFor = knownFor {
            cell.mediaItem = knownFor[indexPath.row]
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }

        if let casts = casts {
            delegate.cell(self, action: .showCast(casts[indexPath.row]))
        } else if let crews = crews {
            delegate.cell(self, action: .showCrew(crews[indexPath.row]))
        } else if let knownFor = knownFor {
            delegate.cell(self, action: .showMedia(knownFor[indexPath.row]))
        }
    }
}

extension PeopleMediaTableViewCell: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell else { return [] }
        var media: MediaModel?

        if let cast = cell.cast {
            if let show = cast.show {
                media = show.mediaModel
            }
            if let movie = cast.movie {
                media = movie.mediaModel
            }
        }
        if let crew = cell.crew {
            if let show = crew.show {
                media = show.mediaModel
            }
            if let movie = crew.movie {
                media = movie.mediaModel
            }
        }
        if let knownFor = cell.mediaItem {
            if let show = knownFor.show {
                media = show.mediaModel
            }
            if let movie = knownFor.movie {
                media = movie.mediaModel
            }
        }
        guard let media = media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell else { return [] }
        var media: MediaModel?

        if let cast = cell.cast {
            if let show = cast.show {
                media = show.mediaModel
            }
            if let movie = cast.movie {
                media = movie.mediaModel
            }
        }
        if let crew = cell.crew {
            if let show = crew.show {
                media = show.mediaModel
            }
            if let movie = crew.movie {
                media = movie.mediaModel
            }
        }
        if let knownFor = cell.mediaItem {
            if let show = knownFor.show {
                media = show.mediaModel
            }
            if let movie = knownFor.movie {
                media = movie.mediaModel
            }
        }
        guard let media = media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell else { return nil }
        let poster = cell.posterImageView!

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.frame, to: cell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}
