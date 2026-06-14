//
//  PulsePreviewTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

final class PulsePreviewTableViewCell: UITableViewCell {
    @IBOutlet var card: CardView!

    @IBOutlet var pulseSymbol: UIImageView!
    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!

    @IBOutlet var recommendedStatus: RecommendedImageView?
    @IBOutlet var watchlistedStatus: WatchlistImageView?
    @IBOutlet var watchedStatus: WatchedImageView?
    @IBOutlet var toWatchStatus: ToWatchImageView?
    @IBOutlet var collectedStatus: CollectedImageView?
    @IBOutlet var commentedStatus: CommentedImageView?
    @IBOutlet var ratedStatus: RatingImageView?
    @IBOutlet var hiddenStatus: HiddenImageView?
    @IBOutlet var droppedStatus: DroppedImageView?
    @IBOutlet var pinnedStatus: PinnedImageView?
    @IBOutlet var listedStatus: ListedImageView?

    var cardType: CardType = .alone {
        didSet {
            card.cardType = cardType
        }
    }

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

    // MARK: - Subtitle

    private func updateSubtitle() {
        guard let media = media else {
            subtitle.isHidden = true
            return
        }
        let text = subtitleText(for: media)
        subtitle.text = text
        subtitle.isHidden = (text ?? "").isEmpty
    }

    private func subtitleText(for media: MediaModel) -> String? {
        switch media {
        case .movie(let movie):
            return subtitleForMovie(movie)
        case .show(let show):
            return subtitleForShow(show)
        case .episode(let episode, let show):
            return subtitleForEpisode(episode, show: show)
        case .season(let season, let show):
            return subtitleForSeason(season, show: show)
        case .list, .showProgress:
            return nil
        }
    }

    private func subtitleForMovie(_ movie: Movie) -> String? {
        var text: String?
        if let year = movie.releaseYear {
            text = "\(year)"
        }
        if let theatrical = subtitleForMovieTheatricalLine(movie) {
            text = theatrical
        }
        return text
    }

    private func subtitleForMovieTheatricalLine(_ movie: Movie) -> String? {
        guard let released = movie.released, let countryCode = movie.country else { return nil }
        guard let date = SubtitleFormatters.apiYMD.date(from: released) else { return nil }

        let country = Locale(identifier: "en_US").localizedCountry(for: countryCode)
        let dateString = SubtitleFormatters.movieDisplay.string(from: date)
        let isUpcoming = date.compare(Date()) == .orderedDescending
        if isUpcoming {
            return "Coming \(dateString) in \(country)"
        }
        return "Released \(dateString) in \(country)"
    }

    private func subtitleForShow(_ show: Show) -> String? {
        var text: String?
        if let year = show.releaseYear {
            text = "\(year)"
        }
        guard let status = show.status else { return text }

        switch status {
        case ShowTraktStatus.returningSeries:
            text = subtitleForReturningShow(show)
        case ShowTraktStatus.inProduction, ShowTraktStatus.planned:
            text = subtitleForPlannedOrInProductionShow(show)
        case ShowTraktStatus.canceled:
            text = showYearNetworkStatusLine(show: show, statusWord: "Canceled")
        case ShowTraktStatus.ended:
            text = showYearNetworkStatusLine(show: show, statusWord: "Ended")
        default:
            break
        }
        return text
    }

    private func subtitleForReturningShow(_ show: Show) -> String {
        if let network = show.network, let year = show.releaseYear {
            return "On \(network) since \(year)"
        }
        if let network = show.network {
            return network
        }
        if let year = show.releaseYear {
            return "Since \(year)"
        }
        return "Returning"
    }

    private func subtitleForPlannedOrInProductionShow(_ show: Show) -> String {
        if let firstAir = show.firstAired {
            let dateString = SubtitleFormatters.showFirstAir.string(from: firstAir)
            return dateString + subtitleNetworkSuffix(show.network)
        }
        if let network = show.network {
            return "Soon on \(network)"
        }
        return "Coming soon"
    }

    private func showYearNetworkStatusLine(show: Show, statusWord: String) -> String {
        var parts = [String]()
        if let year = show.releaseYear {
            parts.append("\(year)")
        }
        if let network = show.network {
            parts.append(network)
        }
        parts.append(statusWord)
        return parts.joined(separator: " · ")
    }

    private func subtitleForEpisode(_ episode: Episode, show: Show) -> String {
        guard let firstAired = episode.firstAired else {
            return "No air date"
        }
        let dateString = SubtitleFormatters.airDateTime.string(from: firstAired)
        let prefix = firstAired < Date() ? "Aired" : "Airs"
        return "\(prefix) \(dateString)" + subtitleNetworkSuffix(show.network)
    }

    private func subtitleForSeason(_ season: Season, show: Show) -> String {
        guard let firstAired = season.firstAired else {
            return "No premiere date"
        }
        let dateString = SubtitleFormatters.airDateTime.string(from: firstAired)
        let prefix = firstAired < Date() ? "Premiered" : "Premieres"
        return "\(prefix) \(dateString)" + subtitleNetworkSuffix(show.network)
    }

    private func subtitleNetworkSuffix(_ network: String?) -> String {
        guard let network = network, !network.isEmpty else { return "" }
        return " on \(network)"
    }

    private enum ShowTraktStatus {
        static let returningSeries = "returning series"
        static let inProduction = "in production"
        static let planned = "planned"
        static let canceled = "canceled"
        static let ended = "ended"
    }

    private enum SubtitleFormatters {
        private static let usLocale = Locale(identifier: "en_US")

        static let apiYMD: DateFormatter = {
            let f = DateFormatter()
            f.locale = usLocale
            f.dateFormat = "yyyy-MM-dd"
            return f
        }()

        static let movieDisplay: DateFormatter = {
            let f = DateFormatter()
            f.locale = usLocale
            f.dateFormat = "MMM d, yyyy"
            return f
        }()

        static let showFirstAir: DateFormatter = {
            let f = DateFormatter()
            f.locale = usLocale
            f.dateFormat = "MMM d, yyyy"
            return f
        }()

        static let airDateTime: DateFormatter = {
            let f = DateFormatter()
            f.locale = usLocale
            f.dateStyle = .medium
            f.timeStyle = .short
            return f
        }()
    }
}
