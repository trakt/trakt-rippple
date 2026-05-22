//
//  MediaMoreTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 19/08/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Receiver
import UIKit

protocol MediaMoreTableViewCellDelegate: AnyObject {
    func cell(_ cell: MediaMoreTableViewCell, didSelect season: Season)
}

final class MediaMoreTableViewCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {
    private let disposeBag = DisposeBag()

    @IBOutlet var title: UILabel!
    @IBOutlet var subtitle: UILabel!
    @IBOutlet var subtitle2: UILabel!
    @IBOutlet var progress: ShowProgressBar!

    @IBOutlet var seasonsCollectionView: UICollectionView!

    weak var delegate: MediaMoreTableViewCellDelegate?

    private var seasons: [Season] = [] {
        didSet {
            seasonsCollectionView.reloadData()
        }
    }

    /*

     Returning Series · Loading...
     Loading...
     Loading...
     ——————————————————————

     Returning Series · 2 seasons (~10h 36m)
     11 of 13 episodes watched (~9h 6m)
     2 episodes (~1h 30m) left to watch
     ——————————————————————

     Returning Series · 2 seasons (~10h 36m)
     13 of 13 episodes watched
     You're up-to-date!
     ——————————————————————

     Ended · 1 season (~10h 36m)
     13 of 13 episodes watched
     You've watched all episodes!
     ——————————————————————

     */

    override func awakeFromNib() {
        super.awakeFromNib()

        seasonsCollectionView.register(UINib(nibName: "SeasonButtonCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "season")

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            if progress.show == self.show {
                Task {
                    let progress = progress.showProgress

                    let seasons = await self.fetchSeasons()

                    var numberOfSeason = 0
                    var episodesWatched = 0
                    var episodesWatchedTime = 0
                    var totalEpisodes = 0
                    var totalEpisodesTime = 0
                    var episodesToWatch = 0
                    var episodesToWatchTime = 0

                    for season in progress.seasons where season.number != 0 {
                        let theSeason = seasons?.first { $0.number == season.number }
                        numberOfSeason += 1
                        for episode in season.episodes {
                            let theEpisode = theSeason?.episodes?.first { $0.number == episode.number }
                            let theEpisodeRuntime = theEpisode?.runtime ?? self.show.runtime ?? 0
                            if episode.completed {
                                episodesWatched += 1
                                episodesWatchedTime += theEpisodeRuntime
                            } else {
                                episodesToWatch += 1
                                episodesToWatchTime += theEpisodeRuntime
                            }
                            totalEpisodes += 1
                            totalEpisodesTime += theEpisodeRuntime
                        }
                    }
                    DispatchQueue.main.async {
                        self.updateTitleWith(numberOfSeason: numberOfSeason,
                                             hours: totalEpisodesTime / 60,
                                             minutes: totalEpisodesTime % 60)
                        self.updateSubtitleWith(episodesWatched: episodesWatched,
                                                totalEpisodes: totalEpisodes,
                                                hours: episodesWatchedTime / 60,
                                                minutes: episodesWatchedTime % 60)
                        self.updateSubtitle2With(episodesToWatch: episodesToWatch,
                                                 hours: episodesToWatchTime / 60,
                                                 minutes: episodesToWatchTime % 60)
                        self.invalidateIntrinsicContentSize()
                    }
                }
            }
        }.disposed(by: disposeBag)
    }

    var show: Show! {
        didSet {
            title.text = "\([show.status?.capitalized, "Loading..."].compactMap { $0 }.joined(separator: " · "))"
            subtitle.text = "Loading..."
            subtitle2.text = "Loading..."
            invalidateIntrinsicContentSize()

            Task {
                let mediaModel = self.show.mediaModel
                guard let progress = await mediaModel.progress() else {
                    title.text = "\([show.status?.capitalized].compactMap { $0 }.joined(separator: " · "))"
                    subtitle.text = "Loading failed!"
                    subtitle2.text = "Loading failed!"
                    invalidateIntrinsicContentSize()
                    return
                }

                let seasons = await self.fetchSeasons()

                var numberOfSeason = 0
                var episodesWatched = 0
                var episodesWatchedTime = 0
                var totalEpisodes = 0
                var totalEpisodesTime = 0
                var episodesToWatch = 0
                var episodesToWatchTime = 0

                for season in progress.seasons where season.number != 0 {
                    let theSeason = seasons?.first { $0.number == season.number }
                    numberOfSeason += 1
                    for episode in season.episodes {
                        let theEpisode = theSeason?.episodes?.first { $0.number == episode.number }
                        let theEpisodeRuntime = theEpisode?.runtime ?? self.show.runtime ?? 0
                        if episode.completed {
                            episodesWatched += 1
                            episodesWatchedTime += theEpisodeRuntime
                        } else {
                            episodesToWatch += 1
                            episodesToWatchTime += theEpisodeRuntime
                        }
                        totalEpisodes += 1
                        totalEpisodesTime += theEpisodeRuntime
                    }
                }

                updateTitleWith(numberOfSeason: numberOfSeason,
                                hours: totalEpisodesTime / 60,
                                minutes: totalEpisodesTime % 60)

                updateSubtitleWith(episodesWatched: episodesWatched,
                                   totalEpisodes: totalEpisodes,
                                   hours: episodesWatchedTime / 60,
                                   minutes: episodesWatchedTime % 60)

                updateSubtitle2With(episodesToWatch: episodesToWatch,
                                    hours: episodesToWatchTime / 60,
                                    minutes: episodesToWatchTime % 60)

                // should use the cache now
                self.progress.media = mediaModel

                invalidateIntrinsicContentSize()
            }
        }
    }

    func updateTitleWith(numberOfSeason: Int, hours: Int, minutes: Int) {
        var text = [String?]()
        text.append(show.status?.capitalized)

        var seasonInfo = ""
        if numberOfSeason <= 0 {
            // No season means we can just show the status and return
            title.text = show.status?.capitalized
            return
        } else if numberOfSeason == 1 {
            seasonInfo += "1 Season"
        } else {
            seasonInfo += "\(numberOfSeason) Seasons"
        }

        if hours <= 0 {
            if minutes > 0 {
                seasonInfo += " (\(minutes)m)"
            }
        } else {
            if minutes > 0 {
                seasonInfo += " (\(hours)h \(minutes)m)"
            } else {
                seasonInfo += " (\(hours)h)"
            }
        }
        text.append(seasonInfo)
        title.text = text.compactMap { $0 }.joined(separator: " · ")
    }

    func updateSubtitleWith(episodesWatched: Int, totalEpisodes: Int, hours: Int, minutes: Int) {
        if totalEpisodes == 0 {
            subtitle.text = "No episode aired yet"
            return
        }
        var text = "\(episodesWatched) of \(totalEpisodes) episodes watched"
        if hours <= 0 {
            if minutes > 0 {
                text += " (\(minutes)m)"
            }
        } else {
            if minutes > 0 {
                text += " (\(hours)h \(minutes)m)"
            } else {
                text += " (\(hours)h)"
            }
        }
        subtitle.text = text
    }

    func updateSubtitle2With(episodesToWatch: Int, hours: Int, minutes: Int) {
        var text = ""
        if episodesToWatch == 0 {
            if show.status == "returning series" {
                subtitle2.text = "You're up-to-date"
                return
            } else if show.status == "in production" {
                subtitle2.text = "Not started yet"
                return
            } else if show.status == "planned" {
                subtitle2.text = "Not started yet"
                return
            } else if show.status == "canceled" {
                subtitle2.text = "You've watched all episodes"
                return
            } else if show.status == "ended" {
                subtitle2.text = "You've watched all episodes"
                return
            } else {
                text += "No episode"
            }
        } else if episodesToWatch == 1 {
            text = "\(episodesToWatch) episode"
        } else {
            text = "\(episodesToWatch) episodes"
        }

        if hours <= 0 {
            if minutes > 0 {
                text += " (\(minutes)m)"
            }
        } else {
            if minutes > 0 {
                text += " (\(hours)h \(minutes)m)"
            } else {
                text += " (\(hours)h)"
            }
        }
        text += " left to watch"
        subtitle2.text = text
    }

    func fetchSeasons() async -> [Season]? {
        guard let show = show else {
            return nil
        }

        guard let showId = show.identifiers.trakt else {
            return nil
        }

        do {
            let result: [Season] = try await withCheckedThrowingContinuation { continuation in
                TraktAPIProvider.provider.request(.seasons(id: showId), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let seasons = try response.map([Season].self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.seasons = seasons.filter { $0.number != 0 }
                            }

                            continuation.resume(returning: seasons)
                        } catch {
                            print("Seasons request JSON mapping failed! \(error)")
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        print("Seasons request failure \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
            return result
        } catch {
            return nil
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return seasons.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "season", for: indexPath) as! SeasonButtonCollectionViewCell

        cell.media = seasons[indexPath.item].mediaModel(given: show)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.cell(self,
                       didSelect: seasons[indexPath.item])
    }
}
