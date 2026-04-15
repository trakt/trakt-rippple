//
//  TraktAPIProvider+Recommended.swift
//  Rippple
//
//  Created by Kevin Cador on 24/03/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

import Moya

extension TraktAPIProvider {
    static func fetchAllRecommendedItems(slug: String,
                                         type: ListMediaType?,
                                         extended: Extended?,
                                         sort: WatchlistSort?,
                                         limit: Int = 1000,
                                         completion: @escaping (Result<[WatchlistItem], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchAllRecommendedItemsAsync(slug: slug,
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

    private static func fetchAllRecommendedItemsAsync(slug: String,
                                                      type: ListMediaType?,
                                                      extended: Extended?,
                                                      sort: WatchlistSort?,
                                                      limit: Int) async throws -> [WatchlistItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var recommendedItems = [WatchlistItem]()

        while true {
            let (items, nextPage) = try await fetchRecommendedPage(slug: slug,
                                                                   type: type,
                                                                   extended: extended,
                                                                   sort: sort,
                                                                   pageInfo: pageInfo)
            recommendedItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return recommendedItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchRecommendedPage(slug: String,
                                             type: ListMediaType?,
                                             extended: Extended?,
                                             sort: WatchlistSort?,
                                             pageInfo: PageInfo) async throws -> ([WatchlistItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.recommended(slug: slug,
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
