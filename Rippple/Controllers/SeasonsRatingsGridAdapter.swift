//
//  SeasonsRatingsGridAdapter.swift
//  Rippple
//
//  Created by Kevin Cador on 24/05/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

enum SeasonsRatingsFilter: Int {
    case trakt
    case yours
}

struct SeasonsRatingsGridCoordinate: Hashable {
    let row: Int
    let column: Int
}

struct SeasonsRatingsCellViewModel {
    let text: String?
    let textColor: UIColor
    let backgroundColor: UIColor
    let progress: Float?
    let accessibilityLabel: String?

    var isEmpty: Bool {
        return text == nil
    }

    static let empty = SeasonsRatingsCellViewModel(text: nil,
                                                   textColor: .label,
                                                   backgroundColor: .systemBackground,
                                                   progress: nil,
                                                   accessibilityLabel: nil)
}

final class SeasonsRatingsGridAdapter {
    let show: Show

    private let seasons: [Season]
    private let filter: SeasonsRatingsFilter
    private let progress: ShowProgress?

    init(show: Show,
         seasons: [Season],
         filter: SeasonsRatingsFilter,
         progress: ShowProgress?) {
        self.show = show
        self.seasons = seasons
        self.filter = filter
        self.progress = progress
    }

    var seasonCount: Int {
        return seasons.count
    }

    var episodeRowCount: Int {
        return seasons.map { $0.episodes?.count ?? 0 }.max() ?? 0
    }

    var bodyItemCount: Int {
        return seasonCount * episodeRowCount
    }

    func coordinate(forBodyItem item: Int) -> SeasonsRatingsGridCoordinate? {
        guard seasonCount > 0 else { return nil }
        let row = item / seasonCount
        let column = item % seasonCount
        guard row < episodeRowCount else { return nil }
        return SeasonsRatingsGridCoordinate(row: row, column: column)
    }

    func seasonTitle(atColumn column: Int) -> String? {
        guard seasons.indices.contains(column) else { return nil }
        return "S\(String(format: "%02d", seasons[column].number))"
    }

    func episodeTitle(atRow row: Int) -> String? {
        guard row >= 0, row < episodeRowCount else { return nil }
        return "E\(String(format: "%02d", row + 1))"
    }

    func episode(at coordinate: SeasonsRatingsGridCoordinate) -> Episode? {
        guard seasons.indices.contains(coordinate.column) else { return nil }
        guard let episodes = seasons[coordinate.column].episodes else { return nil }
        guard episodes.indices.contains(coordinate.row) else { return nil }
        return episodes[coordinate.row]
    }

    func coordinate(forSeasonNumber seasonNumber: Int,
                    episodeNumber: Int?) -> SeasonsRatingsGridCoordinate? {
        guard let column = seasons.firstIndex(where: { $0.number == seasonNumber }) else { return nil }

        if let episodeNumber = episodeNumber {
            guard let episodes = seasons[column].episodes,
                  let row = episodes.firstIndex(where: { $0.number == episodeNumber }) else { return nil }
            return SeasonsRatingsGridCoordinate(row: row, column: column)
        }

        return SeasonsRatingsGridCoordinate(row: 0, column: column)
    }

    func mediaModel(at coordinate: SeasonsRatingsGridCoordinate) -> MediaModel? {
        return episode(at: coordinate)?.mediaModel(given: show)
    }

    func cellViewModel(at coordinate: SeasonsRatingsGridCoordinate) -> SeasonsRatingsCellViewModel {
        guard let episode = episode(at: coordinate) else { return .empty }

        var viewModel: SeasonsRatingsCellViewModel
        switch filter {
        case .trakt:
            guard let rating = episode.rating else { return .empty }
            let roundedRating = round(rating * 10) / 10.0
            viewModel = SeasonsRatingsCellViewModel(text: String(format: "%.1f", roundedRating),
                                                    textColor: .white,
                                                    backgroundColor: color(for: roundedRating),
                                                    progress: nil,
                                                    accessibilityLabel: accessibilityLabel(for: episode,
                                                                                           value: String(format: "%.1f", roundedRating),
                                                                                           source: "Trakt rating"))
        case .yours:
            if let ownRating = episode.userRating(for: show) {
                viewModel = SeasonsRatingsCellViewModel(text: "\(ownRating)",
                                                        textColor: .white,
                                                        backgroundColor: color(for: Double(ownRating)),
                                                        progress: nil,
                                                        accessibilityLabel: accessibilityLabel(for: episode,
                                                                                               value: "\(ownRating)",
                                                                                               source: "Your rating"))
            } else {
                viewModel = SeasonsRatingsCellViewModel(text: "?",
                                                        textColor: .white,
                                                        backgroundColor: .lightGray,
                                                        progress: nil,
                                                        accessibilityLabel: accessibilityLabel(for: episode,
                                                                                               value: "Not rated",
                                                                                               source: "Your rating"))
            }
        }

        viewModel = applyingAiringAndProgressState(to: viewModel, episode: episode)

        if let watchingItem = WatchingManager.shared.watchingItem,
           watchingItem.show == show,
           watchingItem.episode == episode {
            viewModel = SeasonsRatingsCellViewModel(text: viewModel.text,
                                                    textColor: viewModel.textColor,
                                                    backgroundColor: viewModel.backgroundColor,
                                                    progress: Float(WatchingManager.shared.progress),
                                                    accessibilityLabel: viewModel.accessibilityLabel)
        }

        return viewModel
    }

    private func applyingAiringAndProgressState(to viewModel: SeasonsRatingsCellViewModel,
                                                episode: Episode) -> SeasonsRatingsCellViewModel {
        guard let firstAired = episode.firstAired else {
            return SeasonsRatingsCellViewModel(text: "...",
                                               textColor: viewModel.textColor,
                                               backgroundColor: .lightGray,
                                               progress: nil,
                                               accessibilityLabel: accessibilityLabel(for: episode,
                                                                                      value: "Not aired",
                                                                                      source: nil))
        }

        guard firstAired <= Date.now else {
            return SeasonsRatingsCellViewModel(text: "...",
                                               textColor: viewModel.textColor,
                                               backgroundColor: .lightGray,
                                               progress: nil,
                                               accessibilityLabel: accessibilityLabel(for: episode,
                                                                                      value: "Airs later",
                                                                                      source: nil))
        }

        guard let progress = progress else { return viewModel }

        var watchedProgress: Float = 0.0
        for season in progress.seasons where season.number == episode.season {
            for episodeProgress in season.episodes where episodeProgress.number == episode.number && episodeProgress.completed {
                watchedProgress = 1.0
            }
        }

        return SeasonsRatingsCellViewModel(text: viewModel.text,
                                           textColor: viewModel.textColor,
                                           backgroundColor: viewModel.backgroundColor,
                                           progress: watchedProgress,
                                           accessibilityLabel: viewModel.accessibilityLabel)
    }

    private func color(for rating: Double) -> UIColor {
        if rating < 4 {
            return .systemRed
        } else if rating < 6 {
            return .systemOrange
        } else if rating < 8 {
            return .systemYellow
        } else {
            return .systemGreen
        }
    }

    private func accessibilityLabel(for episode: Episode,
                                    value: String,
                                    source: String?) -> String {
        let prefix = "Season \(episode.season), episode \(episode.number)"
        guard let source = source else {
            return "\(prefix), \(value)"
        }
        return "\(prefix), \(source): \(value)"
    }
}
