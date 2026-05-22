//
//  MirTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 16/05/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class MirTableViewCell: UITableViewCell {
    @IBOutlet var plays: EFCountingLabel!
    @IBOutlet var minutes: EFCountingLabel!
    @IBOutlet var ratings: EFCountingLabel!
    @IBOutlet var comments: EFCountingLabel!

    @IBOutlet var monthIn: UILabel!

    @IBOutlet var moreButton: UIButton!

    private let disposeBag = DisposeBag()

    override func awakeFromNib() {
        super.awakeFromNib()

        RatingsManager.shared.onRatedItemsChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchMir()
        }.disposed(by: disposeBag)

        onOwnCommentsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchMir()
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchMir()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchMir()
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchMir()
        }.disposed(by: disposeBag)
    }

    func setup(user: User, year: Int, month: Int) {
        if self.user == user, self.year == year, self.month == month {
            return
        }

        self.year = year
        self.month = month

        switch month {
        case 1:
            monthIn.text = "January in"
        case 2:
            monthIn.text = "February in"
        case 3:
            monthIn.text = "March in"
        case 4:
            monthIn.text = "April in"
        case 5:
            monthIn.text = "May in"
        case 6:
            monthIn.text = "June in"
        case 7:
            monthIn.text = "July in"
        case 8:
            monthIn.text = "August in"
        case 9:
            monthIn.text = "September in"
        case 10:
            monthIn.text = "October in"
        case 11:
            monthIn.text = "November in"
        case 12:
            monthIn.text = "December in"
        default:
            monthIn.text = "Month in"
        }

        // user last, year and month need to be set!
        self.user = user

        update(with: user)
    }

    private var year: Int!
    private var month: Int!
    private var user: User!

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    private let numberFormatter: NumberFormatter = .init()
    private let dateFormatter = DateComponentsFormatter()

    private func update(with user: User) {
        numberFormatter.numberStyle = .decimal

        dateFormatter.unitsStyle = .brief
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        dateFormatter.calendar = calendar

        plays.text = "0"
        plays.method = .easeInOut
        plays.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        ratings.text = "0"
        ratings.method = .easeInOut
        ratings.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        comments.text = "0"
        comments.method = .easeInOut
        comments.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        minutes.text = "0 min"
        minutes.method = .easeInOut
        minutes.formatBlock = { [weak self] value in
            guard let self = self else { return "0 min" }
            if value > 60 {
                self.dateFormatter.allowedUnits = [.hour]
            } else {
                self.dateFormatter.allowedUnits = [.minute]
            }
            return self.dateFormatter.string(from: TimeInterval(value * 60))!
        }

        cancelCancellable()
        cancellable = fetchMir()
    }

    private func updatePlaysWith(plays: Int?) {
        self.plays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
    }

    private func updateMinutesWith(minutes: Int?) {
        self.minutes.countFromCurrentValueTo(CGFloat(minutes ?? 0), withDuration: 0.7)
    }

    private func updateCommentsWith(comments: Int?) {
        self.comments.countFromCurrentValueTo(CGFloat(comments ?? 0), withDuration: 0.7)
    }

    private func updateRatingsWith(ratings: Int?) {
        self.ratings.countFromCurrentValueTo(CGFloat(ratings ?? 0), withDuration: 0.7)
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetchMir() -> Cancellable {
        return TraktAPIProvider.provider.request(.mir(slug: user.slug,
                                                      year: year,
                                                      month: month),
                                                 callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let stats = try response.map(IRUserStats.self, using: TraktAPIProvider.decoder).stats.all

                    DispatchQueue.main.async {
                        self.updateRatingsWith(ratings: stats.ratingsCounts.total)
                        self.updatePlaysWith(plays: stats.playCounts.total)
                        self.updateMinutesWith(minutes: stats.minutes.total)
                        self.updateCommentsWith(comments: stats.commentsCounts.total)
                    }
                } catch {
                    print("fetchMir request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("fetchMir request failure \(error)")
            }
        }
    }

    @IBAction func more(_ sender: Any) {
        UIApplication.shared.openStats(mode: .mir(user: user, month: month, year: year))
    }
}
