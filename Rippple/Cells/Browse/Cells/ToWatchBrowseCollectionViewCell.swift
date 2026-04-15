//
//  ToWatchBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class ToWatchBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backdrop: BackdropImageView!
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var sublabel: UILabel?
    @IBOutlet weak var pinned: UIImageView?

    var media: MediaModel! {
        didSet {
            switch media! {
            case .showProgress(let show, let progress):
                label?.text = show.title
                pinned?.isHidden = !show.isPinned
                backdrop.showEpisodeSpoilers = UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle")
                if let episode = progress.nextEpisodeToWatch {
                    backdrop.media = episode.mediaModel(given: show)
                } else {
                    backdrop.media = show.mediaModel
                }
                if let nextEpisodeToWatch = progress.nextEpisodeToWatch {
                    if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true, let title = nextEpisodeToWatch.title {
                        sublabel?.text = "\(nextEpisodeToWatch.localizedEpisodeNumber) - \(title)"
                    } else {
                        sublabel?.text = nextEpisodeToWatch.localizedEpisodeNumber
                    }
                } else {
                    sublabel?.text = ""
                }
            case .list, .show, .season, .episode, .movie:
                fatalError("This type is not handled")
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

        backdrop.completion = { [weak self] result in
            guard let self = self else { return }
            // if we tried to load the episode backdrop and it hasn't loaded anything (no image for episode -> fallback to loading show image
            if self.backdrop.media?.episode != nil {
                if result == false {
                    switch media! {
                    case .showProgress(let show, _):
                        self.backdrop.media = show.mediaModel
                    case .list, .show, .season, .episode, .movie:
                        fatalError("This type is not handled")
                    }
                }
            }
        }

        maximumContentSizeCategory = .extraExtraExtraLarge
    }
}

final class StandardHistoryBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backdrop: BackdropImageView!
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var sublabel: UILabel?

    var media: MediaModel! {
        didSet {
            switch media! {
            case .list, .show, .season, .showProgress:
                fatalError("This type is not handled")
            case .episode(let episode, let show):
                label?.text = show.title
                backdrop.showEpisodeSpoilers = true
                backdrop.media = media
                if let title = episode.title {
                    sublabel?.text = episode.localizedEpisodeNumber + " · \(title)"
                } else {
                    sublabel?.text = episode.localizedEpisodeNumber
                }
            case .movie(let movie):
                label?.text = movie.title
                backdrop.media = media
                var info = [String]()
                if let release = movie.releaseYear {
                    info.append("\(release)")
                }
                if let status = movie.status, status != "released" {
                    info.append(status)
                }
                sublabel?.text = info.joined(separator: " · ")
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

        backdrop.completion = { [weak self] result in
            guard let self = self else { return }
            // if we tried to load the episode backdrop and it hasn't loaded anything (no image for episode -> fallback to loading show image

            if result == false {
                switch media! {
                case .episode(_, let show):
                    if self.backdrop.media?.episode != nil {
                        self.backdrop.media = show.mediaModel
                    }
                case .movie:
                    break
                case .list, .show, .season, .showProgress:
                    fatalError("This type is not handled")
                }
            }
        }

        maximumContentSizeCategory = .extraExtraExtraLarge
    }
}
