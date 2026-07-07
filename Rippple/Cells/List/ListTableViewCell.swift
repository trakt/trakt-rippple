//
//  ListTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Kingfisher
import Moya
import Receiver
import UIKit

protocol ListTableViewCellDelegate: AnyObject {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action)
}

final class ListTableViewCell: UITableViewCell {
    enum Action {
        case touch
        case user
    }

    weak var delegate: ListTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: LinkEnabledLabel?
    @IBOutlet var accessoryIndicator: UIImageView?

    @IBOutlet var likesCountLabel: UILabel?
    @IBOutlet var itemsCountLabel: UILabel?

    @IBOutlet var avatarButton: UIButton?

    @IBOutlet var privacyBackgroundView: UIView?
    @IBOutlet var privacyLabel: UILabel?
    @IBOutlet var privacyImageView: UIImageView!

    @IBOutlet var collaboratorBackgroundView: UIView?
    @IBOutlet var collaboratorLabel: UILabel?
    @IBOutlet var collaboratorImageView: UIImageView!

    @IBOutlet var collectionSpaceView: UIView?
    @IBOutlet var collectionContainerView: UIView?
    @IBOutlet var collectionView: UICollectionView?

    @IBOutlet var likeButton: UIButton?

    private var items: [WatchlistItem]? {
        didSet {
            collectionView?.reloadData()
        }
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView?.allowsFocus = false
        collectionView?.dragDelegate = self

        collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)

        onListLikedReceiver.listen { [weak self] identifiers in
            guard let self = self else { return }
            guard let list = self.list else { return }
            if list.identifiers == identifiers {
                self.refreshLike()
            }
        }.disposed(by: disposeBag)

        onCollaborationsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.refreshCollaboration()
        }.disposed(by: disposeBag)

        privacyBackgroundView?.layer.cornerRadius = 4.0
        privacyBackgroundView?.layer.cornerCurve = .continuous
        privacyBackgroundView?.layer.masksToBounds = true

        collaboratorBackgroundView?.layer.cornerRadius = 4.0
        collaboratorBackgroundView?.layer.cornerCurve = .continuous
        collaboratorBackgroundView?.layer.masksToBounds = true

        if let avatarButton = avatarButton {
            avatarButton.layer.cornerRadius = avatarButton.bounds.height / 2.0
            avatarButton.layer.borderWidth = 1
            avatarButton.layer.borderColor = UIColor.tertiarySystemFill.cgColor
            avatarButton.clipsToBounds = true
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            titleLabel.textColor = UIColor(asset: .globalTint)
        } else {
            titleLabel.textColor = .label
        }
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        if highlighted {
            titleLabel.textColor = UIColor(asset: .globalTint)
        } else {
            titleLabel.textColor = .label
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        cancelCancellable()
        items = nil
        collectionView?.reloadData()
    }

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    /// Filter
    private static let userFilter = RoundCornerImageProcessor(
        cornerRadius: 20.0,
        targetSize: CGSize(width: 40.0, height: 40.0)
    )

    var isWatchlist = false {
        didSet {
            if isWatchlist {
                titleLabel.text = "Watchlist"
            }
        }
    }

    var isEditingMode = false {
        didSet {
            accessoryIndicator?.isHidden = isEditingMode
            collectionView?.isHidden = isEditingMode
            collectionContainerView?.isHidden = isEditingMode
            collectionSpaceView?.isHidden = isEditingMode
            descriptionLabel?.isHidden = isEditingMode
            avatarButton?.isHidden = isEditingMode
        }
    }

    var user: User?

    var list: List? {
        didSet {
            guard let list = list else { return }
            titleLabel.text = list.name.emojiUnescapedString

            descriptionLabel?.attributedText = attributedString()

            if let type = list.type, type == "official" {
                privacyImageView?.image = UIImage(systemName: "checkmark.seal")
                privacyLabel?.text = "Official"
            } else {
                switch list.privacy {
                case .all:
                    privacyImageView?.image = UIImage(systemName: "globe")
                    privacyLabel?.text = "Public"
                case .me:
                    privacyImageView?.image = UIImage(systemName: "lock.fill")
                    privacyLabel?.text = "Private"
                case .friends:
                    privacyImageView?.image = UIImage(systemName: "lock.open.fill")
                    privacyLabel?.text = "Friends only"
                case .link:
                    privacyImageView?.image = UIImage(systemName: "link")
                    privacyLabel?.text = "Link"
                case .unknown:
                    privacyImageView?.image = UIImage()
                    privacyLabel?.text = "Unknown"
                }
            }

            let user = user ?? list.user
            if let avatarButton = avatarButton {
                if let images = user.images {
                    avatarButton.kf.setBackgroundImage(with: images.avatar.full,
                                                       for: .normal,
                                                       placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                                       options: [.scaleFactor(traitCollection.displayScale), .processor(ListTableViewCell.userFilter)])
                } else if user.isCurrentUser {
                    avatarButton.kf.setBackgroundImage(with: UserManager.shared.currentUser!.images!.avatar.full,
                                                       for: .normal,
                                                       placeholder: #imageLiteral(resourceName: "bg_placeholder_avatar_tiny"),
                                                       options: [.scaleFactor(traitCollection.displayScale), .processor(ListTableViewCell.userFilter)])
                } else {
                    avatarButton.setBackgroundImage(#imageLiteral(resourceName: "bg_placeholder_avatar_tiny"), for: .normal)
                }
            }

            if list.privacy.self == .me {
                likesCountLabel?.text = "\(list.itemCount ?? 0) \((list.itemCount ?? 0) <= 1 ? "item" : "items")"
                itemsCountLabel?.isHidden = true
            } else {
                itemsCountLabel?.isHidden = false
                likesCountLabel?.text = "\(list.likes) \(list.likes <= 1 ? "like" : "likes")"
                itemsCountLabel?.text = "\(list.itemCount ?? 0) \((list.itemCount ?? 0) <= 1 ? "item" : "items")"
            }

            if collectionView != nil {
                fetchItems(for: list)
            }

            refreshLike()
            refreshCollaboration()
        }
    }

    private var markdownParser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                                       automaticLinkDetectionEnabled: true)

    private func attributedString() -> NSAttributedString? {
        guard let listDescription = list?.description else { return nil }

        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label
        markdownParser.highlight.font = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge)))
        markdownParser.link.color = UIColor(asset: .globalTint)
        markdownParser.automaticLink.color = UIColor(asset: .globalTint)

        markdownParser.spoilerStrategy = .showAllSpoilers

        return markdownParser.parse(listDescription.htmlDecoded.emojiUnescapedString)
    }

    private func refreshLike() {
        guard let list = list else { return }
        if list.user.isCurrentUser {
            likeButton?.isHidden = true
        } else {
            likeButton?.isHidden = false
            if list.liked {
                likeButton?.setTitle("You like this list!", for: .normal)
            } else {
                likeButton?.setTitle("Like?", for: .normal)
            }
        }
    }

    private func refreshCollaboration() {
        guard let list = list else { return }
        if CollaborationsManager.shared.collaborations.contains(list) {
            collaboratorBackgroundView?.isHidden = false
            collaboratorLabel?.isHidden = false
            collaboratorImageView?.isHidden = false
        } else {
            collaboratorBackgroundView?.isHidden = true
            collaboratorLabel?.isHidden = true
            collaboratorImageView?.isHidden = true
        }
    }

    @IBAction func like(_ sender: Any) {
        guard let list = list else { return }
        list.like()
    }

    @IBAction func user(_ sender: Any) {
        guard let delegate = delegate else { return }

        delegate.cell(self, action: .user)
    }

    func fetchItems(for list: List) {
        cancellable = TraktAPIProvider.provider.request(.listItems(slug: list.user.identifiers.slug,
                                                                   id: list.identifiers.trakt!,
                                                                   type: nil,
                                                                   extended: .full,
                                                                   pageInfo: PageInfo(page: 1, limit: 20, pageCount: 20, itemCount: 20),
                                                                   marker: ListItemsMarkerManager.shared.marker(for: list.identifiers.trakt!)),
                                                        callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map([WatchlistItem].self, using: TraktAPIProvider.decoder).sorted { $0.listedAt > $1.listedAt }

                    DispatchQueue.main.async {
                        if self.list == list {
                            self.items = results
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("List items request JSON mapping failed! \(error)")
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("List items request failure \(error)")
                }
            }
        }
    }
}

extension ListTableViewCell: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 72, height: 110)
    }
}

extension ListTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView.register(UINib(nibName: "ListMediaCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "media")

        if let items = items {
            return items.count
        } else {
            return min(20, list?.itemCount ?? 0)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "media", for: indexPath) as! ListMediaCollectionViewCell

        if let items = items {
            cell.item = items[indexPath.row]
        } else {
            cell.item = nil
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let delegate = delegate else { return }

        delegate.cell(self, action: .touch)
    }
}

extension ListTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as? ListMediaCollectionViewCell
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

extension ListTableViewCell: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ListMediaCollectionViewCell else { return [] }
        guard let item = cell.item else { return [] }

        var media: MediaModel?

        if let movie = item.movie {
            media = movie.mediaModel
        } else if let show = item.show {
            media = show.mediaModel
        }

        guard let media = media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ListMediaCollectionViewCell else { return [] }
        guard let item = cell.item else { return [] }

        var media: MediaModel?

        if let movie = item.movie {
            media = movie.mediaModel
        } else if let show = item.show {
            media = show.mediaModel
        }

        guard let media = media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ListMediaCollectionViewCell else { return nil }
        let poster = cell.posterImageView!

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.frame, to: cell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}
