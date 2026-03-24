//
//  PulsePreviewTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

final class PulsePreviewTableViewCell: UITableViewCell {
    @IBOutlet weak var pulseSymbol: UIImageView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel!

    @IBOutlet weak var recommendedStatus: RecommendedImageView?
    @IBOutlet weak var watchlistedStatus: WatchlistImageView?
    @IBOutlet weak var watchedStatus: WatchedImageView?
    @IBOutlet weak var toWatchStatus: ToWatchImageView?
    @IBOutlet weak var collectedStatus: CollectedImageView?
    @IBOutlet weak var commentedStatus: CommentedImageView?
    @IBOutlet weak var ratedStatus: RatingImageView?
    @IBOutlet weak var hiddenStatus: HiddenImageView?
    @IBOutlet weak var droppedStatus: DroppedImageView?
    @IBOutlet weak var pinnedStatus: PinnedImageView?
    @IBOutlet weak var listedStatus: ListedImageView?

    override func awakeFromNib() {
        super.awakeFromNib()

        recommendedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchlistedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        watchedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        toWatchStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        collectedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        commentedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        ratedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        hiddenStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        pinnedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        droppedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge
        listedStatus?.maximumContentSizeCategory = .extraExtraExtraLarge

        pulseSymbol.addSymbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing,
                                    options: .repeat(.continuous))
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie:
                title.text = "Pulse"
                recommendedStatus?.media = media
                collectedStatus?.media = media
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                toWatchStatus?.isHidden = true
                commentedStatus?.media = media
                ratedStatus?.media = media
                hiddenStatus?.isHidden = true
                pinnedStatus?.media = media
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .show:
                title.text = "Pulse"
                recommendedStatus?.media = media
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                toWatchStatus?.media = media
                collectedStatus?.media = media
                commentedStatus?.isHidden = true
                ratedStatus?.media = media
                hiddenStatus?.media = media
                pinnedStatus?.media = media
                droppedStatus?.media = media
                listedStatus?.media = media
            case .episode:
                title.text = "Pulse"
                watchlistedStatus?.media = media
                watchedStatus?.media = media
                recommendedStatus?.isHidden = true
                collectedStatus?.media = media
                toWatchStatus?.isHidden = true
                commentedStatus?.media = media
                ratedStatus?.media = media
                hiddenStatus?.isHidden = true
                pinnedStatus?.isHidden = true
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .season:
                title.text = "Pulse"
                recommendedStatus?.isHidden = true
                collectedStatus?.isHidden = true
                watchlistedStatus?.media = media
                watchedStatus?.isHidden = true
                toWatchStatus?.isHidden = true
                commentedStatus?.isHidden = true
                ratedStatus?.media = media
                hiddenStatus?.media = media
                pinnedStatus?.isHidden = true
                droppedStatus?.isHidden = true
                listedStatus?.media = media
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
            updateSubtitle()
        }
    }

    private func updateSubtitle() {
        guard let media = media else {
            subtitle.isHidden = true
            return
        }

        var infoText: String?

        switch media {
        case .movie(let movie):
            if let releaseYear = movie.releaseYear {
                infoText = "\(releaseYear)"
            }

            hasDate: if let released = movie.released, let country = movie.country {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.dateFormat = "yyyy-MM-dd"
                guard let date = dateFormatter.date(from: released) else { break hasDate }
                let localizedCountry = Locale(identifier: "en_US").localizedCountry(for: country)
                dateFormatter.dateFormat = "MMM d, yyyy"
                if date.compare(Date()) == .orderedDescending {
                    infoText = "Coming \(dateFormatter.string(from: date)) in \(localizedCountry)"
                } else {
                    infoText = "Released on \(dateFormatter.string(from: date)) in \(localizedCountry)"
                }
            }
        case .show(let show):
            if let releaseYear = show.releaseYear {
                infoText = "\(releaseYear)"
            }

            if let status = show.status {
                var onNetwork = ""
                if let network = show.network {
                    onNetwork += "on \(network)"
                }

                var sinceYear = ""
                if let releaseYear = show.releaseYear {
                    sinceYear = "since \(releaseYear)"
                }

                if status == "returning series" {
                    infoText = "Airing \(onNetwork) \(sinceYear)"
                } else if status == "in production" || status == "planned" {
                    if let firstAirDate = show.firstAired {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "MMM d, yyyy"
                        infoText = "Coming \(dateFormatter.string(from: firstAirDate)) \(onNetwork)"
                    } else {
                        infoText = "Coming soon \(onNetwork)"
                    }
                } else if status == "canceled" {
                    var info = [String]()
                    if let releaseYear = show.releaseYear {
                        info.append("\(releaseYear)")
                    }
                    if let network = show.network {
                        info.append(network)
                    }
                    info.append("Canceled")
                    infoText = info.joined(separator: " · ")
                } else if status == "ended" {
                    var info = [String]()
                    if let releaseYear = show.releaseYear {
                        info.append("\(releaseYear)")
                    }
                    if let network = show.network {
                        info.append(network)
                    }
                    info.append("Ended")
                    infoText = info.joined(separator: " · ")
                }
            }
        case .episode(let episode, let show):
            var onNetwork = ""
            if let network = show.network {
                onNetwork += "on \(network)"
            }

            if let firstAired = episode.firstAired {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                if firstAired < Date() {
                    infoText = "Aired \(dateFormatter.string(from: firstAired)) \(onNetwork)"
                } else {
                    infoText = "Will air \(dateFormatter.string(from: firstAired)) \(onNetwork)"
                }
            } else {
                infoText = "Missing air date"
            }
        case .season(let season, let show):
            var onNetwork = ""
            if let network = show.network {
                onNetwork += "on \(network)"
            }

            if let firstAired = season.firstAired {
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                if firstAired < Date() {
                    infoText = "First aired \(dateFormatter.string(from: firstAired)) \(onNetwork)"
                } else {
                    infoText = "Will first air \(dateFormatter.string(from: firstAired)) \(onNetwork)"
                }
            } else {
                infoText = "Missing first air date"
            }
        case .list, .showProgress:
            return
        }

        subtitle.text = infoText
        subtitle.isHidden = infoText?.isEmpty != false
    }
}
