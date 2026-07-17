//
//  RatingsStatTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 23/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

protocol RatingsStatTableViewCellDelegate: AnyObject {
    func updateFilteredRatings(filteredRatings: [Int])
}

final class RatingsStatTableViewCell: UITableViewCell {
    @IBOutlet var rating: EFCountingLabel!
    @IBOutlet var votes: EFCountingLabel!

    @IBOutlet var distributionBars: [UIView]!
    @IBOutlet var distributionHeightConstant: [NSLayoutConstraint]!
    @IBOutlet var ratingLabel: [UILabel]!

    private let votesFormatter: NumberFormatter = .init()

    @IBOutlet var action: UIButton!

    weak var delegate: RatingsStatTableViewCellDelegate?
    var filteredRatings: [Int]?

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

        for bar in distributionBars {
            bar.backgroundColor = #colorLiteral(red: 0.737254902, green: 0.7333333333, blue: 0.7568627451, alpha: 1)
            bar.layer.cornerRadius = bar.layer.frame.size.width / 2.0
        }

        for constant in distributionHeightConstant {
            constant.constant = 0.0
        }

        contentView.maximumContentSizeCategory = .extraExtraLarge
    }

    var ratings: TraktRatings? {
        didSet {
            guard let ratings = ratings else {
                return
            }

            updateRatingWith(rating: ratings.rating)
            updateVotesWith(votes: ratings.votes)
            updateDistributionWith(distribution: ratings.distribution)
            updateBarColors()

            action.showsMenuAsPrimaryAction = true
            let everyRating = UIAction(title: "All") { [weak self] _ in
                guard let self = self else { return }
                guard let delegate = self.delegate else { return }
                delegate.updateFilteredRatings(filteredRatings: Array(1...10))
            }

            var children = [UIAction]()

            for i in 1...9 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    delegate.updateFilteredRatings(filteredRatings: Array((i + 1)...10))
                })
            }
            let above = UIMenu(title: "Above...", children: children)

            children.removeAll()
            for i in 2...10 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    delegate.updateFilteredRatings(filteredRatings: Array(1...(i - 1)))
                })
            }
            let below = UIMenu(title: "Below...", children: children)

            children.removeAll()
            for i in 1...10 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    guard let delegate = self.delegate else { return }
                    delegate.updateFilteredRatings(filteredRatings: [i])
                })
            }
            let exactly = UIMenu(title: "Exactly...", children: children)

            action.menu = UIMenu(title: "What Ratings do you want to see?", children: [everyRating, above, below, exactly])
        }
    }

    private func updateBarColors() {
        if let filteredRatings = filteredRatings {
            for bar in distributionBars {
                if filteredRatings.count != distributionBars.count,
                   filteredRatings.contains(where: { $0 == bar.tag }) {
                    bar.backgroundColor = UIColor(asset: .globalTint)
                } else {
                    bar.backgroundColor = #colorLiteral(red: 0.737254902, green: 0.7333333333, blue: 0.7568627451, alpha: 1)
                }
            }
            for label in ratingLabel {
                if filteredRatings.count != distributionBars.count,
                   filteredRatings.contains(where: { $0 == label.tag }) {
                    label.textColor = UIColor(asset: .globalTint)
                } else {
                    label.textColor = #colorLiteral(red: 0.4359999895, green: 0.4359999895, blue: 0.4639999866, alpha: 1)
                }
            }
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
}
