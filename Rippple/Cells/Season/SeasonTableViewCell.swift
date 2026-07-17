//
//  SeasonTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SeasonTableViewCell: UITableViewCell {
    @IBOutlet var seasonTitleLabel: UILabel!
    @IBOutlet var commentsLabel: CommentCountLabel!

    var season: (show: Show, season: Season)! {
        didSet {
            seasonTitleLabel.text = season.season.title

            commentsLabel.media = .season(season.season, season.show)
        }
    }
}
