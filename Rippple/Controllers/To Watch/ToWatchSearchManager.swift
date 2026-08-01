//
//  ToWatchSearchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 21/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

struct ToWatchSearchableDataSource {
    let shows: [MediaModel]
    let movies: [MediaModel]

    static let empty = ToWatchSearchableDataSource(shows: [], movies: [])
}

@MainActor
final class ToWatchSearchManager {
    private enum ShowSource: Int, CaseIterable {
        case toWatch
        case upcoming
        case allToWatch
        case dropped
        case watchlist
        case completed
        case watched
        case hiddenProgress
        case hiddenCalendar
    }

    private enum MovieSource: Int, CaseIterable {
        case toWatch
        case upcoming
        case allToWatch
        case watchlist
        case watched
        case hiddenCalendar
    }

    private enum MediaIdentifier: Hashable {
        case movie(Movie)
        case show(Show)
    }

    static let shared = ToWatchSearchManager()

    private let disposeBag = DisposeBag()
    private var showDataSources = ShowSource.allCases.map { _ in [MediaModel]() }
    private var movieDataSources = MovieSource.allCases.map { _ in [MediaModel]() }

    private init() {}

    func setup() {
        onEpisodeToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveShows(models, from: .toWatch)
        }.disposed(by: disposeBag)
        onShowsToWatchChangedReceiver.listen { [weak self] shows in
            guard let self = self else { return }
            self.receiveShows(ToWatchSearchManager.sorted(Set(shows)).map(\.mediaModel), from: .allToWatch)
        }.disposed(by: disposeBag)
        onMovieToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveMovies(models, from: .toWatch)
        }.disposed(by: disposeBag)
        onAllMoviesToWatchChangedReceiver.listen { [weak self] movies in
            guard let self = self else { return }
            self.receiveMovies(ToWatchSearchManager.sorted(Set(movies)).map(\.mediaModel), from: .allToWatch)
        }.disposed(by: disposeBag)

        calendarSearchableDataSourceReceiver.listen { [weak self] dataSource in
            guard let self = self else { return }
            self.receiveShows(dataSource.shows, from: .upcoming)
            self.receiveMovies(dataSource.movies, from: .upcoming)
        }.disposed(by: disposeBag)
        onDroppedShowsChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveShows(models, from: .dropped)
        }.disposed(by: disposeBag)
        onWatchlistSearchableDataSourceChangedReceiver.listen { [weak self] dataSource in
            guard let self = self else { return }
            self.receiveShows(dataSource.shows, from: .watchlist)
            self.receiveMovies(dataSource.movies, from: .watchlist)
        }.disposed(by: disposeBag)
        onCompletedShowsChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveShows(models, from: .completed)
        }.disposed(by: disposeBag)
        onWatchedSearchableDataSourceChangedReceiver.listen { [weak self] dataSource in
            guard let self = self else { return }
            self.receiveShows(dataSource.shows, from: .watched)
            self.receiveMovies(dataSource.movies, from: .watched)
        }.disposed(by: disposeBag)
        onShowsHiddenFromProgressMediaChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveShows(models, from: .hiddenProgress)
        }.disposed(by: disposeBag)
        onShowsHiddenFromCalendarMediaChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveShows(models, from: .hiddenCalendar)
        }.disposed(by: disposeBag)
        onMoviesHiddenFromCalendarMediaChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            self.receiveMovies(models, from: .hiddenCalendar)
        }.disposed(by: disposeBag)
    }

    func searchMovies(for query: String, limit: Int) async -> [MediaModel] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false, limit > 0 else { return [] }

        let dataSources = movieDataSources
        return await ToWatchSearchManager.candidates(in: dataSources, query: query, limit: limit)
    }

    func searchShows(for query: String, limit: Int) async -> [MediaModel] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false, limit > 0 else { return [] }

        let dataSources = showDataSources
        let candidates = await ToWatchSearchManager.candidates(in: dataSources, query: query, limit: limit)
        guard _Concurrency.Task.isCancelled == false else { return [] }
        return await resolveProgress(in: candidates)
    }

    private nonisolated static func candidates(in sourceModels: [[MediaModel]],
                                               query: String,
                                               limit: Int) async -> [MediaModel] {
        guard limit > 0 else { return [] }

        var identifiers = Set<MediaIdentifier>()
        var results = [MediaModel]()

        for models in sourceModels {
            guard _Concurrency.Task.isCancelled == false else { return [] }
            var matches = [(model: MediaModel, modelOrder: Int, matchRank: Int)]()
            for (modelOrder, model) in models.enumerated() {
                guard _Concurrency.Task.isCancelled == false else { return [] }
                guard let matchRank = ToWatchSearchManager.matchRank(of: model, query: query) else { continue }
                matches.append((model, modelOrder, matchRank))
            }
            matches.sort {
                if $0.matchRank != $1.matchRank {
                    return $0.matchRank < $1.matchRank
                }
                return $0.modelOrder < $1.modelOrder
            }
            guard _Concurrency.Task.isCancelled == false else { return [] }

            for match in matches {
                guard _Concurrency.Task.isCancelled == false else { return [] }
                guard let identifier = ToWatchSearchManager.identifier(for: match.model),
                      identifiers.insert(identifier).inserted else { continue }
                results.append(match.model)
            }
            if results.count >= limit { break }
        }

        return Array(results.prefix(limit))
    }

    private nonisolated func receiveShows(_ models: [MediaModel], from source: ShowSource) {
        let models = models.compactMap(ToWatchSearchManager.showModel)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showDataSources[source.rawValue] = models
        }
    }

    private nonisolated func receiveMovies(_ models: [MediaModel], from source: MovieSource) {
        let models = models.compactMap(ToWatchSearchManager.movieModel)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.movieDataSources[source.rawValue] = models
        }
    }

    private nonisolated static func showModel(from model: MediaModel) -> MediaModel? {
        guard let show = model.show else { return nil }
        if case .showProgress = model { return model }
        return show.mediaModel
    }

    private nonisolated static func movieModel(from model: MediaModel) -> MediaModel? {
        return model.movie?.mediaModel
    }

    private nonisolated static func sorted(_ shows: Set<Show>) -> [Show] {
        return shows.sorted {
            let lhs = (normalized($0.title), $0.identifiers.trakt ?? 0)
            let rhs = (normalized($1.title), $1.identifiers.trakt ?? 0)
            return lhs < rhs
        }
    }

    private nonisolated static func sorted(_ movies: Set<Movie>) -> [Movie] {
        return movies.sorted {
            let lhs = (normalized($0.title), $0.identifiers.trakt ?? 0)
            let rhs = (normalized($1.title), $1.identifiers.trakt ?? 0)
            return lhs < rhs
        }
    }

    private nonisolated static func identifier(for model: MediaModel) -> MediaIdentifier? {
        if let movie = model.movie { return .movie(movie) }
        if let show = model.show { return .show(show) }
        return nil
    }

    private nonisolated static func matchRank(of model: MediaModel, query: String) -> Int? {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let values = searchableValues(for: model)
        guard terms.allSatisfy({ term in
            values.contains { $0.localizedStandardContains(term) }
        }) else { return nil }

        let normalizedQuery = normalized(query)
        let normalizedValues = values.map { normalized($0) }
        if normalizedValues.contains(normalizedQuery) { return 0 }
        if normalizedValues.contains(where: { $0.hasPrefix(normalizedQuery) }) { return 1 }
        return 2
    }

    private nonisolated static func searchableValues(for model: MediaModel) -> [String] {
        if let movie = model.movie {
            return [movie.title, movie.officialTitle] +
                [movie.originalTitle].compactMap { $0 } +
                [movie.releaseYear].compactMap { $0 }.map(String.init)
        }
        if let show = model.show {
            return [show.title, show.officialTitle] +
                [show.originalTitle].compactMap { $0 } +
                [show.releaseYear].compactMap { $0 }.map(String.init)
        }
        return []
    }

    private nonisolated static func normalized(_ value: String) -> String {
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func resolveProgress(in candidates: [MediaModel]) async -> [MediaModel] {
        let referenceDate = Date.now
        var results = [(Int, MediaModel)]()
        var unresolved = [(Int, Show)]()

        for (index, candidate) in candidates.enumerated() {
            guard let show = candidate.show else { continue }
            if let progress = ProgressManager.shared.cachedProgress(for: show) {
                results.append((index, ToWatchSearchManager.searchResult(for: show,
                                                                         progress: progress,
                                                                         at: referenceDate)))
            } else if case .showProgress(_, let progress) = candidate {
                results.append((index, ToWatchSearchManager.searchResult(for: show,
                                                                         progress: progress,
                                                                         at: referenceDate)))
            } else {
                unresolved.append((index, show))
            }
        }

        guard unresolved.isEmpty == false else { return sortedResults(results) }

        await withTaskGroup(of: (Int, MediaModel?).self) { group in
            for (index, show) in unresolved {
                group.addTask {
                    guard _Concurrency.Task.isCancelled == false else { return (index, nil) }
                    let progress = await show.mediaModel.progress()
                    guard _Concurrency.Task.isCancelled == false else { return (index, nil) }

                    let result = progress.map {
                        ToWatchSearchManager.searchResult(for: show,
                                                          progress: $0,
                                                          at: referenceDate)
                    } ?? show.mediaModel
                    return (index, result)
                }
            }

            for await(index, model) in group {
                if let model { results.append((index, model)) }
            }
        }

        guard _Concurrency.Task.isCancelled == false else { return [] }
        return sortedResults(results)
    }

    private nonisolated static func searchResult(for show: Show,
                                                 progress: ShowProgress,
                                                 at referenceDate: Date) -> MediaModel {
        guard let firstAired = progress.nextEpisodeToWatch?.firstAired,
              firstAired <= referenceDate else { return show.mediaModel }
        return .showProgress(show, progress)
    }

    private func sortedResults(_ results: [(Int, MediaModel)]) -> [MediaModel] {
        return results.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
