//
//  RelatedMediaTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 25/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import Kingfisher
import Moya
import Receiver
import UIKit

protocol RelatedMediaTableViewCellDelegate: AnyObject {
    func cell(_ cell: RelatedMediaTableViewCell, action: RelatedMediaTableViewCell.Action)
}

final class RelatedMediaTableViewCell: UITableViewCell {
    enum Action {
        case showMedia(MediaModel)
        case getMoreWithVIP
    }

    private enum State {
        case loading
        case content
        case empty
        case error
    }

    @IBOutlet private var collectionView: UICollectionView!
    @IBOutlet private var moreButton: UIButton!
    @IBOutlet private var statusView: UIView!
    @IBOutlet private var statusLabel: UILabel!
    @IBOutlet private var titleLabel: UILabel!

    weak var delegate: RelatedMediaTableViewCellDelegate?

    var media: MediaModel? {
        didSet {
            guard media != oldValue else { return }
            loadRelatedMedia()
        }
    }

    private let contextMenu = ContextMenuHelper()
    private let disposeBag = DisposeBag()

    private var request: Cancellable? {
        willSet {
            request?.cancel()
        }
    }

    private var requestIdentifier = UUID()
    private var relatedMedia = [MediaModel]()
    private var state = State.loading
    private var wasPurchased = PurchaseManager.shared.purchased

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.register(UINib(nibName: "MediaCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "media")
        collectionView.dragDelegate = self
        collectionView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        maximumContentSizeCategory = .large
        moreButton.maximumContentSizeCategory = .extraExtraLarge

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collectionView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)

        PurchaseManager.shared.onPurchasedChangedReceiver.skipRepeats().listen { [weak self] purchased in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let didUpgrade = self.wasPurchased == false && purchased
                self.wasPurchased = purchased
                self.updateMoreButton()
                if didUpgrade, self.media != nil {
                    self.loadRelatedMedia()
                }
            }
        }.disposed(by: disposeBag)

        updateState()
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        collectionView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: false)
    }

    deinit {
        request?.cancel()
    }

    @IBAction private func performMoreAction(_ sender: Any) {
        switch state {
        case .error:
            loadRelatedMedia()
        case .content, .empty:
            guard wasPurchased == false else { return }
            delegate?.cell(self, action: .getMoreWithVIP)
        case .loading:
            return
        }
    }

    private func loadRelatedMedia() {
        requestIdentifier = UUID()
        request = nil

        guard let media = media else {
            relatedMedia = []
            state = .empty
            updateState()
            return
        }

        let currentRequestIdentifier = requestIdentifier
        let requestedMedia = media

        relatedMedia = []
        state = .loading
        updateState()

        let service: TraktAPIService
        switch media {
        case .movie(let movie):
            service = .movieRelatedSmart(id: movie.identifiers.traktIdOrSlug,
                                         pageInfo: PageInfo.firstPage(with: 20))
        case .show(let show):
            service = .showRelatedSmart(id: show.identifiers.traktIdOrSlug,
                                        pageInfo: PageInfo.firstPage(with: 20))
        case .episode, .season, .list, .showProgress:
            assertionFailure("Related media is only supported for movies and shows.")
            state = .empty
            updateState()
            return
        }

        request = TraktAPIProvider.provider.request(service,
                                                    callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let relatedMedia: [MediaModel]
                    if response.statusCode == 204 {
                        relatedMedia = []
                    } else {
                        switch requestedMedia {
                        case .movie:
                            relatedMedia = try response.map([Movie].self, using: TraktAPIProvider.decoder).map(\.mediaModel)
                        case .show:
                            relatedMedia = try response.map([Show].self, using: TraktAPIProvider.decoder).map(\.mediaModel)
                        case .episode, .season, .list, .showProgress:
                            relatedMedia = []
                        }
                    }

                    DispatchQueue.main.async {
                        guard self.requestIdentifier == currentRequestIdentifier,
                              self.media == requestedMedia else { return }
                        self.relatedMedia = relatedMedia
                        self.state = relatedMedia.isEmpty ? .empty : .content
                        self.updateState()
                    }
                } catch {
                    DispatchQueue.main.async {
                        guard self.requestIdentifier == currentRequestIdentifier,
                              self.media == requestedMedia else { return }
                        self.state = .error
                        self.updateState()
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    guard self.requestIdentifier == currentRequestIdentifier,
                          self.media == requestedMedia else { return }
                    self.state = .error
                    self.updateState()
                }
            }
        }
    }

    private func updateState() {
        guard collectionView != nil else { return }

        switch state {
        case .loading:
            titleLabel.text = "Loading..."
            collectionView.reloadData()
            collectionView.isHidden = false
            collectionView.isUserInteractionEnabled = false
            statusView.isHidden = true
        case .content:
            titleLabel.text = "You may also like"
            collectionView.reloadData()
            collectionView.isHidden = false
            collectionView.isUserInteractionEnabled = true
            statusView.isHidden = true
        case .empty:
            titleLabel.text = "You may also like"
            collectionView.isHidden = true
            collectionView.isUserInteractionEnabled = false
            statusView.isHidden = false
            statusLabel.text = "No suggestions available."
        case .error:
            titleLabel.text = "Error!"
            collectionView.reloadData()
            collectionView.isHidden = false
            collectionView.isUserInteractionEnabled = false
            statusView.isHidden = true
        }

        updateMoreButton()
    }

    private func updateMoreButton() {
        guard moreButton != nil else { return }

        switch state {
        case .loading:
            moreButton.isHidden = true
        case .error:
            moreButton.setTitle("Retry", for: .normal)
            moreButton.isHidden = false
        case .content, .empty:
            moreButton.setTitle("Get More with VIP", for: .normal)
            moreButton.isHidden = wasPurchased
        }
    }

    private func mediaItem(for media: MediaModel) -> MediaItem? {
        switch media {
        case .movie(let movie):
            return MediaItem(movie: movie,
                             show: nil,
                             episode: nil,
                             season: nil,
                             list: nil,
                             watchers: nil,
                             listedAt: nil,
                             collectedAt: nil,
                             lastCollectedAt: nil,
                             hiddenAt: nil,
                             notes: nil)
        case .show(let show):
            return MediaItem(movie: nil,
                             show: show,
                             episode: nil,
                             season: nil,
                             list: nil,
                             watchers: nil,
                             listedAt: nil,
                             collectedAt: nil,
                             lastCollectedAt: nil,
                             hiddenAt: nil,
                             notes: nil)
        case .episode, .season, .list, .showProgress:
            return nil
        }
    }
}

extension RelatedMediaTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 108, height: 163)
    }
}

extension RelatedMediaTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch state {
        case .loading, .error:
            return 3
        case .content:
            return relatedMedia.count
        case .empty:
            return 0
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "media",
                                                      for: indexPath) as! MediaCollectionViewCell

        cell.posterImageView.kf.cancelDownloadTask()
        cell.posterImageView.image = nil
        cell.posterImageView.movie = nil
        cell.posterImageView.show = nil
        cell.posterImageView.backgroundColor = UIColor.tertiarySystemFill
        cell.cast = nil
        cell.crew = nil
        cell.mediaItem = nil
        cell.mediaTitleLabel.isHidden = true
        cell.additionalInfoLabel.isHidden = true

        switch state {
        case .loading, .error:
            cell.isAccessibilityElement = false
            cell.accessibilityLabel = nil
            cell.accessibilityTraits = []
            return cell
        case .empty:
            assertionFailure("Empty state should not display media cells.")
            return cell
        case .content:
            break
        }

        let media = relatedMedia[indexPath.item]
        cell.mediaItem = mediaItem(for: media)
        cell.isAccessibilityElement = true
        cell.accessibilityLabel = media.mediaTitle
        cell.accessibilityTraits = .button
        return cell
    }
}

extension RelatedMediaTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard relatedMedia.indices.contains(indexPath.item) else { return }
        delegate?.cell(self, action: .showMedia(relatedMedia[indexPath.item]))
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard relatedMedia.indices.contains(indexPath.item),
              let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell,
              let controller = delegate as? UIViewController else { return nil }

        contextMenu.cell = cell
        contextMenu.controller = controller

        return UIContextMenuConfiguration(identifier: nil,
                                          previewProvider: {
                                              self.contextMenu.previewViewController
                                          }, actionProvider: { _ in
                                              self.contextMenu.menu
                                          })
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView,
                        willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController,
              let presentingController = delegate as? UIViewController else { return }
        presentingController.show(controller, sender: self)
    }
}

extension RelatedMediaTableViewCell: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        itemsForBeginning session: UIDragSession,
                        at indexPath: IndexPath) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        itemsForAddingTo session: UIDragSession,
                        at indexPath: IndexPath,
                        point: CGPoint) -> [UIDragItem] {
        return dragItems(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? MediaCollectionViewCell,
              let poster = cell.posterImageView else { return nil }

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.bounds, to: cell),
                                              cornerRadius: poster.layer.cornerRadius)
        return parameters
    }

    private func dragItems(at indexPath: IndexPath) -> [UIDragItem] {
        guard relatedMedia.indices.contains(indexPath.item) else { return [] }
        let media = relatedMedia[indexPath.item]
        guard let url = media.traktWebsiteMediaLink else { return [] }

        let dragItem = UIDragItem(itemProvider: NSItemProvider(object: url as NSURL))
        dragItem.localObject = media
        return [dragItem]
    }
}
