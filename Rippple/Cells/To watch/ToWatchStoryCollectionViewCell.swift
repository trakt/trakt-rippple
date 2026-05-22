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
    private let dateComponentsFormatter = DateComponentsFormatter()
    func updateLabel() {
        switch media! {
        case .movie(let movie):
            let releaseDate = dateFormatter.date(from: movie.released ?? "") ?? Date()

            if releaseDate.distance(to: Date.now) < 0 {
                days.text = "in \(dateComponentsFormatter.string(from: Date.now, to: releaseDate) ?? "X")"
            } else {
                days.text = "\(dateComponentsFormatter.string(from: releaseDate, to: Date.now) ?? "X") ago"
            }
        case .show:
            fatalError()
        case .episode(let episode, _):
            if let firstAired = episode.firstAired {
                if firstAired.distance(to: Date.now) < 0 {
                    days.text = "in \(dateComponentsFormatter.string(from: Date.now, to: firstAired) ?? "X")"
                } else {
                    days.text = "\(dateComponentsFormatter.string(from: firstAired, to: Date.now) ?? "X") ago"
                }
            }
        case .season:
            fatalError()
        case .list:
            fatalError()
        case .showProgress(_, let showProgress):
            if let nextToWatch = showProgress.nextEpisodeToWatch, let firstAired = nextToWatch.firstAired {
                if firstAired.distance(to: Date.now) < 0 {
                    days.text = "in \(dateComponentsFormatter.string(from: Date.now, to: firstAired) ?? "X")"
                } else {
                    days.text = "\(dateComponentsFormatter.string(from: firstAired, to: Date.now) ?? "X") ago"
                }
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

        dateComponentsFormatter.allowedUnits = [.second, .minute, .hour, .day]
        dateComponentsFormatter.maximumUnitCount = 1
        dateComponentsFormatter.unitsStyle = .short
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        dateComponentsFormatter.calendar = calendar

        maximumContentSizeCategory = .large
    }
}
