//
//  ReplyCountButton.swift
//  Rippple
//
//  Created by Kevin Cador on 20/07/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class ReplyCountButton: UIButton {
    private let disposeBag = DisposeBag()

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
        print("deiniting ReplyCountButton")
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
            guard var configuration = configuration else {
                fatalError()
            }
            var container = AttributeContainer()
            container.font = .caption
            if let commentCount = commentCount {
                configuration.attributedTitle = AttributedString("\(commentCount)",
                                                                 attributes: container)
            } else {
                configuration.attributedTitle = AttributedString("0",
                                                                 attributes: container)
            }
            configuration.image = UIImage(systemName: "arrowshape.turn.up.left")
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption1)
            configuration.imagePadding = 4.0
            configuration.buttonSize = .mini
            self.configuration = configuration
            superview?.setNeedsLayout()
            superview?.layoutIfNeeded()
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
