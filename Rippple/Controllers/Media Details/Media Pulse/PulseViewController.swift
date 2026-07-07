//
//  PulseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/05/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class PulseViewController: UITableViewController {
    var media: MediaModel!
    private let disposeBag = DisposeBag()
    private var calendarData: CalendarData?

    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .full
        dateFormatter.dateTimeStyle = .numeric
        dateFormatter.formattingContext = .listItem
        return dateFormatter
    }()

    private enum ActivityOrigin {
        case standard
        case movieRelease
        case calendarMovieRelease
    }

    private struct ActivityItem: Hashable {
        let identifier: String
        let activity: String
        let title: String
        let notes: String
        let meta: String
        let date: Date
        let systemImageName: String
        let historyItem: HistoryItem?
        let ratedItem: RatedItem?
        let actions: [ActivityAction]
        let origin: ActivityOrigin

        init(activity: String,
             title: String,
             notes: String,
             meta: String,
             date: Date,
             systemImageName: String,
             historyItem: HistoryItem? = nil,
             ratedItem: RatedItem? = nil,
             actions: [ActivityAction] = [],
             origin: ActivityOrigin = .standard,
             identifier: String) {
            self.identifier = identifier
            self.activity = activity
            self.title = title
            self.notes = notes
            self.meta = meta
            self.date = date
            self.systemImageName = systemImageName
            self.historyItem = historyItem
            self.ratedItem = ratedItem
            self.actions = actions
            self.origin = origin
        }

        static func == (lhs: ActivityItem, rhs: ActivityItem) -> Bool {
            lhs.identifier == rhs.identifier
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(identifier)
        }
    }

    private enum ActionType: Hashable {
        case delete
        case note
        case open
    }

    private struct ActivityAction: Hashable {
        let type: ActionType
        let title: String
        let shortTitle: String?
        let systemImageName: String?

        let handler: () -> Void

        static func == (lhs: ActivityAction, rhs: ActivityAction) -> Bool {
            lhs.type == rhs.type &&
                lhs.title == rhs.title && lhs.shortTitle == rhs.shortTitle &&
                lhs.systemImageName == rhs.systemImageName
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(type)
            hasher.combine(title)
            hasher.combine(shortTitle)
            hasher.combine(systemImageName)
        }
    }

    private func openAction(for media: MediaModel) -> ActivityAction? {
        guard let deeplink = media.deeplink else { return nil }
        return ActivityAction(type: .open,
                              title: "Open \(media.mediaTitle)",
                              shortTitle: nil,
                              systemImageName: nil,
                              handler: {
                                  UIApplication.shared.open(deeplink)
                              })
    }

    private func activityAction(ofType type: ActionType, in actions: [ActivityAction]) -> ActivityAction? {
        actions.first(where: { $0.type == type })
    }

    private func buildHistoryActivityActions(for historyItem: HistoryItem) -> [ActivityAction] {
        guard let media = MediaModel(item: historyItem) else { return [] }

        let notes = ActivityAction(type: .note,
                                   title: historyItem.noteItem == nil ? "Add History Note" : "Edit History Note",
                                   shortTitle: historyItem.noteItem == nil ? "Add Note" : "Edit Note",
                                   systemImageName: "note.text",
                                   handler: {
                                       NotesManager.shared.showNotes(for: historyItem)
                                       UISelectionFeedbackGenerator().selectionChanged()
                                   })

        let remove = ActivityAction(type: .delete,
                                    title: "Remove from History",
                                    shortTitle: "Remove",
                                    systemImageName: "trash.circle.fill",
                                    handler: { [weak self] in
                                        guard let self else { return }

                                        let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                            message: "Do you want to remove this from your watch history?",
                                                                                            preferredStyle: .actionSheet)

                                        let cancel = UIAlertAction(title: "Don't remove", style: .cancel)
                                        confirmationAlertController.addAction(cancel)

                                        let delete = UIAlertAction(title: "Remove", style: .destructive) { _ in
                                            guard let window = self.view.window else { return }
                                            window.isUserInteractionEnabled = false

                                            SwiftMessages.show(message: "Removing from History...", style: .loading)

                                            TraktAPIProvider.provider.request(.removeFromHistory(id: historyItem.identifier),
                                                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                                defer {
                                                    DispatchQueue.main.async {
                                                        window.isUserInteractionEnabled = true
                                                    }
                                                }

                                                guard let self else { return }

                                                switch result {
                                                case .success(let moyaResponse):
                                                    do {
                                                        let response =
                                                            try moyaResponse.filterSuccessfulStatusCodes()
                                                        DispatchQueue.main.async {
                                                            if response.statusCode == 200 {
                                                                SwiftMessages.show(message: "🗑 Activity removed")
                                                                onRemoveWatchTransmitter.broadcast(historyItem.identifier)
                                                                onRemoveWatchMediaTransmitter.broadcast(self.media)
                                                                self.refresh()
                                                            }
                                                        }
                                                    } catch {
                                                        DispatchQueue.main.async {
                                                            SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                        }
                                                    }
                                                case .failure(let error):
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                    }
                                                }
                                            }
                                        }

                                        confirmationAlertController.addAction(delete)
                                        self.present(confirmationAlertController, animated: true)
                                    })

        return [openAction(for: media), notes, remove].compactMap { $0 }
    }

    private func buildActivityActions(for media: MediaModel) -> [ActivityAction] {
        switch media {
        case .movie, .show, .season, .episode:
            break
        default:
            return []
        }

        return [openAction(for: media)].compactMap { $0 }
    }

    private func buildCalendarReleaseActivityItems(for movie: Movie) -> [ActivityItem] {
        guard let calendarData else { return [] }

        let dateFormatter: DateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .none
            return dateFormatter
        }()

        return calendarData.movies
            .filter { release in
                release.movie == movie &&
                    (release.releaseType == .physical || release.releaseType == .streaming)
            }
            .map { release in
                var meta = [String]()
                if let releaseCountryCode = release.releaseCountryCode {
                    meta.append(Locale(identifier: "en_US").localizedCountry(for: releaseCountryCode))
                }

                return ActivityItem(activity: release.tag,
                                    title: dateFormatter.string(from: release.released),
                                    notes: "",
                                    meta: meta.joined(separator: " · "),
                                    date: release.released,
                                    systemImageName: "calendar",
                                    origin: .calendarMovieRelease,
                                    identifier: "calendar-release-\(movie.identifiers.traktIdOrSlug)-\(release.releaseType)-\(release.releaseCountryCode ?? "unknown")-\(release.released.timeIntervalSinceReferenceDate)")
            }
    }

    private func containsReleaseActivity(_ activityItems: [ActivityItem], matching calendarReleaseActivity: ActivityItem) -> Bool {
        activityItems.contains { activityItem in
            activityItem.origin == .movieRelease &&
                calendarReleaseActivity.origin == .calendarMovieRelease &&
                Calendar.current.isDate(activityItem.date, inSameDayAs: calendarReleaseActivity.date)
        }
    }

    private func buildRatedActivityActions(for ratedItem: RatedItem) -> [ActivityAction] {
        let media = MediaModel(item: ratedItem)

        let notes = ActivityAction(type: .note,
                                   title: ratedItem.noteItem == nil ? "Add Rating Note" : "Edit Rating Note",
                                   shortTitle: ratedItem.noteItem == nil ? "Add Note" : "Edit Note",
                                   systemImageName: "note.text",
                                   handler: {
                                       NotesManager.shared.showNotes(for: ratedItem)
                                       UISelectionFeedbackGenerator().selectionChanged()
                                   })

        return [openAction(for: media), notes].compactMap { $0 }
    }

    private func buildCommentActivityActions(for commentItem: CommentItem) -> [ActivityAction] {
        let commentModel = CommentModel(commentItem: commentItem,
                                        spoilerStrategy: .showAllSpoilers)

        let open = ActivityAction(type: .open,
                                  title: "Open Comment",
                                  shortTitle: nil,
                                  systemImageName: nil,
                                  handler: {
                                      guard let deeplink = URL(string: "ripl://comments/\(commentModel.comment.identifier)") else { return }
                                      UIApplication.shared.open(deeplink)
                                  })

        let delete = ActivityAction(type: .delete,
                                    title: "Delete Comment",
                                    shortTitle: "Delete",
                                    systemImageName: "trash.circle.fill",
                                    handler: { [weak self] in
                                        guard let self else { return }

                                        let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                            message: "Are you sure you want to delete this comment?",
                                                                                            preferredStyle: .alert)

                                        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                                        confirmationAlertController.addAction(cancel)

                                        let delete = UIAlertAction(title: "Yes, Delete Comment",
                                                                   style: .destructive) { _ in
                                            TraktAPIProvider.provider.request(.deleteComment(id: commentModel.comment.identifier),
                                                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                                guard let self else { return }

                                                switch result {
                                                case .success(let moyaResponse):
                                                    do {
                                                        if moyaResponse.statusCode == 409 {
                                                            DispatchQueue.main.async {
                                                                let alertController = UIAlertController(title: "Can't Delete",
                                                                                                        message: "We cannot delete a comment that is older than 2 weeks or has at least one comment.",
                                                                                                        preferredStyle: .alert)

                                                                let cancel = UIAlertAction(title: "Okay",
                                                                                           style: .cancel)
                                                                alertController.addAction(cancel)
                                                                self.present(alertController, animated: true)
                                                            }
                                                        } else {
                                                            _ =
                                                                try moyaResponse.filterSuccessfulStatusCodes()

                                                            DispatchQueue.main.async {
                                                                SwiftMessages.show(message: "🗑 Comment deleted")
                                                                self.refresh()
                                                            }
                                                        }
                                                    } catch {
                                                        DispatchQueue.main.async {
                                                            SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                                                        }
                                                    }
                                                case .failure(let error):
                                                    DispatchQueue.main.async {
                                                        SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                                                    }
                                                }
                                            }
                                        }

                                        confirmationAlertController.addAction(delete)
                                        self.present(confirmationAlertController, animated: true)
                                    })

        return [open, delete]
    }

    private func buildNoteActivityActions(for noteItem: NoteItem) -> [ActivityAction] {
        let edit = ActivityAction(type: .note,
                                  title: "Edit Note",
                                  shortTitle: "Edit",
                                  systemImageName: "pencil.circle.fill",
                                  handler: {
                                      NotesManager.shared.showNotes(for: noteItem)
                                  })

        let delete = ActivityAction(type: .delete,
                                    title: "Delete Note",
                                    shortTitle: "Delete",
                                    systemImageName: "trash.circle.fill",
                                    handler: { [weak self] in
                                        guard let self else { return }

                                        let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                            message: "Are you sure you want to delete this note?",
                                                                                            preferredStyle: .alert)
                                        confirmationAlertController.addAction(UIAlertAction(title: "Cancel",
                                                                                            style: .cancel))
                                        confirmationAlertController.addAction(UIAlertAction(title: "Yes, Delete Note",
                                                                                            style: .destructive) { _ in
                                                self.deleteNote(noteItem: noteItem)
                                            })
                                        self.present(confirmationAlertController, animated: true)
                                    })

        return [edit, delete]
    }

    private func buildListActivityActions(for list: List, item: WatchlistItem) -> [ActivityAction] {
        let open = ActivityAction(type: .open,
                                  title: "Open \(list.name)",
                                  shortTitle: nil,
                                  systemImageName: nil,
                                  handler: {
                                      guard let deeplink = URL(string: "ripl://users/\(list.user.slug)/lists/\(list.identifiers.slugOrTraktId)") else { return }
                                      UIApplication.shared.open(deeplink)
                                  })

        let hasNote = item.notes?.isEmpty == false
        let notes = ActivityAction(type: .note,
                                   title: hasNote ? "Edit List Note" : "Add List Note",
                                   shortTitle: hasNote ? "Edit Note" : "Add Note",
                                   systemImageName: "note.text.badge.plus",
                                   handler: {
                                       NotesManager.shared.showNotes(for: WatchlistType.listItem(note: item.notes ?? "",
                                                                                                 userId: list.user.identifiers.slug ?? "me",
                                                                                                 listId: list.identifiers.trakt!,
                                                                                                 itemId: item.id,
                                                                                                 canEdit: true,
                                                                                                 user: list.user,
                                                                                                 listItem: item))
                                   })

        let remove = ActivityAction(type: .delete,
                                    title: "Remove from List",
                                    shortTitle: "Remove",
                                    systemImageName: "trash.circle.fill",
                                    handler: { [weak self] in
                                        guard let self = self else { return }

                                        let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                            message: "Are you sure you want to remove \(self.media.mediaTitle) from \(list.name.emojiUnescapedString)?",
                                                                                            preferredStyle: .alert)

                                        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                                        confirmationAlertController.addAction(cancel)

                                        let delete = UIAlertAction(title: "Yes, Remove",
                                                                   style: .destructive) { _ in
                                            self.remove(from: list)
                                        }

                                        confirmationAlertController.addAction(delete)
                                        self.present(confirmationAlertController, animated: true)
                                    })

        return [open, notes, remove]
    }

    private func buildFavoriteActivityActions(for favoriteItem: WatchlistItem) -> [ActivityAction] {
        let hasNote = favoriteItem.notes?.isEmpty == false
        let notes = ActivityAction(type: .note,
                                   title: hasNote ? "Edit Favorite Note" : "Add Favorite Note",
                                   shortTitle: hasNote ? "Edit Note" : "Add Note",
                                   systemImageName: "note.text.badge.plus",
                                   handler: {
                                       guard let currentUser = UserManager.shared.currentUser else { return }
                                       NotesManager.shared.showNotes(for: WatchlistType.favoriteItem(note: favoriteItem.notes ?? "",
                                                                                                     itemId: favoriteItem.id,
                                                                                                     canEdit: true,
                                                                                                     user: currentUser,
                                                                                                     listItem: favoriteItem))
                                   })

        let remove = ActivityAction(type: .delete,
                                    title: "Remove from Favorites",
                                    shortTitle: "Remove",
                                    systemImageName: "trash.circle.fill",
                                    handler: { [weak self] in
                                        guard let self else { return }

                                        let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                            message: "Are you sure you want to remove \(self.media.mediaTitle) from your favorites?",
                                                                                            preferredStyle: .alert)
                                        confirmationAlertController.addAction(UIAlertAction(title: "Cancel",
                                                                                            style: .cancel))
                                        confirmationAlertController.addAction(UIAlertAction(title: "Yes, Remove",
                                                                                            style: .destructive) { _ in
                                                self.media.removeFromRecommendations()
                                            })
                                        self.present(confirmationAlertController, animated: true)
                                    })

        return [notes, remove]
    }

    private func remove(from list: List) {
        if SessionManager.shared.isLoggedOut { return }

        let item: WatchlistedItem = {
            switch media! {
            case .movie(let movie):
                return WatchlistedItem(movie: movie)
            case .show(let show):
                return WatchlistedItem(show: show)
            case .episode(let episode, _):
                return WatchlistedItem(episode: episode)
            case .season(let season, _):
                return WatchlistedItem(season: season)
            case .list, .showProgress:
                fatalError("Trying to remove something not supported.")
            }
        }()

        TraktAPIProvider.provider.request(.removeFromList(slug: list.user.slug,
                                                          id: list.identifiers.trakt!,
                                                          item: item),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response =
                        try moyaResponse.filterSuccessfulStatusCodes()

                    if response.statusCode == 200 {
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: "🗑 Removed from \(list.name.emojiUnescapedString)")
                            self.refresh()
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                }
            }
        }
    }

    private func showComposer(for comment: Comment?, media: MediaModel) {
        let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController
        composer.mediaModel = media
        composer.editedComment = comment
        present(composer, animated: true)
    }

    private func activityTypeText(for activityItem: ActivityItem) -> String {
        guard activityItem.activity != "Today" else { return "Today" }
        guard activityItem.date.timeIntervalSince1970 != 0 else { return activityItem.activity }
        let relativeDate = relativeDateTimeFormatter.localizedString(for: activityItem.date, relativeTo: .now)
        return "\(activityItem.activity), \(relativeDate)"
    }

    private func referenceDateText(for activityItem: ActivityItem) -> String {
        activityItem.date.timeIntervalSince1970 == 0 ? "At Unknown Date" : activityItem.title
    }

    private func configureNotes(in cell: PulseTableViewCell, for activityItem: ActivityItem) {
        if let noteAction = activityAction(ofType: .note, in: activityItem.actions) {
            cell.noteButton.isHidden = false
            cell.onTapNoteButton = noteAction.handler

            cell.notes.isHiddenInStackView = false
            if activityItem.notes.isEmpty {
                cell.notes.alpha = 0.7
                cell.notes.activityText = "**Add Notes**"
                cell.notesPicto.image = UIImage(systemName: "plus.capsule.fill")
                cell.notesPicto.isHiddenInStackView = false
            } else {
                cell.notes.alpha = 1.0
                cell.notes.activityText = activityItem.notes
                cell.notesPicto.isHiddenInStackView = true
            }
            return
        }

        cell.noteButton.isHidden = true
        cell.notes.tintColor = .label
        cell.notes.alpha = 1.0
        cell.notes.activityText = activityItem.notes
        cell.notes.isHiddenInStackView = activityItem.notes.isEmpty
        cell.notesPicto.isHiddenInStackView = true
    }

    private func configurePicto(in cell: PulseTableViewCell, for activityItem: ActivityItem) {
        let showsSystemIcon = activityItem.systemImageName.hasPrefix("calendar")
        cell.picto.isHidden = !showsSystemIcon
        cell.picto.isHiddenInStackView = !showsSystemIcon
        cell.ownEventIndicator.superview?.isHidden = showsSystemIcon
        cell.ownEventIndicator.superview?.isHiddenInStackView = showsSystemIcon

        guard showsSystemIcon else { return }
        cell.picto.image = UIImage(systemName: activityItem.systemImageName)
        cell.picto.tintColor = .secondaryLabel
    }

    private func configureBackdrop(in cell: PulseTableViewCell, for activityItem: ActivityItem) {
        let shouldShowBackdrop = media.show != nil && media.episode == nil && activityItem.historyItem != nil
        cell.backdrop.isHidden = !shouldShowBackdrop
        cell.backdrop.isHiddenInStackView = !shouldShowBackdrop

        guard let historyItem = activityItem.historyItem, shouldShowBackdrop else { return }
        cell.backdrop.media = MediaModel(item: historyItem)
    }

    private func configureActivityCell(_ cell: PulseTableViewCell, with activityItem: ActivityItem) {
        cell.ratedItem = activityItem.ratedItem
        cell.activityType.text = activityTypeText(for: activityItem)
        cell.metaInfo.text = activityItem.meta
        cell.metaInfo.isHiddenInStackView = activityItem.meta.isEmpty
        cell.referenceDate.text = referenceDateText(for: activityItem)
        configureNotes(in: cell, for: activityItem)
        configurePicto(in: cell, for: activityItem)
        configureBackdrop(in: cell, for: activityItem)
        cell.cardType = .alone
    }

    private func deleteNote(noteItem: NoteItem) {
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false

        SwiftMessages.show(message: "Deleting Notes...", style: .loading)

        TraktAPIProvider.provider.request(.deleteNotes(id: noteItem.note.identifier),
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    NotesManager.shared.refresh()
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "📝 Notes deleted")
                        window.isUserInteractionEnabled = true
                        self.refresh()
                    }
                } catch {
                    NotesManager.shared.refresh()
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error deleting notes", style: .error(error))
                        window.isUserInteractionEnabled = true
                    }
                }
            case .failure(let error):
                NotesManager.shared.refresh()
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error deleting notes", style: .error(error))
                    window.isUserInteractionEnabled = true
                }
            }
        }
    }

    private var isRefreshing = false

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = "Pulse"
        navigationItem.subtitle = "Loading..."

        tableView.register(UINib(nibName: "PulseTableViewCell", bundle: nil), forCellReuseIdentifier: "activity")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.separatorStyle = .none

        tableView.allowsFocus = false

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refresh()
            }
        }.disposed(by: disposeBag)

        onRecommendedChangedReceiver.listen { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refresh()
            }
        }.disposed(by: disposeBag)

        onNotesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refresh()
            }
        }.disposed(by: disposeBag)

        onWatchlistTypeNotesChangedReceiver.listen { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                self.refresh()
            }
        }.disposed(by: disposeBag)

        calendarDataUpdatedReceiver.listen { [weak self] data in
            guard let self else { return }
            DispatchQueue.main.async {
                self.calendarData = data
                self.refresh()
            }
        }.disposed(by: disposeBag)

        refresh(forced: true)

        configureOptionButton()
    }

    private func configureOptionButton() {
        let removeAllWatch = UIAction(title: "Remove All Watch",
                                      image: UIImage(systemName: "minus.circle"),
                                      attributes: .destructive,
                                      handler: { _ in
                                          let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                                              message: "Are you sure you want to remove all watch?",
                                                                                              preferredStyle: .alert)

                                          let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                                          confirmationAlertController.addAction(cancel)

                                          let delete = UIAlertAction(title: "Yes, Remove All Watch",
                                                                     style: .destructive) { _ in
                                              switch self.media! {
                                              case .movie(let movie):
                                                  TraktAPIProvider.provider.request(.removeMovieFromHistory(id: movie.identifiers.trakt!),
                                                                                    callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                                                      guard let self = self else { return }
                                                      switch result {
                                                      case .success(let moyaResponse):
                                                          do {
                                                              _ = try moyaResponse.filterSuccessfulStatusCodes()
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "🗑 Watch removed")
                                                                  onRemoveWatchMediaTransmitter.broadcast(self.media)
                                                                  onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                                                  self.refresh()
                                                              }
                                                          } catch {
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                              }
                                                          }
                                                      case .failure(let error):
                                                          DispatchQueue.main.async {
                                                              SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                          }
                                                      }
                                                  }
                                              case .show(let show):
                                                  TraktAPIProvider.provider.request(.removeShowFromHistory(id: show.identifiers.trakt!),
                                                                                    callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                                                      guard let self = self else { return }
                                                      switch result {
                                                      case .success(let moyaResponse):
                                                          do {
                                                              _ = try moyaResponse.filterSuccessfulStatusCodes()
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "🗑 Watch removed")
                                                                  onRemoveWatchMediaTransmitter.broadcast(self.media)
                                                                  onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                                                  self.refresh()
                                                              }
                                                          } catch {
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                              }
                                                          }
                                                      case .failure(let error):
                                                          DispatchQueue.main.async {
                                                              SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                          }
                                                      }
                                                  }
                                              case .episode(let episode, _):
                                                  TraktAPIProvider.provider.request(.removeEpisodeFromHistory(id: episode.identifiers.trakt!),
                                                                                    callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                                                      guard let self = self else { return }
                                                      switch result {
                                                      case .success(let moyaResponse):
                                                          do {
                                                              _ = try moyaResponse.filterSuccessfulStatusCodes()
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "🗑 Watch removed")
                                                                  onRemoveWatchMediaTransmitter.broadcast(self.media)
                                                                  onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                                                  self.refresh()
                                                              }
                                                          } catch {
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                              }
                                                          }
                                                      case .failure(let error):
                                                          DispatchQueue.main.async {
                                                              SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                          }
                                                      }
                                                  }
                                              case .season(let season, _):
                                                  TraktAPIProvider.provider.request(.removeSeasonFromHistory(id: season.identifiers.trakt!),
                                                                                    callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                                                      guard let self = self else { return }
                                                      switch result {
                                                      case .success(let moyaResponse):
                                                          do {
                                                              _ = try moyaResponse.filterSuccessfulStatusCodes()
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "🗑 Watch removed")
                                                                  onRemoveWatchMediaTransmitter.broadcast(self.media)
                                                                  onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                                                  self.refresh()
                                                              }
                                                          } catch {
                                                              DispatchQueue.main.async {
                                                                  SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                              }
                                                          }
                                                      case .failure(let error):
                                                          DispatchQueue.main.async {
                                                              SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                                          }
                                                      }
                                                  }
                                              case .list:
                                                  fatalError()
                                              case .showProgress:
                                                  fatalError()
                                              }
                                          }
                                          confirmationAlertController.addAction(delete)

                                          self.present(confirmationAlertController, animated: true)
                                      })

        let menu = UIMenu(children: [removeAllWatch])

        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)]
    }

    private func refresh(forced: Bool = false) {
        if isRefreshing { return }
        isRefreshing = true

        navigationItem.subtitle = "Loading..."

        if forced {
            var loading = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            loading.appendSections([.loading])
            loading.appendItems([.loading])
            dataSource.apply(loading, animatingDifferences: false)
        }

        Task {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.content])

            var activityItems = [ActivityItem]()

            if let episode = media.episode, let show = media.show {
                if let firstAired = episode.firstAired {
                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let country = show.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = show.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            actions: buildActivityActions(for: media),
                                            identifier: "episode-first-aired-\(episode.identifiers.traktIdOrSlug)-\(firstAired.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }
            }

            if let season = media.season, let show = media.show {
                if let firstAired = season.firstAired {
                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let country = show.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = show.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            identifier: "season-first-aired-\(season.identifiers.traktIdOrSlug)-\(firstAired.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }
            }

            if let show = media.showShow {
                let fullShow = await fetchDetails(for: show)

                if let firstAired = fullShow.firstAired {
                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let network = fullShow.network {
                        meta.append(network)
                    }
                    if let country = fullShow.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = fullShow.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired.addingTimeInterval(-5), // make sure this is displayed before anythin else,
                                            systemImageName: "calendar",
                                            identifier: "show-first-aired-\(fullShow.identifiers.traktIdOrSlug)-\(firstAired.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }

                if let lastEpisode = await fetchLastEpisode(for: show),
                   let firstAired = lastEpisode.firstAired {
                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    let item = ActivityItem(activity: "Last Aired Episode",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: "\(lastEpisode.localizedEpisodeNumber)",
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            actions: buildActivityActions(for: lastEpisode.mediaModel(given: show)),
                                            identifier: "last-aired-episode-\(lastEpisode.identifiers.traktIdOrSlug)-\(firstAired.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }

                if let nextEpisode = await fetchNextEpisode(for: show),
                   let firstAired = nextEpisode.firstAired {
                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    let item = ActivityItem(activity: "Next Airing Episode",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: "\(nextEpisode.localizedEpisodeNumber)",
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            actions: buildActivityActions(for: nextEpisode.mediaModel(given: show)),
                                            identifier: "next-airing-episode-\(nextEpisode.identifiers.traktIdOrSlug)-\(firstAired.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }
            }

            if let movie = media.movie,
               let movieActivities = await fetchMovieReleases(for: movie) {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    return dateFormatter
                }()

                let localCountry =
                    Locale.current.language.region?.identifier ?? "us"
                for activity in movieActivities.filter({
                    $0.country.lowercased() == movie.country?.lowercased() ||
                        $0.country.lowercased() == localCountry.lowercased() }) {
                    var meta = [String]()
                    meta.append("\(Locale.current.localizedString(forRegionCode: activity.country) ?? activity.country)")
                    if let certification = activity.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "\(activity.releaseType.localizedCapitalized) Release",
                                            title: "\(dateFormatter.string(from: activity.releaseDate))",
                                            notes: activity.note ?? "",
                                            meta: meta.joined(separator: " · "),
                                            date: activity.releaseDate,
                                            systemImageName: "calendar",
                                            origin: .movieRelease,
                                            identifier: "movie-release-\(movie.identifiers.traktIdOrSlug)-\(activity.releaseType)-\(activity.country)-\(activity.releaseDate.timeIntervalSinceReferenceDate)")
                    activityItems.append(item)
                }
            }

            if let movie = media.movie {
                for activity in buildCalendarReleaseActivityItems(for: movie)
                    where !containsReleaseActivity(activityItems, matching: activity) {
                    activityItems.append(activity)
                }
            }

            if let lists = await fetchLists() {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for list in lists {
                    if let item = await fetchItem(in: list) {
                        let activityItem = ActivityItem(activity: "Listed",
                                                        title: "\(dateFormatter.string(from: item.listedAt))",
                                                        notes: item.notes ?? "",
                                                        meta: "Added to \(list.name)",
                                                        date: item.listedAt,
                                                        systemImageName: "plus",
                                                        actions: buildListActivityActions(for: list, item: item),
                                                        identifier: "listed-\(list.identifiers.traktIdOrSlug)-item-\(item.id)")
                        activityItems.append(activityItem)
                    }
                }
            }

            if let watchlistMediaItem = media.watchlistMediaItem,
               let watchlistedAt = watchlistMediaItem.listedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Watchlisted",
                                        title: "\(dateFormatter.string(from: watchlistedAt))",
                                        notes: watchlistMediaItem.notes ?? "",
                                        meta: "",
                                        date: watchlistedAt,
                                        systemImageName: "bookmark.fill",
                                        identifier: "watchlist-\(media.traktId)-\(watchlistedAt.timeIntervalSinceReferenceDate)")
                activityItems.append(item)
            }

            if let recommendedMediaItem = media.recommendedMediaItem {
                let recommendedAt = recommendedMediaItem.listedAt
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Favorited",
                                        title: "\(dateFormatter.string(from: recommendedAt))",
                                        notes: recommendedMediaItem.notes ?? "",
                                        meta: "",
                                        date: recommendedAt,
                                        systemImageName: "star.fill",
                                        actions: buildFavoriteActivityActions(for: recommendedMediaItem),
                                        identifier: "favorited-\(recommendedMediaItem.id)")
                activityItems.append(item)
            }

            if let collectedMediaItem = media.collectedMediaItem,
               let collectedAt = collectedMediaItem.collectedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Collected",
                                        title: "\(dateFormatter.string(from: collectedAt))",
                                        notes: collectedMediaItem.notes ?? "",
                                        meta: "",
                                        date: collectedAt,
                                        systemImageName: "book.circle",
                                        identifier: "collected-\(media.traktId)-\(collectedAt.timeIntervalSinceReferenceDate)")
                activityItems.append(item)
            }

            if let collectedMediaItem = media.collectedMediaItem,
               let collectedAt = collectedMediaItem.lastCollectedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Collected",
                                        title: "\(dateFormatter.string(from: collectedAt))",
                                        notes: collectedMediaItem.notes ?? "",
                                        meta: "",
                                        date: collectedAt,
                                        systemImageName: "book.circle",
                                        identifier: "collected-\(media.traktId)-\(collectedAt.timeIntervalSinceReferenceDate)")
                activityItems.append(item)
            }

            if let ratedMediaItems = media.ratedItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for ratedMediaItem in ratedMediaItems {
                    let media = MediaModel(item: ratedMediaItem)
                    let identifier = "rating-\(ratedMediaItem.type.rawValue)-\(media.traktId)-\(ratedMediaItem.rateDate.timeIntervalSinceReferenceDate)-\(ratedMediaItem.rating)"

                    switch media {
                    case .movie:
                        let item = ActivityItem(activity: "Rated Movie",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                ratedItem: ratedMediaItem,
                                                actions: buildRatedActivityActions(for: ratedMediaItem),
                                                identifier: identifier)
                        activityItems.append(item)
                    case .show:
                        let item = ActivityItem(activity: "Rated Show",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                ratedItem: ratedMediaItem,
                                                actions: buildRatedActivityActions(for: ratedMediaItem),
                                                identifier: identifier)
                        activityItems.append(item)
                    case .season(let season, _):
                        let item = ActivityItem(activity: "Rated \(season.localizedSeasonNumber)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                ratedItem: ratedMediaItem,
                                                actions: buildRatedActivityActions(for: ratedMediaItem),
                                                identifier: identifier)
                        activityItems.append(item)
                    case .episode(let episode, _):
                        let item = ActivityItem(activity: "Rated \(episode.localizedEpisodeNumber)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                ratedItem: ratedMediaItem,
                                                actions: buildRatedActivityActions(for: ratedMediaItem),
                                                identifier: identifier)
                        activityItems.append(item)
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                }
            }

            if let noteItems = media.noteItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for noteItem in noteItems {
                    var meta = [String]()
                    switch noteItem.noteAttachement.type {
                    case .movie:
                        meta.append("Movie Notes")
                    case .show:
                        meta.append("Show Notes")
                    case .season:
                        meta.append("Season Notes")
                    case .episode:
                        meta.append("Episode Notes")
                    default:
                        fatalError("This case shouldn't be handled here")
                    }
                    switch noteItem.note.privacy {
                    case .all:
                        meta.append("Public")
                    case .friends:
                        meta.append("Friends")
                    case .me:
                        meta.append("Private")
                    case .unknown:
                        break
                    }
                    if noteItem.note.spoiler {
                        meta.append("Spoiler Alert!")
                    }

                    let item = ActivityItem(activity: "Note Added",
                                            title: "\(dateFormatter.string(from: noteItem.note.createdAt))",
                                            notes: noteItem.note.notes,
                                            meta: meta.joined(separator: " · "),
                                            date: noteItem.note.createdAt,
                                            systemImageName: "note.text",
                                            actions: buildNoteActivityActions(for: noteItem),
                                            identifier: "note-\(noteItem.note.identifier)")

                    activityItems.append(item)
                }
            }

            for commentItem in media.ownCommentItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Commented",
                                        title: "\(dateFormatter.string(from: commentItem.comment.createDate))",
                                        notes: commentItem.comment.body,
                                        meta: "\(CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers).media.mediaTitle)",
                                        date: commentItem.comment.createDate,
                                        systemImageName: "pencil.circle.fill",
                                        actions: buildCommentActivityActions(for: commentItem),
                                        identifier: "comment-\(commentItem.comment.identifier)")

                activityItems.append(item)
            }

            if let activities = await fetchHistory()?.sorted(by: { $0.watchDate < $1.watchDate }) {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                var ordinalCount = 1
                let formatter = NumberFormatter()
                formatter.numberStyle = .ordinal
                for activity in activities {
                    var header = "Watched"
                    var systemImage = "checkmark"
                    if activity.action == .scrobble {
                        header = "Scrobbled"
                        systemImage = "play.fill"
                    } else if activity.action == .checkin {
                        header = "Checked in"
                        systemImage = "play.fill"
                    }

                    // if it's an episode from a season or a show VS the episode level or movie
                    if let episode = activity.episode, media.episode == nil {
                        let meta =
                            if let title = episode.title {
                                "\(episode.localizedEpisodeNumber) - \(title)"
                            } else { episode.localizedEpisodeNumber }
                        let item = ActivityItem(activity: header,
                                                title: "\(dateFormatter.string(from: activity.watchDate))",
                                                notes: activity.note ?? "",
                                                meta: meta,
                                                date: activity.watchDate,
                                                systemImageName: systemImage,
                                                historyItem: activity,
                                                actions: buildHistoryActivityActions(for: activity),
                                                identifier: "history-\(activity.identifier)")
                        activityItems.append(item)
                    } else {
                        let meta =
                            "\(formatter.string(from: ordinalCount as NSNumber) ?? "1st") watch"
                        let item = ActivityItem(activity: header,
                                                title: "\(dateFormatter.string(from: activity.watchDate))",
                                                notes: activity.note ?? "",
                                                meta: meta,
                                                date: activity.watchDate,
                                                systemImageName: systemImage,
                                                historyItem: activity,
                                                actions: buildHistoryActivityActions(for: activity),
                                                identifier: "history-\(activity.identifier)")
                        activityItems.append(item)
                    }
                    ordinalCount += 1
                }
            }

            let dateFormatter: DateFormatter = {
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter
            }()
            let today = ActivityItem(activity: "Today",
                                     title: dateFormatter.string(from: .now),
                                     notes: "",
                                     meta: "",
                                     date: .now,
                                     systemImageName: "calendar.badge.clock",
                                     identifier: "today")
            activityItems.append(today)

            let sortedActivityItems = activityItems.sorted { $0.date > $1.date }.removingDuplicates()
            snapshot.appendItems(sortedActivityItems.map { .activity($0) })

            if snapshot.itemIdentifiers(inSection: .content).count == 0 {
                snapshot.appendItems([.empty("😵",
                                             "No Pulse",
                                             "There are currently no activities to show",
                                             "Come back later to see something new... or don't.")])
            }

            dataSource.defaultRowAnimation = .fade
            snapshot.reconfigureItems(snapshot.itemIdentifiers)

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: true)
                self.navigationItem.subtitle = self.media.mediaTitle
                self.isRefreshing = false
            }
        }
    }

    private enum Section: Int {
        case content
        case empty
        case loading
    }

    private enum Wrapper: Hashable {
        case activity(ActivityItem)
        case empty(String, String, String, String)
        case loading

        static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
            switch (lhs, rhs) {
            case (.activity(let lhs), .activity(let rhs)):
                return lhs.identifier == rhs.identifier
            case (.empty, .empty):
                return true
            case (.loading, .loading):
                return true
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .activity(let activityItem):
                hasher.combine(0)
                hasher.combine(activityItem.identifier)
            case .empty:
                hasher.combine(1)
            case .loading:
                hasher.combine(2)
            }
        }
    }

    private class MediaActivitesDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .activity:
                return true
            default:
                return false
            }
        }
    }

    private lazy var dataSource = MediaActivitesDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .activity(let activityItem):
            let cell = tableView.dequeueReusableCell(withIdentifier: "activity") as! PulseTableViewCell
            self.configureActivityCell(cell, with: activityItem)
            return cell
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case .activity(let activity) = item else { return }
        activityAction(ofType: .open, in: activity.actions)?.handler()
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case .activity(let activity) = item else { return nil }
        guard let deleteAction = activityAction(ofType: .delete, in: activity.actions) else { return nil }

        let remove = UIContextualAction(style: .destructive,
                                        title: deleteAction.shortTitle ?? deleteAction.title) { _, _, completion in
            deleteAction.handler()
            completion(true)
        }
        remove.image = deleteAction.systemImageName.flatMap(UIImage.init(systemName:))

        let configuration = UISwipeActionsConfiguration(actions: [remove])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    private func fetchMovieReleases(for movie: Movie) async -> [MovieReleaseActivity]? {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.movieReleases(id: movie.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let movieActivities = try response.map([MovieReleaseActivity].self, using: TraktAPIProvider.decoder)

                        continuation.resume(returning: movieActivities)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private var fetchHistoryService: TraktAPIService? {
        switch media! {
        case .movie(let movie):
            return .history(type: .movies,
                            id: movie.identifiers.trakt!,
                            pageInfo: PageInfo.firstPage(with: 100),
                            endDate: nil)
        case .show(let show):
            return .history(type: .shows,
                            id: show.identifiers.trakt!,
                            pageInfo: PageInfo.firstPage(with: 100),
                            endDate: nil)
        case .episode(let episode, _):
            return .history(type: .episodes,
                            id: episode.identifiers.trakt!,
                            pageInfo: PageInfo.firstPage(with: 100),
                            endDate: nil)
        case .season(let season, _):
            return .history(type: .seasons,
                            id: season.identifiers.trakt!,
                            pageInfo: PageInfo.firstPage(with: 100),
                            endDate: nil)
        case .list:
            return nil
        case .showProgress:
            return nil
        }
    }

    private func fetchHistory() async -> [HistoryItem]? {
        guard let fetchHistoryService = fetchHistoryService else { return nil }
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(fetchHistoryService,
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let history = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: history)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchDetails(for show: Show) async -> Show {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.show(id: show.identifiers.traktIdOrSlug, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let fullShow = try response.map(Show.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: fullShow)
                    } catch {
                        continuation.resume(returning: show)
                    }
                case .failure:
                    continuation.resume(returning: show)
                }
            }
        }
    }

    private func fetchLastEpisode(for show: Show) async -> Episode? {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.lastEpisode(id: show.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: episode)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchNextEpisode(for show: Show) async -> Episode? {
        return await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.nextEpisode(id: show.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: episode)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchLists() async -> [List]? {
        let service: TraktAPIService = {
            switch self.media! {
            case .movie(let movie):
                return .movieListed(id: movie.identifiers.trakt!)
            case .show(let show):
                return .showListed(id: show.identifiers.trakt!)
            case .episode(let episode, let show):
                return .episodeListed(id: show.identifiers.trakt!,
                                      season: episode.season,
                                      episode: episode.number)
            case .season(let season, let show):
                return .seasonListed(id: show.identifiers.trakt!,
                                     season: season.number)
            case .list:
                fatalError("List not handled for fetching listed")
            case .showProgress:
                fatalError("showProgress not handled for fetching listed")
            }
        }()

        return await withCheckedContinuation { continuation in
            TraktAPIProvider.noChacheProvider.request(service,
                                                      callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: lists)
                    } catch {
                        print("Listed request JSON mapping failed! \(error)")
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    print("Listed request failure \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func fetchItem(in list: List) async -> WatchlistItem? {
        guard let media = media else { return nil }
        let listItemsType: ListMediaType? = {
            switch media {
            case .movie:
                return .movies
            case .show:
                return .shows
            case .episode:
                return .episodes
            case .season:
                return .seasons
            case .list:
                return nil
            case .showProgress:
                fatalError()
            }
        }()

        return await withCheckedContinuation { continuation in
            TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                               id: list.identifiers.trakt!,
                                               type: listItemsType) { result in
                switch result {
                case .success(let items):
                    continuation.resume(returning: items.first {
                        MediaModel(item: $0).traktId == media.traktId
                    })
                case .failure(let error):
                    print("Items request failure \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
