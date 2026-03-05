//
//  StatsTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 25/09/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

import Moya

final class StatsTableViewCell: UITableViewCell {

    @IBOutlet weak var watchers: EFCountingLabel!
    @IBOutlet weak var plays: EFCountingLabel!
    @IBOutlet weak var lists: EFCountingLabel!
    @IBOutlet weak var recommended: EFCountingLabel!
    @IBOutlet weak var collected: EFCountingLabel!

    @IBOutlet weak var recommendedStack: UIStackView!

    var media: MediaModel! {
        didSet {
            if media == oldValue { return }
            update(with: media)
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

    private let numberFormatter: NumberFormatter = NumberFormatter()

    private func update(with media: MediaModel?) {
        numberFormatter.numberStyle = .decimal

        watchers.text = "0"
        watchers.method = .easeInOut
        watchers.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        plays.text = "0"
        plays.method = .easeInOut
        plays.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")"
        }

        lists.text = "0"
        lists.method = .easeInOut
        lists.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")x"
        }

        recommended.text = "0"
        recommended.method = .easeInOut
        recommended.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")x"
        }

        collected.text = "0"
        collected.method = .easeInOut
        collected.formatBlock = { [weak self] value in
            guard let self = self else { return "0" }
            return "\(self.numberFormatter.string(from: NSNumber(value: Int(value))) ?? "0")x"
        }

        switch media! {
        case let .movie(movie):
            recommendedStack.isHidden = false
            cancellable = fetchStatsFor(type: .movie(movieId: movie.identifiers.trakt!))
        case let .show(show):
            recommendedStack.isHidden = false
            cancellable = fetchStatsFor(type: .show(showId: show.identifiers.trakt!))
        case let .episode(episode, show):
            recommendedStack.isHidden = true
            cancellable = fetchStatsFor(type: .episode(showId: show.identifiers.trakt!,
                                                           season: episode.season,
                                                           episode: episode.number))
        case let .season(season, show):
            recommendedStack.isHidden = true
            cancellable = fetchStatsFor(type: .season(showId: show.identifiers.trakt!,
                                                          season: season.number))
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    private func updateWatchersWith(watchers: Int?) {
        self.watchers.countFromCurrentValueTo(CGFloat(watchers ?? 0), withDuration: 0.7)
    }

    private func updatePlaysWith(plays: Int?) {
        self.plays.countFromCurrentValueTo(CGFloat(plays ?? 0), withDuration: 0.7)
    }

    private func updateListsWith(lists: Int?) {
        self.lists.countFromCurrentValueTo(CGFloat(lists ?? 0), withDuration: 0.7)
    }

    private func updateRecommendedWith(recommended: Int?) {
        self.recommended.countFromCurrentValueTo(CGFloat(recommended ?? 0), withDuration: 0.7)
    }

    private func updateCollectedWith(collected: Int?) {
        self.collected.countFromCurrentValueTo(CGFloat(collected ?? 0), withDuration: 0.7)
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
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let stats = try response.map(Stats.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.updateWatchersWith(watchers: stats.watchers)
                        self.updateListsWith(lists: stats.lists)
                        self.updatePlaysWith(plays: stats.plays)
                        self.updateCollectedWith(collected: stats.collectors)
                        self.updateRecommendedWith(recommended: stats.recommended)
                    }
                } catch {
                    print("Ratings request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Ratings request failure \(error)")
            }
        }
    }

}

private extension Double {
    var shortStringRepresentation: String {
        if self.isNaN {
            return "NaN"
        }
        if self.isInfinite {
            return "\(self < 0.0 ? "-" : "+")Infinity"
        }
        if self.isEqual(to: 0) {
            return "0"
        }
        let units = ["", "k", "M"]
        var interval = self
        var index = 0
        while index < units.count - 1 {
            if abs(interval) < 1000.0 {
                break
            }
            index += 1
            interval /= 1000.0
        }
        // + 2 to have one digit after the comma, + 1 to not have any.
        // Remove the * and the number of digits argument to display all the digits after the comma.
        return "\(String(format: "%0.*g", Int(log10(abs(interval))) + 1, interval))\(units[index])"
    }
}
