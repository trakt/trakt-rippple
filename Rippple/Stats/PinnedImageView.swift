//
//  PinnedImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 23/05/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class PinnedImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            switch media {
            case .movie(let movie):
                isHidden = !movie.isPinned
            case .show(let show):
                isHidden = !show.isPinned
            default:
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onPinnedShowsToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isPinned
                case .show(let show):
                    self.isHidden = !show.isPinned
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)

        onPinnedMoviesToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch self.media {
                case .movie(let movie):
                    self.isHidden = !movie.isPinned
                case .show(let show):
                    self.isHidden = !show.isPinned
                default:
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
