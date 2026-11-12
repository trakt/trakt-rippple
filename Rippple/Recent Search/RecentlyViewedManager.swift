//
//  RecentlyViewedManager.swift
//  Rippple
//
//  Created by Kevin Cador on 08/01/2023.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

struct RecentlyViewedItem: Codable, Equatable {
    enum Kind: String, Codable {
        case movie
        case show
        case person
    }

    let kind: Kind
    let ids: Identifiers
    let title: String
    let year: Int?
    let knownForDepartment: String?

    var key: String {
        "\(kind.rawValue):\(ids.trakt ?? 0)"
    }

    var media: MediaModel? {
        switch kind {
        case .movie:
            return .movie(Movie(officialTitle: title, originalTitle: nil, releaseYear: year, identifiers: ids,
                                status: nil, commentCount: nil, tagline: nil, overview: nil, runtime: nil,
                                certification: nil, genres: nil, released: nil, country: nil, rating: nil,
                                votes: nil, homepage: nil, trailer: nil, language: nil))
        case .show:
            return .show(Show(officialTitle: title, originalTitle: nil, releaseYear: year, identifiers: ids,
                              commentCount: nil, airedEpisodes: nil, tagline: nil, overview: nil, runtime: nil,
                              certification: nil, genres: nil, firstAired: nil, country: nil, network: nil,
                              status: nil, airs: nil, rating: nil, votes: nil, homepage: nil, trailer: nil,
                              language: nil))
        case .person:
            return nil
        }
    }

    var person: Person? {
        guard kind == .person else { return nil }
        return Person(name: title, ids: ids, biography: nil, birthday: nil, death: nil, birthplace: nil,
                      height: nil, homepage: nil, socialIds: nil, knownForDepartment: knownForDepartment)
    }
}

let (onRecentlyViewedChangedTransmitter, onRecentlyViewedChangedReceiver) = Receiver<[RecentlyViewedItem]>.make(with: .warm(upTo: 1))

/// Synced through iCloud so items opened on another device show up here. Main-thread confined.
final class RecentlyViewedManager {
    private static let storageKey = "RecentlyViewedManager.items"
    private static let maximumCount = 100

    private init() {}

    static let shared = RecentlyViewedManager()

    private(set) var items = [RecentlyViewedItem]()

    func setup() {
        items = RecentlyViewedManager.storedItems()
        onRecentlyViewedChangedTransmitter.broadcast(items)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadFromStore),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: nil)
    }

    func record(_ media: MediaModel) {
        switch media {
        case .movie(let movie):
            record(RecentlyViewedItem(kind: .movie, ids: movie.identifiers, title: movie.title,
                                      year: movie.releaseYear, knownForDepartment: nil))
        case .show(let show), .showProgress(let show, _):
            record(RecentlyViewedItem(kind: .show, ids: show.identifiers, title: show.title,
                                      year: show.releaseYear, knownForDepartment: nil))
        case .episode, .season, .list:
            break
        }
    }

    func record(_ person: Person) {
        record(RecentlyViewedItem(kind: .person, ids: person.ids, title: person.name,
                                  year: nil, knownForDepartment: person.knownForDepartment))
    }

    func remove(_ item: RecentlyViewedItem) {
        store(items.filter { $0.key != item.key })
    }

    func removeAll() {
        store([])
    }

    private func record(_ item: RecentlyViewedItem) {
        guard item.ids.trakt != nil, item.title.isEmpty == false, items.first != item else { return }
        store([item] + items)
    }

    private func store(_ newItems: [RecentlyViewedItem]) {
        var seen = Set<String>()
        items = Array(newItems.filter { seen.insert($0.key).inserted }.prefix(RecentlyViewedManager.maximumCount))
        onRecentlyViewedChangedTransmitter.broadcast(items)
        NSUbiquitousKeyValueStore.default.set(try? PropertyListEncoder().encode(items), forKey: RecentlyViewedManager.storageKey)
    }

    @objc private func reloadFromStore(_ notification: Notification) {
        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String]
        guard changedKeys?.contains(RecentlyViewedManager.storageKey) ?? true else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let storedItems = RecentlyViewedManager.storedItems()
            guard storedItems != self.items else { return }
            self.items = storedItems
            onRecentlyViewedChangedTransmitter.broadcast(storedItems)
        }
    }

    private static func storedItems() -> [RecentlyViewedItem] {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: storageKey),
              let entries = try? PropertyListDecoder().decode([StoredEntry].self, from: data) else { return [] }
        return entries.compactMap(\.item)
    }

    /// Skips entries a newer app version wrote with a kind this version does not know.
    private struct StoredEntry: Decodable {
        let item: RecentlyViewedItem?

        init(from decoder: Decoder) throws {
            item = try? RecentlyViewedItem(from: decoder)
        }
    }
}
