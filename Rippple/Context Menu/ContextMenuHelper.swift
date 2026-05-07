//
//  ContextMenuHelper.swift
//  Rippple
//
//  Created by Kevin Cador on 02/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import SafariServices

class ContextMenuHelper: NSObject {

    var media: MediaModel! {
        didSet {
            switch media {
            case .list:
                fatalError()
            case .showProgress(let show, let showProgress):
                if let episode = showProgress.nextEpisodeToWatch {
                    media = episode.mediaModel(given: show)
                } else {
                    media = show.mediaModel
                }
            default:
                break
            }
        }
    }

    weak var cell: UIView? {
        didSet {
            if let mediaCell = cell as? MediaTableViewCell {
                if mediaCell.media.movie != nil {
                    self.media = mediaCell.media
                } else {
                    self.media = mediaCell.media.show?.mediaModel
                }
            }

            if let commentCell = cell as? CommentTableViewCell {
                if commentCell.commentModel.media.movie != nil {
                    self.media = commentCell.commentModel.media
                } else {
                    self.media = commentCell.commentModel.media.show?.mediaModel
                }
            }

            if let mediaCollectionViewCell = cell as? MediaCollectionViewCell {
                if let cast = mediaCollectionViewCell.cast {
                    if let movie = cast.movie {
                        self.media = movie.mediaModel
                    }
                    if let show = cast.show {
                        self.media = show.mediaModel
                    }
                }

                if let crew = mediaCollectionViewCell.crew {
                    if let movie = crew.movie {
                        self.media = movie.mediaModel
                    }
                    if let show = crew.show {
                        self.media = show.mediaModel
                    }
                }

                if let mediaItem = mediaCollectionViewCell.mediaItem {
                    if let movie = mediaItem.movie {
                        self.media = movie.mediaModel
                    }
                    if let show = mediaItem.show {
                        self.media = show.mediaModel
                    }
                }
            }

            if let listMediaCollectionViewCell = cell as? ListMediaCollectionViewCell {
                if let movie = listMediaCollectionViewCell.item?.movie {
                    self.media = movie.mediaModel
                } else if let show = listMediaCollectionViewCell.item?.show {
                    self.media = show.mediaModel
                }
            }

            if let toWatchStoryCollectionViewCell = cell as? ToWatchStoryCollectionViewCell {
                self.media = toWatchStoryCollectionViewCell.media
            }

            if let collectionViewCell = cell as? L1BrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? C1BrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? G1BrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? ListBrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? TopBrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? ToWatchBrowseCollectionViewCell {
                if case let .showProgress(show, showProgress) = collectionViewCell.media {
                    if let episode = showProgress.nextEpisodeToWatch {
                        self.media = episode.mediaModel(given: show)
                    } else {
                        self.media = show.mediaModel
                    }
                }
            }

            if let collectionViewCell = cell as? StandardHistoryBrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let collectionViewCell = cell as? HistoryBrowseCollectionViewCell {
                self.media = collectionViewCell.media
            }

            if let cell = cell as? LastWatchedTableViewCell {
                if case let .episode(_, show) = cell.media {
                    self.media = show.mediaModel
                } else {
                    self.media = cell.media
                }
            }
        }
    }
    weak var controller: UIViewController?

    var previewView: UIView? {
        if let mediaCell = cell as? MediaTableViewCell {
            return mediaCell.poster
        }

        if let commentCell = cell as? CommentTableViewCell {
            return commentCell.poster
        }

        if let mediaCollectionViewCell = cell as? MediaCollectionViewCell {
            return mediaCollectionViewCell.posterImageView
        }

        if let listMediaCollectionViewCell = cell as? ListMediaCollectionViewCell {
            return listMediaCollectionViewCell.posterImageView
        }

        if let toWatchStoryCollectionViewCell = cell as? ToWatchStoryCollectionViewCell {
            return toWatchStoryCollectionViewCell.poster
        }

        if let collectionViewCell = cell as? L1BrowseCollectionViewCell {
            return collectionViewCell.poster
        }

        if let collectionViewCell = cell as? C1BrowseCollectionViewCell {
            return collectionViewCell.backdrop
        }

        if let collectionViewCell = cell as? TopBrowseCollectionViewCell {
            return collectionViewCell.backdrop
        }

        if let collectionViewCell = cell as? ToWatchBrowseCollectionViewCell {
            return collectionViewCell.backdrop
        }

        if let collectionViewCell = cell as? StandardHistoryBrowseCollectionViewCell {
            return collectionViewCell.backdrop
        }

        if let collectionViewCell = cell as? HistoryBrowseCollectionViewCell {
            return collectionViewCell.poster
        }

        if let collectionViewCell = cell as? G1BrowseCollectionViewCell {
            return collectionViewCell.contentView
        }

        if let collectionViewCell = cell as? ListBrowseCollectionViewCell {
            return collectionViewCell.poster
        }

        if let cell = cell as? LastWatchedTableViewCell {
            return cell.poster
        }

        if let cell = cell as? SentimentsTableViewCell {
            return cell.cardView
        }

        return nil
    }

    var commitViewController: UIViewController? {
        guard let media = media else { return nil }
        switch media {
        case .movie, .show, .season, .episode:
            guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                return nil
            }

            mediaViewController.media = media

            return mediaViewController
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var previewViewController: UIViewController? {
        if let mediaPreviewViewController = UIStoryboard(name: "MediaPreview", bundle: nil).instantiateInitialViewController() as? MediaPreviewViewController {

            mediaPreviewViewController.media = media

            mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                     height: 500 * 1.5)
            return mediaPreviewViewController
        }

        return nil
    }

    var menu: UIMenu {

        guard let media = media else { return UIMenu(title: "Somthing wrong happened. Try again.", children: []) }
        let openInSubmenu = makeOpenInSubmenu(for: media)

        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            self.share()
        }

        switch media {
        case let .movie(movie):

            var watchActions = [UIAction]()
            var listsActions = [UIMenuElement]()
            var shareActions = [UIAction]()
            var toWatchActions = [UIAction]()

            if movie.isCurrentlyWatching {
                let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.cancelCheckin()
                }
                watchActions.append(cancel)
            } else {
                let checkin = UIAction(title: "Check in", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.checkin()
                }
                watchActions.append(checkin)
            }

            let markWatchedNow = UIAction(title: "Mark Watched Now", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.markWatched()
            }
            watchActions.append(markWatchedNow)

            let markWatched = UIAction(title: "Mark Watched On...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            if movie.isRecommended {
                let removeRecommendation = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "star.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromRecommendations()
                }
                shareActions.append(removeRecommendation)
            } else {
                let recommendThis = UIAction(title: "Add to Favorites", image: UIImage(systemName: "star.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToRecommendations()
                }
                shareActions.append(recommendThis)
            }

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }
            shareActions.append(write)

            let privateNotes = UIAction(title: media.noteItem == nil ? "Add Private Notes" : "Update Private Notes", image: UIImage(systemName: "note.text")) { [weak self] _ in
                guard let self = self else { return }
                NotesManager.shared.showNotes(for: self.media)
            }
            shareActions.append(privateNotes)

            var pin: UIAction
            if movie.isPinned {
                pin = UIAction(title: "Unpin", image: UIImage(systemName: "pin.slash"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.movie!.unpin()
                }
            } else {
                pin = UIAction(title: "Pin on To Watch", image: UIImage(systemName: "pin.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.movie!.pin()
                }
            }
            if movie.isWatched == false, UserManager.shared.currentUser != nil {
                toWatchActions.append(pin)
            }

            if movie.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if movie.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(movie: movie), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(movie: movie), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)
            let listsSubmenu = UIMenu(title: "", options: .displayInline, children: listsActions)
            let shareSubmenu = UIMenu(title: "", options: .displayInline, children: shareActions)
            let sharingSubmenu = UIMenu(title: "", options: .displayInline, children: [share, openInSubmenu])
            let toWatchSubmenu = UIMenu(title: "", options: .displayInline, children: toWatchActions)

            return UIMenu(title: "\(movie.title)", children: [watchSubmenu, toWatchSubmenu, listsSubmenu, media.rateMenu, shareSubmenu, sharingSubmenu])
        case let .show(show):
            var watchActions = [UIAction]()
            var listsActions = [UIMenuElement]()
            var shareActions = [UIAction]()
            var toWatchActions = [UIAction]()

            if show.isCurrentlyWatching {
                if let episode = WatchingManager.shared.watchingItem?.episode {
                    let cancel = UIAction(title: "Cancel \(episode.localizedEpisodeNumber) Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        self.media.cancelCheckin()
                    }
                    watchActions.append(cancel)
                } else {
                    let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        self.media.cancelCheckin()
                    }
                    watchActions.append(cancel)
                }
            }

            if show.isCompleted == false {
                let markWatched = UIAction(title: "Mark Show Watched...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.markWatched()
                }
                watchActions.append(markWatched)
            }

            let next = UIAction(title: "Next Episode to Watch", image: UIImage(systemName: "chevron.right.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.presentNextEpisode(media: self.media)
            }
            if show.isCompleted == false {
                watchActions.append(next)
            }

            if show.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if show.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(show: show), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(show: show), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            if show.isRecommended {
                let removeRecommendation = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "star.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromRecommendations()
                }
                shareActions.append(removeRecommendation)
            } else {
                let recommendThis = UIAction(title: "Add to Favorites", image: UIImage(systemName: "star.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToRecommendations()
                }
                shareActions.append(recommendThis)
            }

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }
            shareActions.append(write)

            let privateNotes = UIAction(title: media.noteItem == nil ? "Add Private Notes" : "Update Private Notes", image: UIImage(systemName: "note.text")) { [weak self] _ in
                guard let self = self else { return }
                NotesManager.shared.showNotes(for: self.media)
            }
            shareActions.append(privateNotes)

            var pin: UIAction
            if show.isPinned {
                pin = UIAction(title: "Unpin", image: UIImage(systemName: "pin.slash"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.unpin()
                }
            } else {
                pin = UIAction(title: "Pin on To Watch", image: UIImage(systemName: "pin.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.pin()
                }
            }
            if show.isCompleted == false, show.isHiddenFromProgress == false, UserManager.shared.currentUser != nil {
                toWatchActions.append(pin)
            }

            var hide: UIAction
            if show.isHiddenFromProgress {
                hide = UIAction(title: "Unhide from Progress", image: UIImage(systemName: "eye.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.unhideShow()
                }
            } else {
                hide = UIAction(title: "Hide from Progress", image: UIImage(systemName: "eye.slash.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.hide(from: .progressWatched)
                }
            }
            if show.isWatchedAtLeastOnce == true {
                toWatchActions.append(hide)
            }

            if show.isDropped == false, show.isWatchedAtLeastOnce == true {
                let drop = UIAction(title: "Drop", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { _ in
                    show.drop()
                }
                toWatchActions.append(drop)
            }

            var rewatch: UIAction
            if !show.isRewatching {
                rewatch = UIAction(title: "Start Rewatching", image: UIImage(systemName: "backward.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.startRewatchingShow()
                }
            } else {
                rewatch = UIAction(title: "Stop Rewatching", image: UIImage(systemName: "backward.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.stopRewatchingShow()
                }
            }

            if let user = UserManager.shared.currentUser, (user.isVip ?? false || user.isVipOg ?? false || user.isVipEp ?? false) && show.isHiddenFromProgress == false && show.isWatchedAtLeastOnce == true {
                toWatchActions.append(rewatch)
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)
            let listsSubmenu = UIMenu(title: "", options: .displayInline, children: listsActions)
            let shareSubmenu = UIMenu(title: "", options: .displayInline, children: shareActions)
            let sharingSubmenu = UIMenu(title: "", options: .displayInline, children: [share, openInSubmenu])
            let toWatchSubmenu = UIMenu(title: "", options: .displayInline, children: toWatchActions)

            return UIMenu(title: "\(show.title)", children: [watchSubmenu, toWatchSubmenu, listsSubmenu, media.rateMenu, shareSubmenu, sharingSubmenu])
        case let .episode(episode, show):
            var watchActions = [UIAction]()
            var listsActions = [UIMenuElement]()
            var shareActions = [UIAction]()

            if show.isCurrentlyWatching,
                let checkedInEpisode = WatchingManager.shared.watchingItem?.episode,
                episode == checkedInEpisode {
                let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.cancelCheckin()
                }
                watchActions.append(cancel)
            } else {
                let checkin = UIAction(title: "Check in \(episode.localizedEpisodeNumber)", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.checkin()
                }
                watchActions.append(checkin)
            }

            let markWatchedNow = UIAction(title: "Mark Watched Now", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.markWatched()
            }
            watchActions.append(markWatchedNow)

            let markWatched = UIAction(title: "Mark Watched On...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }
            shareActions.append(write)

            let privateNotes = UIAction(title: media.noteItem == nil ? "Add Private Notes" : "Update Private Notes", image: UIImage(systemName: "note.text")) { [weak self] _ in
                guard let self = self else { return }
                NotesManager.shared.showNotes(for: self.media)
            }
            shareActions.append(privateNotes)

            if episode.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if episode.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(episode: episode), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(episode: episode), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)
            let listsSubmenu = UIMenu(title: "", options: .displayInline, children: listsActions)
            let shareSubmenu = UIMenu(title: "", options: .displayInline, children: shareActions)
            let sharingSubmenu = UIMenu(title: "", options: .displayInline, children: [share, openInSubmenu])

            return UIMenu(title: "\(show.title) \(episode.localizedEpisodeNumber)", children: [watchSubmenu, listsSubmenu, media.rateMenu, shareSubmenu, sharingSubmenu])
        case .season(let season, let show):
            var watchActions = [UIAction]()
            var listsActions = [UIMenuElement]()
            var shareActions = [UIAction]()
            var toWatchActions = [UIAction]()

            let markWatched = UIAction(title: "Mark Season Watched...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }
            shareActions.append(write)

            let privateNotes = UIAction(title: media.noteItem == nil ? "Add Private Notes" : "Update Private Notes", image: UIImage(systemName: "note.text")) { [weak self] _ in
                guard let self = self else { return }
                NotesManager.shared.showNotes(for: self.media)
            }
            shareActions.append(privateNotes)

            if season.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(season: season), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(season: season), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            var hide: UIAction
            if season.isHiddenFromProgress {
                hide = UIAction(title: "Unhide Season from Progress", image: UIImage(systemName: "eye.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.unhideSeason()
                }
            } else {
                hide = UIAction(title: "Hide Season from Progress", image: UIImage(systemName: "eye.slash.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.hide(from: .progressWatched)
                }
            }
            if show.isWatchedAtLeastOnce == true {
                toWatchActions.append(hide)
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)
            let toWatchSubmenu = UIMenu(title: "", options: .displayInline, children: toWatchActions)
            let listsSubmenu = UIMenu(title: "", options: .displayInline, children: listsActions)
            let shareSubmenu = UIMenu(title: "", options: .displayInline, children: shareActions)
            let sharingSubmenu = UIMenu(title: "", options: .displayInline, children: [share, openInSubmenu])

            return UIMenu(title: "\(show.title) Season \(season.number)", children: [watchSubmenu, toWatchSubmenu, listsSubmenu, media.rateMenu, shareSubmenu, sharingSubmenu])
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var toWatchMenu: UIMenu {
        guard let media = media else { return UIMenu(title: "Somthing wrong happened. Try again.", children: []) }

        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            self.share()
        }

        switch media {
        case let .episode(episode, show):
            var watchActions = [UIAction]()
            var toWatchActions = [UIAction]()
            var shortcutsActions = [UIAction]()

            let checkin = UIAction(title: "Check in \(episode.localizedEpisodeNumber)", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.checkin()
            }
            watchActions.append(checkin)

            let markWatchedNow = UIAction(title: "Mark Watched Now", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.markWatched()
            }
            watchActions.append(markWatchedNow)

            let markWatched = UIAction(title: "Mark Watched On...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            var pin: UIAction
            if show.isPinned {
                pin = UIAction(title: "Unpin", image: UIImage(systemName: "pin.slash"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.unpin()
                }
            } else {
                pin = UIAction(title: "Pin on To Watch", image: UIImage(systemName: "pin.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.pin()
                }
            }
            toWatchActions.append(pin)

            let hide = UIAction(title: "Hide from Progress", image: UIImage(systemName: "eye.slash.circle"), attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.media.hide(from: .progressWatched)
            }
            toWatchActions.append(hide)

            let drop = UIAction(title: "Drop", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { _ in
                show.drop()
            }
            toWatchActions.append(drop)

            var rewatch: UIAction
            if !show.isRewatching {
                rewatch = UIAction(title: "Start Rewatching", image: UIImage(systemName: "backward.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.startRewatchingShow()
                }
            } else {
                rewatch = UIAction(title: "Stop Rewatching", image: UIImage(systemName: "backward.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.stopRewatchingShow()
                }
            }
            if let user = UserManager.shared.currentUser, (user.isVip ?? false || user.isVipOg ?? false || user.isVipEp ?? false) && show.isHiddenFromProgress == false {
                toWatchActions.append(rewatch)
            }

            let openShow = UIAction(title: "Open Show", image: UIImage(systemName: "rectangle.portrait")) { [weak self] _ in
                guard let self = self else { return }
                self.controller?.performSegue(withIdentifier: "details",
                                              sender: show.mediaModel)
            }
            shortcutsActions.append(openShow)

            let openEpisode = UIAction(title: "Open Episode", image: UIImage(systemName: "rectangle.on.rectangle.angled")) { [weak self] _ in
                guard let self = self else { return }
                self.controller?.performSegue(withIdentifier: "details",
                                              sender: episode.mediaModel(given: show))
            }
            shortcutsActions.append(openEpisode)

            let openEpisodesList = UIAction(title: "Open Episodes List", image: UIImage(systemName: "list.bullet")) { [weak self] _ in
                guard let self = self else { return }
                self.controller?.performSegue(withIdentifier: "seasons",
                                              sender: show)
            }
            shortcutsActions.append(openEpisodesList)

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)
            let toWatchSubmenu = UIMenu(title: "", options: .displayInline, children: toWatchActions)
            let shortcutSubmenu = UIMenu(title: "", options: .displayInline, children: shortcutsActions)
            let sharingSubmenu = UIMenu(title: "", options: .displayInline, children: [share])

            return UIMenu(title: "\(show.title) \(episode.localizedEpisodeNumber)",
                          children: [watchSubmenu, toWatchSubmenu, shortcutSubmenu, sharingSubmenu])
        case .season:
            fatalError()
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        case .movie:
            fatalError()
        case .show:
            fatalError()
        }
    }

    var quickStackMenu: UIMenu {

        guard let media = media else { return UIMenu(title: "Somthing wrong happened. Try again.", children: []) }

        switch media {
        case let .movie(movie):

            var listsActions = [UIMenuElement]()

            if movie.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if movie.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(movie: movie), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(movie: movie), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            return UIMenu(title: "\(movie.title)", children: listsActions)
        case let .show(show):
            var listsActions = [UIMenuElement]()

            if show.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if show.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(show: show), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(show: show), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            return UIMenu(title: "\(show.title)", children: listsActions)
        case let .episode(episode, show):
            var listsActions = [UIMenuElement]()

            if episode.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if episode.isInCollection {
                let removeFromCollection = UIAction(title: "Remove from Library", image: UIImage(systemName: "book.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromCollection()
                }
                listsActions.append(removeFromCollection)
            } else {
                let addToCollection = UIAction(title: "Add to Library", image: UIImage(systemName: "book.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToCollection()
                }
                listsActions.append(addToCollection)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(episode: episode), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(episode: episode), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            return UIMenu(title: "\(show.title) \(episode.localizedEpisodeNumber)", children: listsActions)
        case .season(let season, let show):
            var listsActions = [UIMenuElement]()

            if season.isWatchlisted {
                let removeWatchlist = UIAction(title: "Remove from Watchlist", image: UIImage(systemName: "bookmark.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromWatchlist()
                }
                listsActions.append(removeWatchlist)
            } else {
                let addWatchlist = UIAction(title: "Add to Watchlist", image: UIImage(systemName: "bookmark.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToWatchlist()
                }
                listsActions.append(addWatchlist)
            }

            if ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false || CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }).isEmpty == false {
                let addToList = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        var addToList = [UIAction]()
                        let listed = await media.fetchListed()
                        for list in ListsManager.shared.lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized)",
                                                     attributes: listed?.contains(list) == true ? .disabled : [],
                                                     state: listed?.contains(list) == true ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(season: season), in: list)
                            }
                            addToList.append(add)
                        }
                        for list in CollaborationsManager.shared.collaborations.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                            let add = await UIAction(title: "\(list.name.emojiUnescapedString)",
                                                     subtitle: "\(list.privacy.rawValue.localizedCapitalized) · Collaborator") { [weak self] _ in
                                guard let self = self else { return }
                                self.add(item: WatchlistedItem(season: season), in: list)
                            }
                            addToList.append(add)
                        }
                        let safeAddToList = addToList
                        await MainActor.run {
                            completion(safeAddToList)
                        }
                    }
                })
                listsActions.append(UIMenu(title: "Add to List", image: UIImage(systemName: "text.badge.plus"), children: [addToList]))

                let lists = UIAction(title: "Manage in Lists", image: UIImage(systemName: "plusminus.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.listManagement(media: self.media)
                }
                listsActions.append(lists)
            }

            return UIMenu(title: "\(show.title) Season \(season.number)", children: listsActions)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var quickTrackMenu: UIMenu {
        guard let media = media else { return UIMenu(title: "Somthing wrong happened. Try again.", children: []) }

        switch media {
        case let .movie(movie):
            var watchActions = [UIAction]()

            if movie.isCurrentlyWatching {
                let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.cancelCheckin()
                }
                watchActions.append(cancel)
            } else {
                let checkin = UIAction(title: "Check in", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.checkin()
                }
                watchActions.append(checkin)
            }

            let markWatchedNow = UIAction(title: "Mark Watched Now", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.markWatched()
            }
            watchActions.append(markWatchedNow)

            let markWatched = UIAction(title: "Mark Watched On...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            var pin: UIAction
            if movie.isPinned {
                pin = UIAction(title: "Unpin", image: UIImage(systemName: "pin.slash"), attributes: .destructive) { _ in
                    movie.unpin()
                }
            } else {
                pin = UIAction(title: "Pin on To Watch", image: UIImage(systemName: "pin.circle")) { _ in
                    movie.pin()
                }
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)

            return UIMenu(title: "\(movie.title)", children: [watchSubmenu, pin])
        case let .show(show):
            var watchActions = [UIAction]()

            if show.isCurrentlyWatching {
                if let episode = WatchingManager.shared.watchingItem?.episode {
                    let cancel = UIAction(title: "Cancel \(episode.localizedEpisodeNumber) Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        self.media.cancelCheckin()
                    }
                    watchActions.append(cancel)
                } else {
                    let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                        guard let self = self else { return }
                        self.media.cancelCheckin()
                    }
                    watchActions.append(cancel)
                }
            }

            let markWatched = UIAction(title: "Mark Show Watched...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            let next = UIAction(title: "Next Episode to Watch", image: UIImage(systemName: "chevron.right.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.presentNextEpisode(media: self.media)
            }

            var pin: UIAction
            if show.isPinned {
                pin = UIAction(title: "Unpin", image: UIImage(systemName: "pin.slash"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.unpin()
                }
            } else {
                pin = UIAction(title: "Pin on To Watch", image: UIImage(systemName: "pin.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.show!.pin()
                }
            }

            let watchSubmenu = UIMenu(title: "", options: .displayInline, children: watchActions)

            return UIMenu(title: "\(show.title)", children: [watchSubmenu, next, pin])
        case let .episode(episode, show):
            var watchActions = [UIAction]()

            if show.isCurrentlyWatching,
                let checkedInEpisode = WatchingManager.shared.watchingItem?.episode,
                episode == checkedInEpisode {
                let cancel = UIAction(title: "Cancel Check-in", image: UIImage(systemName: "nosign"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.cancelCheckin()
                }
                watchActions.append(cancel)
            } else {
                let checkin = UIAction(title: "Check in \(episode.localizedEpisodeNumber)", image: UIImage(systemName: "play.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.media.checkin()
                }
                watchActions.append(checkin)
            }

            let markWatchedNow = UIAction(title: "Mark Watched Now", image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.media.markWatched()
            }
            watchActions.append(markWatchedNow)

            let markWatched = UIAction(title: "Mark Watched On...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            return UIMenu(title: "\(show.title) \(episode.localizedEpisodeNumber)", children: watchActions)
        case .season(let season, let show):
            var watchActions = [UIAction]()

            let markWatched = UIAction(title: "Mark Season Watched...", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.markWatched()
            }
            watchActions.append(markWatched)

            return UIMenu(title: "\(show.title) Season \(season.number)", children: watchActions)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    var quickShareMenu: UIMenu {

        guard let media = media else { return UIMenu(title: "Somthing wrong happened. Try again.", children: []) }

        let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            self.share()
        }

        switch media {
        case let .movie(movie):

            var actions = [UIAction]()
            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }

            if movie.isRecommended {
                let removeRecommendation = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "star.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromRecommendations()
                }
                actions.append(removeRecommendation)
            } else {
                let recommendThis = UIAction(title: "Add to Favorites", image: UIImage(systemName: "star.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToRecommendations()
                }
                actions.append(recommendThis)
            }
            actions.append(write)

            return UIMenu(title: "\(movie.title)", children: [UIMenu(title: "", options: .displayInline, children: actions), share])
        case let .show(show):
            var actions = [UIAction]()

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }

            if show.isRecommended {
                let removeRecommendation = UIAction(title: "Remove from Favorites", image: UIImage(systemName: "star.circle"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    self.removeFromRecommendations()
                }
                actions.append(removeRecommendation)
            } else {
                let recommendThis = UIAction(title: "Add to Favorites", image: UIImage(systemName: "star.circle")) { [weak self] _ in
                    guard let self = self else { return }
                    self.addToRecommendations()
                }
                actions.append(recommendThis)
            }

            actions.append(write)

            return UIMenu(title: "\(show.title)", children: [UIMenu(title: "", options: .displayInline, children: actions), share])
        case let .episode(episode, show):
            var actions = [UIAction]()

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }

            actions.append(write)

            return UIMenu(title: "\(show.title) \(episode.localizedEpisodeNumber)", children: [UIMenu(title: "", options: .displayInline, children: [write]), share])
        case .season(let season, let show):

            let write = UIAction(title: "Write a Comment", image: UIImage(systemName: "pencil.circle")) { [weak self] _ in
                guard let self = self else { return }
                self.writeComment(media: self.media)
            }

            return UIMenu(title: "\(show.title) Season \(season.number)", children: [UIMenu(title: "", options: .displayInline, children: [write]), share])
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    fileprivate func share() {
        guard let sharedURL = media.traktWebsiteMediaLink else { return }
        let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
        UIApplication.shared.present(activityViewController)
    }

    private func makeOpenInSubmenu(for media: MediaModel) -> UIMenu {
        let builtIn = OpenActionManager.shared.builtInActions(for: media)
        let custom = OpenActionManager.shared.customActions(for: media)
        let entries = builtIn + custom

        let actions: [UIAction] = entries.map { entry in
            UIAction(title: entry.action.name,
                     image: UIImage(systemName: entry.action.systemImageName)) { [weak self] _ in
                self?.openIn(entry.url)
            }
        }

        return UIMenu(title: "Open In",
                      image: UIImage(systemName: "arrow.up.forward"),
                      children: actions)
    }

    private func openIn(_ url: URL) {
        if url.scheme?.lowercased() == "infuse",
           UIApplication.shared.canOpenURL(url) == false,
           let appStoreURL = URL(string: "https://apps.apple.com/app/id1136220934") {
            UIApplication.shared.open(appStoreURL)
            return
        }

        UIApplication.shared.open(url)
    }

    private func presentNextEpisode(media: MediaModel) {
        let nextEpisodeToWatchNavigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "next episode") as! UINavigationController

        if let nextEpisodeViewController = nextEpisodeToWatchNavigationController.topViewController as? MediaShowNextLoadingViewController {
            nextEpisodeViewController.media = media
        }

        if let controller = controller {
            controller.present(nextEpisodeToWatchNavigationController, animated: true)
        } else {
            UIApplication.shared.present(nextEpisodeToWatchNavigationController)
        }
    }

    fileprivate var watchlistItem: WatchlistedItem {
        switch media! {
        case .movie(let movie):
            return WatchlistedItem(movie: movie)
        case .show(let show):
            return WatchlistedItem(show: show)
        case .episode(let episode, _):
            return WatchlistedItem(episode: episode)
        case .season(let season, _):
            return WatchlistedItem(season: season)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }

        fatalError()
    }

    fileprivate func addToWatchlist() {
        SwiftMessages.show(message: "Adding to Watchlist...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addToWatchlist(item: watchlistItem),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Add to watchlist successful \(response)")

                                                            DispatchQueue.main.async {
                                                                WatchlistManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "🕒 Added to Watchlist")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
    }
    }

    fileprivate func removeFromWatchlist() {
        SwiftMessages.show(message: "Removing from Watchlist...", style: .loading)

                TraktAPIProvider.provider.request(TraktAPIService.removeFromWatchlist(item: watchlistItem),
                                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
    //                                                        guard let self = self else { return }
                                                            switch result {
                                                            case let .success(moyaResponse):
                                                                do {
                                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                                    print("Add to watchlist successful \(response)")

                                                                    DispatchQueue.main.async {
                                                                        WatchlistManager.shared.refresh()
                                                                        AppManager.shared.isUserInteractionEnabled = true
                                                                        SwiftMessages.show(message: "🕒 Removed from Watchlist")
                                                                    }

                                                                } catch {
                                                                    DispatchQueue.main.async {
                                                                        AppManager.shared.isUserInteractionEnabled = true
                                                                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                                    }
                                                                }
                                                            case let .failure(error):
                                                                DispatchQueue.main.async {
                                                                    AppManager.shared.isUserInteractionEnabled = true
                                                                    SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                                }
                                                            }
            }
    }

    fileprivate func addToRecommendations() {

        SwiftMessages.show(message: "Adding to Favorites...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
//                                                    guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Favoriting successful \(response)")

                                                            DispatchQueue.main.async {
                                                                RecommendedManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "⭐️ Added to Favorites")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
        }
    }

    fileprivate func removeFromRecommendations() {

        SwiftMessages.show(message: "Removing from Favorites...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.removeFromRecommendations(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
//                                                        guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Removed from recommendations successful \(response)")

                                                            DispatchQueue.main.async {
                                                                RecommendedManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "⭐️ Removed from Favorites")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
            }
    }

    fileprivate func addToCollection() {
        media.addToCollection()
    }

    fileprivate func removeFromCollection() {
        SwiftMessages.show(message: "Removing from Library...", style: .loading)

        TraktAPIProvider.provider.request(TraktAPIService.removeFromCollection(item: watchlistItem),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
//                                                        guard let self = self else { return }
                                                    switch result {
                                                    case let .success(moyaResponse):
                                                        do {
                                                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                            print("Removed from Collection successful \(response)")

                                                            DispatchQueue.main.async {
                                                                CollectionManager.shared.refresh()
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "📚 Removed from Library")
                                                            }

                                                        } catch {
                                                            DispatchQueue.main.async {
                                                                AppManager.shared.isUserInteractionEnabled = true
                                                                SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                            }
                                                        }
                                                    case let .failure(error):
                                                        DispatchQueue.main.async {
                                                            AppManager.shared.isUserInteractionEnabled = true
                                                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                                                        }
                                                    }
            }
    }

    fileprivate func listManagement(media: MediaModel) {
        let listViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Lists Action") as! ListActionViewController

        listViewController.media = media

        if let controller = controller {
            controller.present(listViewController, animated: true)
        } else {
            UIApplication.shared.present(listViewController)
        }
    }

    fileprivate func writeComment(media: MediaModel) {
        let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController

        composer.mediaModel = media

        if let controller = controller {
            controller.present(composer, animated: true)
        } else {
            UIApplication.shared.present(composer)
        }
    }

    private func openOnTrakt(media: MediaModel) {
        if let traktURL = media.traktWebsiteMediaLink {
            if let controller = controller {
                controller.present(SFSafariViewController(url: traktURL),
                animated: true,
                completion: nil)
            } else {
                UIApplication.shared.present(SFSafariViewController(url: traktURL))
            }
        } else {
            SwiftMessages.show(message: "😓 Couldn't open Trakt", style: .standout)
        }
    }

    func markWatched() {
        guard let navigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Action Navigation Controller") as? UINavigationController else { return }

        let markWatchedActionViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Mark Watched") { [weak self] coder -> MarkWatchedActionViewController? in
            guard let self = self else { return nil }
            return MarkWatchedActionViewController(coder: coder,
                                                   media: self.media)
        }

        navigationController.viewControllers = [markWatchedActionViewController]

        if let controller = controller {
            controller.present(navigationController, animated: true)
        } else {
            UIApplication.shared.present(navigationController)
        }
    }

    private func add(item: WatchlistedItem, in list: List) {
        if SessionManager.shared.isLoggedOut { return }

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            if let shows = item.shows {
                MediaModel.addShowsToWatchlistUndercover(medias: shows.map { $0.mediaModel })
            }
        }

        TraktAPIProvider.provider.request(.addToList(slug: list.user.slug,
                                                     id: list.identifiers.trakt!,
                                                     item: item),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if response.statusCode == 201 {
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: "✅ Added to list")
                            onListChangedTransmitter.broadcast([list])
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                }
            }
        }
    }
}

final class MediaContextMenuInteractionDelegate: ContextMenuHelper, UIContextMenuInteractionDelegate {

    var referenceView: UIView?

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration, highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
        if let referenceView = referenceView {
            return UITargetedPreview(view: referenceView)
        }
        return nil
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        animator.preferredCommitStyle = .dismiss
        animator.addCompletion { [weak self] in
            guard let self = self else { return }

            if let controller = self.controller {
                guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                    return
                }

                mediaViewController.media = self.media
                controller.show(mediaViewController, sender: self)
            } else {
                guard let navigationController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController in NavigationController") as? UINavigationController else {
                    return
                }

                guard let mediaViewController = navigationController.viewControllers.first as? MediaViewController else {
                    return
                }

                mediaViewController.media = self.media
                UIApplication.shared.present(navigationController)
            }
        }
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {

        guard let media = media else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            let mediaPreviewViewController = UIStoryboard(name: "MediaPreview", bundle: nil).instantiateInitialViewController() as! MediaPreviewViewController

            mediaPreviewViewController.media = media
            mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                     height: 500 * 1.5)
            return mediaPreviewViewController
        }, actionProvider: { [weak self] _ in
            guard let self = self else { return nil }
            return self.menu
        })
    }
}
