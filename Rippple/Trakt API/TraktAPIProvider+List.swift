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
    static func fetchAllCustomLists(slug: String = "me",
                                    limit: Int = 1000,
                                    provider: MoyaProvider<TraktAPIService> = TraktAPIProvider.provider,
                                    completion: @escaping (Result<[List], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let lists = try await fetchAllCustomListsAsync(slug: slug,
                                                               limit: limit,
                                                               provider: provider)
                completion(.success(lists))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchAllCustomListsAsync(slug: String,
                                                 limit: Int,
                                                 provider: MoyaProvider<TraktAPIService>) async throws -> [List] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var lists = [List]()

        while true {
            let (pageLists, nextPage) = try await fetchCustomListsPage(slug: slug,
                                                                       pageInfo: pageInfo,
                                                                       provider: provider)
            lists.append(contentsOf: pageLists)

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return lists
            }

            pageInfo = nextPage
        }
    }

    private static func fetchCustomListsPage(slug: String,
                                             pageInfo: PageInfo,
                                             provider: MoyaProvider<TraktAPIService>) async throws -> ([List], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(.customLists(slug: slug,
                                          pageInfo: pageInfo),
                             callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        let nextPage = response.response.flatMap { PageInfo(headers: $0.allHeaderFields)?.nextPage }
                        continuation.resume(returning: (lists, nextPage))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func fetchAllListItems(slug: String?,
                                  id: Int64,
                                  type: ListMediaType?,
                                  limit: Int = 1000,
                                  completion: @escaping (Result<[WatchlistItem], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchAllListItemsAsync(slug: slug,
                                                             id: id,
                                                             type: type,
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
                                               limit: Int) async throws -> [WatchlistItem] {
        var pageInfo = PageInfo.firstPage(with: limit)
        var listItems = [WatchlistItem]()
        let marker = ListItemsMarkerManager.shared.marker(for: id)

        while true {
            let (items, nextPage) = try await fetchListItemsPage(slug: slug,
                                                                 id: id,
                                                                 type: type,
                                                                 pageInfo: pageInfo,
                                                                 marker: marker)
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
                                           pageInfo: PageInfo,
                                           marker: String) async throws -> ([WatchlistItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.listItems(slug: slug,
                                                         id: id,
                                                         type: type,
                                                         extended: .full,
                                                         pageInfo: pageInfo,
                                                         marker: marker),
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
