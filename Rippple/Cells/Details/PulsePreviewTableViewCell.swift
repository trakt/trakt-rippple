//
//  PulsePreviewTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

final class PulsePreviewTableViewCell: UITableViewCell {
    @IBOutlet weak var pulseSymbol: UIImageView!
    @IBOutlet weak var title: UILabel!

    @IBOutlet weak var recommendedStatus: RecommendedImageView?
    @IBOutlet weak var watchlistedStatus: WatchlistImageView?
    @IBOutlet weak var watchedStatus: WatchedImageView?
    @IBOutlet weak var toWatchStatus: ToWatchImageView?
    @IBOutlet weak var collectedStatus: CollectedImageView?
    @IBOutlet weak var commentedStatus: CommentedImageView?
    @IBOutlet weak var ratedStatus: RatingImageView?
    @IBOutlet weak var hiddenStatus: HiddenImageView?
    @IBOutlet weak var droppedStatus: DroppedImageView?
    @IBOutlet weak var pinnedStatus: PinnedImageView?
    @IBOutlet weak var listedStatus: ListedImageView?

    override func awakeFromNib() {
        super.awakeFromNib()

        recommendedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchlistedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        toWatchStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        collectedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        commentedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        ratedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        hiddenStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        pinnedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        droppedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        listedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge

        pulseSymbol.addSymbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing,
                                    options: .repeat(.continuous))
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie:
                title.text = "Pulse"
                recommendedStatus?.media = media
                collectedStatus?.media = media
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                toWatchStatus?.isHidden = true
                commentedStatus?.media = media
                ratedStatus?.media = media
                hiddenStatus?.isHidden = true
                pinnedStatus?.media = media
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .show:
                title.text = "Pulse"
                recommendedStatus?.media = media
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                toWatchStatus?.media = media
                collectedStatus?.media = media
                commentedStatus?.isHidden = true
                ratedStatus?.media = media
                hiddenStatus?.media = media
                pinnedStatus?.media = media
                droppedStatus?.media = media
                listedStatus?.media = media
            case .episode:
                title.text = "Pulse"
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                recommendedStatus?.isHidden = true
                collectedStatus?.media = media
                toWatchStatus?.isHidden = true
                commentedStatus?.media = media
                ratedStatus?.media = media
                hiddenStatus?.isHidden = true
                pinnedStatus?.isHidden = true
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .season:
                title.text = "Pulse"
                recommendedStatus?.isHidden = true
                collectedStatus?.isHidden = true
                watchlistedStatus?.media = media
                watchedStatus?.isHidden = true
                toWatchStatus?.isHidden = true
                commentedStatus?.isHidden = true
                ratedStatus?.media = media
                hiddenStatus?.media = media
                pinnedStatus?.isHidden = true
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
        }
    }
}
