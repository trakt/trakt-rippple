//
//  TraktAPIProvider+ListItems.swift
//  Rippple
//
//  Created by Kevin Cador on 21/01/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

import Moya

extension TraktAPIProvider {
    static func fetchAllListItems(slug: String?,
                                  id: Int64,
                                  type: ListMediaType?,
                                  extended: Extended?,
                                  limit: Int = 1000,
                                  completion: @escaping (Result<[WatchlistItem], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchAllListItemsAsync(slug: slug,
                                                             id: id,
                                                             type: type,
                                                             extended: extended,
                                                             limit: limit)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchAllListItemsAsync(slug: String?,
                                               id: Int64,
                                               type: ListMediaType?,
                                               extended: Extended?,
                                               limit: Int) async throws -> [WatchlistItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var listItems = [WatchlistItem]()

        while true {
            let (items, nextPage) = try await fetchListItemsPage(slug: slug,
                                                                 id: id,
                                                                 type: type,
                                                                 extended: extended,
                                                                 pageInfo: pageInfo)
            listItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return listItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchListItemsPage(slug: String?,
                                           id: Int64,
                                           type: ListMediaType?,
                                           extended: Extended?,
                                           pageInfo: PageInfo) async throws -> ([WatchlistItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.listItems(slug: slug,
                                                         id: id,
                                                         type: type,
                                                         extended: extended,
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
