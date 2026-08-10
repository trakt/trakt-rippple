//
//  RecentSearchManager.swift
//  Rippple
//
//  Created by Kevin Cador on 08/01/2023.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

typealias RecentSearch = SavedFilter

let (onRecentSearchChangedTransmitter, onRecentSearchChangedReceiver) = Receiver<[RecentSearch]>.make(with: .warm(upTo: 1))

extension RecentSearch {
    var searchFieldQuery: String {
        if let value = queryParameter(named: "query"),
           value.isEmpty == false {
            return value
        }

        let queryKey = "query="
        if query.lowercased().hasPrefix(queryKey) {
            let value = String(query.dropFirst(queryKey.count))
            return value.removingPercentEncoding ?? value
        }

        return name
    }

    private func queryParameter(named requestedName: String) -> String? {
        for parameter in query.split(separator: "&", omittingEmptySubsequences: false) {
            let components = parameter.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard let encodedName = components.first else { continue }
            let name = String(encodedName)
            guard name.removingPercentEncoding == requestedName else { continue }

            let value = components.count > 1 ? String(components[1]) : ""
            return value.removingPercentEncoding ?? value
        }

        return nil
    }
}

final class RecentSearchManager {
    private let disposeBag = DisposeBag()

    private init() {}

    static let shared = RecentSearchManager()

    var recentSearches = [RecentSearch]() {
        didSet {
            if recentSearches != oldValue {
                recentSearches.removeDuplicates()

                while recentSearches.count > 5 {
                    recentSearches.removeLast()
                }

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

    func save(title: String,
              query: String,
              path: String = "/search/movie,show",
              limit: Int = 50) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return }

        let recent = RecentSearch(section: "recent",
                                  name: title.isEmpty ? query : title,
                                  path: path,
                                  query: encodedQuery(for: query),
                                  limit: limit)
        recentSearches.insert(recent, at: 0)
    }

    func removeAll() {
        recentSearches = [RecentSearch]()
    }

    private func encodedQuery(for query: String) -> String {
        var components = URLComponents()
        components.queryItems = [URLQueryItem(name: "query", value: query)]
        return components.percentEncodedQuery ?? "query=\(query)"
    }
}
