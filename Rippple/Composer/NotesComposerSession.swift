//
//  NotesComposerSession.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

let (onWatchlistTypeNotesChangedTransmitter, onWatchlistTypeNotesChangedReceiver) = Receiver<WatchlistType>.make(with: .hot)

enum WatchlistType {
    case listItem(note: String, userId: String, listId: Int64, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
    case watchlistItem(note: String, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
    case favoriteItem(note: String, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
}

private extension WatchlistType {
    var note: String {
        switch self {
        case .listItem(let note, _, _, _, _, _, _), .watchlistItem(let note, _, _, _, _), .favoriteItem(let note, _, _, _, _):
            return note
        }
    }

    var canEdit: Bool {
        switch self {
        case .listItem(_, _, _, _, let canEdit, _, _), .watchlistItem(_, _, let canEdit, _, _), .favoriteItem(_, _, let canEdit, _, _):
            return canEdit
        }
    }

    var user: User {
        switch self {
        case .listItem(_, _, _, _, _, let user, _), .watchlistItem(_, _, _, let user, _), .favoriteItem(_, _, _, let user, _):
            return user
        }
    }

    var listItem: WatchlistItem {
        switch self {
        case .listItem(_, _, _, _, _, _, let listItem), .watchlistItem(_, _, _, _, let listItem), .favoriteItem(_, _, _, _, let listItem):
            return listItem
        }
    }

    func service(note: String) -> TraktAPIService {
        switch self {
        case .listItem(_, let userId, let listId, let itemId, _, _, _):
            return .updateListItem(note: note, userId: userId, listId: listId, itemId: itemId)
        case .watchlistItem(_, let itemId, _, _, _):
            return .updateWatchlistItem(note: note, itemId: itemId)
        case .favoriteItem(_, let itemId, _, _, _):
            return .updateRecommendationItem(note: note, itemId: itemId)
        }
    }
}

final class NotesComposerSession: ComposerSession {
    enum Context {
        case media(MediaModel)
        case person(Person)
        case ratedItem(RatedItem)
        case historyItem(HistoryItem)
        case collection(MediaModel)
        case noteItem(NoteItem)
        case watchlist(WatchlistType)
    }

    private static let characterLimit = 500

    private let context: Context
    private let noteItem: NoteItem
    private let subject: ComposerSubject?

    static func makeViewController(context: Context, noteItem: NoteItem?) -> StyledNavigationController? {
        guard let session = NotesComposerSession(context: context, noteItem: noteItem) else { return nil }
        return ComposerViewController.makeNavigationController(session: session)
    }

    private init?(context: Context, noteItem: NoteItem?) {
        self.context = context
        if let noteItem = noteItem {
            self.noteItem = noteItem
        } else {
            guard let user = UserManager.shared.currentUser,
                  let noteItem = NotesComposerSession.newNoteItem(for: context, user: user) else { return nil }
            self.noteItem = noteItem
        }
        subject = NotesComposerSession.subject(for: context, noteItem: self.noteItem)
    }

    // MARK: - ComposerSession

    var configuration: ComposerConfiguration {
        let attachment = noteItem.noteAttachement.type
        var tools: ComposerTools = [.formatting, .preview]
        switch attachment {
        case .collection, .history, .rating:
            tools.formUnion([.privacy, .spoilerFlag])
        case .movie, .show, .season, .episode, .person:
            tools.insert(.privacy)
        case .unknown:
            break
        }

        var configuration = ComposerConfiguration(title: "Compose",
                                                  subtitle: NotesComposerSession.title(for: attachment),
                                                  placeholder: "Add your Notes",
                                                  subject: subject,
                                                  subjectDetail: nil,
                                                  tools: tools,
                                                  characterLimit: NotesComposerSession.characterLimit,
                                                  minimumWordCount: 0,
                                                  isReadOnly: false,
                                                  dismissTitle: nil,
                                                  isPrivacyLocked: [.movie, .show, .season, .episode, .person].contains(attachment))
        if case .watchlist(let watchlistType) = context, watchlistType.canEdit == false {
            configuration.title = "\(watchlistType.user.username)'s Notes"
            configuration.tools = []
            configuration.isReadOnly = true
            configuration.dismissTitle = "Okay"
        }
        return configuration
    }

    var initialDraft: ComposerDraft {
        let note = noteItem.note
        let privacy: NotePrivacy = note.privacy == .unknown ? .me : note.privacy
        return ComposerDraft(text: note.notes, gif: nil, containsSpoiler: note.spoiler, privacy: privacy)
    }

    func submitTitle(for draft: ComposerDraft) -> String {
        if isDeleting(draft) {
            return "Delete"
        }
        return noteItem.note.identifier == 0 ? "Save" : "Update"
    }

    func submitSymbol(for draft: ComposerDraft) -> String {
        isDeleting(draft) ? "trash" : "checkmark"
    }

    func canSubmit(_ draft: ComposerDraft) -> Bool {
        if draft.text.isEmpty, noteItem.note.identifier == 0 {
            if case .watchlist = context { return true }
            return false
        }
        return true
    }

    func cancelPolicy(for draft: ComposerDraft) -> ComposerCancelPolicy {
        guard draft != initialDraft else { return .dismiss }
        return .confirm(title: "Discard Changes?",
                        message: "Keep editing your notes or discard your changes.",
                        keepTitle: "Keep Editing",
                        loseTitle: "Discard")
    }

    func submit(_ draft: ComposerDraft,
                from composer: ComposerViewController,
                anchor: UIBarButtonItem,
                completion: @escaping (ComposerSubmitOutcome) -> Void) {
        guard let service = service(for: draft) else {
            SwiftMessages.show(message: "😓 Notes can’t be saved on this item")
            completion(.keptOpen)
            return
        }
        composer.setSubmitting(true)
        let isDeleting = service.method == .delete
        let watchlistType: WatchlistType? = {
            guard case .watchlist(let watchlistType) = context else { return nil }
            return watchlistType
        }()
        SwiftMessages.show(message: "\(isDeleting ? "Deleting" : "Saving") Notes...", style: .loading)

        TraktAPIProvider.provider.request(service,
                                          callbackQueue: .global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    if let watchlistType = watchlistType {
                        onWatchlistTypeNotesChangedTransmitter.broadcast(watchlistType)
                    } else {
                        NotesManager.shared.refresh()
                    }
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "📝 Notes \(isDeleting ? "deleted" : "saved")")
                        completion(.completed)
                    }
                } catch {
                    NotesComposerSession.fail(error, completion: completion)
                }
            case .failure(let error):
                NotesComposerSession.fail(error, completion: completion)
            }
        }
    }

    // MARK: - Private

    private static func fail(_ error: Error, completion: @escaping (ComposerSubmitOutcome) -> Void) {
        NotesManager.shared.refresh()
        DispatchQueue.main.async {
            SwiftMessages.show(message: "😓 Error saving notes", style: .error(error))
            completion(.failed)
        }
    }

    private func isDeleting(_ draft: ComposerDraft) -> Bool {
        guard draft.text.isEmpty else { return false }
        if noteItem.note.identifier != 0 {
            return true
        }
        if case .watchlist(let watchlistType) = context {
            return watchlistType.note.isEmpty == false
        }
        return false
    }

    private func service(for draft: ComposerDraft) -> TraktAPIService? {
        if case .watchlist(let watchlistType) = context {
            return watchlistType.service(note: draft.text)
        }
        let note = noteItem.note
        guard note.identifier == 0 else {
            if draft.text.isEmpty {
                return .deleteNotes(id: note.identifier)
            }
            return .updateNotes(id: note.identifier, notes: draft.text, spoilers: draft.containsSpoiler, privacy: draft.privacy)
        }
        let target: (NoteType?, Int64?)
        switch context {
        case .media(let media):
            target = (NoteType(rawValue: noteItem.noteAttachement.type.rawValue), media.composerTraktId)
        case .person(let person):
            target = (.person, person.ids.trakt)
        case .ratedItem(let ratedItem):
            target = (NoteType(rawValue: "\(ratedItem.type.rawValue)Rating"), MediaModel(item: ratedItem).composerTraktId)
        case .historyItem(let historyItem):
            target = (.history, historyItem.identifier)
        case .collection(let media):
            switch media {
            case .movie:
                target = (.movieCollection, media.composerTraktId)
            case .show:
                target = (.showCollection, media.composerTraktId)
            default:
                return nil
            }
        case .noteItem, .watchlist:
            return nil
        }
        guard let type = target.0, let traktId = target.1 else { return nil }
        return .addNotes(type: type, traktId: traktId, notes: draft.text, spoilers: draft.containsSpoiler, privacy: draft.privacy)
    }

    private static func title(for attachment: NoteAttachementType) -> String {
        switch attachment {
        case .movie: return "Movie Notes"
        case .show: return "Show Notes"
        case .season: return "Season Notes"
        case .episode: return "Episode Notes"
        case .person: return "People Notes"
        case .history: return "History Notes"
        case .collection: return "Library Notes"
        case .rating: return "Rating Notes"
        case .unknown: return "Notes"
        }
    }

    private static func subject(for context: Context, noteItem: NoteItem) -> ComposerSubject? {
        switch context {
        case .media(let media):
            return .media(media)
        case .person(let person):
            return .person(person)
        case .ratedItem(let ratedItem):
            return .media(MediaModel(item: ratedItem))
        case .historyItem(let historyItem):
            return MediaModel(item: historyItem).map { .media($0) }
        case .collection(let media):
            return .media(media)
        case .watchlist(let watchlistType):
            return .media(MediaModel(item: watchlistType.listItem))
        case .noteItem:
            if let person = noteItem.person, noteItem.noteAttachement.type == .person {
                return .person(person)
            }
            return MediaModel(item: noteItem).map { .media($0) }
        }
    }

    // MARK: - New notes

    private static func newNoteItem(for context: Context, user: User) -> NoteItem? {
        let emptyNote: (String) -> Note = { text in
            Note(identifier: 0, notes: text, privacy: .me, spoiler: false, createdAt: .now, updatedAt: .now, user: user)
        }
        switch context {
        case .person(let person):
            guard let traktId = person.ids.trakt else { return nil }
            return NoteItem(noteAttachement: NoteAttachement(type: .person, identifier: traktId),
                            type: .unknown, movie: nil, show: nil, episode: nil, season: nil, person: person,
                            note: emptyNote(""))
        case .media(let media):
            guard let attachment = attachmentType(for: media) else { return nil }
            return noteItem(for: media, attachment: NoteAttachement(type: attachment, identifier: nil), note: emptyNote(""))
        case .ratedItem(let ratedItem):
            let media = MediaModel(item: ratedItem)
            guard let traktId = media.composerTraktId else { return nil }
            return noteItem(for: media, attachment: NoteAttachement(type: .rating, identifier: traktId), note: emptyNote(""))
        case .collection(let media):
            guard media.movie != nil || media.showShow != nil, let traktId = media.composerTraktId else { return nil }
            return noteItem(for: media, attachment: NoteAttachement(type: .collection, identifier: traktId), note: emptyNote(""))
        case .historyItem(let historyItem):
            guard let media = MediaModel(item: historyItem), let traktId = media.composerTraktId else { return nil }
            return noteItem(for: media, attachment: NoteAttachement(type: .history, identifier: traktId), note: emptyNote(""))
        case .watchlist(let watchlistType):
            return NoteItem(noteAttachement: NoteAttachement(type: .unknown, identifier: nil),
                            type: .unknown, movie: nil, show: nil, episode: nil, season: nil, person: nil,
                            note: emptyNote(watchlistType.note))
        case .noteItem(let noteItem):
            return noteItem
        }
    }

    private static func attachmentType(for media: MediaModel) -> NoteAttachementType? {
        switch media {
        case .movie: return .movie
        case .show: return .show
        case .season: return .season
        case .episode: return .episode
        case .list, .showProgress: return nil
        }
    }

    private static func noteItem(for media: MediaModel, attachment: NoteAttachement, note: Note) -> NoteItem? {
        switch media {
        case .movie(let movie):
            return NoteItem(noteAttachement: attachment, type: .movie, movie: movie, show: nil, episode: nil, season: nil, person: nil, note: note)
        case .show(let show):
            return NoteItem(noteAttachement: attachment, type: .show, movie: nil, show: show, episode: nil, season: nil, person: nil, note: note)
        case .episode(let episode, let show):
            return NoteItem(noteAttachement: attachment, type: .episode, movie: nil, show: show, episode: episode, season: nil, person: nil, note: note)
        case .season(let season, let show):
            return NoteItem(noteAttachement: attachment, type: .season, movie: nil, show: show, episode: nil, season: season, person: nil, note: note)
        case .list, .showProgress:
            return nil
        }
    }
}
