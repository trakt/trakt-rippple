//
//  RatingsTableViewCell
//  Rippple
//
//  Created by Kevin Cador on 26/10/2018.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class RatingsTableViewCell: TintedCanvasTableViewCell {
    private let disposeBag = DisposeBag()

    @IBOutlet var rating: EFCountingLabel!
    @IBOutlet var votes: EFCountingLabel!

    @IBOutlet var distributionBars: [UIView]!
    @IBOutlet var distributionHeightConstant: [NSLayoutConstraint]!
    @IBOutlet var ratingLabel: [UILabel]!

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var moreAction: UIButton!
    @IBOutlet var rateAction: UIButton!

    /** External Ratings */
    @IBOutlet var rottenTomatoesCriticsStack: UIStackView!

    @IBOutlet var rottenTomatoesCriticsRating: EFCountingLabel!
    @IBOutlet var rottentTomatoesCriticsImage: UIButton!

    @IBOutlet var rottenTomatoesAudienceStack: UIStackView!

    @IBOutlet var rottenTomatoesAudienceRating: EFCountingLabel!
    @IBOutlet var rottenTomatoesAudienceImage: UIButton!

    @IBOutlet var imdbStack: UIStackView!

    @IBOutlet var imdbRating: EFCountingLabel!
    @IBOutlet var imdbVotes: EFCountingLabel!
    @IBOutlet var imdbImage: UIButton!

    @IBOutlet var metacriticStack: UIStackView!

    @IBOutlet var metacriticRating: EFCountingLabel!
    @IBOutlet var metacriticLabel: UILabel!
    @IBOutlet var metacriticImage: UIButton!

    @IBOutlet var tmdbStack: UIStackView!

    @IBOutlet var tmdbRating: EFCountingLabel!
    @IBOutlet var tmdbVotes: EFCountingLabel!
    @IBOutlet var tmdbImage: UIButton!

    @IBOutlet var letterboxdStack: UIStackView!

    @IBOutlet var letterboxdRating: EFCountingLabel!
    @IBOutlet var letterboxdVotes: EFCountingLabel!
    @IBOutlet var letterboxdImage: UIButton!

    @IBOutlet var malStack: UIStackView!

    @IBOutlet var malRating: EFCountingLabel!
    @IBOutlet var malVotes: EFCountingLabel!
    @IBOutlet var malImage: UIButton!

    private let votesFormatter: NumberFormatter = .init()

    override func awakeFromNib() {
        super.awakeFromNib()

        votesFormatter.numberStyle = .decimal

        for label in countingLabels {
            label.method = .easeInOut
        }
        for label in [votes, imdbVotes, tmdbVotes, letterboxdVotes, malVotes] {
            label?.formatBlock = { [weak self] value in
                guard let self = self else { return "0 vote" }
                return "\(self.votesFormatter.string(from: NSNumber(value: Int(value))) ?? "0") \(value > 1 ? "votes" : "vote")"
            }
        }
        rating.format = "%d"
        for label in [rottenTomatoesCriticsRating, rottenTomatoesAudienceRating, metacriticRating, tmdbRating] {
            label?.formatBlock = { value in
                String(format: "%02d", Int(value))
            }
        }
        imdbRating.format = "%.1f"
        letterboxdRating.format = "%.1f"
        malRating.format = "%.2f"
        resetRatings()

        for bar in distributionBars {
            bar.backgroundColor = #colorLiteral(red: 0.737254902, green: 0.7333333333, blue: 0.7568627451, alpha: 1)
            bar.layer.cornerRadius = bar.layer.frame.size.width / 2.0
        }

        RatingsManager.shared.onRatedItemsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateBarColorBasedOnUserRating()
        }.disposed(by: disposeBag)

        maximumContentSizeCategory = .large
        moreAction.maximumContentSizeCategory = .extraExtraLarge
    }

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    weak var viewController: UIViewController?

    var media: MediaModel? {
        didSet {
            guard let media = media else {
                cancelCancellable()
                resetRatings()
                return
            }
            rateAction.menu = media.rateMenu
            rateAction.showsMenuAsPrimaryAction = true
            switch media {
            case .episode, .season, .show:
                moreAction.enumerateEventHandlers { action, _, event, _ in
                    if let action = action {
                        moreAction.removeAction(action, for: event)
                    }
                }
                moreAction.addAction(UIAction { [weak self] _ in
                    guard let self = self else { return }
                    guard let viewController = self.viewController else { return }
                    viewController.performSegue(withIdentifier: "ratings", sender: nil)
                    UISelectionFeedbackGenerator().selectionChanged()
                }, for: .touchUpInside)
            default:
                moreAction.enumerateEventHandlers { action, _, event, _ in
                    if let action = action {
                        moreAction.removeAction(action, for: event)
                    }
                }
                moreAction.alpha = 0
            }

            switch media {
            case .episode:
                titleLabel.text = "Episode Ratings"
            case .season:
                titleLabel.text = "Season Ratings"
            case .show:
                titleLabel.text = "Show Ratings"
            case .movie:
                titleLabel.text = "Movie Ratings"
            default:
                titleLabel.text = "Trakt Ratings"
            }

            updateBarColorBasedOnUserRating()

            if media == oldValue { return }
            update(with: media)
        }
    }

    private func updateBarColorBasedOnUserRating() {
        if let media = media {
            for bar in distributionBars {
                if bar.tag == media.userRating {
                    bar.backgroundColor = UIColor(asset: .globalTint)
                } else {
                    bar.backgroundColor = #colorLiteral(red: 0.737254902, green: 0.7333333333, blue: 0.7568627451, alpha: 1)
                }
            }
            for label in ratingLabel {
                if label.tag == media.userRating {
                    label.textColor = UIColor(asset: .globalTint)
                } else {
                    label.textColor = .secondaryLabel
                }
            }
        }
    }

    private func update(with media: MediaModel) {
        resetRatings()
        rating.text = "0"
        votes.isHidden = false
        votes.text = "Loading..."
        switch media {
        case .movie(let movie):
            cancellable = fetchRatingsFor(type: .movie(movieId: movie.identifiers.trakt!))
        case .show(let show):
            cancellable = fetchRatingsFor(type: .show(showId: show.identifiers.trakt!))
        case .episode(let episode, let show):
            cancellable = fetchRatingsFor(type: .episode(showId: show.identifiers.trakt!,
                                                         season: episode.season,
                                                         episode: episode.number))
        case .season(let season, let show):
            cancellable = fetchRatingsFor(type: .season(showId: show.identifiers.trakt!,
                                                        season: season.number))
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    private func updateDistributionWith(distribution: RatingDistribution) {
        let requestedMedia = media
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            guard let self = self, self.media == requestedMedia else { return }
            let values = [distribution.one,
                          distribution.two,
                          distribution.three,
                          distribution.four,
                          distribution.five,
                          distribution.six,
                          distribution.seven,
                          distribution.eight,
                          distribution.nine,
                          distribution.ten]
            let max = values.max()
            if let max = max, max > 0 {
                UIView.animate(withDuration: 0.7,
                               delay: 0,
                               options: [.curveEaseInOut, .allowUserInteraction],
                               animations: { [weak self] in
                                   guard let self = self else { return }
                                   for constant in self.distributionHeightConstant {
                                       let votes = values[Int(constant.identifier!)! - 1]
                                       let proportion = CGFloat(votes) / CGFloat(max)
                                       let height = self.distributionBars.first!.superview!.frame.size.height
                                       constant.constant = height * proportion
                                   }
                                   for bar in self.distributionBars {
                                       bar.superview!.layoutIfNeeded()
                                   }
                               })
            }
        }
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        media = nil
    }

    private var countingLabels: [EFCountingLabel] {
        [rating, votes, rottenTomatoesCriticsRating, rottenTomatoesAudienceRating,
         imdbRating, imdbVotes, metacriticRating, tmdbRating, tmdbVotes,
         letterboxdRating, letterboxdVotes, malRating, malVotes]
    }

    private func resetRatings() {
        for stack in [rottenTomatoesCriticsStack, rottenTomatoesAudienceStack, imdbStack,
                      malStack, letterboxdStack, metacriticStack, tmdbStack] {
            stack?.isHidden = true
        }
        for button in [rottentTomatoesCriticsImage, rottenTomatoesAudienceImage, imdbImage,
                       malImage, letterboxdImage, metacriticImage, tmdbImage] {
            button?.enumerateEventHandlers { action, _, event, _ in
                if let action = action {
                    button?.removeAction(action, for: event)
                }
            }
        }
        for label in countingLabels {
            label.countFrom(0, to: 0, withDuration: 0)
            label.text = nil
            label.accessibilityValue = nil
        }
        metacriticLabel.text = nil
        for constant in distributionHeightConstant {
            constant.constant = 0
        }
    }

    @discardableResult
    private func updateRating(_ value: Float?, label: EFCountingLabel, name: String, maximum: Float) -> Bool {
        guard let value = value, value.isFinite, (0...maximum).contains(value) else { return false }
        label.countFrom(0, to: CGFloat(value), withDuration: 0.7)
        label.accessibilityLabel = "\(name) rating"
        let formattedValue = label.formatBlock?(CGFloat(value)) ?? (label.format.contains("%d")
            ? String(format: label.format, Int(value))
            : String(format: label.format, Double(value)))
        label.accessibilityValue = "\(formattedValue) out of \(Int(maximum))"
        return true
    }

    private func updateVotes(_ count: Int?, label: EFCountingLabel) {
        label.isHidden = true
        guard let count = count, count >= 0 else { return }
        label.isHidden = false
        label.countFrom(0, to: CGFloat(count), withDuration: 0.7)
    }

    private func updateExternalRating(_ value: Float?, count: Int? = nil, link: URL?, stack: UIStackView,
                                      rating: EFCountingLabel, votes: EFCountingLabel? = nil,
                                      image: UIButton, name: String, maximum: Float) {
        guard updateRating(value, label: rating, name: name, maximum: maximum) else { return }
        stack.isHidden = false
        if let votes = votes {
            updateVotes(count, label: votes)
        }
        image.accessibilityLabel = name
        image.isUserInteractionEnabled = false
        guard let link = link else { return }
        let resolvedURL = link.scheme == nil ? URL(string: "https://\(link.absoluteString)") : link
        guard let url = resolvedURL, let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme), url.host != nil else { return }
        image.isUserInteractionEnabled = true
        image.addAction(UIAction { _ in
            UIApplication.shared.open(url)
        }, for: .touchUpInside)
    }

    private func updateRatings(_ ratings: Ratings) {
        updateRating(round(ratings.trakt.rating * 10), label: rating, name: "Trakt", maximum: 100)
        updateVotes(ratings.trakt.votes, label: votes)
        updateDistributionWith(distribution: ratings.trakt.distribution)

        updateExternalRating(ratings.rottenTomatoes.rating.map { Float($0) }, link: ratings.rottenTomatoes.link,
                             stack: rottenTomatoesCriticsStack, rating: rottenTomatoesCriticsRating,
                             image: rottentTomatoesCriticsImage, name: "Rotten Tomatoes critics", maximum: 100)
        updateExternalRating(ratings.rottenTomatoes.userRating.map { Float($0) }, link: ratings.rottenTomatoes.link,
                             stack: rottenTomatoesAudienceStack, rating: rottenTomatoesAudienceRating,
                             image: rottenTomatoesAudienceImage, name: "Rotten Tomatoes audience", maximum: 100)
        updateExternalRating(ratings.imdb.rating, count: ratings.imdb.votes, link: ratings.imdb.link,
                             stack: imdbStack, rating: imdbRating, votes: imdbVotes,
                             image: imdbImage, name: "IMDb", maximum: 10)
        updateExternalRating(ratings.mal?.rating, count: ratings.mal?.votes, link: ratings.mal?.link,
                             stack: malStack, rating: malRating, votes: malVotes,
                             image: malImage, name: "MyAnimeList", maximum: 10)
        updateExternalRating(ratings.letterboxd?.rating, count: ratings.letterboxd?.votes, link: ratings.letterboxd?.link,
                             stack: letterboxdStack, rating: letterboxdRating, votes: letterboxdVotes,
                             image: letterboxdImage, name: "Letterboxd", maximum: 5)
        updateExternalRating(ratings.metascore.rating.map { Float($0) }, link: ratings.metascore.link,
                             stack: metacriticStack, rating: metacriticRating,
                             image: metacriticImage, name: "Metacritic", maximum: 100)
        updateExternalRating(ratings.tmdb.rating.map { $0 * 10 }, count: ratings.tmdb.votes, link: ratings.tmdb.link,
                             stack: tmdbStack, rating: tmdbRating, votes: tmdbVotes,
                             image: tmdbImage, name: "TMDb", maximum: 100)

        updateRottenTomatoesImages(ratings.rottenTomatoes)
        updateMetacriticImage(ratings.metascore)
    }

    private func setRatingImage(_ image: UIImage, on button: UIButton) {
        var configuration = UIButton.Configuration.plain()
        configuration.cornerStyle = .fixed
        configuration.background.imageContentMode = .scaleAspectFit
        configuration.background.image = image
        button.configuration = configuration
    }

    private func updateRottenTomatoesImages(_ ratings: RottenTomatoesRatings) {
        if let rating = ratings.rating {
            let image: UIImage
            switch ratings.state {
            case "fresh":
                image = UIImage(resource: .rottenTomatoesFresh)
            case "certified":
                image = UIImage(resource: .rottenTomatoesCertifiedFresh)
            case "rotten":
                image = UIImage(resource: .rottenTomatoesRotten)
            default:
                if rating >= 75 {
                    image = UIImage(resource: .rottenTomatoesCertifiedFresh)
                } else if rating >= 60 {
                    image = UIImage(resource: .rottenTomatoesFresh)
                } else {
                    image = UIImage(resource: .rottenTomatoesRotten)
                }
            }
            setRatingImage(image, on: rottentTomatoesCriticsImage)
        }
        if let rating = ratings.userRating {
            let image: UIImage
            switch ratings.userState {
            case "upright":
                image = UIImage(resource: .rottenTomatoesPositiveAudience)
            case "certified":
                image = UIImage(resource: .rottenTomatoesVerifiedHot)
            case "spilled":
                image = UIImage(resource: .rottenTomatoesNegativeAudience)
            default:
                if rating >= 90 {
                    image = UIImage(resource: .rottenTomatoesVerifiedHot)
                } else if rating >= 60 {
                    image = UIImage(resource: .rottenTomatoesPositiveAudience)
                } else {
                    image = UIImage(resource: .rottenTomatoesNegativeAudience)
                }
            }
            setRatingImage(image, on: rottenTomatoesAudienceImage)
        }
    }

    private func updateMetacriticImage(_ ratings: MetascoreRatings) {
        guard let rating = ratings.rating else { return }
        let image: UIImage
        switch rating {
        case ...19:
            metacriticLabel.text = "Overwhelming Dislike"
            image = UIImage(resource: .metacriticLogoRed)
        case ...39:
            metacriticLabel.text = "Generally Unfavorable"
            image = UIImage(resource: .metacriticLogoRed)
        case ...60:
            metacriticLabel.text = "Mixed or Average"
            image = UIImage(resource: .metacriticLogoOrange)
        case ...80:
            metacriticLabel.text = "Generally Favorable"
            image = UIImage(resource: .metacriticLogoGreen)
        default:
            metacriticLabel.text = "Universal Acclaim"
            image = UIImage(resource: .metacriticLogoGreen)
        }
        setRatingImage(image, on: metacriticImage)
    }

    private func fetchRatingsFor(type: TraktObjectType) -> Cancellable {
        let requestedMedia = media
        return TraktAPIProvider.provider.request(.ratings(type: type), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            do {
                let response = try result.get().filterSuccessfulStatusCodes()
                let ratings = try response.map(Ratings.self, using: TraktAPIProvider.decoder)

                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.media == requestedMedia else { return }
                    self.updateRatings(ratings)
                }
            } catch {
                print("Ratings request failed! \(error)")
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.media == requestedMedia else { return }
                    self.rating.text = "--"
                    self.votes.text = "Unavailable"
                }
            }
        }
    }
}
