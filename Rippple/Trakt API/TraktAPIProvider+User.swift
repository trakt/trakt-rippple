//
//  TraktAPIProvider+User.swift
//  Rippple
//
//  Created by Kevin Cador on 23/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

extension TraktAPIProvider {
    @discardableResult
    static func fetchUser(with id: String,
                          callbackQueue: DispatchQueue,
                          completion: @escaping Completion) -> Cancellable {
        let slugifiedId = id.slugify()
        let identifiers = id == slugifiedId ? [id] : [id, slugifiedId]
        let cancellable = SequentialCancellable()

        func requestUser(at index: Int) {
            guard cancellable.isCancelled == false else { return }

            let request = TraktAPIProvider.provider.request(.user(id: identifiers[index]),
                                                            callbackQueue: callbackQueue) { result in
                guard cancellable.isCancelled == false else { return }

                if case .success(let response) = result,
                   response.statusCode == 404,
                   identifiers.indices.contains(index + 1) {
                    requestUser(at: index + 1)
                    return
                }

                completion(result)
            }
            cancellable.replace(with: request)
        }

        requestUser(at: identifiers.startIndex)
        return cancellable
    }

    @discardableResult
    static func fetchUserCount(slug: String,
                               type: UserCountType,
                               startDate: Date? = nil,
                               endDate: Date? = nil,
                               completion: @escaping (Result<Int, Error>) -> Void) -> Cancellable {
        return TraktAPIProvider.provider.request(.userCount(slug: slug,
                                                            type: type,
                                                            startDate: startDate,
                                                            endDate: endDate),
                                                 callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            do {
                let response = try result.get().filterSuccessfulStatusCodes()
                guard let count = paginationValue("x-pagination-item-count", in: response) else {
                    throw UserCountError.missingPagination
                }
                completion(.success(count))
            } catch {
                completion(.failure(error))
            }
        }
    }

    @discardableResult
    static func fetchMonthlyUserCount(slug: String,
                                      type: UserCountType,
                                      startDate: Date,
                                      endDate: Date,
                                      completion: @escaping (Result<Int, Error>) -> Void) -> Cancellable {
        let cancellable = SequentialCancellable()
        var count = 0

        func requestPage(_ pageInfo: PageInfo) {
            guard cancellable.isCancelled == false else { return }

            let target: TraktAPIService
            switch type {
            case .ratings:
                target = .rated(slug: slug, type: nil, extended: nil, pageInfo: pageInfo)
            case .comments:
                target = .comments(type: .user(slug: slug), pageInfo: pageInfo, sortBy: .newest, replies: nil)
            default:
                completion(.failure(UserCountError.unsupportedMonthlyType))
                return
            }

            let request = TraktAPIProvider.provider.request(target,
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                guard cancellable.isCancelled == false else { return }

                do {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    let dates: [Date]
                    switch type {
                    case .ratings:
                        dates = try response.map([UserRatingDate].self, using: TraktAPIProvider.decoder).map(\.ratedAt)
                    case .comments:
                        dates = try response.map([UserCommentDate].self, using: TraktAPIProvider.decoder).map(\.comment.createdAt)
                    default:
                        throw UserCountError.unsupportedMonthlyType
                    }

                    count += dates.filter { $0 >= startDate && $0 < endDate }.count

                    // Both endpoints return newest first, so earlier entries cannot affect this month.
                    if dates.isEmpty || dates.contains(where: { $0 < startDate }) {
                        completion(.success(count))
                        return
                    }

                    guard let pageCount = paginationValue("x-pagination-page-count", in: response) else {
                        throw UserCountError.missingPagination
                    }
                    guard pageInfo.page < pageCount else {
                        completion(.success(count))
                        return
                    }

                    requestPage(pageInfo.nextPage)
                } catch {
                    completion(.failure(error))
                }
            }
            cancellable.replace(with: request)
        }

        requestPage(.firstPage(with: 10))
        return cancellable
    }

    private static func paginationValue(_ name: String, in response: Response) -> Int? {
        guard let value = response.response?.allHeaderFields.first(where: {
            String(describing: $0.key).caseInsensitiveCompare(name) == .orderedSame
        })?.value,
            let count = Int(String(describing: value)), count >= 0 else { return nil }
        return count
    }
}

private enum UserCountError: Error {
    case missingPagination
    case unsupportedMonthlyType
}

private struct UserRatingDate: Decodable {
    let ratedAt: Date

    enum CodingKeys: String, CodingKey {
        case ratedAt = "rated_at"
    }
}

private struct UserCommentDate: Decodable {
    let comment: CommentDate

    struct CommentDate: Decodable {
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
        }
    }
}

private final class SequentialCancellable: Cancellable {
    private let lock = NSLock()
    private var current: Cancellable?
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        let current = current
        self.current = nil
        lock.unlock()

        current?.cancel()
    }

    func replace(with cancellable: Cancellable) {
        lock.lock()
        let shouldCancel = cancelled
        if shouldCancel == false {
            current = cancellable
        }
        lock.unlock()

        if shouldCancel {
            cancellable.cancel()
        }
    }
}
