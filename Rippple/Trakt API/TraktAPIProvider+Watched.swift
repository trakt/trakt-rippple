//
//  TraktAPIProvider+Watched.swift
//  Rippple
//
//  Created by Kevin Cador on 28/04/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

private struct ActivityHistoryItem: Decodable {
    let watchedAt: Date

    enum CodingKeys: String, CodingKey {
        case watchedAt = "watched_at"
    }
}

extension TraktAPIProvider {
    static func fetchSyncWatchedItems(type: SyncWatchedType,
                                      completion: @escaping (Result<SyncWatchedItems, Error>) -> Void) {
        _Concurrency.Task {
            do {
                let items = try await fetchSyncWatchedItemsAsync(type: type)
                completion(.success(items))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchSyncWatchedItemsAsync(type: SyncWatchedType) async throws -> SyncWatchedItems {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.syncWatched(type: type),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map(SyncWatchedItems.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: items)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

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
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder)
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

    static func fetchActivityDates(slug: String,
                                   startDate: Date,
                                   endDate: Date,
                                   completion: @escaping (Result<[Date], Error>) -> Void) {
        _Concurrency.Task {
            do {
                let dates = try await fetchActivityDatesAsync(slug: slug,
                                                              startDate: startDate,
                                                              endDate: endDate)
                completion(.success(dates))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func fetchActivityDatesAsync(slug: String,
                                                startDate: Date,
                                                endDate: Date) async throws -> [Date] {
        var pageInfo = PageInfo.firstPage(with: 1000)
        var activityDates = [Date]()

        while true {
            let (items, nextPage) = try await fetchActivityHistoryPage(slug: slug,
                                                                       startDate: startDate,
                                                                       endDate: endDate,
                                                                       pageInfo: pageInfo)
            activityDates.append(contentsOf: items.map(\.watchedAt))

            guard let nextPage = nextPage, nextPage.page <= nextPage.pageCount else {
                return activityDates
            }

            pageInfo = nextPage
        }
    }

    private static func fetchActivityHistoryPage(slug: String,
                                                 startDate: Date,
                                                 endDate: Date,
                                                 pageInfo: PageInfo) async throws -> ([ActivityHistoryItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.history(slug: slug,
                                                       type: nil,
                                                       id: nil,
                                                       pageInfo: pageInfo,
                                                       startDate: startDate,
                                                       endDate: endDate,
                                                       extended: nil),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([ActivityHistoryItem].self, using: TraktAPIProvider.decoder)
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
