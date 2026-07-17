//
//  CommentReactionButton.swift
//  Rippple
//
//  Created by Kevin Cador on 20/07/2025.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class CommentReactionButton: UIButton {
    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        onCommentReactReceiver.listen { [weak self] commentId in
            guard let self = self else { return }
            guard let comment = self.comment else { return }
            if comment.identifier != commentId { return }
            print("refreshing comment like count")
            self.cancellable = self.fetchReactions(commentId: commentId)
        }.disposed(by: disposeBag)

        tintColor = .label
        var configuration = UIButton.Configuration.gray()

        var container = AttributeContainer()
        container.font = .caption

        configuration.attributedTitle = AttributedString("...",
                                                         attributes: container)
        configuration.image = UIImage(systemName: "hand.thumbsup")
        configuration.imagePadding = 4.0
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption1)

        configuration.buttonSize = .mini
        self.configuration = configuration
    }

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    var comment: Comment? {
        willSet {
            cancelCancellable()
        }
        didSet {
            guard let comment = comment else { return }
            reactions = comment.reactions
            cancellable = fetchReactions(commentId: comment.identifier)
        }
    }

    private var reactions: ReactionSummary? {
        didSet {
            guard let reactions = reactions else { return }
            guard var configuration = configuration else {
                fatalError()
            }
            var container = AttributeContainer()
            container.font = .caption
            if reactions.reactionCount >= 1 {
                configuration.attributedTitle = AttributedString("\(reactions.distribution.top3Emojis) \(reactions.distribution.score)",
                                                                 attributes: container)
                configuration.image = nil
            } else {
                configuration.attributedTitle = AttributedString("0",
                                                                 attributes: container)
                configuration.image = UIImage(systemName: "hand.thumbsup")
                configuration.imagePadding = 4.0
                configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .caption1)
            }
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

    private func fetchReactions(commentId: Int64) -> Cancellable {
        return TraktAPIProvider.provider.request(.commentReactionsSummary(id: commentId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let reactions = try response.map(ReactionSummary.self,
                                                     using: TraktAPIProvider.decoder)
                    DispatchQueue.main.async {
                        self.reactions = reactions
                    }
                } catch {
                    print(".commentReactionsSummary request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                if error.localizedDescription == "cancelled" { return }
                print(".commentReactionsSummary request failure \(error)")
            }
        }
    }
}
