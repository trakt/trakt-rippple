//
//  MediaPosterTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class MediaPosterTableViewCell: UITableViewCell {
    let (posterDownloadResultTransmitter, posterDownloadResultReceiver) = Receiver<Bool>.make(with: .hot)

    var media: MediaModel! {
        didSet {
            previewPosterImageView.scale = 0.5
            blurryPosterImageView.scale = 0.25
            posterImageView.isUserInteractionEnabled = false
            switch media! {
            case .movie(let movie):
                previewPosterImageView.movie = movie
                posterImageView.movie = movie
                blurryPosterImageView.movie = movie
            case .show(let show):
                previewPosterImageView.show = show
                posterImageView.show = show
                blurryPosterImageView.show = show
            case .episode(_, let show):
                previewPosterImageView.show = show
                posterImageView.show = show
                blurryPosterImageView.show = show
            case .season(let season, let show):
                previewPosterImageView.season = (show, season)
                posterImageView.season = (show, season)
                blurryPosterImageView.season = (show, season)
            case .list:
                fatalError()
            case .showProgress(let show, _):
                previewPosterImageView.show = show
                posterImageView.show = show
                blurryPosterImageView.show = show
            }
        }
    }

    @IBOutlet var previewPosterImageView: PosterImageView!
    @IBOutlet var posterImageView: PosterImageView!
    @IBOutlet var blurryPosterImageView: PosterImageView!
    @IBOutlet var loadingIndicator: NVActivityIndicatorView!

    @IBOutlet var cardView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.startAnimating()

        previewPosterImageView.layer.cornerRadius = ViewRadius.large.rawValue
        previewPosterImageView.layer.cornerCurve = .continuous
        previewPosterImageView.layer.masksToBounds = true
        previewPosterImageView.overrideBackgroundColor = UIColor.clear

        blurryPosterImageView.superview!.layer.cornerRadius = ViewRadius.large.rawValue
        blurryPosterImageView.superview!.layer.cornerCurve = .continuous
        blurryPosterImageView.superview!.layer.masksToBounds = true
        blurryPosterImageView.isBlurred = true
        blurryPosterImageView.overrideBackgroundColor = UIColor.clear

        posterImageView.layer.cornerRadius = ViewRadius.large.rawValue
        posterImageView.layer.cornerCurve = .continuous
        posterImageView.layer.masksToBounds = true
        posterImageView.overrideBackgroundColor = UIColor.clear
        posterImageView.transitionDuration = 0.25

        posterImageView.isUserInteractionEnabled = false
        posterImageView.completion = { [weak self] result in
            guard let self = self else { return }
            self.posterImageView.isUserInteractionEnabled = true
            if result {
                self.posterDownloadResultTransmitter.broadcast(true)
            } else {
                self.posterDownloadResultTransmitter.broadcast(false)
            }
        }
    }
}
