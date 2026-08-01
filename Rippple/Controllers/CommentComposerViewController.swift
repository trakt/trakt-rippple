//
//  CommentComposerViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 27/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import SafariServices
import UIKit

private extension Comment {
    init(body: String, user: User, containsSpoiler: Bool) {
        identifier = 0
        self.body = body
        self.containsSpoiler = containsSpoiler
        isReview = body.count > 200 ? true : false
        language = nil
        parentIdentifier = 0
        createDate = Date()
        updateDate = Date()
        replies = 0
        likes = 0
        userRating = nil
        self.user = user
        reactions = nil
    }

    init(body: String, comment: Comment, containsSpoiler: Bool) {
        identifier = comment.identifier
        self.body = body
        self.containsSpoiler = containsSpoiler
        isReview = body.count > 200 ? true : false
        language = comment.language
        parentIdentifier = comment.parentIdentifier
        createDate = comment.createDate
        updateDate = comment.updateDate
        replies = comment.replies
        likes = comment.likes
        userRating = comment.userRating
        user = comment.user
        reactions = nil
    }
}

final class CommentComposerViewController: UIViewController {
    /// @IBOutlet weak var placeholderTextView: UITextView!
    @IBOutlet var commentTextView: UITextView!

    @IBOutlet var previewBarButtonItem: UIBarButtonItem!

    var mediaModel: MediaModel!
    var editedComment: Comment?

    private var checkedOnlyOnceAlready = false

    @IBOutlet var customToolbar: UIToolbar!

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let navigationController = navigationController as? ComposeNavigationController else {
            fatalError("This view controller should be embeded in a ComposeViewController")
        }
        mediaModel = navigationController.mediaModel
        editedComment = navigationController.editedComment

        navigationItem.subtitle = "English only, 5+ words, mark spoilers!"

        commentTextView.clipsToBounds = false
        commentTextView.inputAccessoryView = customToolbar
        customToolbar.sizeToFit()

        if let editedComment = editedComment {
            if editedComment.isReply {
                title = "Reply"
            } else {
                title = "Edit"
            }
            commentTextView.text = editedComment.body
        } else if let previousComment = CommentDraftManager.shared.comment(for: mediaModel) {
            commentTextView.text = previousComment
        }

        configureKeyboardNotifications()
        updateUIBasedOnWordCount()

        onCommentsDraftsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }

            guard let previousComment = CommentDraftManager.shared.comment(for: self.mediaModel) else { return }

            if self.commentTextView.text == previousComment { return }

            let alertController = UIAlertController(title: "New Draft",
                                                    message: "We found a new Draft on iCloud. Would you like to use it or dismiss it?",
                                                    preferredStyle: .alert)

            let cancel = UIAlertAction(title: "Dismiss iCloud draft", style: .destructive)
            alertController.addAction(cancel)

            let confirm = UIAlertAction(title: "Use iCloud draft", style: .default) { _ in
                self.commentTextView.text = previousComment
                self.updateUIBasedOnWordCount()
            }
            alertController.addAction(confirm)

            self.present(alertController, animated: true)
        }.disposed(by: disposeBag)

        if UserManager.shared.currentUserCanComment == false {
            let alertController = UIAlertController(title: "Permission to Comment",
                                                    message: "If you just created your Trakt account, you may not be able to comment yet. If it's an older account, you may have been banned from commenting by Trakt.",
                                                    preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Try to Comment Anyway", style: .default)
            alertController.addAction(UIAlertAction(title: "Contact Trakt Support", style: .default, handler: { _ in
                self.dismiss(animated: true, completion: {
                    UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://forums.trakt.tv")!))
                })
            }))
            alertController.addAction(UIAlertAction(title: "Try Commenting Later", style: .cancel, handler: { _ in
                self.dismiss(animated: true)
            }))
            alertController.addAction(cancel)
            present(alertController, animated: true)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !checkedOnlyOnceAlready {
            // new comment but we already have a comment for the user
            if editedComment == nil, let ownCommentItem = mediaModel.ownCommentItem {
                let alertController = UIAlertController(title: "You already commented this",
                                                        message: "Would you like to edit your previous comment or compose a new one?",
                                                        preferredStyle: .alert)

                let new = UIAlertAction(title: "Compose new", style: .default) { _ in
                    if self.commentTextView.text.isEmpty {
                        self.commentTextView.becomeFirstResponder()
                    }
                }
                alertController.addAction(new)

                let edit = UIAlertAction(title: "Edit previous", style: .default) { _ in
                    self.editedComment = ownCommentItem.comment
                    self.title = "Edit"
                    self.commentTextView.text = ownCommentItem.comment.body
                    self.updateUIBasedOnWordCount()
                }
                alertController.addAction(edit)

                present(alertController, animated: true)
            } else if commentTextView.text.isEmpty {
                commentTextView.becomeFirstResponder()
            }

            checkedOnlyOnceAlready = true
        }
    }

    private func updateUIBasedOnWordCount() {
        // placeholderTextView.isHidden = !commentTextView.text.isEmpty

        isModalInPresentation = !commentTextView.text.isEmpty

        let wordCount = commentTextView.text.wordCount
        previewBarButtonItem.isEnabled = wordCount >= 5
    }

    private func configureKeyboardNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardFrameDidChange(notification:)),
                                               name: UIResponder.keyboardDidChangeFrameNotification,
                                               object: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        commentTextView.resignFirstResponder()

        if let previewViewController = segue.destination as? PreviewViewController,
           let commentToPost = sender as? Comment {
            previewViewController.commentModel = CommentModel(media: mediaModel,
                                                              comment: commentToPost,
                                                              spoilerStrategy: .showAllSpoilers)
        }
    }
}

extension CommentComposerViewController {
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        if commentTextView.text.isEmpty || UserManager.shared.currentUser == nil {
            dismiss(animated: true)
            return
        }

        if let editedComment = editedComment, CommentDraftManager.shared.canSaveDraft(for: editedComment) == false {
            // Cannot Save
            if editedComment.isReply {
                let alertController = UIAlertController(title: "Cancel Reply",
                                                        message: "Keep composing your reply or lose it completely.",
                                                        preferredStyle: .actionSheet)

                let cancel = UIAlertAction(title: "Keep Composing", style: .cancel)
                alertController.addAction(cancel)

                let confirm = UIAlertAction(title: "Lose Reply", style: .destructive) { _ in
                    CommentDraftManager.shared.unsaveDraft(for: self.mediaModel)
                    self.dismiss(animated: true)
                }
                alertController.addAction(confirm)

                alertController.popoverPresentationController?.barButtonItem = sender

                present(alertController, animated: true)
            } else {
                let alertController = UIAlertController(title: "Cancel Edit",
                                                        message: "Keep editing your comment or lose your edits.",
                                                        preferredStyle: .actionSheet)

                let cancel = UIAlertAction(title: "Keep Editing", style: .cancel)
                alertController.addAction(cancel)

                let confirm = UIAlertAction(title: "Lose Edits", style: .destructive) { _ in
                    CommentDraftManager.shared.unsaveDraft(for: self.mediaModel)
                    self.dismiss(animated: true)
                }
                alertController.addAction(confirm)

                alertController.popoverPresentationController?.barButtonItem = sender

                present(alertController, animated: true)
            }
        } else {
            let alertController = UIAlertController(title: "Cancel Comment",
                                                    message: "Keep composing your comment, save it as a draft for later or lose it completely.",
                                                    preferredStyle: .actionSheet)

            let cancel = UIAlertAction(title: "Keep Composing", style: .cancel)
            alertController.addAction(cancel)

            let save = UIAlertAction(title: "Save Draft", style: .default) { _ in
                CommentDraftManager.shared.saveDraft(for: self.comment(withSpoilers: false), with: self.mediaModel)
                self.dismiss(animated: true)
            }
            alertController.addAction(save)

            let confirm = UIAlertAction(title: "Lose Comment", style: .destructive) { _ in
                CommentDraftManager.shared.unsaveDraft(for: self.mediaModel)
                self.dismiss(animated: true)
            }
            alertController.addAction(confirm)

            alertController.popoverPresentationController?.barButtonItem = sender

            present(alertController, animated: true)
        }
    }

    @IBAction func preview(_ sender: UIBarButtonItem) {
        if UserManager.shared.currentUser == nil {
            dismiss(animated: true)
            onNeedsToShowLoginTransmitter.broadcast(true)
            return
        }

        let alertController = UIAlertController(title: "Spoiler Alert?",
                                                message: "If your comment contains spoiler and you did not mark them in the text, then you should send your comment with a spoiler alert.",
                                                preferredStyle: .actionSheet)

        let cancel = UIAlertAction(title: "Keep Composing", style: .cancel)
        alertController.addAction(cancel)

        let spoilers = UIAlertAction(title: "Send with Spoiler Alert",
                                     style: .default) { _ in
            self.performSegue(withIdentifier: "preview",
                              sender: self.comment(withSpoilers: true))
        }
        alertController.addAction(spoilers)

        let noSpoilers = UIAlertAction(title: "Send without Spoiler Alert",
                                       style: .default) { _ in
            self.performSegue(withIdentifier: "preview",
                              sender: self.comment(withSpoilers: false))
        }
        alertController.addAction(noSpoilers)

        alertController.popoverPresentationController?.barButtonItem = sender

        present(alertController, animated: true)
    }

    private func comment(withSpoilers spoilers: Bool) -> Comment {
        if let editedComment = editedComment {
            return Comment(body: commentTextView.text,
                           comment: editedComment,
                           containsSpoiler: spoilers)
        } else {
            return Comment(body: commentTextView.text,
                           user: UserManager.shared.currentUser!,
                           containsSpoiler: spoilers)
        }
    }
}

extension CommentComposerViewController {
    private func insertMarkdown(prefix: String, sufix: String) {
        if let selectedRange = commentTextView.selectedTextRange {
            if let selectedText = commentTextView.text(in: selectedRange) {
                commentTextView.insertText(prefix + selectedText + sufix)
            } else {
                commentTextView.insertText(prefix + sufix)
            }
            if let from = commentTextView.position(from: selectedRange.start, offset: prefix.count),
               let to = commentTextView.position(from: selectedRange.end, offset: prefix.count) {
                commentTextView.selectedTextRange = commentTextView.textRange(from: from, to: to)
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

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(toggleItalics(_:)) { return true }
        if action == #selector(toggleBoldface(_:)) { return true }
        return false
    }

    override func toggleItalics(_ sender: Any?) {
        insertMarkdown(prefix: "_", sufix: "_")
    }

    override func toggleBoldface(_ sender: Any?) {
        insertMarkdown(prefix: "**", sufix: "**")
    }
}

extension CommentComposerViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateUIBasedOnWordCount()
        if UserManager.shared.currentUser != nil {
            CommentDraftManager.shared.saveDraft(for: comment(withSpoilers: false), with: mediaModel)
        }
    }
}

@objc extension CommentComposerViewController {
    private func keyboardFrameDidChange(notification: NSNotification) {
        if let frameValue = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let keyboardHeight = frameValue.cgRectValue.size.height - view.safeAreaInsets.bottom
            commentTextView.contentInset = UIEdgeInsets(top: 0.0,
                                                        left: 0.0,
                                                        bottom: keyboardHeight + 60.0,
                                                        right: 0.0)
            commentTextView.scrollIndicatorInsets = UIEdgeInsets(top: 0.0,
                                                                 left: 0.0,
                                                                 bottom: keyboardHeight + 60.0,
                                                                 right: -15.0)
        }
    }
}
