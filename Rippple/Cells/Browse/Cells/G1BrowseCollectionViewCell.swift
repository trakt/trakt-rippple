//
//  G1BrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 18/01/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit

final class G1BrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backdrop: BackdropImageView!

    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!
    @IBOutlet weak var meta: UILabel!

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                backdrop.media = media
                title.text = movie.title
                if let releaseYear = movie.releaseYear {
                    subtitle.text = "\(releaseYear)"
                    subtitle.isHidden = false
                } else {
                    subtitle.isHidden = true
                }
                if let genres = movie.genres {
                    meta.text = genres.joined(separator: ", ").capitalized
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .show(let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                if let status = show.status {
                    subtitle.text = "\(status.capitalized)"
                    subtitle.isHidden = false
                } else {
                    subtitle.isHidden = true
                }
                if let airedEpisodes = show.airedEpisodes {
                    meta.text = "\(airedEpisodes) episode\((airedEpisodes > 1 ? "s" : ""))"
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .episode(let episode, let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                subtitle.text = episode.localizedEpisodeNumber
                subtitle.isHidden = false
                if let episodeTitle = episode.title {
                    meta.text = episodeTitle
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .season(let season, let show):
                backdrop.media = show.mediaModel
                title.text = show.title
                subtitle.text = season.title ?? "Season \(season.number)"
                subtitle.isHidden = false
                if let airedEpisodes = season.airedEpisodes {
                    meta.text = "\(airedEpisodes) episode\((airedEpisodes > 1 ? "s" : ""))"
                    meta.isHidden = false
                } else {
                    meta.isHidden = true
                }
            case .showProgress(let show, let progress):
                backdrop.showEpisodeSpoilers = UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle")
                title.text = show.title

                if let episode = progress.nextEpisodeToWatch {
                    backdrop.media = episode.mediaModel(given: show)
                } else {
                    backdrop.media = show.mediaModel
                }

                if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true, let title = progress.nextEpisodeToWatch!.title {
                    subtitle.text = "\(progress.nextEpisodeToWatch!.localizedEpisodeNumber) - \(title)"
                } else {
                    subtitle.text = progress.nextEpisodeToWatch!.localizedEpisodeNumber
                }

                if progress.toRewatchCount > 0 {
                    meta.text = "\(progress.toRewatchCount) to rewatch"
                } else {
                    let behind = progress.behind
                    if behind > 0 {
                        meta?.text = "\(behind) behind"
                    } else {
                        meta?.text = "At least one behind"
                    }
                }
            default:
                fatalError("Case not handled")
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backdrop.layer.cornerRadius = ViewRadius.large.rawValue
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.backgroundColor = UIColor.tertiarySystemFill
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        let colorEnd =  UIColor.clear.cgColor
        let colorStart = UIColor.black.withAlphaComponent(0.9).cgColor

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [colorStart, colorEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.frame = backdrop.bounds

        backdrop.layer.addSublayer(gradientLayer)

        title.layer.shadowColor = UIColor.black.cgColor
        title.layer.shadowRadius = 2.0
        title.layer.shadowOpacity = 0.7
        title.layer.shadowOffset = .zero
        title.layer.masksToBounds = false

        subtitle.layer.shadowColor = UIColor.black.cgColor
        subtitle.layer.shadowRadius = 2.0
        subtitle.layer.shadowOpacity = 0.7
        subtitle.layer.shadowOffset = .zero
        subtitle.layer.masksToBounds = false

        meta.layer.shadowColor = UIColor.black.cgColor
        meta.layer.shadowRadius = 2.0
        meta.layer.shadowOpacity = 0.7
        meta.layer.shadowOffset = .zero
        meta.layer.masksToBounds = false
    }
}
