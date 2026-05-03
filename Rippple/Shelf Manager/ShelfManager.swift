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

struct ShelfSortConfiguration: Equatable {
    let by: String
    let how: String
}

struct ShelfModuleEditConfiguration {
    let name: String
    let module: String
    let ignoresWatched: Bool
    let sort: ShelfSortConfiguration
    let buttonStyle: ShelfBrowseActionButtonStyle
}

enum ShelfBrowseActionButtonStyle: String, Codable, CaseIterable, Equatable, Hashable {
    case none
    case ellipsis
    case checkmark
    case play
    case plus

    var label: String {
        switch self {
        case .none:
            return "Default"
        case .ellipsis:
            return "Track Menu"
        case .checkmark:
            return "Mark Watched"
        case .play:
            return "Check In"
        case .plus:
            return "Mark Watched On..."
        }
    }

    var systemImageName: String? {
        switch self {
        case .none:
            return nil
        case .ellipsis:
            return "ellipsis"
        case .checkmark:
            return "checkmark"
        case .play:
            return "play"
        case .plus:
            return "plus"
        }
    }
}

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
        shelf = modules.map { $0.shelfLine }.joined(separator: "\n")
    }

    func delete(at indexSet: IndexSet) {
        var modules = shelfModules
        modules.remove(atOffsets: indexSet)
        shelf = modules.map { $0.shelfLine }.joined(separator: "\n")
    }

    func edit(module: BrowseViewController.ModuleType,
              with configuration: ShelfModuleEditConfiguration) {
        shelf = shelfModules.map {
            if $0 == module {
                let filter = $0.filter.updating(name: configuration.name,
                                                ignoreWatched: configuration.ignoresWatched,
                                                sort: configuration.sort)
                return BrowseViewController.ModuleType(module: configuration.module,
                                                       filter: filter,
                                                       buttonStyle: configuration.buttonStyle == .none ? nil : configuration.buttonStyle).shelfLine
            } else {
                return $0.shelfLine
            }
        }.joined(separator: "\n")
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

extension BrowseViewController.ModuleType {
    fileprivate var shelfLine: String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self),
              let string = String(data: data, encoding: .utf8) else {
            return "{ \"module\": \"\(module)\", \(filter.filterString) }"
        }
        return string
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

    fileprivate func filterString(with name: String, ignoreWatched: Bool, sort: ShelfSortConfiguration) -> String {
        return updating(name: name, ignoreWatched: ignoreWatched, sort: sort).filterString
    }

    fileprivate func updating(name: String, ignoreWatched: Bool, sort: ShelfSortConfiguration) -> SavedFilter {
        var parts = query.split(separator: "&").map(String.init).filter {
            let part = $0.lowercased()
            return !part.hasPrefix("ignore_watched=") && !part.hasPrefix("sort_by=") && !part.hasPrefix("sort_how=")
        }
        if ignoreWatched {
            parts.append("ignore_watched=true")
        }
        if !sort.by.isEmpty && !sort.how.isEmpty {
            parts.append("sort_by=\(sort.by)")
            parts.append("sort_how=\(sort.how)")
        }
        let updatedQuery = parts.joined(separator: "&")
        return SavedFilter(section: section,
                           name: name,
                           path: path,
                           query: updatedQuery,
                           limit: limit)
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
