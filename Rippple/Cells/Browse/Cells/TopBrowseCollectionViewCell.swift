//
//  TopBrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 02/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

final class TopBrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var backdrop: BackdropImageView!
    @IBOutlet weak var logo: LogoImageView!
    @IBOutlet weak var rank: UILabel?
    @IBOutlet weak var label: UILabel?
    @IBOutlet weak var sublabel: UILabel?

    var notes: String?
    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                backdrop.media = media
                logo.media = media
                label?.text = movie.title
                var info = [String]()
                if let notes = notes {
                    sublabel?.text = notes
                } else {
                    if let genres = movie.genres, !genres.isEmpty {
                        sublabel?.text = genres.joined(separator: ", ")
                    } else if let release = movie.releaseYear {
                        info.append("\(release)")
                        if let status = movie.status, status != "released" {
                            info.append(status)
                        }
                        sublabel?.text = info.joined(separator: " · ")
                    }
                }
            case .show(let show), .season(_, let show), .episode(_, let show):
                let media = show.mediaModel
                backdrop.media = media
                logo.media = media
                label?.text = show.title
                var info = [String]()
                if let airedEpisodes = show.airedEpisodes, airedEpisodes != 0 {
                    info.append("\(airedEpisodes) episode\((airedEpisodes > 1 ? "s" : ""))")
                } else if let release = show.releaseYear {
                    info.append("\(release)")
                }
                if let status = show.status, status != "returning series" {
                    info.append(status)
                }
                if let notes = notes {
                    sublabel?.text = notes
                } else {
                    sublabel?.text = info.joined(separator: " · ")
                }
            case .list, .showProgress:
                fatalError("This type is not handled")
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        backdrop.addSubview(logo)

        backdrop.layer.cornerRadius = ViewRadius.large.rawValue
        backdrop.layer.cornerCurve = .continuous
        backdrop.layer.masksToBounds = true
        backdrop.backgroundColor = UIColor.tertiarySystemFill
        backdrop.layer.borderWidth = 1
        backdrop.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        logo.clipsToBounds = false
        logo.layer.masksToBounds = false
        logo.layer.shadowColor = UIColor.black.cgColor
        logo.layer.shadowOffset = CGSize(width: 0, height: 0)
        logo.layer.shadowOpacity = 1.0
        logo.layer.shadowRadius = 5.0

        if let rank = rank, let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .extraLargeTitle2)
            .withDesign(.rounded) {
            rank.font = UIFont(descriptor: descriptor, size: 48)
        }

        maximumContentSizeCategory = .extraExtraExtraLarge
    }
}
