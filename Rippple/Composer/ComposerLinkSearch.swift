//
//  ComposerLinkSearch.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

struct ComposerLink {
    let title: String
    let detail: String
    let url: URL
    let media: MediaModel?
    let person: Person?
    let searchId: Int64?

    var markdown: String {
        "[\(ComposerLink.escape(title))](\(url.absoluteString))"
    }

    init?(media: MediaModel, searchId: Int64? = nil) {
        let detail: String
        let identifiers: Identifiers
        switch media {
        case .movie(let movie):
            identifiers = movie.identifiers
            detail = (["Movie"] + [movie.releaseYear.map(String.init)].compactMap { $0 }).joined(separator: " · ")
        case .show(let show):
            identifiers = show.identifiers
            detail = (["TV Show"] + [show.releaseYear.map(String.init)].compactMap { $0 }).joined(separator: " · ")
        case .season(_, let show):
            identifiers = show.identifiers
            detail = "Season"
        case .episode(let episode, let show):
            identifiers = show.identifiers
            detail = episode.title ?? "Episode"
        case .list, .showProgress:
            return nil
        }
        guard ComposerLink.hasWebIdentifier(identifiers),
              let title = ComposerLink.title(of: media),
              let url = media.traktWebsiteMediaLink,
              ComposerLink.isSafe(url) else { return nil }
        self.title = title
        self.detail = detail
        self.url = url
        self.media = media
        person = nil
        self.searchId = searchId
    }

    init?(person: Person, characters: [String], searchId: Int64? = nil) {
        guard ComposerLink.hasWebIdentifier(person.ids),
              let url = URL(string: "https://app.trakt.tv/people/\(person.ids.slugOrTraktId)"),
              ComposerLink.isSafe(url) else { return nil }
        title = person.name
        let characters = characters.filter { $0.isEmpty == false }
        detail = characters.isEmpty ? (person.knownForDepartment?.capitalized ?? "Person") : "as \(characters.joined(separator: ", "))"
        self.url = url
        media = nil
        self.person = person
        self.searchId = searchId
    }

    init?(character: String, person: Person) {
        let name = ComposerLink.cleanCharacterName(character)
        guard name.isEmpty == false, let link = ComposerLink(person: person, characters: [character]) else { return nil }
        title = name
        detail = "Played by \(person.name)"
        url = link.url
        media = nil
        self.person = person
        searchId = nil
    }

    static func title(of media: MediaModel) -> String? {
        switch media {
        case .movie(let movie): return movie.title
        case .show(let show), .showProgress(let show, _): return show.title
        case .season(let season, let show): return "\(show.title) \(season.title ?? "Season \(season.number)")"
        case .episode(let episode, let show): return "\(show.title) \(episode.localizedEpisodeNumber)"
        case .list: return nil
        }
    }

    static func cleanCharacterName(_ character: String) -> String {
        character.replacingOccurrences(of: "\\s*\\([^)]*\\)\\s*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Haring's link pattern cannot contain brackets in the visible text, and newlines would break the line.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "[", with: "(")
            .replacingOccurrences(of: "]", with: ")")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private static func hasWebIdentifier(_ identifiers: Identifiers) -> Bool {
        identifiers.slug != nil || identifiers.trakt != nil
    }

    private static func isSafe(_ url: URL) -> Bool {
        let string = url.absoluteString
        return string.contains(")") == false && string.rangeOfCharacter(from: .whitespacesAndNewlines) == nil
    }
}

struct ComposerLinkSuggestions {
    var cast = [ComposerLink]()
    var results = [ComposerLink]()
    var isLoadingCast = false
    var isSearching = false
    var didFail = false
}

final class ComposerLinkSearch {
    enum Mode {
        case people
        case characters
        case media
    }

    private static let castLimit = 8
    private static let resultsLimit = 20

    var onUpdate: ((ComposerLinkSuggestions) -> Void)?

    var mode = Mode.people {
        didSet {
            guard mode != oldValue else { return }
            resetSearch()
            rebuildCastLinks()
            publish()
        }
    }

    var hasCast: Bool {
        castService != nil
    }

    private let subject: ComposerSubject?
    private var cast: [(person: Person, characters: [String])]?
    private var castRequest: Cancellable?
    private var related: [MediaModel]?
    private var castLinks = [ComposerLink]()
    private var relatedRequest: Cancellable?
    private var searchRequest: Cancellable?
    private var latestQuery = ""
    private var searchedQuery: String?
    /// Cancelling can't retract a response already queued on the main thread, so only the latest generation is applied.
    private var searchGeneration = 0
    private var suggestions = ComposerLinkSuggestions()

    init(subject: ComposerSubject?) {
        self.subject = subject
    }

    deinit {
        castRequest?.cancel()
        relatedRequest?.cancel()
        searchRequest?.cancel()
    }

    func activate() {
        activateRelated()
        guard cast == nil, castRequest == nil, let service = castService else { return }
        suggestions.isLoadingCast = true
        castRequest = TraktAPIProvider.provider.request(service,
                                                        callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let cast: [(person: Person, characters: [String])]? = {
                guard case .success(let response) = result,
                      let people = try? response.filterSuccessfulStatusCodes().map(People.self, using: TraktAPIProvider.decoder) else {
                    return nil
                }
                var seen = Set<Person>()
                return (people.cast + (people.guestStars ?? [])).compactMap { cast in
                    guard let person = cast.person, seen.insert(person).inserted else { return nil }
                    return (person, cast.characters)
                }
            }()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.castRequest = nil
                self.cast = cast
                self.suggestions.isLoadingCast = self.relatedRequest != nil
                self.rebuildCastLinks()
                self.publish()
            }
        }
        publish()
    }

    func update(query: String) {
        latestQuery = query
        filterCast()
        if query.count < 2 {
            resetSearch()
        } else if query != searchedQuery {
            invalidateSearch()
            // The debounced search is about to run: the header says so instead of "No match" in the meantime.
            suggestions.isSearching = mode != .characters
        }
        publish()
    }

    func search() {
        let query = latestQuery
        // Characters only exist in the subject's cast, so there is nothing to search on Trakt.
        guard mode != .characters, query.count >= 2, query != searchedQuery else { return }
        searchRequest?.cancel()
        searchGeneration += 1
        let generation = searchGeneration
        searchedQuery = query
        suggestions.isSearching = true
        suggestions.didFail = false
        publish()
        guard mode != .people else {
            searchPeople(query, generation: generation)
            return
        }
        searchRequest = TraktAPIProvider.search(query: query,
                                                type: .moviesAndShow,
                                                includeLocal: true,
                                                onUpdate: { [weak self] results in
                                                    guard let self = self, generation == self.searchGeneration else { return }
                                                    self.apply(results)
                                                },
                                                completion: { [weak self] result in
                                                    guard let self = self, generation == self.searchGeneration else { return }
                                                    self.finishSearch(result)
                                                })
    }

    /// The combined search also waits on movie and show endpoints, which kept the spinner up for people.
    private func searchPeople(_ query: String, generation: Int) {
        searchRequest = TraktAPIProvider.noRatingProvider.request(.search(type: .person, query: query),
                                                                  callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let decoded: Result<[TraktSearchResult], Error> = Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                return try response.map([PersonItem].self, using: TraktAPIProvider.decoder)
                    .map { TraktSearchResult(movie: nil, show: nil, person: $0.person, score: nil) }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, generation == self.searchGeneration else { return }
                self.finishSearch(decoded)
            }
        }
    }

    private func finishSearch(_ result: Result<[TraktSearchResult], Error>) {
        searchRequest = nil
        suggestions.isSearching = false
        switch result {
        case .success(let results):
            apply(results)
        case .failure:
            suggestions.didFail = true
            searchedQuery = nil
            publish()
        }
    }

    func retry() {
        searchedQuery = nil
        search()
    }

    // MARK: - Private

    /// Clearing `searchedQuery` makes a query that returns to the previous one search again.
    private func invalidateSearch() {
        searchRequest?.cancel()
        searchRequest = nil
        searchGeneration += 1
        searchedQuery = nil
    }

    private func resetSearch() {
        invalidateSearch()
        suggestions.results = []
        suggestions.isSearching = false
        suggestions.didFail = false
    }

    private func activateRelated() {
        guard related == nil, relatedRequest == nil, let target = relatedTarget else { return }
        suggestions.isLoadingCast = true
        relatedRequest = TraktAPIProvider.provider.request(target.service,
                                                           callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            let related: [MediaModel]? = {
                guard case .success(let response) = result,
                      let response = try? response.filterSuccessfulStatusCodes() else { return nil }
                guard response.statusCode != 204 else { return [] }
                if target.isMovie {
                    return (try? response.map([Movie].self, using: TraktAPIProvider.decoder))?.map(\.mediaModel)
                }
                return (try? response.map([Show].self, using: TraktAPIProvider.decoder))?.map(\.mediaModel)
            }()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.relatedRequest = nil
                self.related = related
                self.suggestions.isLoadingCast = self.castRequest != nil
                self.rebuildCastLinks()
                self.publish()
            }
        }
    }

    private var relatedTarget: (service: TraktAPIService, isMovie: Bool)? {
        guard case .media(let media) = subject else { return nil }
        switch media {
        case .movie(let movie):
            guard movie.identifiers.trakt != nil || movie.identifiers.slug != nil else { return nil }
            return (.movieRelatedSmart(id: movie.identifiers.traktIdOrSlug, pageInfo: PageInfo.firstPage(with: 20)), true)
        case .show(let show), .showProgress(let show, _), .season(_, let show), .episode(_, let show):
            guard show.identifiers.trakt != nil || show.identifiers.slug != nil else { return nil }
            return (.showRelatedSmart(id: show.identifiers.traktIdOrSlug, pageInfo: PageInfo.firstPage(with: 20)), false)
        case .list:
            return nil
        }
    }

    private var castService: TraktAPIService? {
        guard case .media(let media) = subject else { return nil }
        switch media {
        case .movie(let movie):
            guard let id = movie.identifiers.trakt else { return nil }
            return .peopleMovie(id: id)
        case .show(let show), .showProgress(let show, _):
            guard let id = show.identifiers.trakt else { return nil }
            return .peopleShow(id: id, extended: nil)
        case .season(let season, let show):
            guard let id = show.identifiers.trakt else { return nil }
            return .peopleSeason(id: id, season: season.number, extended: .guestStars)
        case .episode(let episode, let show):
            guard let id = show.identifiers.trakt else { return nil }
            return .peopleEpisode(id: id, season: episode.season, episode: episode.number, extended: .guestStars)
        case .list:
            return nil
        }
    }

    private func rebuildCastLinks() {
        let cast = cast ?? []
        switch mode {
        case .people:
            castLinks = cast.compactMap { ComposerLink(person: $0.person, characters: $0.characters) }
        case .characters:
            castLinks = cast.flatMap { entry in
                entry.characters.compactMap { ComposerLink(character: $0, person: entry.person) }
            }
        case .media:
            castLinks = (related ?? []).compactMap { ComposerLink(media: $0) }
        }
        filterCast()
    }

    private func filterCast() {
        let query = ComposerLinkSearch.fold(latestQuery)
        guard query.isEmpty == false else {
            suggestions.cast = Array(castLinks.prefix(ComposerLinkSearch.castLimit))
            return
        }
        let ranked = castLinks.enumerated().compactMap { index, link -> (Int, Int, ComposerLink)? in
            let names = [link.title, link.detail.hasPrefix("as ") ? String(link.detail.dropFirst(3)) : link.person?.name ?? ""].map(ComposerLinkSearch.fold)
            if names.contains(where: { ComposerLinkSearch.hasWordPrefix(query, in: $0) }) {
                return (0, index, link)
            }
            if names.contains(where: { $0.contains(query) }) {
                return (1, index, link)
            }
            return nil
        }
        suggestions.cast = ranked
            .sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 < $1.0 }
            .prefix(ComposerLinkSearch.castLimit)
            .map { $0.2 }
    }

    private func apply(_ results: [TraktSearchResult]) {
        let castPeople = Set(suggestions.cast.compactMap { $0.person })
        let suggestedMedia = Set(suggestions.cast.compactMap { $0.media })
        let subjectMedia: MediaModel? = {
            guard case .media(let media) = subject else { return nil }
            return media
        }()
        let subjectPerson: Person? = {
            guard case .person(let person) = subject else { return nil }
            return person
        }()
        suggestions.results = results.compactMap { result -> ComposerLink? in
            if let media = result.media {
                guard mode != .people, media != subjectMedia, suggestedMedia.contains(media) == false else { return nil }
                return ComposerLink(media: media, searchId: result.id)
            }
            if let person = result.person {
                guard mode != .media, castPeople.contains(person) == false, person != subjectPerson else { return nil }
                return ComposerLink(person: person, characters: [], searchId: result.id)
            }
            return nil
        }
        .prefix(ComposerLinkSearch.resultsLimit)
        .map { $0 }
        publish()
    }

    private func publish() {
        onUpdate?(suggestions)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
    }

    private static func hasWordPrefix(_ query: String, in text: String) -> Bool {
        if text.hasPrefix(query) { return true }
        return text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .contains { $0.isEmpty == false && $0.hasPrefix(query) }
            || text.range(of: " " + query) != nil
    }
}
