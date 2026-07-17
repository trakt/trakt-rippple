//
//  CommentedImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 12/02/2021.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class CommentedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = movie.ownCommentItem == nil
            case .episode(let episode, _):
                isHidden = episode.ownCommentItem == nil
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onOwnCommentsChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = movie.ownCommentItem == nil
                case .episode(let episode, _):
                    self.isHidden = episode.ownCommentItem == nil
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
