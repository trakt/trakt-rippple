//
//  SentimentsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/04/2025.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class SentimentsTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var bodyLabel: UILabel!
    @IBOutlet var metaLabel: UILabel!

    @IBOutlet var cardView: UIView!

    private static let dateFormatter = RelativeDateTimeFormatter()

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.autoresizingMask = .flexibleHeight

        maximumContentSizeCategory = .large

        SentimentsTableViewCell.dateFormatter.unitsStyle = .abbreviated
        SentimentsTableViewCell.dateFormatter.dateTimeStyle = .numeric
        SentimentsTableViewCell.dateFormatter.formattingContext = .listItem
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
            metaLabel.text = "Aggregated audience sentiment"
        } else {
            titleLabel.text = "Comments Highlights"
            bodyLabel.text = sentiments.formattedSentiment
            metaLabel.text = "\(sentiments.commentCount) comments analyzed \(SentimentsTableViewCell.dateFormatter.localizedString(for: sentiments.analyzedAt, relativeTo: Date()))"
        }
    }
}
