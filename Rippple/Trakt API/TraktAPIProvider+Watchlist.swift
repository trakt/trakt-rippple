//
//  TraktAPIProvider+Watchlist.swift
//  Rippple
//
//  Created by Kevin Cador on 24/03/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

import Moya

extension TraktAPIProvider {
    static func fetchAllWatchlistItems(slug: String,
                                       type: ListMediaType?,
                                       extended: Extended?,
                                       sort: WatchlistSort?,
                                       limit: Int = 1000,
                                       completion: @escaping (Result<[WatchlistItem], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchAllWatchlistItemsAsync(slug: slug,
                                                                  type: type,
                                                                  extended: extended,
                                                                  sort: sort,
                                                                  limit: limit)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchAllWatchlistItemsAsync(slug: String,
                                                    type: ListMediaType?,
                                                    extended: Extended?,
                                                    sort: WatchlistSort?,
                                                    limit: Int) async throws -> [WatchlistItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var watchlistItems = [WatchlistItem]()

        while true {
            let (items, nextPage) = try await fetchWatchlistPage(slug: slug,
                                                                 type: type,
                                                                 extended: extended,
                                                                 sort: sort,
                                                                 pageInfo: pageInfo)
            watchlistItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return watchlistItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchWatchlistPage(slug: String,
                                           type: ListMediaType?,
                                           extended: Extended?,
                                           sort: WatchlistSort?,
                                           pageInfo: PageInfo) async throws -> ([WatchlistItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.watchlist(slug: slug,
                                                         type: type,
                                                         extended: extended,
                                                         sort: sort,
                                                         pageInfo: pageInfo),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([WatchlistItem].self, using: TraktAPIProvider.decoder)
                        let nextPage = response.response.flatMap { PageInfo(headers: $0.allHeaderFields)?.nextPage }
                        continuation.resume(returning: (items, nextPage))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
