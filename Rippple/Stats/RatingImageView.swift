//
//  RatingImageView.swift
//  Rippple
//
//  Created by Kevin Cador on 12/02/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class RatingImageView: UIImageView {
    private let disposeBag = DisposeBag()

    var ratedItem: RatedItem? {
        didSet {
            if let ratedItem = ratedItem {
                image = UIImage(systemName: "\(ratedItem.rating).circle")
                isHidden = false
                invalidateCellIntrinsicContentSize()
            }
        }
    }

    var media: MediaModel? {
        didSet {
            if let rating = media?.userRating {
                image = UIImage(systemName: "\(rating).circle")
                isHidden = false
            } else {
                isHidden = true
            }
            invalidateCellIntrinsicContentSize()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.ratedItem != nil { return }
                if let rating = self.media?.userRating {
                    self.image = UIImage(systemName: "\(rating).circle")
                    self.isHidden = false
                } else {
                    self.isHidden = true
                }
                self.invalidateCellIntrinsicContentSize()
            }
        }.disposed(by: disposeBag)
    }
}
