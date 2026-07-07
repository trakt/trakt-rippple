//
//  UserStatsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/11/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class UserStatsTableViewCell: UITableViewCell {
    @IBOutlet var plays: EFCountingLabel!
    @IBOutlet var minutes: EFCountingLabel!

    @IBOutlet var moviesPlays: EFCountingLabel!
    @IBOutlet var showsPlays: EFCountingLabel!
    @IBOutlet var episodesPlays: EFCountingLabel!

    @IBOutlet var ratings: EFCountingLabel!
    @IBOutlet var comments: EFCountingLabel!

    @IBOutlet var yirButton: UIButton!

    @IBOutlet private var statsColumnsStack: UIStackView!

    private let disposeBag = DisposeBag()

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelCancellable()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        configureStatsColumnsPriorities()

        RatingsManager.shared.onRatedItemsChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStatsFor(type: .user(slug: self.user.slug))
        }.disposed(by: disposeBag)

        onOwnCommentsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetchCommentCount(type: .user(slug: self.user.slug))
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStatsFor(type: .user(slug: self.user.slug))
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStatsFor(type: .user(slug: self.user.slug))
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStatsFor(type: .user(slug: self.user.slug))
        }.disposed(by: disposeBag)
    }

    private func configureStatsColumnsPriorities() {
        for column in statsColumnsStack.arrangedSubviews {
            column.setContentHuggingPriority(.required, for: .horizontal)
            column.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    var user: User! {
        didSet {
            if user == oldValue { return }
            update(with: user)
        }
    }

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

        moviesPlays.text = "0"
        moviesPlays.method = .easeInOut
        moviesPlays.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        showsPlays.text = "0"
        showsPlays.method = .easeInOut
        showsPlays.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        episodesPlays.text = "0"
        episodesPlays.method = .easeInOut
        episodesPlays.formatBlock = { [weak self] value in
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
            if value > 60 * 24 {
                self.dateFormatter.allowedUnits = [.day]
            } else if value > 60 {
                self.dateFormatter.allowedUnits = [.hour]
            } else {
                self.dateFormatter.allowedUnits = [.minute]
            }
            return self.dateFormatter.string(from: TimeInterval(value * 60))!
        }

        cancelCancellable()
        cancellable = fetchStatsFor(type: .user(slug: user.slug))
        fetchCommentCount(type: .user(slug: self.user.slug))
    }

    private func updatePlaysWith(plays: Int?) {
        self.plays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
    }

    private func updateMinutesWith(minutes: Int?) {
        self.minutes.countFromCurrentValueTo(CGFloat(minutes ?? 0), withDuration: 0.7)
    }

    private func updateMoviesPlaysWith(plays: Int?) {
        moviesPlays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
    }

    private func updateShowsPlaysWith(plays: Int?) {
        showsPlays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
    }

    private func updateEpisodesPlaysWith(plays: Int?) {
        episodesPlays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
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

    private func fetchStatsFor(type: TraktObjectType) -> Cancellable {
        return TraktAPIProvider.provider.request(.stats(type: type), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let stats = try response.map(UserStats.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        if case .user(let slug) = type, self.user.slug != slug { return }
                        self.updateRatingsWith(ratings: stats.ratings)
                        self.updatePlaysWith(plays: stats.plays)
                        self.updateMinutesWith(minutes: stats.minutes)

                        self.updateMoviesPlaysWith(plays: stats.movies.plays)
                        self.updateShowsPlaysWith(plays: stats.shows.watched)
                        self.updateEpisodesPlaysWith(plays: stats.episodes.plays)
                    }
                } catch {
                    print("fetchStatsFor request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("fetchStatsFor request failure \(error)")
            }
        }
    }

    private func fetchCommentCount(type: TraktObjectType) {
        TraktAPIProvider.provider.request(.commentCount(type: type), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if let response = response.response {
                        let allHTTPHeaders = response.allHeaderFields
                        if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                            DispatchQueue.main.async {
                                if case .user(let slug) = type, self.user.slug != slug { return }
                                self.updateCommentsWith(comments: Int(itemCount))
                            }
                        }
                    }
                } catch {
                    print("Stats request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                if error.localizedDescription == "cancelled" { return }
                print("Stats request failure \(error)")
            }
        }
    }

    @IBAction func yir(_ sender: Any) {
        UIApplication.shared.openStats(mode: .all(user: user))
    }
}

private extension UserStats {
    var plays: Int {
        return movies.plays + episodes.plays
    }

    var watched: Int {
        return movies.watched + episodes.watched
    }

    var ratings: Int {
        return movies.ratings + episodes.ratings + shows.ratings + seasons.ratings
    }

    var comments: Int {
        return movies.comments + episodes.comments + shows.comments + seasons.comments
    }

    var minutes: Int {
        return movies.minutes + episodes.minutes
    }
}
