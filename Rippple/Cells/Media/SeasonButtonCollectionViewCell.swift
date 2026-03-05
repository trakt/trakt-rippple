//
//  SeasonButtonCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/02/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

final class SeasonButtonCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var meta: CommentCountLabel?
    @IBOutlet weak var whereToWatchImageView: WhereToWatchImageView?
    @IBOutlet weak var poster: PosterButton!

    @IBOutlet weak var cardView: InsideCardView!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        poster.layer.cornerRadius = ViewRadius.medium.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        title.maximumContentSizeCategory = .extraLarge
        subtitle.maximumContentSizeCategory = .extraLarge
        meta?.maximumContentSizeCategory = .extraLarge
    }

    var media: MediaModel! {
        didSet {
            switch media {
            case .season(let season, let show):
                setupSeason(season: season, show: show)
            default:
                fatalError("Media type not handled in SeasonShowTableViewCell")
            }
        }
    }

    private func setupSeason(season: Season, show: Show) {
        title.text = "Season \(season.number)"
        if let episodeCount = season.airedEpisodes {
            subtitle.text = "\(episodeCount) aired"
        } else {
            subtitle.text = ""
        }

        meta?.media = media

        whereToWatchImageView?.isHidden = true
        // whereToWatchImageView?.media = media

        poster.season = (show, season)
    }
}
