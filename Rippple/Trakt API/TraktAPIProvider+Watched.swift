//
//  TraktAPIProvider+Watched.swift
//  Rippple
//
//  Created by Kevin Cador on 28/04/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

import Moya

extension TraktAPIProvider {
    static func fetchAllWatchedItems(slug: String = "me",
                                     type: WatchedType,
                                     extended: Extended?,
                                     limit: Int = 1000,
                                     completion: @escaping (Result<[WatchedItem], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchAllWatchedItemsAsync(slug: slug,
                                                                type: type,
                                                                extended: extended,
                                                                limit: limit)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchAllWatchedItemsAsync(slug: String,
                                                  type: WatchedType,
                                                  extended: Extended?,
                                                  limit: Int) async throws -> [WatchedItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var watchedItems = [WatchedItem]()

        while true {
            let (items, nextPage) = try await fetchWatchedPage(slug: slug,
                                                               type: type,
                                                               extended: extended,
                                                               pageInfo: pageInfo)
            watchedItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return watchedItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchWatchedPage(slug: String,
                                         type: WatchedType,
                                         extended: Extended?,
                                         pageInfo: PageInfo) async throws -> ([WatchedItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.watched(slug: slug,
                                                       type: type,
                                                       extended: extended,
                                                       pageInfo: pageInfo),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder)
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
