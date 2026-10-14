//
//  TraktAPIProvider+List.swift
//  Rippple
//
//  Created by Kevin Cador on 21/01/2026.
//  Copyright © Trakt. All rights reserved.
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
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        let nextPage = response.response.flatMap { PageInfo(headers: $0.allHeaderFields)?.nextPage }
                        continuation.resume(returning: (lists, nextPage))
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
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

        while true {
            let (items, nextPage) = try await fetchListItemsPage(slug: slug,
                                                                 id: id,
                                                                 type: type,
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
                                           pageInfo: PageInfo) async throws -> ([WatchlistItem], PageInfo?) {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.listItems(slug: slug,
                                                         id: id,
                                                         type: type,
                                                         extended: .full,
                                                         pageInfo: pageInfo),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let items = try response.map([WatchlistItem].self, using: TraktAPIProvider.decoder)
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

// MARK: - Smart Lists

extension TraktAPIProvider {
    /// Smart lists can resolve from open-ended sources such as trending, so they are read as a single capped page.
    static let smartListDetailItemsLimit = 250
    static let smartListToWatchItemsLimit = 100

    static func fetchSmartLists(user: User,
                                provider: MoyaProvider<TraktAPIService> = TraktAPIProvider.provider,
                                completion: @escaping (Result<[List], Error>) -> Void) {
        provider.request(.smartLists(slug: user.identifiers.slug ?? "me"),
                         callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            completion(Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try response.map([SmartList].self, using: TraktAPIProvider.decoder).map { List(smartList: $0, user: user) }
            })
        }
    }

    static func fetchSmartList(slug: String,
                               user: User,
                               completion: @escaping (Result<List, Error>) -> Void) {
        noChacheProvider.request(.smartList(userSlug: user.identifiers.slug ?? "me", slug: slug),
                                 callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            completion(Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try List(smartList: response.map(SmartList.self, using: TraktAPIProvider.decoder), user: user)
            })
        }
    }

    /// Fetches the items of a custom list, or the first `smartListLimit` items a smart list currently resolves to.
    static func fetchAllListItems(list: List,
                                  type: ListMediaType?,
                                  smartListLimit: Int = smartListDetailItemsLimit,
                                  completion: @escaping (Result<[WatchlistItem], Error>) -> Void) {
        guard let slug = list.smartListSlug else {
            guard let id = list.identifiers.trakt else {
                completion(.failure(MoyaError.requestMapping("Missing list identifier")))
                return
            }
            fetchAllListItems(slug: list.user.identifiers.slug, id: id, type: type, completion: completion)
            return
        }

        TraktAPIProvider.provider.request(.smartListItems(slug: slug, pageInfo: PageInfo.firstPage(with: smartListLimit)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            completion(Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try response.map([SmartListItem].self, using: TraktAPIProvider.decoder)
                    .compactMap { $0.watchlistItem }
                    .filter { $0.matches(type) }
            })
        }
    }
}

extension List {
    var smartListSlug: String? {
        return smartList?.identifiers.slug
    }

    /// The first page of items, used by list previews.
    func previewItemsService(limit: Int) -> TraktAPIService? {
        let pageInfo = PageInfo.firstPage(with: limit)
        if let slug = smartListSlug {
            return .smartListItems(slug: slug, pageInfo: pageInfo)
        }
        guard isSmartList == false, let id = identifiers.trakt else { return nil }
        return .listItems(slug: user.identifiers.slug, id: id, type: nil, extended: .full, pageInfo: pageInfo)
    }

    func previewItems(from response: Response) throws -> [WatchlistItem] {
        if isSmartList {
            return try response.map([SmartListItem].self, using: TraktAPIProvider.decoder).compactMap { $0.watchlistItem }
        }
        return try response.map([WatchlistItem].self, using: TraktAPIProvider.decoder).sorted { $0.listedAt > $1.listedAt }
    }
}

private extension WatchlistItem {
    func matches(_ type: ListMediaType?) -> Bool {
        switch type {
        case .movies: return movie != nil
        case .shows: return show != nil && episode == nil && season == nil
        case .seasons: return season != nil
        case .episodes: return episode != nil
        case nil: return true
        }
    }
}

// MARK: - Collaborators

enum ListCollaboratorError: LocalizedError {
    case missingIdentifier
    case limitReached
    case signedOut

    var errorDescription: String? {
        switch self {
        case .missingIdentifier:
            return "This list couldn't be found."
        case .limitReached:
            return "This list has reached its collaborator limit."
        case .signedOut:
            return "You need to be signed in."
        }
    }
}

extension TraktAPIProvider {
    static func fetchListCollaborators(list: List) async throws -> [User] {
        guard let id = list.identifiers.trakt else { throw ListCollaboratorError.missingIdentifier }
        return try await withCheckedThrowingContinuation { continuation in
            noChacheProvider.request(.listCollaborators(id: id),
                                     callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                continuation.resume(with: Result {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    if response.statusCode == 204 { return [] }
                    return try response.map([User].self, using: TraktAPIProvider.decoder)
                })
            }
        }
    }

    /// Cast and crew appearing in more than one title of the list, in Trakt's ranked order.
    static func fetchFeaturedPeople(list: List) async throws -> [Person] {
        guard list.isSmartList == false, let id = list.identifiers.trakt else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            provider.request(.listFeaturedPeople(id: id),
                             callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                continuation.resume(with: Result {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    if response.statusCode == 204 { return [] }
                    return try response.map(FeaturedPeopleResponse.self, using: TraktAPIProvider.decoder).featured ?? []
                })
            }
        }
    }

    static func fetchFollowUsers(_ service: TraktAPIService) async throws -> [User] {
        return try await withCheckedThrowingContinuation { continuation in
            noChacheProvider.request(service,
                                     callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                continuation.resume(with: Result {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    return try response.map([Follow].self, using: TraktAPIProvider.decoder).map(\.user).removingDuplicates()
                })
            }
        }
    }

    /// Trakt only accepts people who follow the list owner, up to a per-list limit.
    static func addListCollaborator(_ user: User, to list: List) async throws {
        guard let id = list.identifiers.trakt else { throw ListCollaboratorError.missingIdentifier }
        try await requestCollaboratorChange(.addListCollaborator(id: id, userSlug: user.slug))
    }

    static func removeListCollaborator(_ user: User, from list: List) async throws {
        guard let id = list.identifiers.trakt else { throw ListCollaboratorError.missingIdentifier }
        try await requestCollaboratorChange(.removeListCollaborator(id: id, userSlug: user.slug))
    }

    private static func requestCollaboratorChange(_ service: TraktAPIService) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            provider.request(service,
                             callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                continuation.resume(with: Result {
                    do {
                        _ = try result.get().filterSuccessfulStatusCodes()
                    } catch let error as MoyaError where error.response?.statusCode == 420 {
                        throw ListCollaboratorError.limitReached
                    }
                })
            }
        }
    }
}

/// `extended=featured` returns the list summary with its featured people attached.
private struct FeaturedPeopleResponse: Decodable {
    let featured: [Person]?
}
