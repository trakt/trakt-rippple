//
//  MediaOverviewTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 12/01/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class MediaOverviewTableViewCell: UITableViewCell {
    @IBOutlet var taglineLabel: UILabel!
    @IBOutlet var overviewLabel: UILabel!

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                if let tagline = movie.tagline, !tagline.isEmpty {
                    taglineLabel.text = tagline
                    taglineLabel.isHidden = false
                } else {
                    taglineLabel.isHidden = true
                }

                if let overview = movie.overview, overview.isEmpty == false {
                    overviewLabel.text = overview
                } else {
                    overviewLabel.text = "No Overview."
                }
            case .show(let show):
                if let tagline = show.tagline, !tagline.isEmpty {
                    taglineLabel.text = tagline
                    taglineLabel.isHidden = false
                } else {
                    taglineLabel.isHidden = true
                }

                if let overview = show.overview, overview.isEmpty == false {
                    overviewLabel.text = overview
                } else {
                    overviewLabel.text = "No Overview."
                }
            case .episode(let episode, _):
                taglineLabel.isHidden = true

                if let overview = episode.overview, overview.isEmpty == false {
                    overviewLabel.text = overview
                } else {
                    overviewLabel.text = "No Overview."
                }
            case .season(let season, _):
                taglineLabel.isHidden = true

                if let overview = season.overview, overview.isEmpty == false {
                    overviewLabel.text = overview
                } else {
                    overviewLabel.text = "No Overview."
                }
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        }
    }
}
