//
//  OpenActionManager.swift
//  Rippple
//
//  Created by Kevin Cador on 18/03/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

let (onCustomOpenActionsChangedTransmitter, onCustomOpenActionsChangedReceiver) = Receiver<[CustomOpenAction]>.make(with: .warm(upTo: 1))
let (onBuiltInOpenActionsChangedTransmitter, onBuiltInOpenActionsChangedReceiver) = Receiver<[BuiltInOpenAction]>.make(with: .warm(upTo: 1))

final class OpenActionManager {
    static let shared = OpenActionManager()

    private let customOpenActionsKey = "OpenAction.custom.actions"
    private let openActionItemsKey = "OpenAction.items"

    private init() {}

    func setup() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(ubiquitousKeyValueStoreDidChange(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                               object: NSUbiquitousKeyValueStore.default)

        if NSUbiquitousKeyValueStore.default.synchronize() == false {
            fatalError("This app was not built with the proper entitlement requests.")
        }
    }

    @objc private func ubiquitousKeyValueStoreDidChange(_ notification: NSNotification) {
        guard let keys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else {
            return
        }
        if keys.contains(customOpenActionsKey) {
            onCustomOpenActionsChangedTransmitter.broadcast(customOpenActions)
        }

        if keys.contains(openActionItemsKey) {
            onBuiltInOpenActionsChangedTransmitter.broadcast(BuiltInOpenAction.allCases)
        }
    }

    // MARK: - Custom actions

    var customOpenActions: [CustomOpenAction] {
        get {
            guard let data = NSUbiquitousKeyValueStore.default.data(forKey: customOpenActionsKey),
                  let decoded = try? JSONDecoder().decode([CustomOpenAction].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                NSUbiquitousKeyValueStore.default.set(data, forKey: customOpenActionsKey)
            }
            onCustomOpenActionsChangedTransmitter.broadcast(newValue)
        }
    }

    func customActions(for media: MediaModel) -> [(action: CustomOpenAction, url: URL)] {
        guard let mediaType = media.openActionMediaType else { return [] }

        return customOpenActions.compactMap { item in
            guard item.mediaTypes.contains(mediaType) else { return nil }
            guard let url = OpenActionURLResolver.resolve(template: item.urlTemplate, for: media) else { return nil }
            return (item, url)
        }
    }

    // MARK: - Ordered actions

    var openActionItems: [OpenActionItem] {
        get {
            openActionItems(for: customOpenActions)
        }
        set {
            let normalized = normalizedOpenActionItems(newValue,
                                                       customActions: customOpenActions,
                                                       shouldAppendMissingCustomActions: false)
            if let data = try? JSONEncoder().encode(normalized) {
                NSUbiquitousKeyValueStore.default.set(data, forKey: openActionItemsKey)
            }
            onBuiltInOpenActionsChangedTransmitter.broadcast(BuiltInOpenAction.allCases)
        }
    }

    func actions(for media: MediaModel) -> [(action: CustomOpenAction, url: URL)] {
        guard let mediaType = media.openActionMediaType else { return [] }

        let currentCustomActions = customOpenActions
        var customActionsByID: [UUID: CustomOpenAction] = [:]
        for customAction in currentCustomActions where customActionsByID[customAction.id] == nil {
            customActionsByID[customAction.id] = customAction
        }

        return openActionItems(for: currentCustomActions).compactMap { item in
            if let builtInAction = item.builtInAction {
                return builtInAction.actions(for: media)
            }

            guard let customActionID = item.customActionID,
                  let customAction = customActionsByID[customActionID],
                  customAction.mediaTypes.contains(mediaType),
                  let url = OpenActionURLResolver.resolve(template: customAction.urlTemplate, for: media) else {
                return nil
            }

            return (customAction, url)
        }
    }

    private func openActionItems(for customActions: [CustomOpenAction]) -> [OpenActionItem] {
        guard let storedItems = storedOpenActionItems else {
            return defaultOpenActionItems(for: customActions)
        }

        return normalizedOpenActionItems(storedItems,
                                         customActions: customActions,
                                         shouldAppendMissingCustomActions: true)
    }

    private var storedOpenActionItems: [OpenActionItem]? {
        guard let data = NSUbiquitousKeyValueStore.default.data(forKey: openActionItemsKey),
              let decoded = try? JSONDecoder().decode([OpenActionItem].self, from: data) else {
            return nil
        }

        return decoded
    }

    private func defaultOpenActionItems(for customActions: [CustomOpenAction]) -> [OpenActionItem] {
        let builtInItems = BuiltInOpenAction.allCases
            .filter { $0.enabled }
            .map(OpenActionItem.init(builtInAction:))
        let customItems = customActions.map { OpenActionItem(customActionID: $0.id) }

        return builtInItems + customItems
    }

    private func normalizedOpenActionItems(_ items: [OpenActionItem],
                                           customActions: [CustomOpenAction],
                                           shouldAppendMissingCustomActions: Bool) -> [OpenActionItem] {
        let customActionIDs = Set(customActions.map(\.id))
        var seenIDs = Set<String>()
        var normalized: [OpenActionItem] = []

        for item in items {
            let isValid: Bool
            switch item.kind {
            case .builtIn:
                isValid = item.builtInAction != nil
            case .custom:
                isValid = item.customActionID.map { customActionIDs.contains($0) } ?? false
            }

            guard isValid, seenIDs.insert(item.id).inserted else { continue }
            normalized.append(item)
        }

        if shouldAppendMissingCustomActions {
            for customAction in customActions {
                let item = OpenActionItem(customActionID: customAction.id)
                if seenIDs.insert(item.id).inserted {
                    normalized.append(item)
                }
            }
        }

        return normalized
    }

    // MARK: - Built-in actions

    func builtInActions(for media: MediaModel) -> [(action: CustomOpenAction, url: URL)] {
        BuiltInOpenAction.allCases
            .filter { $0.enabled }
            .compactMap { $0.actions(for: media) }
    }
}

// MARK: - Models

struct OpenActionItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    let kind: Kind
    let rawValue: String

    var id: String {
        "\(kind.rawValue):\(rawValue)"
    }

    var builtInAction: BuiltInOpenAction? {
        guard kind == .builtIn else { return nil }
        return BuiltInOpenAction(rawValue: rawValue)
    }

    var customActionID: UUID? {
        guard kind == .custom else { return nil }
        return UUID(uuidString: rawValue)
    }

    init(builtInAction: BuiltInOpenAction) {
        kind = .builtIn
        rawValue = builtInAction.rawValue
    }

    init(customActionID: UUID) {
        kind = .custom
        rawValue = customActionID.uuidString
    }
}

enum BuiltInOpenAction: String, CaseIterable, Identifiable, Hashable {
    case trakt
    case tmdb
    case imdb
    case stremio
    case infuse

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .trakt:
            return "Trakt"
        case .tmdb:
            return "TMDb"
        case .imdb:
            return "IMDb"
        case .stremio:
            return "Stremio"
        case .infuse:
            return "Infuse"
        }
    }

    var subtitle: String {
        switch self {
        case .trakt:
            return "app.trakt.tv"
        case .tmdb:
            return "themoviedb.org"
        case .imdb:
            return "imdb.com"
        case .stremio:
            return "stremio"
        case .infuse:
            return "infuse"
        }
    }

    var systemImageName: String {
        switch self {
        case .trakt:
            return "link"
        case .tmdb:
            return "link"
        case .imdb:
            return "link"
        case .stremio:
            return "play.diamond.fill"
        case .infuse:
            return "play"
        }
    }
}

extension BuiltInOpenAction {
    var enabled: Bool {
        get {
            let key = "OpenAction.builtIn." + rawValue
            if UserDefaults.standard.object(forKey: key) == nil {
                switch self {
                case .stremio, .infuse:
                    return false
                case .trakt, .tmdb, .imdb:
                    return true
                }
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            let key = "OpenAction.builtIn." + rawValue
            UserDefaults.standard.set(newValue, forKey: key)

            onBuiltInOpenActionsChangedTransmitter.broadcast(BuiltInOpenAction.allCases)
        }
    }

    func url(for media: MediaModel) -> URL? {
        switch self {
        case .trakt:
            return media.traktWebsiteMediaLink
        case .tmdb:
            return media.tmdbURL
        case .imdb:
            return media.imdbURL
        case .stremio:
            switch media {
            case .movie(let movie):
                guard let id = movie.identifiers.imdb else { return nil }
                return URL(string: "https://web.strem.io/#/detail/movie/\(id)/\(id)")
            case .show(let show):
                guard let id = show.identifiers.imdb else { return nil }
                return URL(string: "https://web.strem.io/#/detail/series/\(id)")
            case .season(_, let show):
                guard let id = show.identifiers.imdb else { return nil }
                return URL(string: "https://web.strem.io/#/detail/series/\(id)")
            case .episode(let episode, let show):
                guard let id = show.identifiers.imdb else { return nil }
                let videoId = "\(id):\(episode.season):\(episode.number)"
                return URL(string: "https://web.strem.io/#/detail/series/\(id)/\(videoId)")
            case .list, .showProgress:
                return nil
            }
        case .infuse:
            switch media {
            case .movie(let movie):
                guard let tmdbId = movie.identifiers.tmdb else { return nil }
                return URL(string: "infuse://movie/\(tmdbId)")
            case .show(let show):
                guard let tmdbId = show.identifiers.tmdb else { return nil }
                return URL(string: "infuse://series/\(tmdbId)")
            case .season(let season, let show):
                guard let tmdbId = show.identifiers.tmdb else { return nil }
                return URL(string: "infuse://series/\(tmdbId)-\(season.number)")
            case .episode(let episode, let show):
                guard let tmdbId = show.identifiers.tmdb else { return nil }
                return URL(string: "infuse://series/\(tmdbId)-\(episode.season)-\(episode.number)")
            case .list, .showProgress:
                return nil
            }
        }
    }

    func actions(for media: MediaModel) -> (action: CustomOpenAction, url: URL)? {
        guard let url = url(for: media),
              let mediaType = media.openActionMediaType else {
            return nil
        }

        let item = CustomOpenAction(id: UUID(),
                                    name: title,
                                    urlTemplate: url.absoluteString,
                                    mediaTypes: [mediaType],
                                    systemImageName: systemImageName)

        return (action: item, url: url)
    }
}

struct CustomOpenAction: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var urlTemplate: String
    var mediaTypes: Set<OpenActionMediaType>
    var systemImageName: String

    init(id: UUID = UUID(),
         name: String,
         urlTemplate: String,
         mediaTypes: Set<OpenActionMediaType>,
         systemImageName: String = "arrow.up.forward") {
        self.id = id
        self.name = name
        self.urlTemplate = urlTemplate
        self.mediaTypes = mediaTypes
        self.systemImageName = systemImageName
    }
}

enum OpenActionMediaType: String, Codable, CaseIterable, Identifiable {
    case movie
    case show
    case season
    case episode

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .movie: return "Movies"
        case .show: return "TV Shows"
        case .season: return "Seasons"
        case .episode: return "Episodes"
        }
    }
}

enum OpenActionVariable: String, CaseIterable, Identifiable {
    case title
    case showTitle

    case slug
    case traktId

    case tmdbId
    case imdbId

    case showTmdbId
    case showTraktId
    case showImdbId

    case year
    case season
    case episode

    var id: String {
        rawValue
    }

    var placeholder: String {
        "{\(rawValue)}"
    }

    var displayName: String {
        switch self {
        case .title: return "Title"
        case .showTitle: return "Show title"
        case .slug: return "Slug"
        case .traktId: return "Trakt ID"
        case .tmdbId: return "TMDb ID"
        case .imdbId: return "IMDb ID"
        case .showTraktId: return "Show Trakt ID"
        case .showTmdbId: return "Show TMDb ID"
        case .showImdbId: return "Show IMDb ID"
        case .year: return "Year"
        case .season: return "Season number"
        case .episode: return "Episode number"
        }
    }
}

enum OpenActionURLResolver {
    static func resolve(template: String, for media: MediaModel) -> URL? {
        var result = template
        let replacements = variableReplacements(for: media)
        for (key, value) in replacements {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return URL(string: result)
    }

    private static func variableReplacements(for media: MediaModel) -> [String: String] {
        switch media {
        case .movie(let movie):
            return [
                "tmdbId": stringValue(movie.identifiers.tmdb),
                "showTmdbId": "",
                "showTraktId": "",
                "showImdbId": "",
                "imdbId": stringValue(movie.identifiers.imdb),
                "traktId": stringValue(movie.identifiers.trakt),
                "slug": stringValue(movie.identifiers.slug),
                "title": urlEscapedString(movie.officialTitle),
                "year": stringValue(movie.releaseYear)
            ]
        case .show(let show):
            return [
                "tmdbId": stringValue(show.identifiers.tmdb),
                "showTmdbId": stringValue(show.identifiers.tmdb),
                "showTraktId": stringValue(show.identifiers.trakt),
                "showImdbId": stringValue(show.identifiers.imdb),
                "imdbId": stringValue(show.identifiers.imdb),
                "traktId": stringValue(show.identifiers.trakt),
                "slug": stringValue(show.identifiers.slug),
                "title": urlEscapedString(show.officialTitle),
                "showTitle": urlEscapedString(show.officialTitle),
                "year": stringValue(show.releaseYear)
            ]
        case .season(let season, let show):
            return [
                "tmdbId": firstNonEmptyString(season.identifiers.tmdb, show.identifiers.tmdb),
                "showTmdbId": stringValue(show.identifiers.tmdb),
                "showTraktId": stringValue(show.identifiers.trakt),
                "showImdbId": stringValue(show.identifiers.imdb),
                "imdbId": firstNonEmptyString(season.identifiers.imdb, show.identifiers.imdb),
                "traktId": stringValue(season.identifiers.trakt),
                "slug": firstNonEmptyString(season.identifiers.slug, show.identifiers.slug),
                "title": urlEscapedString("\(show.officialTitle) \(season.localizedSeasonNumber)"),
                "season": String(season.number),
                "showTitle": urlEscapedString(show.officialTitle)
            ]
        case .episode(let episode, let show):
            return [
                "tmdbId": firstNonEmptyString(episode.identifiers.tmdb, show.identifiers.tmdb),
                "showTmdbId": stringValue(show.identifiers.tmdb),
                "showTraktId": stringValue(show.identifiers.trakt),
                "showImdbId": stringValue(show.identifiers.imdb),
                "imdbId": firstNonEmptyString(episode.identifiers.imdb, show.identifiers.imdb),
                "traktId": stringValue(episode.identifiers.trakt),
                "slug": firstNonEmptyString(episode.identifiers.slug, show.identifiers.slug),
                "title": urlEscapedString("\(show.officialTitle) \(episode.localizedEpisodeNumber)"),
                "year": stringValue(show.releaseYear),
                "season": String(episode.season),
                "episode": String(episode.number),
                "showTitle": urlEscapedString(show.officialTitle)
            ]
        case .list, .showProgress:
            return [:]
        }
    }

    private static func urlEscapedString(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
    }

    private static func stringValue<T: CustomStringConvertible>(_ value: T?) -> String {
        value?.description ?? ""
    }

    private static func firstNonEmptyString<T: CustomStringConvertible>(_ values: T?...) -> String {
        values.lazy.compactMap { $0?.description }.first ?? ""
    }
}

extension MediaModel {
    var openActionMediaType: OpenActionMediaType? {
        switch self {
        case .movie: return .movie
        case .show: return .show
        case .season: return .season
        case .episode: return .episode
        case .list, .showProgress: return nil
        }
    }
}
