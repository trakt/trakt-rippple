//
//  SmartSearchBuilderViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 18/10/2021.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya
import Receiver
import UIKit

let (onMovieSmartSearchChangedTransmitter, onMovieSmartSearchChangedReceiver) = Receiver<Int>.make(with: .hot)
let (onShowSmartSearchChangedTransmitter, onShowSmartSearchChangedReceiver) = Receiver<Int>.make(with: .hot)

struct SmartSearch: Codable, Equatable, Hashable {
    enum ContentType: String, Codable {
        case movie
        case show
    }

    enum ContentKind: String, Codable {
        case trending
        case anticipated
        case popular
        case boxOffice
        case recommended
        case watched
        case played
        case collected
    }

    enum Period: String, Codable {
        case all
        case daily
        case weekly
        case monthly
        case yearly
    }

    enum Filter: String, Codable {
        case years
        case genres
        case languages
        case countries
        case runtimes
        case ratings
        case certifications
        case networks
        case status
        case ignoreWatched = "ignore_watched"
    }

    var contentType: ContentType {
        didSet {
            if contentType == .show && contentKind == .boxOffice {
                contentKind = .trending
                period = nil
                filters = [Filter: String]()
            }
            if contentType != oldValue {
                filters.removeValue(forKey: .genres)
                filters.removeValue(forKey: .status)
                filters.removeValue(forKey: .certifications)
                filters.removeValue(forKey: .networks)
                filters.removeValue(forKey: .countries)
                filters.removeValue(forKey: .languages)
            }
        }
    }

    var contentKind: ContentKind {
        didSet {
            if contentKind != oldValue {
                period = nil
            }
            if contentKind == .boxOffice {
                filters = [Filter: String]()
            }
        }
    }

    var count: Int
    var period: Period?

    var name: String?

    var filters = [Filter: String]() {
        didSet {
            // First check if years can be canonicalized (same start and end date
            if let yearsFilter = filters.first(where: { $0.key == .years }) {
                let split = yearsFilter.value.split(separator: "-")
                if split.count > 1 {
                    if split[0] == split[1] {
                        filters[.years] = String(split[0])
                    }
                }
            }
            // Then check to put older date first
            if let yearsFilter = filters.first(where: { $0.key == .years }) {
                let split = yearsFilter.value.split(separator: "-")
                if split.count > 1 {
                    if Int(split[0])! > Int(split[1])! {
                        filters[.years] = "\(split[1])-\(split[0])"
                    }
                }
            }
            // Check runtime order
            if let runtimesFilter = filters.first(where: { $0.key == .runtimes }) {
                let split = runtimesFilter.value.split(separator: "-")
                if Int(split[0])! > Int(split[1])! {
                    filters[.runtimes] = "\(split[1])-\(split[0])"
                }
            }
            // Check ratings order
            if let ratingsFilter = filters.first(where: { $0.key == .ratings }) {
                let split = ratingsFilter.value.split(separator: "-")
                if Int(split[0])! > Int(split[1])! {
                    filters[.ratings] = "\(split[1])-\(split[0])"
                }
            }
        }
    }

    var uuid = UUID().uuidString

    init(urlString: String, count: Int, name: String? = nil) {
        let URL = URL(string: urlString)!

        self.count = count
        self.name = name

        switch URL.path {
        case "/movies/boxoffice":
            contentType = .movie
            contentKind = .boxOffice
            period = nil
        case "/movies/trending":
            contentType = .movie
            contentKind = .trending
            period = nil
        case "/movies/anticipated":
            contentType = .movie
            contentKind = .anticipated
            period = nil
        case "/movies/popular":
            contentType = .movie
            contentKind = .popular
            period = nil
        case "/movies/recommended/daily":
            contentType = .movie
            contentKind = .recommended
            period = .daily
        case "/movies/recommended/weekly":
            contentType = .movie
            contentKind = .recommended
            period = .weekly
        case "/movies/recommended/monthly":
            contentType = .movie
            contentKind = .recommended
            period = .monthly
        case "/movies/recommended/yearly":
            contentType = .movie
            contentKind = .recommended
            period = .yearly
        case "/movies/recommended/all":
            contentType = .movie
            contentKind = .recommended
            period = .all
        case "/movies/favorited/daily":
            contentType = .movie
            contentKind = .recommended
            period = .daily
        case "/movies/favorited/weekly":
            contentType = .movie
            contentKind = .recommended
            period = .weekly
        case "/movies/favorited/monthly":
            contentType = .movie
            contentKind = .recommended
            period = .monthly
        case "/movies/favorited/yearly":
            contentType = .movie
            contentKind = .recommended
            period = .yearly
        case "/movies/favorited/all":
            contentType = .movie
            contentKind = .recommended
            period = .all
        case "/movies/played/daily":
            contentType = .movie
            contentKind = .played
            period = .daily
        case "/movies/played/weekly":
            contentType = .movie
            contentKind = .played
            period = .weekly
        case "/movies/played/monthly":
            contentType = .movie
            contentKind = .played
            period = .monthly
        case "/movies/played/yearly":
            contentType = .movie
            contentKind = .played
            period = .yearly
        case "/movies/played/all":
            contentType = .movie
            contentKind = .played
            period = .all
        case "/movies/watched/daily":
            contentType = .movie
            contentKind = .watched
            period = .daily
        case "/movies/watched/weekly":
            contentType = .movie
            contentKind = .watched
            period = .weekly
        case "/movies/watched/monthly":
            contentType = .movie
            contentKind = .watched
            period = .monthly
        case "/movies/watched/yearly":
            contentType = .movie
            contentKind = .watched
            period = .yearly
        case "/movies/watched/all":
            contentType = .movie
            contentKind = .watched
            period = .all
        case "/movies/collected/daily":
            contentType = .movie
            contentKind = .collected
            period = .daily
        case "/movies/collected/weekly":
            contentType = .movie
            contentKind = .collected
            period = .weekly
        case "/movies/collected/monthly":
            contentType = .movie
            contentKind = .collected
            period = .monthly
        case "/movies/collected/yearly":
            contentType = .movie
            contentKind = .collected
            period = .yearly
        case "/movies/collected/all":
            contentType = .movie
            contentKind = .collected
            period = .all
        // Shows
        case "/shows/trending":
            contentType = .show
            contentKind = .trending
            period = nil
        case "/shows/anticipated":
            contentType = .show
            contentKind = .anticipated
            period = nil
        case "/shows/popular":
            contentType = .show
            contentKind = .popular
            period = nil
        case "/shows/recommended/daily":
            contentType = .show
            contentKind = .recommended
            period = .daily
        case "/shows/recommended/weekly":
            contentType = .show
            contentKind = .recommended
            period = .weekly
        case "/shows/recommended/monthly":
            contentType = .show
            contentKind = .recommended
            period = .monthly
        case "/shows/recommended/yearly":
            contentType = .show
            contentKind = .recommended
            period = .yearly
        case "/shows/recommended/all":
            contentType = .show
            contentKind = .recommended
            period = .all
        case "/shows/favorited/daily":
            contentType = .show
            contentKind = .recommended
            period = .daily
        case "/shows/favorited/weekly":
            contentType = .show
            contentKind = .recommended
            period = .weekly
        case "/shows/favorited/monthly":
            contentType = .show
            contentKind = .recommended
            period = .monthly
        case "/shows/favorited/yearly":
            contentType = .show
            contentKind = .recommended
            period = .yearly
        case "/shows/favorited/all":
            contentType = .show
            contentKind = .recommended
            period = .all
        case "/shows/played/daily":
            contentType = .show
            contentKind = .played
            period = .daily
        case "/shows/played/weekly":
            contentType = .show
            contentKind = .played
            period = .weekly
        case "/shows/played/monthly":
            contentType = .show
            contentKind = .played
            period = .monthly
        case "/shows/played/yearly":
            contentType = .show
            contentKind = .played
            period = .yearly
        case "/shows/played/all":
            contentType = .show
            contentKind = .played
            period = .all
        case "/shows/watched/daily":
            contentType = .show
            contentKind = .watched
            period = .daily
        case "/shows/watched/weekly":
            contentType = .show
            contentKind = .watched
            period = .weekly
        case "/shows/watched/monthly":
            contentType = .show
            contentKind = .watched
            period = .monthly
        case "/shows/watched/yearly":
            contentType = .show
            contentKind = .watched
            period = .yearly
        case "/shows/watched/all":
            contentType = .show
            contentKind = .watched
            period = .all
        case "/shows/collected/daily":
            contentType = .show
            contentKind = .collected
            period = .daily
        case "/shows/collected/weekly":
            contentType = .show
            contentKind = .collected
            period = .weekly
        case "/shows/collected/monthly":
            contentType = .show
            contentKind = .collected
            period = .monthly
        case "/shows/collected/yearly":
            contentType = .show
            contentKind = .collected
            period = .yearly
        case "/shows/collected/all":
            contentType = .show
            contentKind = .collected
            period = .all
        default:
            fatalError()
        }

        if let URLComponents = URLComponents(url: URL, resolvingAgainstBaseURL: false),
           let queryItems = URLComponents.queryItems {
            for item in queryItems {
                if let filter = Filter(rawValue: item.name) {
                    filters[filter] = item.value
                }
            }
        }
    }

    var contentKindValue: String {
        switch contentType {
        case .movie:
            switch (contentKind, period) {
            case (.boxOffice, nil):
                return "Box office"
            case (.trending, nil):
                return "Trending"
            case (.anticipated, nil):
                return "Anticipated"
            case (.popular, nil):
                return "Popular"
            case (.recommended, .daily):
                return "Favorited Today"
            case (.recommended, .weekly):
                return "Favorited This Week"
            case (.recommended, .monthly):
                return "Favorited This Month"
            case (.recommended, .yearly):
                return "Favorited This Year"
            case (.recommended, .all):
                return "Favorited"
            case (.played, .daily):
                return "Played Today"
            case (.played, .weekly):
                return "Played This Week"
            case (.played, .monthly):
                return "Played This Month"
            case (.played, .yearly):
                return "Played This Year"
            case (.played, .all):
                return "Played"
            case (.watched, .daily):
                return "Watched Today"
            case (.watched, .weekly):
                return "Watched This Week"
            case (.watched, .monthly):
                return "Watched This Month"
            case (.watched, .yearly):
                return "Watched This Year"
            case (.watched, .all):
                return "Watched"
            case (.collected, .daily):
                return "Collected Today"
            case (.collected, .weekly):
                return "Collected This Week"
            case (.collected, .monthly):
                return "Collected This Month"
            case (.collected, .yearly):
                return "Collected This Year"
            case (.collected, .all):
                return "Collected"
            default:
                fatalError()
            }
        case .show:
            switch (contentKind, period) {
            case (.trending, nil):
                return "Trending"
            case (.anticipated, nil):
                return "Anticipated"
            case (.popular, nil):
                return "Popular"
            case (.recommended, .daily):
                return "Favorited Today"
            case (.recommended, .weekly):
                return "Favorited This Week"
            case (.recommended, .monthly):
                return "Favorited This Month"
            case (.recommended, .yearly):
                return "Favorited This Year"
            case (.recommended, .all):
                return "Favorited"
            case (.played, .daily):
                return "Played Today"
            case (.played, .weekly):
                return "Played This Week"
            case (.played, .monthly):
                return "Played This Month"
            case (.played, .yearly):
                return "Played This Year"
            case (.played, .all):
                return "Played"
            case (.watched, .daily):
                return "Watched Today"
            case (.watched, .weekly):
                return "Watched This Week"
            case (.watched, .monthly):
                return "Watched This Month"
            case (.watched, .yearly):
                return "Watched This Year"
            case (.watched, .all):
                return "Watched"
            case (.collected, .daily):
                return "Collected Today"
            case (.collected, .weekly):
                return "Collected This Week"
            case (.collected, .monthly):
                return "Collected This Month"
            case (.collected, .yearly):
                return "Collected This Year"
            case (.collected, .all):
                return "Collected"
            default:
                fatalError()
            }
        }
    }

    var isValid: Bool {
        switch contentType {
        case .movie:
            switch (contentKind, period) {
            case (.recommended, .none): return false
            case (.watched, .none): return false
            case (.played, .none): return false
            case (.collected, .none): return false
            default: return true
            }
        case .show:
            switch (contentKind, period) {
            case (.boxOffice, _): return false
            case (.recommended, .none): return false
            case (.watched, .none): return false
            case (.played, .none): return false
            case (.collected, .none): return false
            default: return true
            }
        }
    }

    fileprivate mutating func add(slug: String, for filter: Filter) {
        let current = filters[filter] ?? ""
        var split = current.split(separator: ",").map { String($0) }
        split.append(slug)
        split.sort()
        filters[filter] = split.joined(separator: ",")
    }

    fileprivate mutating func remove(slug: String, for filter: Filter) {
        let current = filters[filter]
        if let current = current {
            var split = current.split(separator: ",").map { String($0) }
            if let indexToDelete = split.firstIndex(of: slug) {
                split.remove(at: indexToDelete)
                filters[filter] = split.joined(separator: ",")
            }
            if let newFilters = filters[filter], newFilters.isEmpty {
                filters.removeValue(forKey: filter)
            }
        }
    }

    static func save(smartSearches: [SmartSearch], contentType: ContentType, transmit: Bool? = true) {
        switch contentType {
        case .movie:
            NSUbiquitousKeyValueStore.default.set(try? PropertyListEncoder().encode(smartSearches), forKey: "SmartSearch.movies")
            if transmit! { onMovieSmartSearchChangedTransmitter.broadcast(1) }
        case .show:
            NSUbiquitousKeyValueStore.default.set(try? PropertyListEncoder().encode(smartSearches), forKey: "SmartSearch.shows")
            if transmit! { onShowSmartSearchChangedTransmitter.broadcast(1) }
        }
    }

    static func smartSearches(for contentType: ContentType) -> [SmartSearch] {
        switch contentType {
        case .movie:
            if let data = NSUbiquitousKeyValueStore.default.data(forKey: "SmartSearch.movies"), let smartSearches = try? PropertyListDecoder().decode([SmartSearch].self, from: data), smartSearches.isEmpty == false {
                return smartSearches
            } else {
                return createDefaultSmartSearchesForMovies()
            }
        case .show:
            if let data = NSUbiquitousKeyValueStore.default.data(forKey: "SmartSearch.shows"), let smartSearches = try? PropertyListDecoder().decode([SmartSearch].self, from: data), smartSearches.isEmpty == false {
                return smartSearches
            } else {
                return createDefaultSmartSearchesForShows()
            }
        }
    }

    private static func createDefaultSmartSearchesForShows() -> [SmartSearch] {
        let defaultShows = [SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/trending", count: 50, name: "Trending"),
                            SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/popular", count: 50, name: "Popular"),
                            SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/anticipated", count: 50, name: "Anticipated"),
                            SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/favorited/weekly", count: 50, name: "Favorited")]

        save(smartSearches: defaultShows, contentType: .show, transmit: false)

        return defaultShows
    }

    private static func createDefaultSmartSearchesForMovies() -> [SmartSearch] {
        let defaultMovies = [SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/trending", count: 50, name: "Trending"),
                             SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/popular", count: 50, name: "Popular"),
                             SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/anticipated", count: 50, name: "Anticipated"),
                             SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/favorited/weekly", count: 50, name: "Favorited"),
                             SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/boxoffice", count: 50, name: "Box Office")]

        save(smartSearches: defaultMovies, contentType: .movie, transmit: false)

        return defaultMovies
    }

    func getLatest() -> SmartSearch? {
        return SmartSearch.smartSearches(for: contentType).first { $0.uuid == self.uuid }
    }

    func save() {
        var smartSearches = SmartSearch.smartSearches(for: contentType)
        smartSearches.append(self)
        SmartSearch.save(smartSearches: smartSearches, contentType: contentType)
        SwiftMessages.show(message: "🤓 Smart Search Saved")
    }

    func update() {
        var smartSearches = SmartSearch.smartSearches(for: contentType)
        if let index = smartSearches.firstIndex(where: { $0.uuid == self.uuid }) {
            smartSearches.remove(at: index)
            smartSearches.insert(self, at: index)
        }
        SmartSearch.save(smartSearches: smartSearches, contentType: contentType)
        SwiftMessages.show(message: "🤓 Smart Search Updated")
    }

    func delete() {
        var smartSearches = SmartSearch.smartSearches(for: contentType)
        if let index = smartSearches.firstIndex(where: { $0.uuid == self.uuid }) {
            smartSearches.remove(at: index)
        }
        SmartSearch.save(smartSearches: smartSearches, contentType: contentType)
        SwiftMessages.show(message: "🤓 Smart Search Deleted")
    }

    func move(at index: Int) {
        var smartSearches = SmartSearch.smartSearches(for: contentType)
        if let i = smartSearches.firstIndex(where: { $0.uuid == self.uuid }) {
            smartSearches.remove(at: i)
        }
        smartSearches.insert(self, at: index)
        SmartSearch.save(smartSearches: smartSearches, contentType: contentType, transmit: true)
    }
}

extension UILabel {
    func boundingRect(forCharacterRange range: NSRange) -> CGRect? {
        guard let attributedText = attributedText else { return nil }

        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: bounds.size)
        let textStorage = NSTextStorage(attributedString: attributedText)

        layoutManager.addTextContainer(textContainer)

        textStorage.addLayoutManager(layoutManager)
        let length = attributedText.length
        if let style = attributedText.attribute(.paragraphStyle,
                                                at: 0,
                                                longestEffectiveRange: nil,
                                                in: range) {
            textStorage.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: length))
        }

        textContainer.lineFragmentPadding = 0.0
        textContainer.lineBreakMode = lineBreakMode
        textContainer.maximumNumberOfLines = numberOfLines
        textContainer.size = bounds.size

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range,
                                                  actualCharacterRange: nil)
        let frame = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        return CGRect(x: frame.origin.x,
                      y: frame.origin.y,
                      width: frame.size.width,
                      height: font.lineHeight)
    }
}

final class SmartSearchBuilderViewController: SearchResultsViewController {
    @IBOutlet var addConditionButton: UIButton!

    var smartSearch: SmartSearch! {
        didSet {
            if smartSearch.isValid {
                buildSearchText()
                DispatchQueue.main.async {
                    self.buildButtons()
                }
                service = smartSearch.service
                refresh(self)
                addConditionButton.menu = buildMenu()
                addConditionButton.isHidden = smartSearch.contentKind == .boxOffice
            }
        }
    }

    private func buildSearchText() {
        let attributedString = buildAttributedString()
        smartSearchLabel.attributedText = attributedString

        if let headerView = smartSearchLabel.superview {
            tableView.tableHeaderView = headerView
            let sizeWithBigLabel = smartSearchLabel.bounds.size.height + 200
            headerView.frame = CGRect(origin: headerView.frame.origin,
                                      size: CGSize(width: 0.0,
                                                   height: max(view.bounds.size.height - 200, sizeWithBigLabel)))
        }
    }

    private func buildAttributedString() -> NSAttributedString {
        let highAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label,
                                                             .font: UIFont.systemFont(ofSize: 22, weight: .medium),
                                                             .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
                                                             .underlineColor: UIColor.secondaryLabel]
        let lowAttributes = [NSAttributedString.Key.foregroundColor: UIColor.secondaryLabel,
                             NSAttributedString.Key.font: UIFont.systemFont(ofSize: 22, weight: .regular)]

        let attributedString = NSMutableAttributedString(string: "I’m looking for ", attributes: lowAttributes)

        if smartSearch.contentKind != .boxOffice {
            attributedString.append(NSAttributedString(string: "\(smartSearch.count)", attributes: highAttributes))
            attributedString.append(NSAttributedString(string: " ", attributes: lowAttributes))
        }

        switch smartSearch.contentType {
        case .movie:
            attributedString.append(NSAttributedString(string: smartSearch.count == 1 ? "Movie" : "Movies", attributes: highAttributes))
            switch (smartSearch.contentKind, smartSearch.period) {
            case (.boxOffice, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") in the US ", attributes: lowAttributes))
            case (.trending, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") currently ", attributes: lowAttributes))
            case (.anticipated, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") currently ", attributes: lowAttributes))
            case (.popular, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") ", attributes: lowAttributes))
            case (.recommended, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.played, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.watched, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.collected, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            default:
                fatalError()
            }
        case .show:
            attributedString.append(NSAttributedString(string: smartSearch.count == 1 ? "TV Show" : "TV Shows", attributes: highAttributes))
            switch (smartSearch.contentKind, smartSearch.period) {
            case (.trending, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") currently ", attributes: lowAttributes))
            case (.anticipated, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") currently ", attributes: lowAttributes))
            case (.popular, nil):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") ", attributes: lowAttributes))
            case (.recommended, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.recommended, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.played, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.played, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.watched, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.watched, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            case (.collected, .daily):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .weekly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .monthly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .yearly):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "was" : "were") most ", attributes: lowAttributes))
            case (.collected, .all):
                attributedString.append(NSAttributedString(string: " that \(smartSearch.count == 1 ? "is" : "are") the most ", attributes: lowAttributes))
            default:
                fatalError()
            }
        }

        attributedString.append(NSAttributedString(string: "\(smartSearch.contentKindValue)", attributes: highAttributes))

        var i = 0
        for filter in smartSearch.filters.sorted(by: {
            if $0.key == .ignoreWatched {
                return false
            } else if $1.key == .ignoreWatched {
                return true
            } else {
                return $0.key.rawValue < $1.key.rawValue
            }
        }) {
            if i == smartSearch.filters.count - 1 {
                attributedString.append(NSAttributedString(string: " and", attributes: lowAttributes))
            } else {
                attributedString.append(NSAttributedString(string: ",", attributes: lowAttributes))
            }
            i += 1
            switch filter.key {
            case .years:
                let yearsSplit = filter.value.split(separator: "-")

                if yearsSplit.count == 1 {
                    attributedString.append(NSAttributedString(string: " released in ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(yearsSplit[0])", attributes: highAttributes))
                } else {
                    attributedString.append(NSAttributedString(string: " released between ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(yearsSplit[0])", attributes: highAttributes))
                    attributedString.append(NSAttributedString(string: " and ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(yearsSplit[1])", attributes: highAttributes))
                }
            case .genres:
                attributedString.append(NSAttributedString(string: " in the ", attributes: lowAttributes))
                var i = 0
                for genre in filter.value.split(separator: ",") {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    attributedString.append(NSAttributedString(string: "\(genre.replacingOccurrences(of: "-", with: " ").capitalized)", attributes: highAttributes))
                    i += 1
                }
                attributedString.append(NSAttributedString(string: " genre", attributes: lowAttributes))
            case .languages:
                attributedString.append(NSAttributedString(string: " where the original language is ", attributes: lowAttributes))
                var i = 0
                let locale = Locale(identifier: "en_US")
                for language in filter.value.split(separator: ",") {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    attributedString.append(NSAttributedString(string: "\(locale.localizedString(forLanguageCode: String(language)) ?? "??")", attributes: highAttributes))
                    i += 1
                }
            case .countries:
                attributedString.append(NSAttributedString(string: " released in ", attributes: lowAttributes))
                var i = 0
                let locale = Locale(identifier: "en_US")
                for country in filter.value.split(separator: ",").sorted(by: { $0 < $1 }) {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    attributedString.append(NSAttributedString(string: "\(locale.localizedString(forRegionCode: String(country)) ?? "??")", attributes: highAttributes))
                    i += 1
                }
            case .runtimes:
                let runtimesSplit = filter.value.split(separator: "-")

                if runtimesSplit[0] == runtimesSplit[1] {
                    attributedString.append(NSAttributedString(string: " with a runtime of ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(runtimesSplit[0])‘", attributes: highAttributes))
                } else {
                    attributedString.append(NSAttributedString(string: " with a runtime between ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(runtimesSplit[0])‘", attributes: highAttributes))
                    attributedString.append(NSAttributedString(string: " and ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(runtimesSplit[1])‘", attributes: highAttributes))
                }
            case .ratings:
                let ratingsSplit = filter.value.split(separator: "-")

                if ratingsSplit[0] == ratingsSplit[1] {
                    attributedString.append(NSAttributedString(string: " with a trakt rating of ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(ratingsSplit[0])%", attributes: highAttributes))
                } else {
                    attributedString.append(NSAttributedString(string: " with a trakt rating between ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(ratingsSplit[0])%", attributes: highAttributes))
                    attributedString.append(NSAttributedString(string: " and ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "\(ratingsSplit[1])%", attributes: highAttributes))
                }
            case .certifications:
                attributedString.append(NSAttributedString(string: " with a ", attributes: lowAttributes))
                var i = 0
                for certification in filter.value.split(separator: ",") {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    if certification == "nr" {
                        attributedString.append(NSAttributedString(string: "No Certification", attributes: highAttributes))
                    } else {
                        attributedString.append(NSAttributedString(string: "\(certification.uppercased())", attributes: highAttributes))
                    }
                    i += 1
                }
                attributedString.append(NSAttributedString(string: " certification", attributes: lowAttributes))
            case .networks:
                attributedString.append(NSAttributedString(string: " released on ", attributes: lowAttributes))
                var i = 0
                for network in filter.value.split(separator: ",").sorted(by: { $0 < $1 }) {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    attributedString.append(NSAttributedString(string: "\(network)", attributes: highAttributes))
                    i += 1
                }
            case .status:
                attributedString.append(NSAttributedString(string: " with a ", attributes: lowAttributes))
                var i = 0
                for certification in filter.value.split(separator: ",") {
                    if i > 0 {
                        attributedString.append(NSAttributedString(string: " or ", attributes: lowAttributes))
                    }
                    attributedString.append(NSAttributedString(string: "\(certification.capitalized)", attributes: highAttributes))
                    i += 1
                }
                attributedString.append(NSAttributedString(string: " status", attributes: lowAttributes))
            case .ignoreWatched:
                let ignored = filter.value == "true" ? true : false
                if ignored {
                    attributedString.append(NSAttributedString(string: " that I haven't ", attributes: lowAttributes))
                    attributedString.append(NSAttributedString(string: "already watched", attributes: highAttributes))
                }
            }
        }

        attributedString.append(NSAttributedString(string: ".", attributes: lowAttributes))

        let length = attributedString.length
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 18
        attributedString.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: length))

        return attributedString
    }

    private func buildButtons() {
        for button in smartSearchLabel.subviews where button is UIButton {
            button.removeFromSuperview()
        }

        placeContentTypeButton()
        placeContentKindButton()
        placeCountButton()

        placeFiltersButtons()

        /*
         for button in smartSearchLabel.subviews where button is UIButton {
             button.layer.borderWidth = 1
             button.layer.borderColor = UIColor.red.cgColor
         }
          */
    }

    private func placeFiltersButtons() {
        placeYearsButtons()
        placeRuntimesButtons()
        placeRatingsButtons()

        placeGenresButtons()

        placeStatusButtons()

        placeCertificationsButtons()

        placeNetworksButtons()

        placeCountriesButtons()

        placeLanguageButtons()

        placeWatchedButtons()
    }

    private func placeWatchedButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        let keyword = "already watched"
        let delete = UIAction(title: "Remove \(keyword)", attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.remove(slug: "true", for: .ignoreWatched)
        }

        var subRange: Range<String.Index>?
        for n in keyword.split(separator: " ") {
            guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
            subRange = range
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [delete])
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeLanguageButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let filter = smartSearch.filters.first(where: { $0.key == .languages }) else { return }

        let split = filter.value.split(separator: ",")

        var previousRange: Range<String.Index>?
        for language in split.sorted(by: { $0 < $1 }) {
            let locale = Locale(identifier: "en_US")
            let languageName = locale.localizedString(forLanguageCode: String(language)) ?? "??"
            let delete = UIAction(title: "Remove \(languageName)", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(language), for: .languages)
            }

            var subRange = previousRange
            for n in languageName.split(separator: " ") {
                guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
                subRange = range
                if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                    let button = UIButton(frame: frame)
                    button.showsMenuAsPrimaryAction = true
                    button.menu = UIMenu(children: [delete])
                    smartSearchLabel.addSubview(button)
                }
            }
            previousRange = subRange
        }
    }

    private func placeCountriesButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let filter = smartSearch.filters.first(where: { $0.key == .countries }) else { return }

        let split = filter.value.split(separator: ",")

        var previousRange: Range<String.Index>?
        for country in split.sorted(by: { $0 < $1 }) {
            let locale = Locale(identifier: "en_US")
            let countryName = locale.localizedString(forRegionCode: String(country)) ?? "??"
            let delete = UIAction(title: "Remove \(countryName)", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(country), for: .countries)
            }

            var subRange = previousRange
            for n in countryName.split(separator: " ") {
                guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
                subRange = range
                if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                    let button = UIButton(frame: frame)
                    button.showsMenuAsPrimaryAction = true
                    button.menu = UIMenu(children: [delete])
                    smartSearchLabel.addSubview(button)
                }
            }
            previousRange = subRange
        }
    }

    private func placeNetworksButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let filter = smartSearch.filters.first(where: { $0.key == .networks }) else { return }

        let split = filter.value.split(separator: ",")

        var previousRange: Range<String.Index>?
        for network in split.sorted(by: { $0 < $1 }) {
            let delete = UIAction(title: "Remove \(network)", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(network), for: .networks)
            }

            var subRange = previousRange
            for n in network.split(separator: " ") {
                guard let range = attributedText.string.range(of: n, range: (subRange?.upperBound ?? attributedText.string.startIndex)..<attributedText.string.endIndex) else { return }
                subRange = range
                if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                    let button = UIButton(frame: frame)
                    button.showsMenuAsPrimaryAction = true
                    button.menu = UIMenu(children: [delete])
                    smartSearchLabel.addSubview(button)
                }
            }
            previousRange = subRange
        }
    }

    private func placeCertificationsButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let certificationsFilter = smartSearch.filters.first(where: { $0.key == .certifications }) else { return }

        let certificationsSplit = certificationsFilter.value.split(separator: ",")

        for certification in certificationsSplit {
            let delete = UIAction(title: "Remove \(certification == "nr" ? "No Certification" : certification.uppercased())", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(certification), for: .certifications)
            }

            guard let range = attributedText.string.range(of: "\(certification == "nr" ? "No Certification" : certification.uppercased())") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [delete])
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeStatusButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let filter = smartSearch.filters.first(where: { $0.key == .status }) else { return }

        let split = filter.value.split(separator: ",")

        for status in split {
            let delete = UIAction(title: "Remove \(status.capitalized)", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(status), for: .status)
            }

            guard let range = attributedText.string.range(of: status.capitalized) else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [delete])
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeGenresButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let genresFilter = smartSearch.filters.first(where: { $0.key == .genres }) else { return }

        let genresSplit = genresFilter.value.split(separator: ",")

        for genre in genresSplit {
            let textGenre = "\(genre.replacingOccurrences(of: "-", with: " ").capitalized)"
            let delete = UIAction(title: "Remove \(textGenre)", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.remove(slug: String(genre), for: .genres)
            }

            guard let range = attributedText.string.range(of: textGenre) else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [delete])
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeRatingsButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let ratingsFilter = smartSearch.filters.first(where: { $0.key == .ratings }) else { return }

        let ratingsSplit = ratingsFilter.value.split(separator: "-")

        if ratingsSplit[0] == ratingsSplit[1] {
            var children = [UIAction]()
            for i in stride(from: 0, through: 100, by: 5) {
                let action = UIAction(title: "\(i)%") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.ratings] = "\(i)-\(i)"
                }
                children.append(action)
            }
            let menu = UIMenu(title: "Ratings", children: children)

            let resetDefault = UIAction(title: "Reset Default Values") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.ratings] = "75-100"
            }

            let delete = UIAction(title: "Remove Condition", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters.removeValue(forKey: .ratings)
            }

            guard let range = attributedText.string.range(of: "\(ratingsSplit[0])%") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [menu, resetDefault, delete])
                smartSearchLabel.addSubview(button)
            }
        } else {
            var children = [UIAction]()
            for i in stride(from: 0, through: 100, by: 5) {
                let action = UIAction(title: "\(i)%") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.ratings] = "\(i)-\(ratingsSplit[1])"
                }
                children.append(action)
            }

            let deleteFirst = UIAction(title: "Remove Start of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.ratings] = "\(ratingsSplit[1])-\(ratingsSplit[1])"
            }
            children.append(deleteFirst)

            guard let range = attributedText.string.range(of: "\(ratingsSplit[0])%") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: children)
                smartSearchLabel.addSubview(button)
            }

            children = [UIAction]()
            for i in stride(from: 0, through: 100, by: 5) {
                let action = UIAction(title: "\(i)%") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.ratings] = "\(ratingsSplit[0])-\(i)"
                }
                children.append(action)
            }

            let deleteSecond = UIAction(title: "Remove End of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.ratings] = "\(ratingsSplit[0])-\(ratingsSplit[0])"
            }
            children.append(deleteSecond)

            guard let range = attributedText.string.range(of: "\(ratingsSplit[1])%") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: children)
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeRuntimesButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let runtimesFilter = smartSearch.filters.first(where: { $0.key == .runtimes }) else { return }

        let runtimesSplit = runtimesFilter.value.split(separator: "-")

        if runtimesSplit[0] == runtimesSplit[1] {
            var children = [UIAction]()
            for i in stride(from: 0, through: 500, by: 10) {
                let action = UIAction(title: i > 1 ? "\(i) minutes" : "\(i) minute") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.runtimes] = "\(i)-\(i)"
                }
                children.append(action)
            }
            let menu = UIMenu(title: "Runtimes", children: children)

            let resetDefault = UIAction(title: "Reset Default Values") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.runtimes] = "20-180"
            }

            let delete = UIAction(title: "Remove Condition", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters.removeValue(forKey: .runtimes)
            }

            guard let range = attributedText.string.range(of: "\(runtimesSplit[0])‘") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [menu, resetDefault, delete])
                smartSearchLabel.addSubview(button)
            }
        } else {
            var children = [UIAction]()
            for i in stride(from: 0, through: 500, by: 10) {
                let action = UIAction(title: i > 1 ? "\(i) minutes" : "\(i) minute") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.runtimes] = "\(i)-\(runtimesSplit[1])"
                }
                children.append(action)
            }

            let deleteFirst = UIAction(title: "Remove Start of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.runtimes] = "\(runtimesSplit[1])-\(runtimesSplit[1])"
            }
            children.append(deleteFirst)

            guard let range = attributedText.string.range(of: "\(runtimesSplit[0])‘") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: children)
                smartSearchLabel.addSubview(button)
            }

            children = [UIAction]()
            for i in stride(from: 0, through: 500, by: 10) {
                let action = UIAction(title: i > 1 ? "\(i) minutes" : "\(i) minute") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.runtimes] = "\(runtimesSplit[0])-\(i)"
                }
                children.append(action)
            }

            let deleteSecond = UIAction(title: "Remove End of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.runtimes] = "\(runtimesSplit[0])-\(runtimesSplit[0])"
            }
            children.append(deleteSecond)

            guard let range = attributedText.string.range(of: "\(runtimesSplit[1])‘") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: children)
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeYearsButtons() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let yearsFilter = smartSearch.filters.first(where: { $0.key == .years }) else { return }

        let yearsSplit = yearsFilter.value.split(separator: "-")

        if yearsSplit.count == 1 {
            var children = [UIAction]()
            for i in stride(from: 1880, through: 2028, by: 1) {
                let action = UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.years] = "\(i)"
                }
                children.append(action)
            }
            let yearsMenu = UIMenu(title: "Years", children: children)

            let seventies = UIAction(title: "1970s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "1970-1979"
            }
            let eighties = UIAction(title: "1980s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "1980-1989"
            }
            let nineties = UIAction(title: "1990s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "1990-1999"
            }
            let twenties = UIAction(title: "2000s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "2000-2009"
            }
            let tenies = UIAction(title: "2010s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "2010-2019"
            }
            let twentytwenties = UIAction(title: "2020s") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "2020-2028"
            }

            let decades = UIMenu(title: "Decades", children: [seventies, eighties, nineties, twenties, tenies, twentytwenties])

            let resetDefault = UIAction(title: "Reset Default Values") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "1880-2028"
            }

            let delete = UIAction(title: "Remove Condition", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters.removeValue(forKey: .years)
            }

            let year = Calendar.current.component(.year, from: Date())
            let thisYear = UIAction(title: "This Year (\(year))") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "\(year)"
            }

            guard let range = attributedText.string.range(of: "\(yearsSplit[0])") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [thisYear, yearsMenu, decades, resetDefault, delete])
                smartSearchLabel.addSubview(button)
            }
        } else {
            var children = [UIAction]()
            for i in stride(from: 1880, through: 2028, by: 1) {
                let action = UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.years] = "\(i)-\(yearsSplit[1])"
                }
                children.append(action)
            }

            let deleteFirst = UIAction(title: "Remove Start of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "\(yearsSplit[1])"
            }

            let firstMenu = UIMenu(title: "Years", children: children)

            guard let range = attributedText.string.range(of: "\(yearsSplit[0])") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [firstMenu, deleteFirst])
                smartSearchLabel.addSubview(button)
            }

            children = [UIAction]()
            for i in stride(from: 1880, through: 2028, by: 1) {
                let action = UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.smartSearch.filters[.years] = "\(yearsSplit[0])-\(i)"
                }
                children.append(action)
            }

            let deleteSecond = UIAction(title: "Remove End of Range", attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.filters[.years] = "\(yearsSplit[0])"
            }

            let secondMenu = UIMenu(title: "Years", children: children)

            guard let range = attributedText.string.range(of: "\(yearsSplit[1])") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = UIMenu(children: [secondMenu, deleteSecond])
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeContentTypeButton() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        let movies = UIAction(title: smartSearch.count == 1 ? "Movie" : "Movies") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.contentType = .movie
        }
        let shows = UIAction(title: smartSearch.count == 1 ? "TV Show" : "TV Shows") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.contentType = .show
        }
        let menu = UIMenu(children: [movies, shows])

        switch smartSearch.contentType {
        case .movie:
            guard let range = attributedText.string.range(of: smartSearch.count == 1 ? "Movie" : "Movies") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = menu
                smartSearchLabel.addSubview(button)
            }
        case .show:
            guard let range = attributedText.string.range(of: smartSearch.count == 1 ? "TV Show" : "TV Shows") else { return }
            if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                let button = UIButton(frame: frame)
                button.showsMenuAsPrimaryAction = true
                button.menu = menu
                smartSearchLabel.addSubview(button)
            }
        }
    }

    private func placeContentKindButton() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        switch smartSearch.contentType {
        case .movie:
            let boxOffice = UIAction(title: "Box Office") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .boxOffice
            }
            let trending = UIAction(title: "Trending") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .trending
            }
            let popular = UIAction(title: "Popular") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .popular
            }
            let anticipated = UIAction(title: "Anticipated") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .anticipated
            }

            let collectedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .daily
            }
            let collectedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .weekly
            }
            let collectedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .monthly
            }
            let collectedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .yearly
            }
            let collectedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .all
            }

            let watchedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .daily
            }
            let watchedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .weekly
            }
            let watchedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .monthly
            }
            let watchedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .yearly
            }
            let watchedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .all
            }

            let playedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .daily
            }
            let playedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .weekly
            }
            let playedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .monthly
            }
            let playedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .yearly
            }
            let playedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .all
            }

            let recommendedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .daily
            }
            let recommendedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .weekly
            }
            let recommendedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .monthly
            }
            let recommendedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .yearly
            }
            let recommendedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .all
            }

            let collected = UIMenu(title: "Collected", children: [collectedDaily, collectedWeekly, collectedMonthly, collectedYearly, collectedAll])
            let watched = UIMenu(title: "Watched", children: [watchedDaily, watchedWeekly, watchedMonthly, watchedYearly, watchedAll])
            let played = UIMenu(title: "Played", children: [playedDaily, playedWeekly, playedMonthly, playedYearly, playedAll])
            let recommended = UIMenu(title: "Favorited", children: [recommendedDaily, recommendedWeekly, recommendedMonthly, recommendedYearly, recommendedAll])

            let menu = UIMenu(children: [trending, popular, anticipated, recommended, played, watched, collected, boxOffice])

            for kind in smartSearch.contentKindValue.split(separator: " ") {
                guard let range = attributedText.string.range(of: kind) else { return }
                if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                    let button = UIButton(frame: frame)
                    button.showsMenuAsPrimaryAction = true
                    button.menu = menu
                    smartSearchLabel.addSubview(button)
                }
            }
        case .show:
            let trending = UIAction(title: "Trending") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .trending
            }
            let popular = UIAction(title: "Popular") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .popular
            }
            let anticipated = UIAction(title: "Anticipated") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .anticipated
            }

            let collectedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .daily
            }
            let collectedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .weekly
            }
            let collectedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .monthly
            }
            let collectedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .yearly
            }
            let collectedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .collected
                self.smartSearch.period = .all
            }

            let watchedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .daily
            }
            let watchedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .weekly
            }
            let watchedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .monthly
            }
            let watchedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .yearly
            }
            let watchedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .watched
                self.smartSearch.period = .all
            }

            let playedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .daily
            }
            let playedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .weekly
            }
            let playedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .monthly
            }
            let playedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .yearly
            }
            let playedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .played
                self.smartSearch.period = .all
            }

            let recommendedDaily = UIAction(title: "Today") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .daily
            }
            let recommendedWeekly = UIAction(title: "This Week") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .weekly
            }
            let recommendedMonthly = UIAction(title: "This Month") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .monthly
            }
            let recommendedYearly = UIAction(title: "This Year") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .yearly
            }
            let recommendedAll = UIAction(title: "All Time") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.contentKind = .recommended
                self.smartSearch.period = .all
            }

            let collected = UIMenu(title: "Collected", children: [collectedDaily, collectedWeekly, collectedMonthly, collectedYearly, collectedAll])
            let watched = UIMenu(title: "Watched", children: [watchedDaily, watchedWeekly, watchedMonthly, watchedYearly, watchedAll])
            let played = UIMenu(title: "Played", children: [playedDaily, playedWeekly, playedMonthly, playedYearly, playedAll])
            let recommended = UIMenu(title: "Favorited", children: [recommendedDaily, recommendedWeekly, recommendedMonthly, recommendedYearly, recommendedAll])
            let menu = UIMenu(children: [trending, popular, anticipated, recommended, played, watched, collected])

            for kind in smartSearch.contentKindValue.split(separator: " ") {
                guard let range = attributedText.string.range(of: kind) else { return }
                if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
                    let button = UIButton(frame: frame)
                    button.showsMenuAsPrimaryAction = true
                    button.menu = menu
                    smartSearchLabel.addSubview(button)
                }
            }
        }
    }

    private func placeCountButton() {
        guard let attributedText = smartSearchLabel.attributedText else { return }

        guard let range = attributedText.string.range(of: "\(smartSearch.count)") else { return }
        if let frame = smartSearchLabel.boundingRect(forCharacterRange: NSRange(range, in: attributedText.string)) {
            let button = UIButton(frame: frame)

            let a1 = UIAction(title: "1") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 1
            }

            let a3 = UIAction(title: "3") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 3
            }

            let a5 = UIAction(title: "5") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 5
            }

            let a10 = UIAction(title: "10") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 10
            }

            let a20 = UIAction(title: "20") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 20
            }

            let a50 = UIAction(title: "50") { [weak self] _ in
                guard let self = self else { return }
                self.smartSearch.count = 50
            }
            button.showsMenuAsPrimaryAction = true
            button.menu = UIMenu(children: [a1, a3, a5, a10, a20, a50])
            smartSearchLabel.addSubview(button)
        }
    }

    private func buildMenu() -> UIMenu {
        let runtimeAction = UIAction(title: "Runtime") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.runtimes] = "20-180"
        }

        let ratingsAction = UIAction(title: "Ratings") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.ratings] = "75-100"
        }

        let ignoreWatched = UIAction(title: "Filter Watched", state: smartSearch.filters[.ignoreWatched] == "true" ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            if self.smartSearch.filters[.ignoreWatched] == "true" {
                self.smartSearch.remove(slug: "true", for: .ignoreWatched)
            } else {
                self.smartSearch.filters[.ignoreWatched] = "true"
            }
        }

        let genres = UIMenu(title: "Genres", children: [buildGenresMenu()])
        let certifications = UIMenu(title: "Certifications", children: [buildCertificationsMenu()])
        let networks = UIMenu(title: "Networks", children: [buildNetworkMenu()])
        let countries = UIMenu(title: "Countries", children: [buildCountriesMenu()])
        let languages = UIMenu(title: "Languages", children: [buildLanguagesMenu()])

        if smartSearch.contentType == .movie {
            return UIMenu(children: [genres,
                                     certifications,
                                     buildReleaseYearMenu(), /* a2, a3, a4, */
                                     runtimeAction,
                                     ratingsAction,
                                     countries,
                                     languages,
                                     ignoreWatched])
        } else {
            let statusMenu = buildStatusMenu()
            return UIMenu(children: [genres,
                                     certifications,
                                     buildReleaseYearMenu(),
                                     statusMenu, /* , a3, a4, */
                                     runtimeAction,
                                     ratingsAction,
                                     networks,
                                     countries,
                                     languages,
                                     ignoreWatched])
        }
    }

    private func buildLanguagesMenu() -> UIMenuElement {
        return UIDeferredMenuElement.uncached { completion in
            var service = TraktAPIService.movieLanguages
            if self.smartSearch.contentType == .show {
                service = TraktAPIService.tvLanguages
            }
            TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let languages = try response.map([Language].self, using: TraktAPIProvider.decoder)

                        let current = self.smartSearch.filters[.languages] ?? ""
                        var actions = [UIAction]()
                        let locale = Locale(identifier: "en_US")
                        for language in languages {
                            let alreadySelected = current.split(separator: ",").contains { $0 == language.code }
                            guard let languageName = locale.localizedString(forLanguageCode: language.code) else { continue }
                            let action = UIAction(title: languageName,
                                                  attributes: alreadySelected ? .disabled : [],
                                                  state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: language.code, for: .languages)
                            }
                            actions.append(action)
                        }
                        let alreadySelected = current.split(separator: ",").contains { $0 == "en" }
                        let languageName = locale.localizedString(forLanguageCode: "en")!
                        let en = UIAction(title: languageName,
                                          attributes: alreadySelected ? .disabled : [],
                                          state: alreadySelected ? .on : .off) { [weak self] _ in
                            guard let self = self else { return }
                            self.smartSearch.add(slug: "en", for: .languages)
                        }

                        if let localLanguage = Locale.preferredLanguages.first, localLanguage.prefix(2) != "en" {
                            let alreadySelected = current.split(separator: ",").contains { $0 == localLanguage.prefix(2) }
                            let languageName = locale.localizedString(forLanguageCode: localLanguage)!
                            let localLanguage = UIAction(title: languageName,
                                                         attributes: alreadySelected ? .disabled : [],
                                                         state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: String(localLanguage.prefix(2)), for: .languages)
                            }
                            DispatchQueue.main.async {
                                completion([localLanguage, en,
                                            UIMenu(title: "",
                                                   options: .displayInline,
                                                   children: actions)])
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion([en,
                                            UIMenu(title: "",
                                                   options: .displayInline,
                                                   children: actions)])
                            }
                        }
                    } catch {
                        print("Error Fetching Languages \(error)")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                case .failure(let error):
                    print("Error Fetching Languages \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }

    private func buildCountriesMenu() -> UIMenuElement {
        return UIDeferredMenuElement.uncached { completion in
            var service = TraktAPIService.movieCountries
            if self.smartSearch.contentType == .show {
                service = TraktAPIService.tvCountries
            }
            TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let countries = try response.map([Language].self, using: TraktAPIProvider.decoder)

                        let current = self.smartSearch.filters[.countries] ?? ""
                        var actions = [UIAction]()
                        let locale = Locale(identifier: "en_US")
                        for country in countries {
                            let alreadySelected = current.split(separator: ",").contains { $0 == country.code }
                            guard let countryName = locale.localizedString(forRegionCode: country.code) else { continue }
                            let action = UIAction(title: countryName,
                                                  attributes: alreadySelected ? .disabled : [],
                                                  state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: country.code, for: .countries)
                            }
                            actions.append(action)
                        }
                        let alreadySelected = current.split(separator: ",").contains { $0 == "us" }
                        let countryName = locale.localizedString(forRegionCode: "us")!
                        let us = UIAction(title: countryName,
                                          attributes: alreadySelected ? .disabled : [],
                                          state: alreadySelected ? .on : .off) { [weak self] _ in
                            guard let self = self else { return }
                            self.smartSearch.add(slug: "us", for: .countries)
                        }

                        if let localCountry = Locale.current.language.region?.identifier, localCountry.lowercased() != "us" {
                            let alreadySelected = current.split(separator: ",").contains { $0 == localCountry.lowercased() }
                            let countryName = locale.localizedString(forRegionCode: localCountry)!
                            let localCountry = UIAction(title: countryName,
                                                        attributes: alreadySelected ? .disabled : [],
                                                        state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: localCountry.lowercased(), for: .countries)
                            }
                            DispatchQueue.main.async {
                                completion([localCountry, us,
                                            UIMenu(title: "",
                                                   options: .displayInline,
                                                   children: actions)])
                            }
                        } else {
                            DispatchQueue.main.async {
                                completion([us,
                                            UIMenu(title: "",
                                                   options: .displayInline,
                                                   children: actions)])
                            }
                        }
                    } catch {
                        print("Error Fetching Countries \(error)")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                case .failure(let error):
                    print("Error Fetching Countries \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }

    private func alphabeticalNetworks(networks: [Network]) -> [String: [Network]] {
        var alphabeticalNetworks = [String: [Network]]()
        for network in networks {
            var firstLetter = network.name.prefix(1).uppercased()
            if firstLetter.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil {
                firstLetter = "#"
            }
            if !"ABCDEFGHIJKLMNOPQRSTUVWXYZ#".contains(firstLetter) {
                firstLetter = "~"
            }
            if alphabeticalNetworks[firstLetter] != nil {
                alphabeticalNetworks[firstLetter]!.append(network)
            } else {
                alphabeticalNetworks[firstLetter] = [Network]([network])
            }
        }
        return alphabeticalNetworks
    }

    private func buildNetworkMenu() -> UIMenuElement {
        return UIDeferredMenuElement.uncached { completion in
            TraktAPIProvider.provider.request(TraktAPIService.networks, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let networks = try response.map([Network].self, using: TraktAPIProvider.decoder)
                        let alphabeticalNetworks = self.alphabeticalNetworks(networks: networks.removingDuplicates())

                        let current = self.smartSearch.filters[.networks] ?? ""
                        var children = [UIMenu]()

                        /*
                         var actions = [UIAction]()
                         for favoriteProvider in CountryManager.shared.favoriteProviders.compactMap({ $0.name }) where networks.map({ $0.name }).contains(where: { $0.lowercased() == favoriteProvider.lowercased() }) {
                             let alreadySelected = current.split(separator: ",").contains { $0 == favoriteProvider }
                             let action = UIAction(title: favoriteProvider,
                                                   attributes: alreadySelected ? .disabled : [],
                                                   state: alreadySelected ? .on : .off) { [weak self] _ in
                                 guard let self = self else { return }
                                 self.smartSearch.add(slug: favoriteProvider, for: .networks)
                             }
                             actions.append(action)
                         }
                         children.append(UIMenu(options: .displayInline, children: actions))
                          */

                        for alphabet in alphabeticalNetworks.keys.sorted(by: { $0 < $1 }) {
                            var actions = [UIAction]()
                            for network in alphabeticalNetworks[alphabet]!.sorted(by: { $0.name.uppercased() > $1.name.uppercased()
                            }) {
                                let alreadySelected = current.split(separator: ",").contains { $0 == network.name }
                                let action = UIAction(title: network.name,
                                                      attributes: alreadySelected ? .disabled : [],
                                                      state: alreadySelected ? .on : .off) { [weak self] _ in
                                    guard let self = self else { return }
                                    self.smartSearch.add(slug: network.name, for: .networks)
                                }
                                actions.append(action)
                            }
                            children.append(UIMenu(title: alphabet, children: actions))
                        }

                        DispatchQueue.main.async {
                            completion(children)
                        }
                    } catch {
                        print("Error Fetching Networks \(error)")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                case .failure(let error):
                    print("Error Fetching Networks \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }

    private func buildCertificationsMenu() -> UIMenuElement {
        return UIDeferredMenuElement.uncached { completion in
            var service = TraktAPIService.movieCertifications
            if self.smartSearch.contentType == .show {
                service = TraktAPIService.tvCertifications
            }
            TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let certifications = try response.map(CertificationsCounties.self, using: TraktAPIProvider.decoder).us

                        let current = self.smartSearch.filters[.certifications] ?? ""
                        var actions = [UIAction]()
                        for certification in certifications {
                            let alreadySelected = current.split(separator: ",").contains { $0 == certification.slug }
                            let action = UIAction(title: certification.name,
                                                  subtitle: certification.description,
                                                  attributes: alreadySelected ? .disabled : [],
                                                  state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: certification.slug, for: .certifications)
                            }
                            actions.append(action)
                        }

                        DispatchQueue.main.async {
                            completion(actions)
                        }
                    } catch {
                        print("Error Fetching Certification \(error)")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                case .failure(let error):
                    print("Error Fetching Certification \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }

    private func buildGenresMenu() -> UIMenuElement {
        return UIDeferredMenuElement.uncached { completion in
            var service = TraktAPIService.movieGenres
            if self.smartSearch.contentType == .show {
                service = TraktAPIService.tvGenres
            }
            TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let genres = try response.map([Genre].self, using: TraktAPIProvider.decoder)

                        let currentGenres = self.smartSearch.filters[.genres] ?? ""
                        var actions = [UIAction]()
                        for genre in genres {
                            let alreadySelected = currentGenres.split(separator: ",").contains { $0 == genre.slug }
                            let action = UIAction(title: genre.name,
                                                  attributes: alreadySelected ? .disabled : [],
                                                  state: alreadySelected ? .on : .off) { [weak self] _ in
                                guard let self = self else { return }
                                self.smartSearch.add(slug: genre.slug, for: .genres)
                            }
                            actions.append(action)
                        }

                        DispatchQueue.main.async {
                            completion(actions)
                        }
                    } catch {
                        print("Error Fetching Genres \(error)")
                        DispatchQueue.main.async {
                            completion([])
                        }
                    }
                case .failure(let error):
                    print("Error Fetching Genres \(error)")
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }

    private func buildStatusMenu() -> UIMenu {
        let current = smartSearch.filters[.status] ?? ""
        let split = current.split(separator: ",")

        let returning = UIAction(title: "Returning Series",
                                 attributes: split.contains("Returning Series") ? .disabled : [],
                                 state: split.contains("Returning Series") ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.add(slug: "returning series", for: .status)
        }
        let production = UIAction(title: "In Production",
                                  attributes: split.contains("In Production") ? .disabled : [],
                                  state: split.contains("In Production") ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.add(slug: "in production", for: .status)
        }
        let planned = UIAction(title: "Planned",
                               attributes: split.contains("Planned") ? .disabled : [],
                               state: split.contains("Planned") ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.add(slug: "planned", for: .status)
        }
        let canceled = UIAction(title: "Canceled",
                                attributes: split.contains("Canceled") ? .disabled : [],
                                state: split.contains("Canceled") ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.add(slug: "canceled", for: .status)
        }
        let ended = UIAction(title: "Ended",
                             attributes: split.contains("Ended") ? .disabled : [],
                             state: split.contains("Ended") ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.add(slug: "ended", for: .status)
        }

        return UIMenu(title: "Status", children: [returning, production, planned, canceled, ended])
    }

    private func buildReleaseYearMenu() -> UIMenu {
        let seventies = UIAction(title: "1970s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "1970-1979"
        }
        let eighties = UIAction(title: "1980s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "1980-1989"
        }
        let nineties = UIAction(title: "1990s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "1990-1999"
        }
        let twenties = UIAction(title: "2000s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "2000-2009"
        }
        let tenies = UIAction(title: "2010s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "2010-2019"
        }
        let twentytwenties = UIAction(title: "2020s") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "2020-2028"
        }

        let decades = UIMenu(title: "Decades", children: [seventies, eighties, nineties, twenties, tenies, twentytwenties])

        let resetDefault = UIAction(title: "Default (1880-2028)") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "1880-2028"
        }

        let year = Calendar.current.component(.year, from: Date())
        let thisYear = UIAction(title: "This Year (\(year))") { [weak self] _ in
            guard let self = self else { return }
            self.smartSearch.filters[.years] = "\(year)"
        }

        return UIMenu(title: "Release Date", children: [thisYear, decades, resetDefault])
    }

    @IBOutlet var smartSearchLabel: UILabel!
    @IBOutlet var saveButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        isModalInPresentation = true

        smartSearchLabel.isUserInteractionEnabled = true

        addConditionButton.showsMenuAsPrimaryAction = true
        addConditionButton.menu = buildMenu()
        addConditionButton.isHidden = smartSearch.contentKind == .boxOffice

        if let name = smartSearch.name {
            title = name
            saveButton.title = "Update"
        } else {
            title = "Smart Search"
            saveButton.title = "Save"
        }
    }

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func save(_ sender: Any) {
        if let name = smartSearch.name {
            promptForNewName(currentName: name)
        } else {
            promptForName()
        }
    }

    private func promptForName() {
        let alert = UIAlertController(title: "What's My Name?",
                                      message: "Type a name for your Smart Search. Tip: You'll be able to edit it later.",
                                      preferredStyle: .alert)
        alert.addTextField()

        let submitAction = UIAlertAction(title: "Save", style: .default) { [unowned alert, weak self] _ in
            guard let self = self else { return }
            let answer = alert.textFields![0]

            self.smartSearch.name = answer.text

            self.smartSearch.save()

            self.dismiss(animated: true)
        }
        alert.addAction(submitAction)

        present(alert, animated: true)
    }

    private func promptForNewName(currentName: String) {
        let alert = UIAlertController(title: "What's My New Name?",
                                      message: "Type a new name for your Smart Search.",
                                      preferredStyle: .alert)
        alert.addTextField()
        alert.textFields![0].text = currentName

        let submitAction = UIAlertAction(title: "Update", style: .default) { [unowned alert, weak self] _ in
            guard let self = self else { return }
            let answer = alert.textFields![0]

            self.smartSearch.name = answer.text

            self.smartSearch.update()

            self.dismiss(animated: true)
        }
        alert.addAction(submitAction)

        present(alert, animated: true)
    }
}
