//
//  NotesComposerViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 24/09/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Receiver
import UIKit

let (onWatchlistTypeNotesChangedTransmitter, onWatchlistTypeNotesChangedReceiver) = Receiver<WatchlistType>.make(with: .hot)

enum WatchlistType {
    case listItem(note: String, userId: String, listId: Int64, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
    case watchlistItem(note: String, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
    case favoriteItem(note: String, itemId: Int64, canEdit: Bool, user: User, listItem: WatchlistItem)
}

final class NotesComposerViewController: UIViewController {
    var media: MediaModel?
    var ratedItem: RatedItem?
    var historyItem: HistoryItem?
    var collectionItem: CollectionItem?
    var noteItem: NoteItem?
    var person: Person?

    var watchlistType: WatchlistType?

    @IBOutlet var textView: UITextView!
    @IBOutlet var placeholderTextView: UITextView!
    @IBOutlet var previewTextView: UITextView!

    @IBOutlet var charCountLabel: UILabel!

    @IBOutlet var privacyButton: UIButton!
    @IBOutlet var spoilerButton: UIButton!
    @IBOutlet var previewButton: UIButton!

    @IBOutlet var toolbar: UIToolbar!
    @IBOutlet var inputAccessoryBackgroundView: UIView!
    @IBOutlet var commentInputAccessoryView: UIView!

    @IBOutlet var sendButton: UIBarButtonItem!
    @IBOutlet var cancelButton: UIBarButtonItem!

    @IBOutlet var metaLabel: UILabel!

    // internal
    private var notesPrivacy: NotePrivacy = .me
    private var notesContainsSpoilers: Bool = false

    override func viewDidLoad() {
        isModalInPresentation = true

        privacyButton.maximumContentSizeCategory = .large
        spoilerButton.maximumContentSizeCategory = .large
        previewButton.maximumContentSizeCategory = .large

        previewTextView.isEditable = false
        previewTextView.clipsToBounds = false
        placeholderTextView.isEditable = false

        if noteItem != nil {
            // do nothing, it's a note update
        } else if noteItem == nil, let person = person {
            // it's a new private note on a Person
            noteItem = NoteItem(noteAttachement: NoteAttachement(type: .person, identifier: person.ids.trakt!),
                                type: .unknown,
                                movie: nil,
                                show: nil,
                                episode: nil,
                                season: nil,
                                person: person,
                                note: Note(identifier: 0,
                                           notes: "",
                                           privacy: .me,
                                           spoiler: false,
                                           createdAt: .now,
                                           updatedAt: .now,
                                           user: UserManager.shared.currentUser!))
        } else if noteItem == nil, let media = media {
            // it's a new private note on a media item
            switch media {
            case .movie(let movie):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .movie, identifier: nil),
                                    type: .movie,
                                    movie: movie,
                                    show: nil,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .show(let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .show, identifier: nil),
                                    type: .show,
                                    movie: nil,
                                    show: show,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .episode(let episode, let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .episode, identifier: nil),
                                    type: .episode,
                                    movie: nil,
                                    show: show,
                                    episode: episode,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .season(let season, let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .season, identifier: nil),
                                    type: .season,
                                    movie: nil,
                                    show: show,
                                    episode: nil,
                                    season: season,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        } else if noteItem == nil, let ratedItem = ratedItem {
            // it's a new rating notes
            let media = MediaModel(item: ratedItem)
            switch media {
            case .movie(let movie):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .rating,
                                                                     identifier: movie.identifiers.trakt!),
                                    type: .movie,
                                    movie: movie,
                                    show: nil,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .show(let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .rating,
                                                                     identifier: show.identifiers.trakt!),
                                    type: .show,
                                    movie: nil,
                                    show: show,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .episode(let episode, let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .rating,
                                                                     identifier: episode.identifiers.trakt!),
                                    type: .episode,
                                    movie: nil,
                                    show: show,
                                    episode: episode,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .season(let season, let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .rating,
                                                                     identifier: season.identifiers.trakt!),
                                    type: .season,
                                    movie: nil,
                                    show: show,
                                    episode: nil,
                                    season: season,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        } else if noteItem == nil, let collectionItem = collectionItem {
            // it's a new ceollection notes
            let media = MediaModel(item: collectionItem)
            switch media {
            case .movie(let movie):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .collection,
                                                                     identifier: movie.identifiers.trakt!),
                                    type: .movie,
                                    movie: movie,
                                    show: nil,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .show(let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .collection,
                                                                     identifier: show.identifiers.trakt!),
                                    type: .show,
                                    movie: nil,
                                    show: show,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .episode:
                fatalError()
            case .season:
                fatalError()
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        } else if noteItem == nil, let historyItem = historyItem {
            // it's a new rating notes
            let media = MediaModel(item: historyItem)!
            switch media {
            case .movie(let movie):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .history,
                                                                     identifier: movie.identifiers.trakt!),
                                    type: .movie,
                                    movie: movie,
                                    show: nil,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .show:
                fatalError()
            case .episode(let episode, let show):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .history,
                                                                     identifier: episode.identifiers.trakt!),
                                    type: .episode,
                                    movie: nil,
                                    show: show,
                                    episode: episode,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: "",
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
            case .season:
                fatalError()
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        } else if let watchlistType = watchlistType {
            switch watchlistType {
            case .listItem(let note, _, _, _, let canEdit, let user, let listItem), .watchlistItem(let note, _, let canEdit, let user, let listItem), .favoriteItem(let note, _, let canEdit, let user, let listItem):
                noteItem = NoteItem(noteAttachement: NoteAttachement(type: .unknown,
                                                                     identifier: nil),
                                    type: .unknown,
                                    movie: nil,
                                    show: nil,
                                    episode: nil,
                                    season: nil,
                                    person: nil,
                                    note: Note(identifier: 0,
                                               notes: note,
                                               privacy: .me,
                                               spoiler: false,
                                               createdAt: .now,
                                               updatedAt: .now,
                                               user: UserManager.shared.currentUser!))
                metaLabel.text = MediaModel(item: listItem).mediaTitle
                if canEdit == false {
                    title = "\(user.username)'s Notes"
                    cancelButton.title = "Okay"
                    isModalInPresentation = false

                    sendButton.isHidden = true
                    textView.isHidden = true
                    placeholderTextView.isHidden = true
                    commentInputAccessoryView.isHidden = true
                    previewButton.isHidden = true

                    textView.text = noteItem!.note.notes // set the note anyway to be able to have the markdown version
                    previewTextView.attributedText = attributedString()
                    previewTextView.isHidden = false

                    textView.isEditable = false

                    previewTextView.scrollIndicatorInsets = UIEdgeInsets(top: -16.0,
                                                                         left: 0.0,
                                                                         bottom: 0.0,
                                                                         right: -16.0)

                    previewTextView.clipsToBounds = false
                    return
                }
            }
        }

        let mediaForTitle: MediaModel? = if let media = media {
            media
        } else if let media = MediaModel(item: noteItem!) {
            media
        } else if let watchlistType = watchlistType {
            switch watchlistType {
            case .listItem(_, _, _, _, _, _, let listItem), .watchlistItem(_, _, _, _, let listItem), .favoriteItem(_, _, _, _, let listItem):
                MediaModel(item: listItem)
            }
        } else {
            nil
        }
        switch noteItem!.noteAttachement.type {
        case .movie:
            title = "Movie Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .show:
            title = "Show Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .season:
            title = "Season Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .episode:
            title = "Episode Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .person:
            title = "People Notes"
            metaLabel.text = noteItem!.person!.name
        case .history:
            title = "History Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .collection:
            title = "Library Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .rating:
            title = "Rating Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        case .unknown:
            title = "Notes"
            metaLabel.text = mediaForTitle?.mediaTitle
        }

        notesPrivacy = noteItem?.note.privacy ?? .me
        notesContainsSpoilers = noteItem?.note.spoiler ?? false

        previewTextView.isHidden = true

        textView.text = noteItem!.note.notes

        textView.scrollIndicatorInsets = UIEdgeInsets(top: -16.0,
                                                      left: 0.0,
                                                      bottom: 0.0,
                                                      right: -16.0)

        textView.clipsToBounds = false
        textView.inputAccessoryView = commentInputAccessoryView

        updateUIBasedOnWordCount()
        configureKeyboardNotifications()
        updateQuickActions()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        toolbar.tintColor = view.traitCollection.ripppleTintColor.color
        previewButton.tintColor = view.traitCollection.ripppleTintColor.color
        spoilerButton.tintColor = view.traitCollection.ripppleTintColor.color
        privacyButton.tintColor = view.traitCollection.ripppleTintColor.color

        textView.becomeFirstResponder()
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true)
    }

    private var service: TraktAPIService? {
        if let watchlistType = watchlistType {
            switch watchlistType {
            case .listItem(_, let userId, let listId, let itemId, _, _, _):
                return .updateListItem(note: textView.text,
                                       userId: userId,
                                       listId: listId,
                                       itemId: itemId)
            case .watchlistItem(_, let itemId, _, _, _):
                return .updateWatchlistItem(note: textView.text,
                                            itemId: itemId)
            case .favoriteItem(_, let itemId, _, _, _):
                return .updateRecommendationItem(note: textView.text,
                                                 itemId: itemId)
            }
        }
        guard let noteItem = noteItem else {
            return nil
        }
        if noteItem.note.identifier == 0, let media = media {
            // it's a new media notes
            return .addNotes(type: NoteType(rawValue: noteItem.noteAttachement.type.rawValue)!,
                             traktId: media.traktId,
                             notes: textView.text,
                             spoilers: notesContainsSpoilers,
                             privacy: notesPrivacy)
        } else if noteItem.note.identifier == 0, let person = person {
            // it's a person note
            return .addNotes(type: .person,
                             traktId: person.ids.trakt!,
                             notes: textView.text,
                             spoilers: notesContainsSpoilers,
                             privacy: notesPrivacy)
        } else if noteItem.note.identifier == 0, let ratedItem = ratedItem {
            // it's a rated item
            let media = MediaModel(item: ratedItem)
            return .addNotes(type: NoteType(rawValue: "\(ratedItem.type.rawValue)Rating")!,
                             traktId: media.traktId,
                             notes: textView.text,
                             spoilers: notesContainsSpoilers,
                             privacy: notesPrivacy)
        } else if noteItem.note.identifier == 0, let historyItem = historyItem {
            // it's an history item
            return .addNotes(type: .history,
                             traktId: historyItem.identifier,
                             notes: textView.text,
                             spoilers: notesContainsSpoilers,
                             privacy: notesPrivacy)
        } else if noteItem.note.identifier == 0, let collectionItem = collectionItem {
            // it's a collection item
            let media = MediaModel(item: collectionItem)
            return .addNotes(type: NoteType(rawValue: "\(collectionItem.type.rawValue)Collection")!,
                             traktId: media.traktId,
                             notes: textView.text,
                             spoilers: notesContainsSpoilers,
                             privacy: notesPrivacy)
        } else if textView.text.isEmpty {
            // delete of an existing note
            return .deleteNotes(id: noteItem.note.identifier)
        } else {
            // update of an existing note
            return .updateNotes(id: noteItem.note.identifier,
                                notes: textView.text,
                                spoilers: notesContainsSpoilers,
                                privacy: notesPrivacy)
        }
    }

    @IBAction func save(_ sender: Any) {
        textView.resignFirstResponder()

        guard let service = service else { return }
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false
        showLoader()

        SwiftMessages.show(message: "\(service.method == .delete ? "Deleting" : "Saving") Notes...", style: .loading)

        TraktAPIProvider.provider.request(service,
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else {
                window.isUserInteractionEnabled = true
                return
            }
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    if case .updateRecommendationItem = service {
                        onWatchlistTypeNotesChangedTransmitter.broadcast(watchlistType!)
                    } else if case .updateListItem = service {
                        if case .listItem(_, _, let listId, _, _, _, _) = watchlistType! {
                            ListItemsMarkerManager.shared.invalidate(listId: listId)
                        }
                        onWatchlistTypeNotesChangedTransmitter.broadcast(watchlistType!)
                    } else if case .updateWatchlistItem = service {
                        onWatchlistTypeNotesChangedTransmitter.broadcast(watchlistType!)
                    } else {
                        NotesManager.shared.refresh()
                    }
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "📝 Notes \(service.method == .delete ? "deleted" : "saved")")
                        self.dismiss(animated: true)
                        window.isUserInteractionEnabled = true
                    }
                } catch {
                    NotesManager.shared.refresh()
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error saving notes", style: .error(error))
                        window.isUserInteractionEnabled = true
                        self.navigationItem.rightBarButtonItem = self.sendButton
                    }
                }
            case .failure(let error):
                print("Notes saving failed! \(error)")
                NotesManager.shared.refresh()
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error saving notes", style: .error(error))
                    window.isUserInteractionEnabled = true
                    self.navigationItem.rightBarButtonItem = self.sendButton
                }
            }
        }
    }

    private func showLoader() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        let activityItem = UIBarButtonItem(customView: activityIndicator)
        navigationItem.rightBarButtonItem = activityItem
    }

    private func updateUIBasedOnWordCount() {
        if noteItem!.note.identifier == 0 {
            if textView.text.isEmpty, let watchlistType = watchlistType {
                switch watchlistType {
                case .favoriteItem(let note, _, _, _, _), .watchlistItem(let note, _, _, _, _), .listItem(let note, _, _, _, _, _, _):
                    if note == "" {
                        sendButton.title = "Save"
                    } else {
                        sendButton.title = "Delete"
                    }
                }
            } else {
                sendButton.title = "Save"
            }
        } else if textView.text.isEmpty {
            sendButton.title = "Delete"
        } else {
            sendButton.title = "Update"
        }

        placeholderTextView.isHidden = !textView.text.isEmpty

        charCountLabel.text = "\(500 - textView.text.count)"

        if textView.text.count > 500 {
            sendButton.isEnabled = false
            charCountLabel.textColor = .systemRed
        } else if textView.text.count == 0 {
            charCountLabel.textColor = .secondaryLabel
            if noteItem!.note.identifier == 0 {
                if textView.text.isEmpty, watchlistType == nil {
                    sendButton.isEnabled = false
                } else {
                    sendButton.isEnabled = true
                }
            } else {
                sendButton.isEnabled = true
            }
        } else {
            sendButton.isEnabled = true
            charCountLabel.textColor = .secondaryLabel
        }

        previewButton.isEnabled = textView.hasText
    }

    private func configureKeyboardNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameDidChange(notification:)),
                                               name: UIResponder.keyboardDidChangeFrameNotification,
                                               object: nil)
    }

    private func updateQuickActions() {
        privacyButton.tintColor = UIColor(resource: .globalTint)
        privacyButton.configuration?.buttonSize = .medium
        switch notesPrivacy {
        case .all:
            privacyButton.configuration?.title = "Public"
            privacyButton.configuration?.image = UIImage(systemName: "globe",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        case .me:
            privacyButton.configuration?.title = "Private"
            privacyButton.configuration?.image = UIImage(systemName: "lock",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        case .friends:
            privacyButton.configuration?.title = "Friends"
            privacyButton.configuration?.image = UIImage(systemName: "lock.open",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        case .unknown:
            privacyButton.configuration?.title = "Private"
            privacyButton.configuration?.image = UIImage(systemName: "lock",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        }
        privacyButton.showsMenuAsPrimaryAction = true

        let privacyPublic = UIAction(title: "Public",
                                     image: UIImage(systemName: "globe"),
                                     handler: { [weak self] _ in
                                         guard let self = self else { return }
                                         notesPrivacy = .all
                                         updateQuickActions()
                                     })
        let privacyFriends = UIAction(title: "Friends",
                                      image: UIImage(systemName: "lock.open"),
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          notesPrivacy = .friends
                                          updateQuickActions()
                                      })
        let privacyPrivate = UIAction(title: "Private",
                                      image: UIImage(systemName: "lock"),
                                      handler: { [weak self] _ in
                                          guard let self = self else { return }
                                          notesPrivacy = .me
                                          updateQuickActions()
                                      })

        if noteItem?.noteAttachement.type == .collection || noteItem?.noteAttachement.type == .history || noteItem?.noteAttachement.type == .rating {
            privacyButton.menu = UIMenu(title: "Choose who can see your Note:",
                                        children: [privacyPrivate, privacyFriends, privacyPublic])
            privacyButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                self.privacyButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
            }, for: .menuActionTriggered)
        } else if noteItem?.noteAttachement.type == .unknown {
            privacyButton.isHidden = true
        } else {
            // it's a private notre, show it's private but without the action possible
            privacyButton.isEnabled = false
        }

        spoilerButton.tintColor = UIColor(resource: .globalTint)
        spoilerButton.configuration?.buttonSize = .medium
        spoilerButton.configuration?.title = "Spoiler?"
        if notesContainsSpoilers {
            spoilerButton.configuration?.image = UIImage(systemName: "exclamationmark.bubble",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        } else {
            spoilerButton.configuration?.image = UIImage(systemName: "text.bubble",
                                                         withConfiguration: UIImage.SymbolConfiguration(scale: .small))
        }
        spoilerButton.showsMenuAsPrimaryAction = true

        let spoilerYes = UIAction(title: "Spoiler Alert",
                                  image: UIImage(systemName: "exclamationmark.bubble"),
                                  handler: { [weak self] _ in
                                      guard let self = self else { return }
                                      notesContainsSpoilers = true
                                      updateQuickActions()
                                  })
        let spoilerNo = UIAction(title: "No Spoiler",
                                 image: UIImage(systemName: "text.bubble"),
                                 handler: { [weak self] _ in
                                     guard let self = self else { return }
                                     notesContainsSpoilers = false
                                     updateQuickActions()
                                 })

        if noteItem?.noteAttachement.type == .collection || noteItem?.noteAttachement.type == .history || noteItem?.noteAttachement.type == .rating {
            spoilerButton.menu = UIMenu(title: "Mark your Notes with a Spoiler Alert:",
                                        children: [spoilerYes, spoilerNo])
            spoilerButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                UISelectionFeedbackGenerator().selectionChanged()
                self.spoilerButton.imageView?.addSymbolEffect(.bounce.down.byLayer, options: .speed(1.3))
            }, for: .menuActionTriggered)
        } else {
            spoilerButton.isHidden = true
        }

        previewButton.tintColor = UIColor(resource: .globalTint)
        previewButton.configuration?.buttonSize = .medium
        previewButton.configuration?.image = UIImage(systemName: "eyes", withConfiguration: UIImage.SymbolConfiguration(scale: .small))

        previewButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.previewTextView.attributedText = self.attributedString()
            self.previewTextView.contentOffset = self.textView.contentOffset
            self.previewTextView.isHidden = false
            self.textView.isHidden = true
            self.title = "Preview"
            self.sendButton.isEnabled = false
            self.navigationItem.leftBarButtonItem?.isEnabled = false
        }, for: .touchDown)
        previewButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.previewTextView.isHidden = true
            self.textView.isHidden = false
            self.title = "Notes"
            self.updateUIBasedOnWordCount()
            self.navigationItem.leftBarButtonItem?.isEnabled = true
        }, for: [.touchUpInside, .touchCancel, .touchDragExit, .touchDragOutside])
    }

    private var markdownParser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .body),
                                                       automaticLinkDetectionEnabled: true)

    private func attributedString() -> NSAttributedString? {
        markdownParser.color = .label
        markdownParser.strike.strikeColor = .label
        markdownParser.strike.color = .label
        markdownParser.highlight.color = .label
        markdownParser.highlight.highlightColor = UIColor(asset: .globalTint).withAlphaComponent(0.4)
        markdownParser.spoiler.color = .label
        markdownParser.allSpoiler.color = .label
        markdownParser.displaySpoiler.color = .label
        markdownParser.mention.color = .label

        markdownParser.spoilerStrategy = .showAllSpoilers

        return markdownParser.parse(textView.text.htmlDecoded.emojiUnescapedString)
    }
}

extension NotesComposerViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateUIBasedOnWordCount()
    }
}

@objc extension NotesComposerViewController {
    private func keyboardFrameDidChange(notification: NSNotification) {
        if let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = frameValue.cgRectValue.size.height - view.safeAreaInsets.bottom
            textView.contentInset = UIEdgeInsets(top: 0.0,
                                                 left: 0.0,
                                                 bottom: keyboardHeight,
                                                 right: 0.0)
            textView.scrollIndicatorInsets = UIEdgeInsets(top: -16.0,
                                                          left: 0.0,
                                                          bottom: keyboardHeight,
                                                          right: -16.0)
        }
    }
}

extension NotesComposerViewController {
    private func insertMarkdown(prefix: String, sufix: String) {
        if let selectedRange = textView.selectedTextRange {
            if let selectedText = textView.text(in: selectedRange) {
                textView.insertText(prefix + selectedText + sufix)
            } else {
                textView.insertText(prefix + sufix)
            }
            if let from = textView.position(from: selectedRange.start, offset: prefix.count),
               let to = textView.position(from: selectedRange.end, offset: prefix.count) {
                textView.selectedTextRange = textView.textRange(from: from, to: to)
            }
        }
    }

    @IBAction func spoiler(_ sender: Any?) {
        insertMarkdown(prefix: "[spoiler]", sufix: "[/spoiler]")
    }

    @IBAction func highlight(_ sender: Any?) {
        insertMarkdown(prefix: "==", sufix: "==")
    }

    @IBAction func strike(_ sender: Any?) {
        insertMarkdown(prefix: "~~", sufix: "~~")
    }

    @IBAction func italic(_ sender: Any?) {
        insertMarkdown(prefix: "_", sufix: "_")
    }

    @IBAction func bold(_ sender: Any?) {
        insertMarkdown(prefix: "**", sufix: "**")
    }
}
