//
//  C1BrowseCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 28/06/2023.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class C1BrowseCollectionViewCell: UICollectionViewCell {
    @IBOutlet var backdrop: BackdropImageView!
    @IBOutlet var logo: LogoImageView?

    @IBOutlet var playButton: UIButton?

    var notes: String?
    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie:
                backdrop.media = media
                logo?.media = media
            case .show(let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            case .episode(_, let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            case .season(_, let show):
                let media = show.mediaModel
                backdrop.media = media
                logo?.media = media
            default:
                fatalError("Case not handled")
            }

            if let notes = notes, URL(string: notes) != nil {
                playButton?.layer.shadowOffset = CGSize(width: 0, height: 0)
                playButton?.layer.shadowOpacity = 1.0
                playButton?.layer.shadowRadius = 5.0
                playButton?.isHidden = false
            } else {
                playButton?.isHidden = true
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

        if let logo = logo {
            backdrop.addSubview(logo)

            logo.clipsToBounds = false
            logo.layer.masksToBounds = false
            logo.layer.shadowColor = UIColor.black.cgColor
            logo.layer.shadowOffset = CGSize(width: 0, height: 0)
            logo.layer.shadowOpacity = 1.0
            logo.layer.shadowRadius = 5.0
        }
    }

    @IBAction func playTrailer(_ sender: Any) {
        guard let notes = notes, let url = URL(string: notes) else { return }
        UIApplication.shared.open(url)
    }
}
