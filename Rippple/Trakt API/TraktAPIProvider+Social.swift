//
//  TraktAPIProvider+Social.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

// swiftformat:disable redundantFileprivate
fileprivate extension MediaModel {
    var socialService: (PageInfo) -> TraktAPIService {
        switch self {
        case .movie(let movie):
            return { .movieSocial(id: movie.identifiers.slugOrTraktId, pageInfo: $0) }
        case .show(let show), .showProgress(let show, _):
            return { .showSocial(id: show.identifiers.slugOrTraktId, pageInfo: $0) }
        case .season(let season, let show):
            return { .seasonSocial(id: show.identifiers.slugOrTraktId, season: season.number, pageInfo: $0) }
        case .episode(let episode, let show):
            return { .episodeSocial(id: show.identifiers.slugOrTraktId, season: episode.season, episode: episode.number, pageInfo: $0) }
        case .list:
            fatalError("Social entries are not supported for lists")
        }
    }
}

// swiftformat:enable redundantFileprivate

extension TraktAPIProvider {
    static func fetchAllSocialEntries(for media: MediaModel,
                                      limit: Int = 100,
                                      completion: @escaping (Result<[SocialEntry], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let entries = try await fetchAllSocialEntriesAsync(for: media,
                                                                   limit: limit)
                completion(.success(entries))
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func fetchSocialEntries(for media: MediaModel,
                                   pageInfo: PageInfo = PageInfo.firstPage(with: 100),
                                   completion: @escaping (Result<(entries: [SocialEntry], nextPage: PageInfo?), Error>) -> Void) {
        _Concurrency.Task {
            do {
                let page = try await fetchSocialEntriesAsync(for: media,
                                                             pageInfo: pageInfo)
                completion(.success(page))
            } catch {
                completion(.failure(error))
            }
        }
    }

    static func fetchAllSocialEntriesAsync(for media: MediaModel,
                                           limit: Int = 100) async throws -> [SocialEntry] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var socialEntries = [SocialEntry]()

        while true {
            let (entries, nextPage) = try await fetchSocialEntriesAsync(for: media,
                                                                        pageInfo: pageInfo)
            socialEntries.append(contentsOf: entries)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return socialEntries
            }

            pageInfo = nextPage
        }
    }

    static func fetchSocialEntriesAsync(for media: MediaModel,
                                        pageInfo: PageInfo = PageInfo.firstPage(with: 100)) async throws -> (entries: [SocialEntry], nextPage: PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(media.socialService(pageInfo),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        if response.statusCode == 204 {
                            continuation.resume(returning: ([], nil))
                            return
                        }

                        let entries = try response.map([SocialEntry].self, using: TraktAPIProvider.decoder)
                        let nextPage = response.response.flatMap { PageInfo(headers: $0.allHeaderFields)?.nextPage }
                        continuation.resume(returning: (entries, nextPage))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
