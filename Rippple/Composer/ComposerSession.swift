//
//  ComposerSession.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

enum ComposerSubject {
    case media(MediaModel)
    case person(Person)
}

struct ComposerDraft: Equatable {
    var text: String
    var gif: CommentGIF?
    var containsSpoiler: Bool
    var privacy: NotePrivacy
}

struct ComposerTools: OptionSet {
    let rawValue: Int

    static let formatting = ComposerTools(rawValue: 1 << 0)
    static let gif = ComposerTools(rawValue: 1 << 1)
    static let spoilerFlag = ComposerTools(rawValue: 1 << 2)
    static let privacy = ComposerTools(rawValue: 1 << 3)
    static let preview = ComposerTools(rawValue: 1 << 4)
}

struct ComposerConfiguration {
    var title: String
    var subtitle: String?
    var placeholder: String
    var subject: ComposerSubject?
    var subjectDetail: String?
    var tools: ComposerTools
    var characterLimit: Int?
    var minimumWordCount: Int
    var isReadOnly: Bool
    var dismissTitle: String?
    var isPrivacyLocked: Bool
}

enum ComposerCancelPolicy {
    case dismiss
    case confirm(title: String, message: String, keepTitle: String, loseTitle: String)
    case offerDraft(title: String, message: String)
}

enum ComposerSubmitOutcome {
    case completed
    case keptOpen
    case failed
}

struct ComposerAlertAction {
    let title: String
    var style: UIAlertAction.Style = .default
    var handler: (() -> Void)?
}

protocol ComposerSession: AnyObject {
    var configuration: ComposerConfiguration { get }
    var initialDraft: ComposerDraft { get }

    func submitTitle(for draft: ComposerDraft) -> String
    func submitSymbol(for draft: ComposerDraft) -> String
    func canSubmit(_ draft: ComposerDraft) -> Bool
    func cancelPolicy(for draft: ComposerDraft) -> ComposerCancelPolicy

    func draftDidChange(_ draft: ComposerDraft)
    func saveDraft(_ draft: ComposerDraft)
    func discardDraft()

    func composerDidAppear(_ composer: ComposerViewController)
    func composerWillDisappear(_ draft: ComposerDraft)

    func submit(_ draft: ComposerDraft,
                from composer: ComposerViewController,
                anchor: UIBarButtonItem,
                completion: @escaping (ComposerSubmitOutcome) -> Void)
}

extension ComposerSession {
    func draftDidChange(_ draft: ComposerDraft) {}
    func saveDraft(_ draft: ComposerDraft) {}
    func discardDraft() {}
    func composerWillDisappear(_ draft: ComposerDraft) {}

    func composerDidAppear(_ composer: ComposerViewController) {
        composer.focusTextView()
    }
}

extension MediaModel {
    var composerTraktId: Int64? {
        switch self {
        case .movie(let movie): return movie.identifiers.trakt
        case .show(let show): return show.identifiers.trakt
        case .episode(let episode, _): return episode.identifiers.trakt
        case .season(let season, _): return season.identifiers.trakt
        case .list, .showProgress: return nil
        }
    }
}
