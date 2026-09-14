//
//  MediaBackdropTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 22/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class MediaBackdropTableViewCell: TintedCanvasTableViewCell {
    let (backdropDownloadResultTransmitter, backdropDownloadResultReceiver) = Receiver<Bool>.make(with: .hot)

    var media: MediaModel! {
        didSet {
            let media = media!
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.media == media else { return }
                switch media {
                case .movie:
                    self.backPreviewBackdropImageView.media = media
                    self.backBackdropImageView.media = media
                case .show:
                    self.backPreviewBackdropImageView.media = media
                    self.backBackdropImageView.media = media
                case .episode(let episode, _):
                    let redactsEpisodeImages =
                        UserDefaults.standard.bool(forKey: "GeneralSettings.episodeImageSpoilers")
                    self.backPreviewBackdropImageView.showEpisodeSpoilers = redactsEpisodeImages == false
                    self.backPreviewBackdropImageView.media = media
                    self.backBackdropImageView.showEpisodeSpoilers = redactsEpisodeImages == false
                    self.backBackdropImageView.media = media

                    guard redactsEpisodeImages else { return }
                    media.progress { [weak self] progress in
                        guard let self = self else { return }

                        var episodeIsWatched = false
                        if let progress = progress {
                            for season in progress.seasons where season.number == episode.season {
                                for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                                    episodeIsWatched = episodeProgress.completed
                                }
                            }
                        }

                        DispatchQueue.main.async {
                            guard self.media == media else { return }
                            let showsEpisodeImage =
                                UserDefaults.standard.bool(forKey: "GeneralSettings.episodeImageSpoilers") == false ||
                                episodeIsWatched
                            self.backBackdropImageView.showEpisodeSpoilers = showsEpisodeImage
                            self.backBackdropImageView.media = media
                        }
                    }
                case .season:
                    self.backPreviewBackdropImageView.media = media
                    self.backBackdropImageView.media = media
                case .list:
                    fatalError()
                case .showProgress:
                    fatalError()
                }
            }
        }
    }

    @IBOutlet var backPreviewBackdropImageView: BackdropImageView!
    @IBOutlet var backBackdropImageView: BackdropImageView!

    @IBOutlet var loadingIndicator: NVActivityIndicatorView!

    @IBOutlet var cardView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()

        loadingIndicator.tintColor = UIColor(asset: .globalTint)
        loadingIndicator.startAnimating()

        backPreviewBackdropImageView.layer.cornerRadius = ViewRadius.large.rawValue
        backPreviewBackdropImageView.layer.cornerCurve = .continuous
        backPreviewBackdropImageView.layer.masksToBounds = true
        backPreviewBackdropImageView.overrideBackgroundColor = UIColor.clear

        backBackdropImageView.layer.cornerRadius = ViewRadius.large.rawValue
        backBackdropImageView.layer.cornerCurve = .continuous
        backBackdropImageView.layer.masksToBounds = true
        backBackdropImageView.overrideBackgroundColor = UIColor.clear

        backPreviewBackdropImageView.scale = 0.3

        backBackdropImageView.completion = { [weak self] result in
            guard let self = self else { return }
            if result {
                self.backdropDownloadResultTransmitter.broadcast(true)
            } else {
                self.backdropDownloadResultTransmitter.broadcast(false)
            }
        }
    }
}
