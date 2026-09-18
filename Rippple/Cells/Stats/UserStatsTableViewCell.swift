//
//  UserStatsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 20/11/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class UserStatsTableViewCell: TintedCanvasTableViewCell {
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
    private var vipNudgeView: StatsVIPNudgeView?

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelCancellable()
        user = nil
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        configureStatsColumnsPriorities()
        vipNudgeView = StatsVIPNudgeView.install(in: contentView)
        onSettingsChangedReceiver.listen { [weak self] _ in
            guard let self = self, let user = self.user else { return }
            self.update(with: user)
        }.disposed(by: disposeBag)
        onVIPChangedReceiver.listen { [weak self] _ in
            guard let self = self, let user = self.user else { return }
            self.update(with: user)
        }.disposed(by: disposeBag)

        RatingsManager.shared.onRatedItemsChangedReceiver.skip(count: 1).listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStats()
        }.disposed(by: disposeBag)

        onOwnCommentsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.fetchCommentCount()
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStats()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStats()
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.cancelCancellable()
            self.cancellable = self.fetchStats()
        }.disposed(by: disposeBag)

        onSyncWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self, self.user?.isCurrentUser == true else { return }
            self.updateWatchedStats()
        }.disposed(by: disposeBag)

        onSyncWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self, self.user?.isCurrentUser == true else { return }
            self.updateWatchedStats()
        }.disposed(by: disposeBag)

        onSyncWatchedEpisodesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self, self.user?.isCurrentUser == true else { return }
            self.updateWatchedStats()
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
            if user == oldValue, user?.isTraktVIP == oldValue?.isTraktVIP { return }
            guard let user = user else { return }
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
        cancelCancellable()
        vipNudgeView?.setLocked(!UserManager.shared.canAccessStats(for: user))
        for label in [plays, minutes, moviesPlays, showsPlays, episodesPlays, ratings, comments] {
            label?.countFrom(0, to: 0, withDuration: 0)
            label?.text = "—"
        }
        guard UserManager.shared.canAccessStats(for: user) else { return }

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

        cancellable = fetchStats()
        fetchCommentCount()

        if user.isCurrentUser {
            updateWatchedStats()
        }
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

    private func updateWatchedStats() {
        guard UserManager.shared.canAccessStats(for: user) else { return }
        let manager = SyncWatchedManager.shared
        let moviePlays = manager.movieWatchedItems.watchedDatesByTraktId.values.reduce(0) { $0 + $1.count }
        let episodePlays = manager.episodeWatchedItems.watchedDatesByTraktId.values.reduce(0) { $0 + $1.count }

        updatePlaysWith(plays: moviePlays + episodePlays)
        updateMoviesPlaysWith(plays: manager.watchedMovies.count)
        updateShowsPlaysWith(plays: manager.watchedShows.count)
        updateEpisodesPlaysWith(plays: manager.watchedEpisodes.count)
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private func fetchStats() -> Cancellable? {
        guard UserManager.shared.canAccessStats(for: user), let requestedUser = user else { return nil }
        return TraktAPIProvider.provider.request(.stats(type: .user(slug: requestedUser.slug)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    guard response.statusCode != 204 else { return }
                    let stats = try response.map(UserStats.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self, self.user == requestedUser, UserManager.shared.canAccessStats(for: self.user) else { return }
                        self.updateRatingsWith(ratings: stats.ratings)
                        self.updateMinutesWith(minutes: stats.minutes)

                        if self.user.isCurrentUser {
                            self.updateWatchedStats()
                        } else {
                            self.updatePlaysWith(plays: stats.plays)
                            self.updateMoviesPlaysWith(plays: stats.movies.plays)
                            self.updateShowsPlaysWith(plays: stats.shows.watched)
                            self.updateEpisodesPlaysWith(plays: stats.episodes.plays)
                        }
                    }
                } catch {
                    print("fetchStats request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("fetchStats request failure \(error)")
            }
        }
    }

    private func fetchCommentCount() {
        guard UserManager.shared.canAccessStats(for: user), let requestedUser = user else { return }
        TraktAPIProvider.provider.request(.commentCount(type: .user(slug: requestedUser.slug)), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if let response = response.response {
                        let allHTTPHeaders = response.allHeaderFields
                        if let itemCount = allHTTPHeaders["x-pagination-item-count"] as? String {
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self, self.user == requestedUser, UserManager.shared.canAccessStats(for: self.user) else { return }
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

/// Shared by the profile and monthly stats cards, keeping their existing sizing.
final class StatsVIPNudgeView: UIView {
    private weak var statsContent: UIView?
    private var minimumHeightConstraints = [NSLayoutConstraint]()

    static func install(in contentView: UIView) -> StatsVIPNudgeView? {
        guard let card = contentView.subviews.first as? CardView else { return nil }
        let nudge = StatsVIPNudgeView()
        nudge.statsContent = card.subviews.first { $0 is UIScrollView }
        nudge.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(nudge)
        NSLayoutConstraint.activate([
            nudge.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            nudge.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            nudge.topAnchor.constraint(equalTo: card.topAnchor),
            nudge.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        let icon = UIImageView(image: UIImage(systemName: "chart.pie"))
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        icon.tintColor = UIColor(asset: .globalTint)
        icon.contentMode = .scaleAspectFit
        icon.isAccessibilityElement = false

        let title = UILabel()
        title.text = "Advanced Stats"
        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .label
        title.adjustsFontForContentSizeCategory = true
        title.numberOfLines = 0

        let subtitle = UILabel()
        subtitle.text = "With Trakt VIP"
        subtitle.font = .preferredFont(forTextStyle: .footnote)
        subtitle.textColor = .secondaryLabel
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [title, subtitle])
        text.axis = .vertical
        text.spacing = 2

        let button = TitleOnlyButton(frame: .zero)
        button.setTitle("Get VIP", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addAction(UIAction { _ in
            UIApplication.shared.switchToPurchase()
        }, for: .touchUpInside)

        let row = UIStackView(arrangedSubviews: [icon, text, button])
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        nudge.addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 24),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            row.centerYAnchor.constraint(equalTo: nudge.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: nudge.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: nudge.trailingAnchor, constant: -16)
        ])
        nudge.minimumHeightConstraints = [
            row.topAnchor.constraint(greaterThanOrEqualTo: nudge.topAnchor, constant: 8),
            row.bottomAnchor.constraint(lessThanOrEqualTo: nudge.bottomAnchor, constant: -8)
        ]
        nudge.setLocked(true)
        return nudge
    }

    func setLocked(_ locked: Bool) {
        isHidden = !locked
        for constraint in minimumHeightConstraints {
            constraint.isActive = locked
        }
        statsContent?.isHidden = locked
        statsContent?.accessibilityElementsHidden = locked
    }
}
