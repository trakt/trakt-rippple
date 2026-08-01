//
//  CommentDraftManager.swift
//  Rippple
//
//  Created by Kevin Cador on 24/08/2018.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

private extension MediaModel {
    var key: String {
        switch self {
        case .movie(let movie):
            return "CommentDraftManager.drafts.movie.\(movie.identifiers.trakt!)"
        case .show(let show):
            return "CommentDraftManager.drafts.show.\(show.identifiers.trakt!)"
        case .episode(let episode, let show):
            return "CommentDraftManager.drafts.episode.\(episode.identifiers.trakt!).show.\(show.identifiers.trakt!)"
        case .season(let season, let show):
            return "CommentDraftManager.drafts.season.\(season.identifiers.trakt!).show.\(show.identifiers.trakt!)"
        case .list(let list):
            return "CommentDraftManager.drafts.list.\(list.identifiers.trakt!)"
        case .showProgress:
            fatalError()
        }
    }
}

struct CommentDraft: Codable, Hashable {
    init(mediaModel: MediaModel, comment: Comment) {
        switch mediaModel {
        case .movie(let movie):
            type = .movie
            self.movie = movie
            show = nil
            episode = nil
            season = nil
            list = nil
        case .show(let show):
            type = .show
            movie = nil
            self.show = show
            episode = nil
            season = nil
            list = nil
        case .episode(let episode, let show):
            type = .episode
            movie = nil
            self.show = show
            self.episode = episode
            season = nil
            list = nil
        case .season(let season, let show):
            type = .season
            movie = nil
            self.show = show
            episode = nil
            self.season = season
            list = nil
        case .list(let list):
            type = .list
            movie = nil
            show = nil
            episode = nil
            season = nil
            self.list = list
        case .showProgress:
            fatalError()
        }
        identifier = mediaModel.key
        updated = Date()
        self.comment = comment.body
    }

    static func == (lhs: CommentDraft, rhs: CommentDraft) -> Bool {
        return lhs.identifier == rhs.identifier && lhs.comment == rhs.comment
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(comment)
    }

    let identifier: String
    let type: CommentType

    let updated: Date

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    let comment: String
}

let (onCommentsDraftsChangedTransmitter, onCommentsDraftsChangedReceiver) = Receiver<Int>.make(with: .hot)

final class CommentDraftManager {
    private var drafts = Set<CommentDraft>()

    private init() {
        readDrafts()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(didChangeExternally),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil)
    }

    private func readDrafts() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "CommentDraftManager.drafts") else { return }
        guard let previousDrafts = try? JSONDecoder().decode(Set<CommentDraft>.self, from: data) else { return }
        drafts = previousDrafts
    }

    @objc private func didChangeExternally() {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: "CommentDraftManager.drafts") else { return }
        guard let previousDrafts = try? JSONDecoder().decode(Set<CommentDraft>.self, from: data) else { return }
        if drafts != previousDrafts {
            drafts = previousDrafts
            onCommentsDraftsChangedTransmitter.broadcast(1)
        }
    }

    static let shared = CommentDraftManager()

    func canSaveDraft(for comment: Comment) -> Bool {
        // is not a reply and is not an edit of a previous comment
        return comment.isReply == false && comment.identifier == 0
    }

    private func draft(for mediaModel: MediaModel) -> CommentDraft? {
        for draft in drafts where draft.identifier == mediaModel.key {
            return draft
        }
        return nil
    }

    func comment(for mediaModel: MediaModel) -> String? {
        if let draft = draft(for: mediaModel) {
            return draft.comment
        }
        return nil
    }

    func saveDraft(for comment: Comment, with mediaModel: MediaModel) {
        if canSaveDraft(for: comment) == false { return }

        if let draft = draft(for: mediaModel) {
            drafts.remove(draft)
        }
        drafts.insert(CommentDraft(mediaModel: mediaModel, comment: comment))

        saveDrafts()
    }

    func unsaveDraft(for mediaModel: MediaModel) {
        if let draft = draft(for: mediaModel) {
            drafts.remove(draft)
        }

        saveDrafts()
    }

    private func saveDrafts() {
        if let data = try? JSONEncoder().encode(drafts) {
            NSUbiquitousKeyValueStore.default.set(data, forKey: "CommentDraftManager.drafts")
        }
    }
}
