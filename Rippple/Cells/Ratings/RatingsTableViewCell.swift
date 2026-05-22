//
//  RatingsTableViewCell
//  Rippple
//
//  Created by Kevin Cador on 26/10/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class RatingsTableViewCell: UITableViewCell {
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

    private let votesFormatter: NumberFormatter = .init()

    override func awakeFromNib() {
        super.awakeFromNib()

        votesFormatter.numberStyle = .decimal

        rating.method = .easeInOut
        rating.format = "%d"

        votes.method = .easeInOut
        votes.formatBlock = { [weak self] value in
            guard let self = self else { return "0 vote" }
            return "\(self.votesFormatter.string(from: NSNumber(value: Int(value))) ?? "0") \(value > 1 ? "votes" : "vote")"
        }

        rottenTomatoesCriticsRating.method = .easeInOut
        rottenTomatoesCriticsRating.formatBlock = { value in
            String(format: "%02d", Int(value))
        }

        rottenTomatoesAudienceRating.method = .easeInOut
        rottenTomatoesAudienceRating.formatBlock = { value in
            String(format: "%02d", Int(value))
        }

        imdbRating.method = .easeInOut
        imdbRating.format = "%.1f"

        imdbVotes.method = .easeInOut
        imdbVotes.formatBlock = { [weak self] value in
            guard let self = self else { return "0 vote" }
            return "\(self.votesFormatter.string(from: NSNumber(value: Int(value))) ?? "0") \(value > 1 ? "votes" : "vote")"
        }

        metacriticRating.method = .easeInOut
        metacriticRating.formatBlock = { value in
            String(format: "%02d", Int(value))
        }

        tmdbRating.method = .easeInOut
        tmdbRating.formatBlock = { value in
            String(format: "%02d", Int(value * 10))
        }

        tmdbVotes.method = .easeInOut
        tmdbVotes.formatBlock = { [weak self] value in
            guard let self = self else { return "0 vote" }
            return "\(self.votesFormatter.string(from: NSNumber(value: Int(value))) ?? "0") \(value > 1 ? "votes" : "vote")"
        }

        rottenTomatoesCriticsStack.isHidden = true
        rottenTomatoesAudienceStack.isHidden = true
        imdbStack.isHidden = true
        metacriticStack.isHidden = true
        tmdbStack.isHidden = true

        for bar in distributionBars {
            bar.backgroundColor = #colorLiteral(red: 0.737254902, green: 0.7333333333, blue: 0.7568627451, alpha: 1)
            bar.layer.cornerRadius = bar.layer.frame.size.width / 2.0
        }

        for constant in distributionHeightConstant {
            constant.constant = 0.0
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

    private func update(with media: MediaModel?) {
        rating.text = "0"
        votes.text = "Loading..."
        switch media! {
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

    private func updateRatingWith(rating: Float) {
        self.rating.countFromCurrentValueTo(CGFloat(round(rating * 10.0)), withDuration: 0.7)
    }

    private func updateVotesWith(votes: Int) {
        self.votes.countFromCurrentValueTo(CGFloat(votes), withDuration: 0.7)
    }

    private func updateDistributionWith(distribution: RatingDistribution) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
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
                               animations: {
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

    private func fetchRatingsFor(type: TraktObjectType) -> Cancellable {
        rottenTomatoesAudienceRating.text = "--"
        rottenTomatoesCriticsRating.text = "--"
        return TraktAPIProvider.provider.request(.ratings(type: type), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let ratings = try response.map(Ratings.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.updateRatingWith(rating: ratings.trakt.rating)
                        self.updateVotesWith(votes: ratings.trakt.votes)
                        self.updateDistributionWith(distribution: ratings.trakt.distribution)
                        if let rating = ratings.rottenTomatoes.rating {
                            self.rottenTomatoesCriticsStack.isHidden = false

                            self.rottenTomatoesCriticsRating.countFromCurrentValueTo(CGFloat(rating),
                                                                                     withDuration: 0.7)
                            var configuration = UIButton.Configuration.plain()
                            configuration.cornerStyle = .fixed
                            configuration.background.imageContentMode = .scaleAspectFit
                            if let state = ratings.rottenTomatoes.state {
                                switch state {
                                case "fresh":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesFresh)
                                case "certified":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesCertifiedFresh)
                                case "rotten":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesRotten)
                                default:
                                    // Fallback
                                    if rating >= 75 {
                                        // certified fresh
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesCertifiedFresh)
                                    } else if rating >= 60 {
                                        // fresh
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesFresh)
                                    } else {
                                        // rotten
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesRotten)
                                    }
                                }
                            }
                            self.rottentTomatoesCriticsImage.configuration = configuration
                            if let url = ratings.rottenTomatoes.link {
                                self.rottentTomatoesCriticsImage.addAction(UIAction(handler: { _ in
                                    UIApplication.shared.open(url)
                                }), for: .touchUpInside)
                            }
                        } else {
                            self.rottenTomatoesCriticsRating.text = "--"
                        }
                        if let userRating = ratings.rottenTomatoes.userRating {
                            self.rottenTomatoesAudienceStack.isHidden = false

                            self.rottenTomatoesAudienceRating.countFromCurrentValueTo(CGFloat(userRating),
                                                                                      withDuration: 0.7)
                            var configuration = UIButton.Configuration.plain()
                            configuration.cornerStyle = .fixed
                            configuration.background.imageContentMode = .scaleAspectFit
                            if let state = ratings.rottenTomatoes.userState {
                                switch state {
                                case "upright":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesPositiveAudience)
                                case "certified":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesVerifiedHot)
                                case "spilled":
                                    configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesNegativeAudience)
                                default:
                                    // Fallback
                                    if userRating >= 90 {
                                        // verified hot
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesVerifiedHot)
                                    } else if userRating >= 60 {
                                        // upright
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesPositiveAudience)
                                    } else {
                                        // spilled
                                        configuration.background.image = UIImage(resource: ImageResource.rottenTomatoesNegativeAudience)
                                    }
                                }
                            }
                            self.rottenTomatoesAudienceImage.configuration = configuration
                            if let url = ratings.rottenTomatoes.link {
                                self.rottenTomatoesAudienceImage.addAction(UIAction(handler: { _ in
                                    UIApplication.shared.open(url)
                                }), for: .touchUpInside)
                            }
                        } else {
                            self.rottenTomatoesAudienceRating.text = "--"
                        }
                        if let imdbRating = ratings.imdb.rating, let imdbVotes = ratings.imdb.votes {
                            self.imdbStack.isHidden = false

                            self.imdbRating.countFromCurrentValueTo(CGFloat(imdbRating),
                                                                    withDuration: 0.7)
                            self.imdbVotes.countFromCurrentValueTo(CGFloat(imdbVotes),
                                                                   withDuration: 0.7)
                            if let url = ratings.imdb.link {
                                self.imdbImage.addAction(UIAction(handler: { _ in
                                    UIApplication.shared.open(url)
                                }), for: .touchUpInside)
                            }
                        } else {
                            self.imdbRating.text = "--"
                        }
                        if let metascore = ratings.metascore.rating {
                            self.metacriticStack.isHidden = false

                            self.metacriticRating.countFromCurrentValueTo(CGFloat(metascore),
                                                                          withDuration: 0.7)
                            var configuration = UIButton.Configuration.plain()
                            configuration.cornerStyle = .fixed
                            configuration.background.imageContentMode = .scaleAspectFit
                            if metascore <= 19 {
                                self.metacriticLabel.text = "Overwhelming Dislike"
                                configuration.background.image = UIImage(resource: ImageResource.metacriticLogoRed)
                            } else if metascore <= 39 {
                                self.metacriticLabel.text = "Generally Unfavorable"
                                configuration.background.image = UIImage(resource: ImageResource.metacriticLogoRed)
                            } else if metascore <= 60 {
                                self.metacriticLabel.text = "Mixed or Average"
                                configuration.background.image = UIImage(resource: ImageResource.metacriticLogoOrange)
                            } else if metascore <= 80 {
                                self.metacriticLabel.text = "Generally Favorable"
                                configuration.background.image = UIImage(resource: ImageResource.metacriticLogoGreen)
                            } else {
                                self.metacriticLabel.text = "Universal Acclaim"
                                configuration.background.image = UIImage(resource: ImageResource.metacriticLogoGreen)
                            }
                            self.metacriticImage.configuration = configuration
                            if let url = ratings.metascore.link {
                                self.metacriticImage.addAction(UIAction(handler: { _ in
                                    UIApplication.shared.open(url)
                                }), for: .touchUpInside)
                            }
                        } else {
                            self.metacriticRating.text = "--"
                            self.metacriticLabel.text = ""
                        }
                        if let tmdbRating = ratings.tmdb.rating, let tmdbVotes = ratings.tmdb.votes {
                            self.tmdbStack.isHidden = false

                            self.tmdbRating.countFromCurrentValueTo(CGFloat(tmdbRating),
                                                                    withDuration: 0.7)
                            self.tmdbVotes.countFromCurrentValueTo(CGFloat(tmdbVotes),
                                                                   withDuration: 0.7)
                            if let url = ratings.tmdb.link {
                                self.tmdbImage.addAction(UIAction(handler: { _ in
                                    UIApplication.shared.open(url)
                                }), for: .touchUpInside)
                            }
                        } else {
                            self.tmdbRating.text = "--"
                        }
                    }
                } catch {
                    print("Ratings request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Ratings request failure \(error)")
            }
        }
    }
}
