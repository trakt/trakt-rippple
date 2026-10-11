//
//  MirTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 16/05/2025.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class MirTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var plays: EFCountingLabel!
    @IBOutlet var minutes: EFCountingLabel!
    @IBOutlet var ratings: EFCountingLabel!
    @IBOutlet var comments: EFCountingLabel!

    @IBOutlet var monthIn: UILabel!

    @IBOutlet var moreButton: UIButton!

    private let disposeBag = DisposeBag()
    private var vipNudgeView: StatsVIPNudgeView?

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelCancellables()
        user = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        vipNudgeView = StatsVIPNudgeView.install(in: contentView)
        onSettingsChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let user = self.user else { return }
                self.update(with: user)
            }
        }.disposed(by: disposeBag)
        onVIPChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let user = self.user else { return }
                self.update(with: user)
            }
        }.disposed(by: disposeBag)

        RatingsManager.shared.onRatedItemsChangedReceiver.skip(count: 1).listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshStats()
            }
        }.disposed(by: disposeBag)

        onOwnCommentsChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshStats()
            }
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshStats()
            }
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshStats()
            }
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshStats()
            }
        }.disposed(by: disposeBag)
    }

    func setup(user: User, year: Int, month: Int) {
        if self.user == user, self.user?.isTraktVIP == user.isTraktVIP,
           self.user?.isPrivate == user.isPrivate,
           self.year == year, self.month == month {
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

    private var cancellables: [Cancellable] = []
    private var statsRequestID = 0

    deinit {
        cancelCancellables()
    }

    private let numberFormatter: NumberFormatter = .init()
    private let dateFormatter = DateComponentsFormatter()

    private func update(with user: User) {
        vipNudgeView?.setLocked(!UserManager.shared.canAccessStats(for: user))
        minutes.superview?.isHidden = !(user.isCurrentUser ? UserManager.shared.isCurrentVIP : user.isTraktVIP)

        numberFormatter.numberStyle = .decimal

        dateFormatter.unitsStyle = .brief
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "en_US")
        dateFormatter.calendar = calendar

        plays.method = .easeInOut
        plays.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        ratings.method = .easeInOut
        ratings.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        comments.method = .easeInOut
        comments.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

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

        refreshStats()
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

    private func cancelCancellables() {
        statsRequestID += 1
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    private func refreshStats() {
        cancelCancellables()
        for label in [plays, minutes, ratings, comments] {
            label?.countFrom(0, to: 0, withDuration: 0)
        }
        guard let user = user, UserManager.shared.canAccessStats(for: user) else {
            showUnavailableStats()
            return
        }
        if user.isCurrentUser || user.isTraktVIP {
            if let cancellable = fetchMir() {
                cancellables.append(cancellable)
            }
        } else {
            fetchFallbackCounts()
        }
    }

    private func showUnavailableStats() {
        for label in [plays, minutes, ratings, comments] {
            label?.text = "—"
        }
    }

    private func fetchFallbackCounts() {
        guard let requestedUser = user, let requestedYear = year, let requestedMonth = month,
              let date = Calendar.current.date(from: DateComponents(year: requestedYear, month: requestedMonth)),
              let interval = Calendar.current.dateInterval(of: .month, for: date) else {
            showUnavailableStats()
            return
        }
        let requestID = statsRequestID
        let viewer = UserManager.shared.currentUser

        let counts: [(UserCountType, EFCountingLabel)] = [(.plays, plays), (.ratings, ratings), (.comments, comments)]
        for (type, label) in counts {
            let completion: (Result<Int, Error>) -> Void = { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.user == requestedUser,
                          self.statsRequestID == requestID,
                          UserManager.shared.currentUser == viewer,
                          self.user?.isTraktVIP == requestedUser.isTraktVIP,
                          self.year == requestedYear, self.month == requestedMonth,
                          UserManager.shared.canAccessStats(for: self.user) else { return }
                    switch result {
                    case .success(let count):
                        label.countFromCurrentValueTo(CGFloat(count), withDuration: 0.7)
                    case .failure(let error):
                        label.text = "—"
                        print("Monthly user count request failed! \(error)")
                    }
                }
            }
            let cancellable: Cancellable
            if type == .plays {
                cancellable = TraktAPIProvider.fetchUserCount(slug: requestedUser.slug,
                                                              type: type,
                                                              startDate: interval.start,
                                                              endDate: interval.end.addingTimeInterval(-0.001),
                                                              completion: completion)
            } else {
                cancellable = TraktAPIProvider.fetchMonthlyUserCount(slug: requestedUser.slug,
                                                                     type: type,
                                                                     startDate: interval.start,
                                                                     endDate: interval.end,
                                                                     completion: completion)
            }
            cancellables.append(cancellable)
        }
    }

    private func fetchMir() -> Cancellable? {
        guard UserManager.shared.canAccessStats(for: user), let requestedUser = user,
              let requestedYear = year, let requestedMonth = month else {
            showUnavailableStats()
            return nil
        }
        let requestID = statsRequestID
        let viewer = UserManager.shared.currentUser
        return TraktAPIProvider.provider.request(.mir(slug: requestedUser.slug,
                                                      year: requestedYear,
                                                      month: requestedMonth),
                                                 callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let statsResult = Result {
                try result.get().filterSuccessfulStatusCodes()
                    .map(IRUserStats.self, using: TraktAPIProvider.decoder).stats.all
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.user == requestedUser,
                      self.statsRequestID == requestID,
                      UserManager.shared.currentUser == viewer,
                      self.user?.isTraktVIP == requestedUser.isTraktVIP,
                      self.year == requestedYear, self.month == requestedMonth,
                      UserManager.shared.canAccessStats(for: self.user) else { return }
                switch statsResult {
                case .success(let stats):
                    self.updateRatingsWith(ratings: stats.ratingsCounts.total)
                    self.updatePlaysWith(plays: stats.playCounts.total)
                    self.updateMinutesWith(minutes: stats.minutes.total)
                    self.updateCommentsWith(comments: stats.commentsCounts.total)
                case .failure(let error):
                    self.showUnavailableStats()
                    print("fetchMir request failed! \(error)")
                }
            }
        }
    }

    @IBAction func more(_ sender: Any) {
        UIApplication.shared.openStats(mode: .mir(user: user, month: month, year: year))
    }
}
