//
//  TraktAPIProvider+CollectionItems.swift
//  Rippple
//
//  Created by Kevin Cador on 21/01/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

import Moya

extension TraktAPIProvider {
    static func fetchAllCollectionItems(slug: String,
                                        type: ListMediaType?,
                                        extended: Extended?,
                                        sort: WatchlistSort?,
                                        limit: Int = 1000) async throws -> [CollectionItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var collectionItems = [CollectionItem]()

        while true {
            let (items, nextPage) = try await fetchCollectionPage(slug: slug,
                                                                  type: type,
                                                                  extended: extended,
                                                                  sort: sort,
                                                                  pageInfo: pageInfo)
            collectionItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return collectionItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchCollectionPage(slug: String,
                                            type: ListMediaType?,
                                            extended: Extended?,
                                            sort: WatchlistSort?,
                                            pageInfo: PageInfo) async throws -> ([CollectionItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.collection(slug: slug,
                                                          type: type,
                                                          extended: extended,
                                                          sort: sort,
                                                          pageInfo: pageInfo),
                                               callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([CollectionItem].self, using: TraktAPIProvider.decoder)
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
