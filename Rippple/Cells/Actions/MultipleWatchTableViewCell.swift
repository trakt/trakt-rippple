//
//  MultipleWatchTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/09/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import UIKit

final class MultipleWatchTableViewCell: TintedCanvasTableViewCell {
    @IBOutlet var mainLabel: UILabel!
    @IBOutlet var secondaryLabel: UILabel!

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    var media: MediaModel? {
        didSet {
            update(with: media)
        }
    }

    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .full
        dateFormatter.dateTimeStyle = .named
        dateFormatter.formattingContext = .dynamic
        return dateFormatter
    }()

    private let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    private func update(with media: MediaModel?) {
        mainLabel.text = "Loading history"
        secondaryLabel.text = "Wait for it..."
        switch media! {
        case .movie(let movie):
            cancellable = fetchActivities(for: .history(type: .movies, id: movie.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 1), endDate: nil))
        case .episode(let episode, _):
            cancellable = fetchActivities(for: .history(type: .episodes, id: episode.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 1), endDate: nil))
        case .season(let season, let show):
            cancellable = fetchSeasonProgress(for: show, season: season)
        case .show(let show):
            cancellable = fetchShowProgress(for: show)
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    private func fetchActivities(for type: TraktAPIService) -> Cancellable {
        return TraktAPIProvider.provider.request(type, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        if let activity = fetchedActivities.first {
                            self.mainLabel.text = "Last watched \(self.relativeDateTimeFormatter.localizedString(for: activity.watchDate, relativeTo: Date()))"
                            self.secondaryLabel.text = "\(self.dateFormatter.string(from: activity.watchDate))"
                        } else {
                            self.mainLabel.text = "This is your first watch"
                            self.secondaryLabel.text = "Hope you enjoyed it"
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/activities) request JSON mapping failed! \(error)")
                        self.mainLabel.text = "An error occurred"
                        self.secondaryLabel.text = "Try again..."
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/activities) request failure \(error)")
                    self.mainLabel.text = "An error occurred"
                    self.secondaryLabel.text = "Try again..."
                }
            }
        }
    }

    private func fetchShowProgress(for show: Show) -> Cancellable {
        return TraktAPIProvider.provider.request(.showProgress(id: show.identifiers.trakt!, includesSpecials: false), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        let remaining = showProgress.aired - showProgress.completed
                        if remaining == 0 {
                            self.mainLabel.text = "Up to date"
                            self.secondaryLabel.text = "You watched everything once"
                        } else {
                            self.mainLabel.text = "Watched \(showProgress.completed) of \(showProgress.aired) \(showProgress.aired > 1 ? "episodes" : "episode")"
                            self.secondaryLabel.text = "\(remaining) \(remaining > 1 ? "episodes" : "episode") left to watch"
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/progress) request JSON mapping failed! \(error)")
                        self.mainLabel.text = "An error occurred"
                        self.secondaryLabel.text = "Try again..."
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/progress) request failure \(error)")
                    self.mainLabel.text = "An error occurred"
                    self.secondaryLabel.text = "Try again..."
                }
            }
        }
    }

    private func fetchSeasonProgress(for show: Show, season: Season) -> Cancellable {
        return TraktAPIProvider.provider.request(.showProgress(id: show.identifiers.trakt!, includesSpecials: true), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        for seasonProgress in showProgress.seasons where seasonProgress.number == season.number {
                            let remaining = seasonProgress.aired - seasonProgress.completed
                            if remaining == 0 {
                                self.mainLabel.text = "Up to date"
                                self.secondaryLabel.text = "You watched everything once"
                            } else {
                                self.mainLabel.text = "Watched \(seasonProgress.completed) of \(seasonProgress.aired) \(seasonProgress.aired > 1 ? "episodes" : "episode")"
                                self.secondaryLabel.text = "\(remaining) \(remaining > 1 ? "episodes" : "episode") left to watch"
                            }
                            break
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/progress) request JSON mapping failed! \(error)")
                        self.mainLabel.text = "An error occurred"
                        self.secondaryLabel.text = "Try again..."
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/progress) request failure \(error)")
                    self.mainLabel.text = "An error occurred"
                    self.secondaryLabel.text = "Try again..."
                }
            }
        }
    }
}
