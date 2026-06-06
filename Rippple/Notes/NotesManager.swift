//
//  NotesManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/09/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation
import Receiver
import UIKit

let (onNotesChangedTransmitter, onNotesChangedReceiver) = Receiver<[NoteItem]>.make(with: .warm(upTo: 1))

final class NotesManager {
    private let disposeBag = DisposeBag()

    private var debouncedRefresh: Debouncer!

    private init() {}

    private var refreshing = false

    fileprivate var notes = [NoteItem]() {
        didSet {
            onNotesChangedTransmitter.broadcast(notes)
            UserDefaults.standard.set(try? PropertyListEncoder().encode(notes), forKey: "NotesManager.notes")
            UserDefaults.standard.synchronize()
        }
    }

    static let shared = NotesManager()

    func setup() {
        if let data = UserDefaults.standard.data(forKey: "NotesManager.notes"), let array = try? PropertyListDecoder().decode([NoteItem].self, from: data) {
            notes = array
        }

        debouncedRefresh = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }

            if self.refreshing == true { return }
            self.refreshing = true
            self.refreshNotes()
        }

        applicationLifecycleReceiver.listen { applicationLifecycle in
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 3600 {
                    self.debouncedRefresh.call()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefresh.call()
        }.disposed(by: disposeBag)

        debouncedRefresh.call()
    }

    func showNotes(for media: MediaModel) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.media = media
        notesViewController.noteItem = media.noteItem
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for ratedItem: RatedItem) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.ratedItem = ratedItem
        notesViewController.noteItem = ratedItem.noteItem
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for historyItem: HistoryItem) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.historyItem = historyItem
        notesViewController.noteItem = historyItem.noteItem
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for collectionItem: CollectionItem) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.collectionItem = collectionItem
        notesViewController.noteItem = collectionItem.noteItem
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for noteItem: NoteItem) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.noteItem = noteItem
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for watchlistType: WatchlistType) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.watchlistType = watchlistType
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func showNotes(for person: Person) {
        let notesRootViewController = UIStoryboard(name: "Notes", bundle: nil).instantiateInitialViewController() as! UINavigationController
        let notesViewController = notesRootViewController.topViewController as! NotesComposerViewController
        notesViewController.person = person
        AppManager.shared.present(viewController: notesRootViewController, animated: true)
    }

    func refresh() {
        debouncedRefresh.call()
    }
}

private extension NotesManager {
    private func refreshNotes(pageInfo: PageInfo = PageInfo.firstPage(with: 50), notes: [NoteItem] = [NoteItem]()) {
        if SessionManager.shared.isLoggedOut {
            refreshing = false
            return
        }
        TraktAPIProvider.provider.request(.notes(userId: UserManager.shared.currentUser?.slug ?? "me",
                                                 noteType: .all,
                                                 extended: nil,
                                                 pageInfo: pageInfo),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let items = try response.map([NoteItem].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                       let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                        DispatchQueue.main.async {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.refreshNotes(pageInfo: pageInfo, notes: notes + items)
                            } else {
                                self.notes = notes + items
                                self.refreshing = false
                            }
                        }
                    } else {
                        self.refreshing = false
                    }
                } catch {
                    print("Notes request JSON mapping failed! \(error)")
                    self.refreshing = false
                }
            case .failure(let error):
                print("Notes request failure \(error)")
                self.refreshing = false
            }
        }
    }
}

extension MediaModel {
    var noteItem: NoteItem? {
        switch self {
        case .movie(let movie):
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .movie && $0.noteAttachement.type == .movie && $0.movie == movie }) {
                return noteItem
            }
            return nil
        case .episode(let episode, let show):
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .episode && $0.noteAttachement.type == .episode && $0.episode == episode && $0.show == show }) {
                return noteItem
            }
            return nil
        case .show(let show):
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .show && $0.noteAttachement.type == .show && $0.show == show }) {
                return noteItem
            }
            return nil
        case .season(let season, let show):
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .season && $0.noteAttachement.type == .season && $0.season == season && $0.show == show }) {
                return noteItem
            }
            return nil
        case .list:
            return nil
        case .showProgress:
            return nil
        }
    }

    var noteItems: [NoteItem]? {
        switch self {
        case .movie(let movie):
            return NotesManager.shared.notes.filter { $0.movie == movie && $0.noteAttachement.type == .movie }
        case .episode(let episode, let show):
            return NotesManager.shared.notes.filter { $0.episode == episode && $0.show == show && $0.noteAttachement.type == .episode }
        case .show(let show):
            return NotesManager.shared.notes.filter { $0.show == show && ($0.noteAttachement.type == .show || $0.noteAttachement.type == .episode || $0.noteAttachement.type == .season) }
        case .season(let season, let show):
            return NotesManager.shared.notes.filter { $0.season == season && $0.show == show && ($0.noteAttachement.type == .episode || $0.noteAttachement.type == .season) }
        case .list:
            return nil
        case .showProgress:
            return nil
        }
    }
}

extension Person {
    var noteItem: NoteItem? {
        let personIdentifier = ids.trakt
        if let noteItem = NotesManager.shared.notes.first(where: { $0.person?.ids.trakt == personIdentifier && $0.noteAttachement.type == .person }) {
            return noteItem
        }
        return nil
    }
}

extension RatedItem {
    var noteItem: NoteItem? {
        switch type {
        case .movie:
            let movieIdentifier = movie!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .movie && $0.noteAttachement.type == .rating && $0.movie!.identifiers.trakt! == movieIdentifier }) {
                return noteItem
            }
            return nil
        case .episode:
            let episodeIdentifier = episode!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .episode && $0.noteAttachement.type == .rating && $0.episode!.identifiers.trakt! == episodeIdentifier }) {
                return noteItem
            }
            return nil
        case .show:
            let showIdentifier = show!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .show && $0.noteAttachement.type == .rating && $0.show!.identifiers.trakt! == showIdentifier }) {
                return noteItem
            }
            return nil
        case .season:
            let seasonIdentifier = season!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .season && $0.noteAttachement.type == .rating && $0.season!.identifiers.trakt! == seasonIdentifier }) {
                return noteItem
            }
            return nil
        case .unknown:
            return nil
        }
    }

    var note: String? {
        return noteItem?.note.notes ?? nil
    }
}

extension HistoryItem {
    var noteItem: NoteItem? {
        if let noteItem = NotesManager.shared.notes.first(where: { $0.noteAttachement.type == .history && $0.noteAttachement.identifier == identifier }) {
            return noteItem
        }
        return nil
    }

    var note: String? {
        return noteItem?.note.notes ?? nil
    }
}

extension CollectionItem {
    var noteItem: NoteItem? {
        switch type {
        case .movie:
            let movieIdentifier = movie!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .movie && $0.noteAttachement.type == .collection && $0.movie!.identifiers.trakt! == movieIdentifier }) {
                return noteItem
            }
            return nil
        case .show:
            let showIdentifier = show!.identifiers.trakt!
            if let noteItem = NotesManager.shared.notes.first(where: { $0.type == .show && $0.noteAttachement.type == .collection && $0.show!.identifiers.trakt! == showIdentifier }) {
                return noteItem
            }
            return nil
        default:
            return nil
        }
    }

    var note: String? {
        return noteItem?.note.notes ?? nil
    }
}
