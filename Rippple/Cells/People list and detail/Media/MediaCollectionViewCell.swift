//
//  MediaCollectionViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

final class MediaCollectionViewCell: UICollectionViewCell {
    @IBOutlet var posterImageView: PosterImageView!
    @IBOutlet var mediaTitleLabel: UILabel!
    @IBOutlet var additionalInfoLabel: UILabel!

    var isRecentlyWatched = false

    private let dateComponentsFormatter = DateComponentsFormatter()

    override func awakeFromNib() {
        super.awakeFromNib()

        posterImageView.layer.cornerRadius = ViewRadius.medium.rawValue
        posterImageView.layer.cornerCurve = .continuous
        posterImageView.layer.masksToBounds = true
        posterImageView.layer.borderWidth = 1
        posterImageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        posterImageView.backgroundColor = UIColor.tertiarySystemFill

        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        dateComponentsFormatter.calendar = calendar
        dateComponentsFormatter.allowedUnits = [.second, .minute, .hour, .day, .month, .year]
        dateComponentsFormatter.maximumUnitCount = 1
        dateComponentsFormatter.unitsStyle = .short
    }

    var cast: Cast? {
        didSet {
            if let cast = cast {
                crew = nil
                mediaItem = nil

                additionalInfoLabel.isHidden = true
                mediaTitleLabel.isHidden = false

                if let movie = cast.movie {
                    mediaTitleLabel.text = movie.title
                    posterImageView.movie = movie
                    if isRecentlyWatched, let lastWatchedDate = cast.recentlyWatchedAt {
                        additionalInfoLabel.isHidden = false
                        if lastWatchedDate > Date.now {
                            additionalInfoLabel.text = "Just now..."
                        } else if lastWatchedDate.timeIntervalSince1970 == 0 {
                            additionalInfoLabel.text = "Unknown"
                        } else {
                            additionalInfoLabel.text = "\(dateComponentsFormatter.string(from: lastWatchedDate, to: Date.now) ?? "X") ago"
                        }
                    } else if let year = movie.releaseYear {
                        additionalInfoLabel.isHidden = false
                        additionalInfoLabel.text = "\(String(year))"
                    }
                } else if let show = cast.show {
                    mediaTitleLabel.text = show.title
                    posterImageView.show = show
                    if isRecentlyWatched, let lastWatchedDate = cast.recentlyWatchedAt {
                        additionalInfoLabel.isHidden = false
                        if lastWatchedDate > Date.now {
                            additionalInfoLabel.text = "Just now..."
                        } else {
                            additionalInfoLabel.text = "\(dateComponentsFormatter.string(from: lastWatchedDate, to: Date.now) ?? "X") ago"
                        }
                    } else if let episodeCount = cast.episodeCount {
                        additionalInfoLabel.isHidden = false
                        additionalInfoLabel.text = episodeCount <= 1 ? "\(episodeCount) episode" : "\(episodeCount) episodes"
                    }
                }
            }
        }
    }

    var crew: Job? {
        didSet {
            if let crew = crew {
                cast = nil
                mediaItem = nil

                mediaTitleLabel.isHidden = false
                additionalInfoLabel.isHidden = false
                additionalInfoLabel.text = crew.jobs.joined(separator: ", ")

                if let movie = crew.movie {
                    mediaTitleLabel.text = movie.title
                    posterImageView.movie = movie
//                    if let year = movie.releaseYear {
//                        additionalInfoLabel.isHidden = false
//                        additionalInfoLabel.text = "\(String(year))"
//                    }
                } else if let show = crew.show {
                    mediaTitleLabel.text = show.title
                    posterImageView.show = show
                }
            }
        }
    }

    var mediaItem: MediaItem? {
        didSet {
            if let mediaItem = mediaItem {
                cast = nil
                crew = nil

                additionalInfoLabel.isHidden = true
                mediaTitleLabel.isHidden = true

                if let movie = mediaItem.movie {
                    posterImageView.movie = movie
                } else if let show = mediaItem.show {
                    posterImageView.show = show
                }
            }
        }
    }
}
