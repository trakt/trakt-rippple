//
//  MediaBackdropTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 22/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class MediaBackdropTableViewCell: UITableViewCell {
    let (backdropDownloadResultTransmitter, backdropDownloadResultReceiver) = Receiver<Bool>.make(with: .hot)

    var media: MediaModel! {
        didSet {
            if media == oldValue { return }
            DispatchQueue.main.async {
                switch self.media! {
                case .movie:
                    self.backPreviewBackdropImageView.media = self.media
                    self.backBackdropImageView.media = self.media
                case .show:
                    self.backPreviewBackdropImageView.media = self.media
                    self.backBackdropImageView.media = self.media
                case .episode(let episode, let show):
                    if UserDefaults.standard.bool(forKey: "GeneralSettings.detailepisodetitle") {
                        self.backPreviewBackdropImageView.showEpisodeSpoilers = true
                        self.backPreviewBackdropImageView.media = self.media
                        self.backBackdropImageView.showEpisodeSpoilers = true
                        self.backBackdropImageView.media = self.media
                    } else {
                        self.backPreviewBackdropImageView.showEpisodeSpoilers = false
                        self.backPreviewBackdropImageView.media = show.mediaModel
                        self.media.progress { [weak self] progress in
                            guard let self = self else { return }
                            if let progress = progress {
                                for season in progress.seasons where season.number == episode.season {
                                    for episodeProgress in season.episodes where episodeProgress.number == episode.number {
                                        DispatchQueue.main.async {
                                            if episodeProgress.completed {
                                                DispatchQueue.main.async {
                                                    self.backBackdropImageView.showEpisodeSpoilers = true
                                                    self.backBackdropImageView.media = self.media
                                                }
                                            } else {
                                                DispatchQueue.main.async {
                                                    self.backBackdropImageView.showEpisodeSpoilers = false
                                                    self.backBackdropImageView.media = show.mediaModel
                                                }
                                            }
                                        }
                                        return
                                    }
                                }
                            }
                            DispatchQueue.main.async {
                                self.backBackdropImageView.showEpisodeSpoilers = false
                                self.backBackdropImageView.media = show.mediaModel
                            }
                        }
                    }
                case .season:
                    self.backPreviewBackdropImageView.media = self.media
                    self.backBackdropImageView.media = self.media
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
