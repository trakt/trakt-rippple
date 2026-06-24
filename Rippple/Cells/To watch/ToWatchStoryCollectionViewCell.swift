//
//  ToWatchStoryCollectionViewCell.swift
//  ToWatchStoryCollectionViewCell
//
//  Created by Kevin Cador on 20/07/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

final class ToWatchStoryCollectionViewCell: UICollectionViewCell {
    @IBOutlet var days: UILabel!
    @IBOutlet var poster: PosterImageView!

    private let dateFormatter = DateFormatter()
    func updateLabel() {
        switch media! {
        case .movie(let movie):
            let releaseDate = dateFormatter.date(from: movie.released ?? "") ?? Date()
            days.text = CalendarRelativeDateFormatter.string(for: releaseDate, unitsStyle: .short)
        case .show:
            fatalError()
        case .episode(let episode, _):
            if let firstAired = episode.firstAired {
                days.text = CalendarRelativeDateFormatter.string(for: firstAired, unitsStyle: .short)
            }
        case .season:
            fatalError()
        case .list:
            fatalError()
        case .showProgress(_, let showProgress):
            if let nextToWatch = showProgress.nextEpisodeToWatch, let firstAired = nextToWatch.firstAired {
                days.text = CalendarRelativeDateFormatter.string(for: firstAired, unitsStyle: .short)
            }
        }
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                poster.movie = movie
                updateLabel()
            case .show:
                fatalError()
            case .episode(_, let show):
                poster.show = show
                updateLabel()
            case .season:
                fatalError()
            case .list:
                fatalError()
            case .showProgress(let show, _):
                poster.show = show
                updateLabel()
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        poster.layer.cornerRadius = ViewRadius.medium.rawValue
        poster.layer.cornerCurve = .continuous
        poster.layer.masksToBounds = true
        poster.layer.borderWidth = 1
        poster.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        poster.backgroundColor = UIColor.tertiarySystemFill

        dateFormatter.dateFormat = "yyyy-MM-dd"

        maximumContentSizeCategory = .large
    }
}
