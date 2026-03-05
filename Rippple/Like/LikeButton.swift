//
//  LikeButton.swift
//  Rippple
//
//  Created by Kevin Cador on 06/12/2017.
//  Copyright © 2017 LINITIX. All rights reserved.
//

import UIKit

import Receiver

let (onCommentLikedTransmitter, onCommentLikedReceiver) = Receiver<Int64>.make(with: .hot)

final class ReactButton: TitleOnlyButton {

    var comment: Comment! {
        didSet {
            setTitle(comment.userReacted ? "Reacted" : "React", for: .normal)

            let actions = UIMenu(title: "React",
                                 children: ReactionsManager.shared.possibleReactions.map { reaction in
                if self.comment.userReacted(with: reaction.emoji) {
                    UIAction(title: "\(reaction.emoji) \(reaction.type.capitalized)",
                             state: .on,
                             handler: { _ in
                        self.comment.removeReaction(emoji: reaction.type)
                    })
                } else {
                    UIAction(title: "\(reaction.emoji) \(reaction.type.capitalized)",
                             state: .off,
                             handler: { _ in
                        self.comment.addReaction(emoji: reaction.type)
                        AppManager.shared.emitEmoji(emoji: reaction.emoji)
                    })
                }
            })

            menu = actions
        }
    }

    private let disposeBag = DisposeBag()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    private func setup() {

        showsMenuAsPrimaryAction = true

        onCommentLikedReceiver.listen { [weak self] (commentId) in
            guard let self = self else { return }
            if self.comment.identifier == commentId {
                self.setTitle(comment.userReacted ? "Reacted" : "React", for: .normal)
            }
        }.disposed(by: disposeBag)
    }
}
