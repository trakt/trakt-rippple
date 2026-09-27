//
//  TrendingSearchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import TinyStorage

let (onTrendingSearchChangedTransmitter, onTrendingSearchChangedReceiver) = Receiver<[TraktSearchResult]>.make(with: .warm(upTo: 1))

@MainActor
final class TrendingSearchManager {
    static let shared = TrendingSearchManager()

    private let disposeBag = DisposeBag()
    private let cacheKey = "TrendingSearchManager.results"
    private var request: Cancellable?
    private var lastSuccessfulRefresh: Date?
    private(set) var results = [TraktSearchResult]()

    private init() {}

    func setup() {
        results = TinyStorage.cache.retrieve(type: [TraktSearchResult].self, forKey: cacheKey) ?? []
        onTrendingSearchChangedTransmitter.broadcast(results)

        applicationLifecycleReceiver.listen { [weak self] lifecycle in
            guard case .didBecomeActive = lifecycle else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if let lastSuccessfulRefresh = self.lastSuccessfulRefresh,
                   Date().timeIntervalSince(lastSuccessfulRefresh) < 3600 { return }
                self.refresh()
            }
        }.disposed(by: disposeBag)
        refresh()
    }

    private func refresh() {
        guard request == nil else { return }
        request = TraktAPIProvider.search(query: "", requireCompleteResults: true) { [weak self] result in
            guard let self = self else { return }
            self.request = nil
            guard case .success(let results) = result else { return }
            self.lastSuccessfulRefresh = Date()
            let updatedResults = Array(results.prefix(50))
            // Search result equality only compares identity; cached metadata can change too.
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            guard let updatedData = try? encoder.encode(updatedResults),
                  updatedData != (try? encoder.encode(self.results)) else { return }
            self.results = updatedResults
            TinyStorage.cache.store(updatedResults, forKey: self.cacheKey)
            onTrendingSearchChangedTransmitter.broadcast(updatedResults)
        }
    }
}
