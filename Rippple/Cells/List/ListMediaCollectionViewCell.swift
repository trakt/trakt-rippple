//
//  ListMediaCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 30/03/2020.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class ListMediaCollectionViewCell: UICollectionViewCell {
    @IBOutlet var posterImageView: PosterImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        posterImageView.layer.cornerRadius = ViewRadius.medium.rawValue
        posterImageView.layer.cornerCurve = .continuous
        posterImageView.layer.masksToBounds = true
        posterImageView.layer.borderWidth = 1
        posterImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        posterImageView.backgroundColor = UIColor.tertiarySystemFill
    }

    var item: WatchlistItem? {
        didSet {
            if let item = item {
                if let movie = item.movie {
                    posterImageView.movie = movie
                } else if let show = item.show {
                    posterImageView.show = show
                }
            } else {
                posterImageView.show = nil
                posterImageView.movie = nil
                posterImageView.image = nil
            }
        }
    }
}
