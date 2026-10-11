//
//  WidgetSearch.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

struct WidgetSearchResult: Decodable {
    struct Media: Decodable {
        struct IDs: Decodable { let trakt: Int64 }
        let title: String
        let year: Int?
        let ids: IDs
    }

    let movie: Media?
    let show: Media?
    let score: Double?
    var type: String {
        movie == nil ? "show" : "movie"
    }

    var media: Media? {
        movie ?? show
    }

    var key: String {
        "\(type):\(media?.ids.trakt ?? 0)"
    }

    var subtitle: String {
        ([movie == nil ? "TV Show" : "Movie"] + [media?.year.map(String.init)].compactMap { $0 }).joined(separator: " · ")
    }
}

/// The intent extension uses the same lightweight URLSession boundary as the widget loaders.
struct WidgetSearchLoader {
    var session = URLSession.shared

    private var userAgent: String {
        let bundle = Bundle.main
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Rippple"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(name)/\(version) (\(build))"
    }

    func search(query: String) async throws -> [WidgetSearchResult] {
        async let exact = fetch(path: "/search/movie,show/exact", query: query)
        async let trending = fetch(path: "/search/recent_by_id/global/movies,shows", query: query)
        async let broad = fetch(path: "/search/movie,show", query: query)
        let responses = await[exact, trending, broad]
        try Task.checkCancellation()
        let successes = responses.compactMap { try? $0.get() }
        guard successes.isEmpty == false else { return try responses[0].get() }
        let exactItems = (try? responses[0].get()) ?? []
        let ordered = exactItems.filter { ($0.score ?? 1) >= 1 }
            + ((try? responses[1].get()) ?? []) + ((try? responses[2].get()) ?? [])
            + exactItems.filter { ($0.score ?? 1) < 1 }
        var seen = Set<String>()
        let items = Array(ordered.filter { seen.insert($0.key).inserted }.prefix(20))
        if items.isEmpty {
            for response in responses {
                _ = try response.get()
            }
        }
        return items
    }

    private func fetch(path: String, query: String) async -> Result<[WidgetSearchResult], Error> {
        do {
            var components = URLComponents(string: TraktAPIConfiguration.baseURL + path)
            components?.queryItems = [URLQueryItem(name: "query", value: query),
                                      URLQueryItem(name: "extended", value: "full"),
                                      URLQueryItem(name: "limit", value: "20")]
            let encodedQuery = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
            components?.percentEncodedQuery = encodedQuery
            guard let url = components?.url else { throw URLError(.badURL) }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(TraktAPIConfiguration.clientId, forHTTPHeaderField: "trakt-api-key")
            request.setValue("2", forHTTPHeaderField: "trakt-api-version")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let results = try JSONDecoder().decode([WidgetSearchResult].self, from: data)
                .filter { ($0.movie?.ids.trakt ?? $0.show?.ids.trakt ?? 0) > 0 }
            return .success(results)
        } catch { return .failure(error) }
    }
}
