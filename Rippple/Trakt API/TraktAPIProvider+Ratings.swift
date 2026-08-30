//
//  TraktAPIProvider+Ratings.swift
//  Rippple
//
//  Created by Kevin Cador on 30/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

extension TraktAPIProvider {
    @discardableResult
    static func fetchAllRatedItems(slug: String,
                                   type: RatedMediaType?,
                                   extended: Extended?,
                                   limit: Int = 1000,
                                   completion: @escaping (Result<[RatedItem], Error>) -> Void) -> _Concurrency.Task<Void, Never> {
        return _Concurrency.Task {
            do {
                let items = try await fetchAllRatedItemsAsync(slug: slug,
                                                              type: type,
                                                              extended: extended,
                                                              limit: limit)
                guard _Concurrency.Task.isCancelled == false else { return }
                completion(.success(items))
            } catch {
                guard _Concurrency.Task.isCancelled == false else { return }
                completion(.failure(error))
            }
        }
    }

    private static func fetchAllRatedItemsAsync(slug: String,
                                                type: RatedMediaType?,
                                                extended: Extended?,
                                                limit: Int) async throws -> [RatedItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var ratedItems = [RatedItem]()

        while true {
            let (items, nextPage) = try await fetchRatedPage(slug: slug,
                                                             type: type,
                                                             extended: extended,
                                                             pageInfo: pageInfo)
            try _Concurrency.Task.checkCancellation()
            ratedItems.append(contentsOf: items)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return ratedItems
            }

            pageInfo = nextPage
        }
    }

    private static func fetchRatedPage(slug: String,
                                       type: RatedMediaType?,
                                       extended: Extended?,
                                       pageInfo: PageInfo) async throws -> ([RatedItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.rated(slug: slug,
                                                     type: type,
                                                     extended: extended,
                                                     pageInfo: pageInfo),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([RatedItem].self, using: TraktAPIProvider.decoder)
                        let nextPage = response.response.flatMap { PageInfo(headers: $0.allHeaderFields)?.nextPage }
                        continuation.resume(returning: (items, nextPage))
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
