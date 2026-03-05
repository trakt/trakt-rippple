//
//  RecentSearchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 08/01/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Foundation

import Receiver

typealias RecentSearch = SavedFilter

let (onRecentSearchChangedTransmitter, onRecentSearchChangedReceiver) = Receiver<[RecentSearch]>.make(with: .warm(upTo: 1))

final class RecentSearchManager {

    private let disposeBag = DisposeBag()

    private init() { }

    static let shared = RecentSearchManager()

    public var recentSearches = [RecentSearch]() {
        didSet {
            if recentSearches != oldValue {
                recentSearches.removeDuplicates()

                while recentSearches.count > 5 { recentSearches.removeLast() }

                onRecentSearchChangedTransmitter.broadcast(recentSearches)
                NSUbiquitousKeyValueStore.default.set(try? PropertyListEncoder().encode(recentSearches), forKey: "RecentSearchManager.recentSearches")
            }
        }
    }

    func setup() {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: "RecentSearchManager.recentSearches"), let array = try? PropertyListDecoder().decode([SavedFilter].self, from: data) {
            recentSearches = array
        }

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadSearch),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil)
    }

    @objc private func reloadSearch() {
        if let data = NSUbiquitousKeyValueStore.default.data(forKey: "RecentSearchManager.recentSearches"), let array = try? PropertyListDecoder().decode([SavedFilter].self, from: data) {
            recentSearches = array
        }
    }

    public func removeAll() {
        recentSearches = [RecentSearch]()
    }
}
