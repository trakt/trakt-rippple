//
//  SentimentsPeekCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

final class SentimentsPeekCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var bodyLabel: UILabel!
    @IBOutlet weak var metaLabel: UILabel!

    @IBOutlet weak var cardView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        maximumContentSizeCategory = .large
    }

    var sentiments: CommentsSentiments! {
        didSet {
            setupSentiments()
        }
    }

    private func setupSentiments() {
        if sentiments.commentCount == 0 {
            titleLabel.text = "Sentiment Highlights"
            bodyLabel.text = sentiments.formattedSentiment
            metaLabel.text = ""
        } else {
            titleLabel.text = "Comments Highlights"
            bodyLabel.text = sentiments.formattedSentiment
            metaLabel.text = ""
        }
    }
}
