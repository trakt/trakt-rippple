//
//  ToWatchImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 09/12/2020.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class ToWatchImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var media: MediaModel? {
        didSet {
            if let media = media {
                isHidden = !(media.show?.isInToWatch ?? false)
            } else {
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        onShowsToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let media = self.media {
                    self.isHidden = !(media.show?.isInToWatch ?? false)
                } else {
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
