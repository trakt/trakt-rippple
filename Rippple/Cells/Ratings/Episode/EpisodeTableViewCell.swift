//
//  EpisodeTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

final class EpisodeTableViewCell: UITableViewCell {
    @IBOutlet var episodeTitleLabel: UILabel!
    @IBOutlet var commentsLabel: CommentCountLabel!

    var episode: (show: Show, episode: Episode)! {
        didSet {
            episodeTitleLabel.text = "Episode \(episode.episode.number)"

            commentsLabel.media = .episode(episode.episode, episode.show)
        }
    }
}
