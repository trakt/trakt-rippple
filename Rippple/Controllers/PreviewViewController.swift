//
//  PreviewViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Receiver
import SafariServices
import UIKit

let (commentPostedTransmitter, commentPostedReceiver) = Receiver<CommentModel>.make(with: .hot)

final class PreviewViewController: UIViewController {
    var commentModel: CommentModel!

    @IBOutlet var sendButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(commentModel != nil)

        isModalInPresentation = true

        if commentModel.comment.identifier != 0 {
            sendButton.title = "Update"
        } else {
            sendButton.title = "Send"
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Preview
        if let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.preview(commentModel))
        }
    }

    private func service() -> TraktAPIService {
        if commentModel.comment.identifier != 0 {
            return .updateComment(id: commentModel.comment.identifier,
                                  body: commentModel.comment.body,
                                  spoilers: commentModel.comment.containsSpoiler)
        } else if commentModel.comment.parentIdentifier != 0 {
            return .postReply(id: commentModel.comment.parentIdentifier,
                              body: commentModel.comment.body,
                              spoilers: commentModel.comment.containsSpoiler)
        } else {
            switch commentModel.media {
            case .movie(let movie):
                return .postComment(type: .movie,
                                    traktId: movie.identifiers.trakt!,
                                    body: commentModel.comment.body,
                                    spoilers: commentModel.comment.containsSpoiler)
            case .show(let show):
                return .postComment(type: .show,
                                    traktId: show.identifiers.trakt!,
                                    body: commentModel.comment.body,
                                    spoilers: commentModel.comment.containsSpoiler)
            case .episode(let episode, _):
                return .postComment(type: .episode,
                                    traktId: episode.identifiers.trakt!,
                                    body: commentModel.comment.body,
                                    spoilers: commentModel.comment.containsSpoiler)
            case .season(let season, _):
                return .postComment(type: .season,
                                    traktId: season.identifiers.trakt!,
                                    body: commentModel.comment.body,
                                    spoilers: commentModel.comment.containsSpoiler)
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        }
    }

    private func showLoader() {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        let activityItem = UIBarButtonItem(customView: activityIndicator)
        navigationItem.rightBarButtonItem = activityItem
    }

    @IBAction func send(_ sender: Any) {
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false
        showLoader()

        TraktAPIProvider.provider.request(service(),
                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else {
                window.isUserInteractionEnabled = true
                return
            }
            switch result {
            case .success(let moyaResponse):
                do {
                    //
                    if moyaResponse.statusCode == 401 {
                        DispatchQueue.main.async {
                            AppManager.shared.isUserInteractionEnabled = true
                            self.navigationItem.rightBarButtonItem = self.sendButton
                            let alertController = UIAlertController(title: "Can't Post Comment",
                                                                    message: "We cannot post your comment! If you just created your Trakt account, you may not be able to comment yet. If it's an older account, you may have been banned from commenting by Trakt.",
                                                                    preferredStyle: .alert)
                            alertController.addAction(UIAlertAction(title: "Contact Trakt Support", style: .default, handler: { _ in
                                self.dismiss(animated: true, completion: {
                                    UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://support.trakt.tv")!))
                                })
                            }))
                            let cancel = UIAlertAction(title: "Okay", style: .cancel)
                            alertController.addAction(cancel)
                            self.present(alertController, animated: true)
                        }
                    } else {
                        _ = try moyaResponse.filterSuccessfulStatusCodes()
                        commentPostedTransmitter.broadcast(self.commentModel)

                        DispatchQueue.main.async {
                            if self.commentModel.comment.identifier != 0 {
                                CommentDraftManager.shared.unsaveDraft(for: self.commentModel.media)
                                SwiftMessages.show(message: "📭 Update posted")
                            } else if self.commentModel.comment.parentIdentifier != 0 {
                                SwiftMessages.show(message: "📭 Reply posted")
                            } else {
                                CommentDraftManager.shared.unsaveDraft(for: self.commentModel.media)
                                SwiftMessages.show(message: "📭 Comment posted")
                            }

                            self.dismiss(animated: true)
                            window.isUserInteractionEnabled = true
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error posting", style: .error(error))
                        window.isUserInteractionEnabled = true
                        self.navigationItem.rightBarButtonItem = self.sendButton
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error posting", style: .error(error))
                    window.isUserInteractionEnabled = true
                    self.navigationItem.rightBarButtonItem = self.sendButton
                }
            }
        }
    }
}
