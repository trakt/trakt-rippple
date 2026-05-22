//
//  ListItemsMarkerManager.swift
//  Rippple
//
//  Created by Kevin Cador on 27/03/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

final class ListItemsMarkerManager {
    static let shared = ListItemsMarkerManager()

    private var markers = [Int64: String]()
    private let lock = NSLock()

    private init() {}

    func marker(for listId: Int64) -> String {
        lock.lock()
        defer { lock.unlock() }

        if let marker = markers[listId] {
            return marker
        }

        let marker = UUID().uuidString
        markers[listId] = marker
        return marker
    }

    func invalidate(listId: Int64) {
        lock.lock()
        defer { lock.unlock() }
        markers[listId] = UUID().uuidString
    }

    func invalidate(lists: [List]) {
        for list in lists {
            if let listId = list.identifiers.trakt {
                invalidate(listId: listId)
            }
        }
    }
}
