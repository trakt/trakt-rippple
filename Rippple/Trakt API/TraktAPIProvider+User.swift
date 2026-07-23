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
