//
//  ShelfManager.swift
//  Rippple
//
//  Created by Kevin Cador on 24/07/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import Foundation

import Receiver

let (onShelfChangedTransmitter, onShelfChangedReceiver) = Receiver<String>.make(with: .warm(upTo: 1))

extension StringProtocol {
    fileprivate var lines: [SubSequence] { split(whereSeparator: \.isNewline) }
    fileprivate var removingAllExtraNewLines: String { lines.joined(separator: "\n") }
}

final class ShelfManager {

    static let shared = ShelfManager()

    private let disposeBag = DisposeBag()

    private init() {
        // NSUbiquitousKeyValueStore.default.removeObject(forKey: "ShelfManager.shelf")
        if let shelf = NSUbiquitousKeyValueStore.default.string(forKey: "ShelfManager.shelf") {
            var sanitizedShelf = ""
            for line in shelf.removingAllExtraNewLines.components(separatedBy: .newlines) {
                let jsonData = line.data(using: .utf8)!
                do {
                    _ = try JSONDecoder().decode(BrowseViewController.ModuleType.self, from: jsonData)
                    sanitizedShelf += "\(line)\n"
                } catch {
                    print("Couldn't parse JSON line! \(error)")
                }
            }
            self.shelf = sanitizedShelf.removingAllExtraNewLines
        } else {
            self.shelf = ""
        }
        broadcastShelf()
    }

    private func broadcastShelf() {
        let shelf = self.shelf.removingAllExtraNewLines
        onShelfChangedTransmitter.broadcast(shelf)
        print("Shelf Transmited:\n\(shelf)")
    }

    var shelf: String = "default" {
        didSet {
            if shelf != oldValue {
                broadcastShelf()
                NSUbiquitousKeyValueStore.default.set(shelf.trimmingCharacters(in: .newlines), forKey: "ShelfManager.shelf")
            }
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var modules = shelfModules
        modules.move(fromOffsets: source, toOffset: destination)
        shelf = modules.map { "{ \"module\": \"\($0.module)\", \($0.filter.filterString) }" }.joined(separator: "\n")
    }

    func delete(at indexSet: IndexSet) {
        var modules = shelfModules
        modules.remove(atOffsets: indexSet)
        shelf = modules.map { "{ \"module\": \"\($0.module)\", \($0.filter.filterString) }" }.joined(separator: "\n")
    }

    func edit(module: BrowseViewController.ModuleType,
              with newName: String,
              and newModule: String,
              ignoringWatched: Bool) {
        shelf = shelfModules.map { "{ \"module\": \"\($0 == module ? newModule : $0.module)\", \($0 == module ? $0.filter.filterString(with: newName, and: ignoringWatched) : $0.filter.filterString) }" }.joined(separator: "\n")
    }

    var shelfModules: [BrowseViewController.ModuleType] {
        do {
            let jsonString = "[\(shelf.removingAllExtraNewLines.components(separatedBy: .newlines).joined(separator: ","))]"
            let jsonData = jsonString.data(using: .utf8)!
            return try JSONDecoder().decode([BrowseViewController.ModuleType].self, from: jsonData)
        } catch {
            print("Couldn't set shelf modules! \(error)")
            return [BrowseViewController.ModuleType]()
        }
    }

    func setup() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ubiquitousKeyValueStoreDidChange(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: NSUbiquitousKeyValueStore.default)

        if NSUbiquitousKeyValueStore.default.synchronize() == false {
            fatalError("This app was not built with the proper entitlement requests.")
        }
    }

    @objc func ubiquitousKeyValueStoreDidChange(_ notification: NSNotification) {
        if let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            for key in keys where key == "ShelfManager.shelf" {
                if let shelf = NSUbiquitousKeyValueStore.default.string(forKey: "ShelfManager.shelf") {
                    var sanitizedShelf = ""
                    for line in shelf.removingAllExtraNewLines.components(separatedBy: .newlines) {
                        let jsonData = line.data(using: .utf8)!
                        do {
                            _ = try JSONDecoder().decode(BrowseViewController.ModuleType.self, from: jsonData)
                            sanitizedShelf += "\(line)\n"
                        } catch {
                            print("Couldn't parse JSON line! \(error)")
                        }
                    }
                    self.shelf = sanitizedShelf.removingAllExtraNewLines
                    return
                }
            }
        }
    }
}

extension SavedFilter {
    public func shelf(onTop: Bool, module: String? = "L1") {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        if onTop {
            ShelfManager.shared.shelf =  """
{ "module": "\(module ?? "L1")", \(filterString) }\n
""" + ShelfManager.shared.shelf
        } else {
            ShelfManager.shared.shelf += """
\n{ "module": "\(module ?? "L1")", \(filterString) }
"""
        }
    }

    public func unshelf() {
        let pathAndQuery = """
"path": "\(path)", "query": "\(query)"
"""
        let section = """
"section": "\(section)"
"""

        let lines = ShelfManager.shared.shelf.components(separatedBy: "\n")
        var newShelf = ""
        for line in lines where !(line.localizedStandardContains(pathAndQuery) && line.localizedStandardContains(section)) {
            newShelf += "\(line)\n"
        }
        ShelfManager.shared.shelf = newShelf.trimmingCharacters(in: .newlines)
    }

    fileprivate var filterString: String {
        return """
"filter": { "section": "\(section)", "name": "\(name.replacingOccurrences(of: "\"", with: "\\\""))", "path": "\(path)", "query": "\(query)" }
"""
    }

    fileprivate func filterString(with name: String, and ignoreWatched: Bool) -> String {
        // Prepare updated query by adding/removing ignore_watched parameter based on flag
        var parts = query.split(separator: "&").map(String.init).filter { !$0.lowercased().hasPrefix("ignore_watched=") }
        if ignoreWatched {
            parts.append("ignore_watched=true")
        }
        let updatedQuery = parts.joined(separator: "&")
        let escapedName = name.replacingOccurrences(of: "\"", with: "\\\"")
        return """
"filter": { "section": "\(section)", "name": "\(escapedName)", "path": "\(path)", "query": "\(updatedQuery)" }
"""
    }

    var isShelved: Bool {
        let pathAndQuery = """
"path": "\(path)", "query": "\(query)"
"""
        let section = """
"section": "\(section)"
"""
        return ShelfManager.shared.shelf.localizedStandardContains(pathAndQuery) && ShelfManager.shared.shelf.localizedStandardContains(section)
    }
}
