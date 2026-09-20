//
//  TraktSearch.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

struct TraktSearchResult: Decodable, Hashable {
    let movie: Movie?
    let show: Show?
    let person: Person?
    let score: Double?

    var type: SearchType {
        movie != nil ? .movie : show != nil ? .show : .person
    }

    var id: Int64? {
        movie?.identifiers.trakt ?? show?.identifiers.trakt ?? person?.ids.trakt
    }

    var key: String {
        "\(type.rawValue):\(id ?? 0)"
    }

    var title: String {
        movie?.title ?? show?.title ?? person?.name ?? ""
    }

    var year: Int? {
        movie?.releaseYear ?? show?.releaseYear
    }

    var subtitle: String {
        ([type == .movie ? "Movie" : type == .show ? "TV Show" : "Person"] + [year.map(String.init)].compactMap { $0 }).joined(separator: " · ")
    }

    var media: MediaModel? {
        if let movie = movie { return .movie(movie) }
        if let show = show { return .show(show) }
        return nil
    }

    static func == (lhs: TraktSearchResult, rhs: TraktSearchResult) -> Bool {
        lhs.key == rhs.key
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
    }
}

/// Each request owns its responses. Cancellation and delivery are confined to the main queue.
private final class TraktSearchRequest: Cancellable {
    var requests = [Cancellable]()
    var isCancelled = false
    func cancel() {
        isCancelled = true
        let pending = requests
        requests.removeAll()
        pending.forEach { $0.cancel() }
    }
}

@MainActor
private final class TraktAsyncSearchRequest {
    private var request: Cancellable?
    private var continuation: CheckedContinuation<[TraktSearchResult], Error>?
    private var isCancelled = false

    func start(query: String, type: SearchType, continuation: CheckedContinuation<[TraktSearchResult], Error>) {
        guard isCancelled == false else {
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        request = TraktAPIProvider.search(query: query, type: type) { [weak self] result in
            guard let self = self else { return }
            self.finish(result)
        }
    }

    func cancel() {
        isCancelled = true
        let pending = request
        finish(.failure(CancellationError()))
        pending?.cancel()
    }

    private func finish(_ result: Result<[TraktSearchResult], Error>) {
        let pending = continuation
        continuation = nil
        request = nil
        pending?.resume(with: result)
    }
}

extension TraktAPIProvider {
    @discardableResult
    static func search(query: String, type: SearchType = .moviesAndShow, includePeople: Bool = false,
                       onUpdate: (([TraktSearchResult]) -> Void)? = nil,
                       completion: @escaping (Result<[TraktSearchResult], Error>) -> Void) -> Cancellable {
        let request = TraktSearchRequest()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var targets: [TraktAPIService] = query.isEmpty
            ? (type == .moviesAndShow ? [.searchTrending(type: .movie, query: ""), .searchTrending(type: .show, query: "")] : [.searchTrending(type: type, query: "")])
            : [.searchExact(type: type, query: query), .searchTrending(type: type, query: query), .search(type: type, query: query)]
        if includePeople, query.isEmpty == false { targets.append(.search(type: .person, query: query)) }
        var results = [[TraktSearchResult]?](repeating: nil, count: targets.count)
        var remaining = targets.count
        var failure: Error?
        for (index, target) in targets.enumerated() {
            let child = noRatingProvider.request(target, callbackQueue: .global(qos: .userInitiated)) { response in
                let decoded: Result<[TraktSearchResult], Error> = Result {
                    let response = try response.get().filterSuccessfulStatusCodes()
                    return try response.map([TraktSearchResult].self, using: decoder)
                }
                DispatchQueue.main.async {
                    guard request.isCancelled == false else { return }
                    switch decoded {
                    case .success(let items): results[index] = items
                    case .failure(let error): failure = error
                    }
                    remaining -= 1
                    if remaining == 0 { request.requests.removeAll() }
                    if remaining == 0, results.allSatisfy({ $0 == nil }), let failure = failure {
                        completion(.failure(failure))
                        return
                    }
                    let exact = results[0] ?? []
                    // Raw exact scores use 2/1/0 bands; never compare them with fuzzy scores.
                    let trending = query.isEmpty && type == .moviesAndShow ? interleaveTrending(movies: exact, shows: results[1] ?? []) : exact
                    let ordered = query.isEmpty ? trending : exact.filter { ($0.score ?? 1) >= 1 }
                        + (results[1] ?? []) + (results[2] ?? [])
                        + exact.filter { ($0.score ?? 1) < 1 }
                    var seen = Set<String>()
                    let media = ordered.filter { ($0.id ?? 0) > 0 && !$0.title.isEmpty && seen.insert($0.key).inserted }
                    let people = includePeople && results.count > 3 ? (results[3] ?? []).prefix(12) : []
                    let combined = media + people.filter { ($0.id ?? 0) > 0 && seen.insert($0.key).inserted }
                    if remaining > 0 {
                        if combined.isEmpty == false { onUpdate?(combined) }
                        return
                    }
                    if combined.isEmpty, let failure = failure {
                        completion(.failure(failure))
                    } else {
                        completion(.success(combined))
                    }
                }
            }
            request.requests.append(child)
        }
        return request
    }

    private static func interleaveTrending(movies: [TraktSearchResult], shows: [TraktSearchResult]) -> [TraktSearchResult] {
        var items = [TraktSearchResult]()
        for index in 0..<max(movies.count, shows.count) {
            if movies.indices.contains(index) { items.append(movies[index]) }
            if shows.indices.contains(index) { items.append(shows[index]) }
        }
        return items
    }

    static func search(query: String, type: SearchType = .moviesAndShow) async throws -> [TraktSearchResult] {
        try _Concurrency.Task.checkCancellation()
        let request = await TraktAsyncSearchRequest()
        let results = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.main.async {
                    request.start(query: query, type: type, continuation: continuation)
                }
            }
        } onCancel: {
            DispatchQueue.main.async {
                request.cancel()
            }
        }
        try _Concurrency.Task.checkCancellation()
        return results
    }

    static func recordSearchSelection(query: String, type: SearchType, id: Int64?) {
        guard let id = id, id > 0, SessionManager.shared.isLoggedOut == false else { return }
        noRatingProvider.request(.searchSelected(type: type, query: query, id: id)) { result in
            if case .success(let response) = result, (200..<300).contains(response.statusCode) { return }
            // Feedback is best effort and must never delay navigation or trigger a rating prompt.
            print("Trakt search selection could not be recorded")
        }
    }
}
