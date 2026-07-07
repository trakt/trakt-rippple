//
//  CommentCountLabel.swift
//  Rippple
//
//  Created by Kevin Cador on 07/12/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class CommentCountLabel: UILabel {
    private let disposeBag = DisposeBag()

    enum Mode: Int {
        case text
        case alone
    }

    var mode: Mode = .text

    override func awakeFromNib() {
        super.awakeFromNib()

        commentPostedReceiver.listen { [weak self] commentModel in
            guard let self = self else { return }

            if let media = self.media,
               media == commentModel.media {
                self.update(with: media)
            }

            if let comment = self.comment,
               comment == commentModel.comment {
                self.cancellable = self.fetchCommentCount(type: .comment(commentId: comment.identifier))
            }
        }.disposed(by: disposeBag)
    }

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
        print("deiniting CommentCountLabel")
    }

    var comment: Comment? {
        willSet {
            cancelCancellable()
        }
        didSet {
            guard let comment = comment else { return }
            commentCount = comment.replies
            cancellable = fetchCommentCount(type: .comment(commentId: comment.identifier))
        }
    }

    var media: MediaModel? {
        didSet {
            if media == oldValue { return }
            update(with: media)
        }
    }

    private func update(with media: MediaModel?) {
        guard let media = media else { return }

        let symbolStyle = UIImage.SymbolConfiguration(font: font, scale: .small)

        let heartTextAttachment = NSTextAttachment()
        heartTextAttachment.image = UIImage(systemName: "heart.fill")?.withConfiguration(symbolStyle).withTintColor(.tertiaryLabel)

        switch mode {
        case .alone:
            break
        case .text:
            if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 3 {
                // do nothing, continue to get commments count
            } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 0 {
                // do nothing, continue to get commments count
            } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 1 {
                if let rating = media.rating {
                    let fullString = NSMutableAttributedString(string: "")
                    fullString.append(NSAttributedString(attachment: heartTextAttachment))
                    fullString.append(NSAttributedString(string: "\(Int(round(rating * 10.0)))%"))
                    attributedText = fullString
                    return
                }
            } else {
                attributedText = NSMutableAttributedString(string: "")
                return
            }
        }

        switch media {
        case .movie(let movie):
            commentCount = movie.commentCount
            cancellable = fetchCommentCount(type: .movie(movieId: movie.identifiers.trakt!))
        case .show(let show):
            commentCount = show.commentCount
            cancellable = fetchCommentCount(type: .show(showId: show.identifiers.trakt!))
        case .episode(let episode, let show):
            commentCount = episode.commentCount
            cancellable = fetchCommentCount(type: .episode(showId: show.identifiers.trakt!,
                                                           season: episode.season,
                                                           episode: episode.number))
        case .season(let season, let show):
            commentCount = season.commentCount
            cancellable = fetchCommentCount(type: .season(showId: show.identifiers.trakt!,
                                                          season: season.number))
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    private var commentCount: Int? {
        didSet {
            switch mode {
            case .alone:
                if let commentCount = commentCount {
                    text = "\(commentCount)"
                } else {
                    text = "0"
                }
            case .text:
                let symbolStyle = UIImage.SymbolConfiguration(font: font, scale: .small)

                let heartTextAttachment = NSTextAttachment()
                heartTextAttachment.image = UIImage(systemName: "heart.fill")?.withConfiguration(symbolStyle).withTintColor(.tertiaryLabel)

                let fullString = NSMutableAttributedString(string: "")

                if let media = media {
                    if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 3 {
                        if let rating = media.rating {
                            fullString.append(NSAttributedString(attachment: heartTextAttachment))
                            fullString.append(NSAttributedString(string: "\(Int(round(rating * 10.0)))% "))
                        }
                        // continue to get commments count
                    } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 0 {
                        // do nothing, continue to get commments count
                    } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 1 {
                        if let rating = media.rating {
                            fullString.append(NSAttributedString(attachment: heartTextAttachment))
                            fullString.append(NSAttributedString(string: "\(Int(round(rating * 10.0)))%"))
                            attributedText = fullString
                            return
                        }
                    } else {
                        attributedText = NSMutableAttributedString(string: "")
                        return
                    }
                }

                let commentTextAttachment = NSTextAttachment()
                if comment != nil {
                    commentTextAttachment.image = UIImage(systemName: "arrowshape.turn.up.left")?.withConfiguration(symbolStyle).withTintColor(.tertiaryLabel)
                } else {
                    commentTextAttachment.image = UIImage(systemName: "bubble.fill")?.withConfiguration(symbolStyle).withTintColor(.tertiaryLabel)
                }
                fullString.append(NSAttributedString(attachment: commentTextAttachment))

                if let commentCount = commentCount {
                    fullString.append(NSAttributedString(string: "\(commentCount)"))
                } else {
                    fullString.append(NSAttributedString(string: "0"))
                }
                attributedText = fullString
            }
        }
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetchCommentCount(type: TraktObjectType) -> Cancellable {
        return TraktAPIProvider.provider.request(.commentCount(type: type), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if let response = response.response {
                        let allHTTPHeaders = response.allHeaderFields
                        if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                            DispatchQueue.main.async {
                                self.commentCount = Int(itemCount)
                            }
                        }
                    }
                } catch {
                    print("Stats request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                if error.localizedDescription == "cancelled" { return }
                print("Stats request failure \(error)")
            }
        }
    }
}
