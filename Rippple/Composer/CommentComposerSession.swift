//
//  CommentComposerSession.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import SafariServices
import UIKit

let (commentPostedTransmitter, commentPostedReceiver) = Receiver<CommentModel>.make(with: .hot)

private extension Comment {
    init(body: String, gif: CommentGIF?, containsSpoiler: Bool, user: User, comment: Comment?) {
        identifier = comment?.identifier ?? 0
        self.body = body
        self.gif = gif
        self.containsSpoiler = containsSpoiler
        isReview = body.count > 200
        language = comment?.language
        parentIdentifier = comment?.parentIdentifier ?? 0
        createDate = comment?.createDate ?? Date()
        updateDate = comment?.updateDate ?? Date()
        replies = comment?.replies ?? 0
        likes = comment?.likes ?? 0
        userRating = comment?.userRating
        self.user = comment?.user ?? user
        reactions = nil
    }
}

final class CommentComposerSession: ComposerSession {
    private static let minimumWordCount = 5

    private let media: MediaModel
    private let user: User
    private var editedComment: Comment?
    private var lastSavedDraft: SavedDraft?
    private var pendingDraft: ComposerDraft?
    private lazy var draftSaver = Debouncer(delay: 1.0) { [weak self] in
        guard let self = self else { return }
        self.flushDraft()
    }

    private weak var composer: ComposerViewController?
    private let disposeBag = DisposeBag()

    static func makeViewController(media: MediaModel, editedComment: Comment? = nil) -> StyledNavigationController? {
        guard let user = UserManager.shared.currentUser else {
            onNeedsToShowLoginTransmitter.broadcast(true)
            return nil
        }
        let session = CommentComposerSession(media: media, editedComment: editedComment, user: user)
        return ComposerViewController.makeNavigationController(session: session)
    }

    private init(media: MediaModel, editedComment: Comment?, user: User) {
        self.media = media
        self.editedComment = editedComment
        self.user = user
        lastSavedDraft = SavedDraft(media: media)
    }

    // MARK: - ComposerSession

    var configuration: ComposerConfiguration {
        var tools: ComposerTools = [.formatting, .spoilerFlag, .preview]
        if KlipyAPIProvider.isAvailable, isEditingPosted == false {
            tools.insert(.gif)
        }
        let detail: String?
        if isEditingPosted {
            detail = "Editing your comment"
        } else if editedComment?.isReply == true {
            detail = "Reply"
        } else {
            detail = nil
        }
        return ComposerConfiguration(title: "Compose",
                                     subtitle: "5+ words, mark spoilers!",
                                     placeholder: editedComment?.isReply == true ? "Write your reply…" : "Share your thoughts…",
                                     subject: .media(media),
                                     subjectDetail: detail,
                                     tools: tools,
                                     characterLimit: nil,
                                     minimumWordCount: CommentComposerSession.minimumWordCount,
                                     isReadOnly: false,
                                     dismissTitle: nil,
                                     isPrivacyLocked: false)
    }

    var initialDraft: ComposerDraft {
        let text: String
        let gif: CommentGIF?
        if let editedComment = editedComment {
            text = editedComment.body
            gif = editedComment.gif
        } else {
            text = CommentDraftManager.shared.comment(for: media) ?? ""
            gif = CommentDraftManager.shared.gif(for: media)
        }
        return ComposerDraft(text: text,
                             gif: gif,
                             containsSpoiler: editedComment?.containsSpoiler ?? false,
                             privacy: .me)
    }

    func submitTitle(for draft: ComposerDraft) -> String {
        isEditingPosted ? "Update" : "Post"
    }

    func submitSymbol(for draft: ComposerDraft) -> String {
        isEditingPosted ? "checkmark" : "paperplane.fill"
    }

    func canSubmit(_ draft: ComposerDraft) -> Bool {
        true
    }

    func cancelPolicy(for draft: ComposerDraft) -> ComposerCancelPolicy {
        if draft.text.isEmpty, draft.gif == nil {
            return .dismiss
        }
        if canSaveDraft == false {
            if editedComment?.isReply == true {
                return .confirm(title: "Cancel Reply",
                                message: "Keep composing your reply or lose it completely.",
                                keepTitle: "Keep Composing",
                                loseTitle: "Lose Reply")
            }
            return .confirm(title: "Cancel Edit",
                            message: "Keep editing your comment or lose your edits.",
                            keepTitle: "Keep Editing",
                            loseTitle: "Lose Edits")
        }
        return .offerDraft(title: "Cancel Comment",
                           message: "Keep composing your comment, save it as a draft for later or lose it completely.")
    }

    func draftDidChange(_ draft: ComposerDraft) {
        guard canSaveDraft else { return }
        pendingDraft = draft
        draftSaver.call()
    }

    func saveDraft(_ draft: ComposerDraft) {
        guard canSaveDraft else { return }
        pendingDraft = draft
        flushDraft()
    }

    func discardDraft() {
        pendingDraft = nil
        lastSavedDraft = nil
        CommentDraftManager.shared.unsaveDraft(for: media)
    }

    func composerWillDisappear(_ draft: ComposerDraft) {
        // A pending debounced save would otherwise resurrect a draft that was just posted or discarded.
        if pendingDraft != nil {
            flushDraft()
        }
    }

    func composerDidAppear(_ composer: ComposerViewController) {
        self.composer = composer
        listenForICloudDrafts()

        if UserManager.shared.currentUserCanComment == false {
            composer.presentAlert(title: "Permission to Comment",
                                  message: "If you just created your Trakt account, you may not be able to comment yet. If it's an older account, you may have been banned from commenting by Trakt.",
                                  actions: [
                                      ComposerAlertAction(title: "Contact Trakt Support") { [weak composer] in
                                          guard let composer = composer else { return }
                                          composer.dismiss(animated: true) {
                                              CommentComposerSession.openSupport()
                                          }
                                      },
                                      ComposerAlertAction(title: "Try Commenting Later", style: .cancel) { [weak composer] in
                                          guard let composer = composer else { return }
                                          composer.dismiss(animated: true)
                                      },
                                      ComposerAlertAction(title: "Try to Comment Anyway") { [weak composer] in
                                          guard let composer = composer else { return }
                                          composer.focusTextView()
                                      }
                                  ])
            return
        }

        if editedComment == nil, let ownCommentItem = media.ownCommentItem {
            composer.presentAlert(title: "You already commented this",
                                  message: "Would you like to edit your previous comment or compose a new one?",
                                  actions: [
                                      ComposerAlertAction(title: "Compose new") { [weak composer] in
                                          guard let composer = composer else { return }
                                          composer.focusTextView()
                                      },
                                      ComposerAlertAction(title: "Edit previous") { [weak self] in
                                          guard let self = self else { return }
                                          self.editPrevious(ownCommentItem.comment)
                                      }
                                  ])
            return
        }

        composer.focusTextView()
    }

    func submit(_ draft: ComposerDraft,
                from composer: ComposerViewController,
                anchor: UIBarButtonItem,
                completion: @escaping (ComposerSubmitOutcome) -> Void) {
        let post: (Bool) -> Void = { [weak self, weak composer] spoilers in
            guard let self = self else { return }
            composer?.setSubmitting(true)
            self.post(draft, spoilers: spoilers, completion: completion)
        }
        let keepComposing = ComposerAlertAction(title: "Keep Composing", style: .cancel) {
            completion(.keptOpen)
        }
        if draft.containsSpoiler {
            composer.presentSheet(title: "Post with Spoiler Alert?",
                                  message: "Your comment will be marked as containing spoilers.",
                                  actions: [
                                      keepComposing,
                                      ComposerAlertAction(title: submitTitle(for: draft)) {
                                          post(true)
                                      }
                                  ],
                                  anchor: anchor)
        } else {
            composer.presentSheet(title: "Spoiler Alert?",
                                  message: "If your comment contains spoiler and you did not mark them in the text, then you should send your comment with a spoiler alert.",
                                  actions: [
                                      keepComposing,
                                      ComposerAlertAction(title: "Send with Spoiler Alert") {
                                          post(true)
                                      },
                                      ComposerAlertAction(title: "Send without Spoiler Alert") {
                                          post(false)
                                      }
                                  ],
                                  anchor: anchor)
        }
    }

    // MARK: - Private

    private var isEditingPosted: Bool {
        (editedComment?.identifier ?? 0) != 0
    }

    private var canSaveDraft: Bool {
        guard let editedComment = editedComment else { return true }
        return CommentDraftManager.shared.canSaveDraft(for: editedComment)
    }

    /// Trakt's update leaves a posted comment's GIF as it is, so an edit keeps it.
    private func comment(from draft: ComposerDraft, spoilers: Bool) -> Comment {
        Comment(body: draft.text,
                gif: isEditingPosted ? editedComment?.gif : draft.gif,
                containsSpoiler: spoilers,
                user: user,
                comment: editedComment)
    }

    private func flushDraft() {
        guard let draft = pendingDraft else { return }
        pendingDraft = nil
        let saved = SavedDraft(text: draft.text, gif: draft.gif)
        guard canSaveDraft, saved != lastSavedDraft else { return }
        lastSavedDraft = saved
        if draft.text.isEmpty, draft.gif == nil {
            CommentDraftManager.shared.unsaveDraft(for: media)
        } else {
            CommentDraftManager.shared.saveDraft(for: comment(from: draft, spoilers: false), with: media)
        }
    }

    private func editPrevious(_ comment: Comment) {
        editedComment = comment
        pendingDraft = nil
        composer?.reloadConfiguration()
        composer?.replace(with: initialDraft)
        composer?.focusTextView()
    }

    private func listenForICloudDrafts() {
        onCommentsDraftsChangedReceiver.listen { [weak self] _ in
            // iCloud key-value store changes are delivered on a background thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.canSaveDraft, let composer = self.composer else { return }
                guard let remote = SavedDraft(media: self.media),
                      remote != SavedDraft(text: composer.draft.text, gif: composer.draft.gif),
                      remote != self.lastSavedDraft else { return }
                composer.presentAlert(title: "New Draft",
                                      message: "We found a new Draft on iCloud. Would you like to use it or dismiss it?",
                                      actions: [
                                          ComposerAlertAction(title: "Dismiss iCloud draft", style: .destructive),
                                          ComposerAlertAction(title: "Use iCloud draft") { [weak self] in
                                              guard let self = self, let composer = self.composer else { return }
                                              self.lastSavedDraft = remote
                                              var draft = composer.draft
                                              draft.text = remote.text
                                              draft.gif = remote.gif
                                              composer.replace(with: draft)
                                          }
                                      ])
            }
        }.disposed(by: disposeBag)
    }

    private func service(for comment: Comment) -> TraktAPIService? {
        if comment.identifier != 0 {
            return .updateComment(id: comment.identifier, body: comment.body, spoilers: comment.containsSpoiler)
        }
        if comment.parentIdentifier != 0 {
            return .postReply(id: comment.parentIdentifier, body: comment.body, spoilers: comment.containsSpoiler, gif: comment.gif)
        }
        let type: PostType
        switch media {
        case .movie: type = .movie
        case .show: type = .show
        case .episode: type = .episode
        case .season: type = .season
        case .list, .showProgress: return nil
        }
        guard let traktId = media.composerTraktId else { return nil }
        return .postComment(type: type, traktId: traktId, body: comment.body, spoilers: comment.containsSpoiler, gif: comment.gif)
    }

    private func post(_ draft: ComposerDraft, spoilers: Bool, completion: @escaping (ComposerSubmitOutcome) -> Void) {
        let comment = comment(from: draft, spoilers: spoilers)
        guard let service = service(for: comment) else {
            SwiftMessages.show(message: "😓 Comments on this item can’t be posted from Rippple yet")
            completion(.keptOpen)
            return
        }
        let media = media
        TraktAPIProvider.provider.request(service,
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            switch result {
            case .success(let moyaResponse):
                if moyaResponse.statusCode == 401 {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.showCannotPostMessage()
                        completion(.keptOpen)
                    }
                    return
                }
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    let commentModel = CommentModel(media: media, comment: comment, spoilerStrategy: .showAllSpoilers)
                    commentPostedTransmitter.broadcast(commentModel)
                    DispatchQueue.main.async { [weak self] in
                        if comment.identifier != 0 {
                            SwiftMessages.show(message: "📭 Update posted")
                        } else if comment.parentIdentifier != 0 {
                            SwiftMessages.show(message: "📭 Reply posted")
                        } else {
                            SwiftMessages.show(message: "📭 Comment posted")
                        }
                        guard let self = self else {
                            completion(.completed)
                            return
                        }
                        if comment.parentIdentifier == 0 {
                            self.discardDraft()
                        }
                        completion(.completed)
                    }
                } catch {
                    CommentComposerSession.fail(error, completion: completion)
                }
            case .failure(let error):
                CommentComposerSession.fail(error, completion: completion)
            }
        }
    }

    private static func fail(_ error: Error, completion: @escaping (ComposerSubmitOutcome) -> Void) {
        DispatchQueue.main.async {
            SwiftMessages.show(message: "😓 Error posting", style: .error(error))
            completion(.failed)
        }
    }

    private func showCannotPostMessage() {
        composer?.presentAlert(title: "Can't Post Comment",
                               message: "We cannot post your comment! If you just created your Trakt account, you may not be able to comment yet. If it's an older account, you may have been banned from commenting by Trakt.",
                               actions: [
                                   ComposerAlertAction(title: "Contact Trakt Support") { [weak self] in
                                       guard let self = self else { return }
                                       self.composer?.dismiss(animated: true) {
                                           CommentComposerSession.openSupport()
                                       }
                                   },
                                   ComposerAlertAction(title: "Okay", style: .cancel)
                               ])
    }

    private static func openSupport() {
        guard let url = URL(string: "https://support.trakt.tv") else { return }
        UIApplication.shared.present(SFSafariViewController(url: url))
    }
}

private struct SavedDraft: Equatable {
    let text: String
    let gif: CommentGIF?
}

private extension SavedDraft {
    init?(media: MediaModel) {
        guard let text = CommentDraftManager.shared.comment(for: media) else { return nil }
        self.init(text: text, gif: CommentDraftManager.shared.gif(for: media))
    }
}
