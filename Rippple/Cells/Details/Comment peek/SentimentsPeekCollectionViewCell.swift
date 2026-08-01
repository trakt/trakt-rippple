//
//  SentimentsPeekCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2025.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SentimentsPeekCollectionViewCell: UICollectionViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bodyLabel: UILabel!
    @IBOutlet var metaLabel: UILabel!

    @IBOutlet var cardView: UIView!

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
        if sentiments.commentCount == 0 || sentiments.commentCount == 100000 {
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
