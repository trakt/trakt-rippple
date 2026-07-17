//
//  SearchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/06/2018.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class SearchViewController: UITableViewController {
    let searchController = UISearchController(searchResultsController: nil)

    private let disposeBag = DisposeBag()

    private var savedFilters = [SavedFilter]() {
        didSet {
            updateDatasource()
        }
    }

    /// request
    private var request: Cancellable?

    var isDeeplink = false
    var searchQuery: String = "" {
        didSet {
            updateDatasource()
        }
    }

    private var shouldOpenKeyboard = false

    private var showsSmartSearches = [SmartSearch]() {
        didSet {
            updateDatasource()
        }
    }

    private var moviesSmartSearches = [SmartSearch]() {
        didSet {
            updateDatasource()
        }
    }

    private enum Section: Int {
        case filters
        case movies
        case series
        case lists
        case trending
        case suggestions
        case search
        case editingMovies
        case editingSeries
        case recents
    }

    private struct CellConfig {
        let identifier: String

        let cardType: CardType
        let title: String
        let subtitle: String?
        let query: String?

        let segue: String
    }

    private enum Wrapper: Hashable {
        case smartSearch(CellConfig, SmartSearch)
        case savedFilter(CellConfig, SavedFilter)
        case search(CellConfig, TraktAPIService)
        case suggestion(CellConfig, TMDbResult)
        case user(CellConfig)
        case recentSearch(CellConfig, RecentSearch)

        static func == (lhs: SearchViewController.Wrapper, rhs: SearchViewController.Wrapper) -> Bool {
            switch (lhs, rhs) {
            case (.smartSearch(let lhsConfig, _), .smartSearch(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.savedFilter(let lhsConfig, _), .savedFilter(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.search(let lhsConfig, _), .search(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.suggestion(let lhsConfig, _), .suggestion(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.user(let lhsConfig), .user(let rhsConfig)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.recentSearch(let lhsConfig, _), .recentSearch(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .smartSearch(let config, _):
                hasher.combine(config.identifier)
            case .savedFilter(let config, _):
                hasher.combine(config.identifier)
            case .search(let config, _):
                hasher.combine(config.identifier)
            case .suggestion(let config, _):
                hasher.combine(config.identifier)
            case .user(let config):
                hasher.combine(config.identifier)
            case .recentSearch(let config, _):
                hasher.combine(config.identifier)
            }
        }
    }

    private class WatchlistDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            guard let item = sectionIdentifier(for: indexPath.section) else { return false }

            switch item {
            case .editingSeries, .editingMovies:
                return true
            default:
                return false
            }
        }

        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let item = sectionIdentifier(for: indexPath.section) else { return false }

            switch item {
            case .editingSeries, .editingMovies:
                return true
            case .movies, .series:
                return true
            case .recents:
                return true
            default:
                return false
            }
        }

        override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            if editingStyle == .delete {
                guard let item = itemIdentifier(for: indexPath) else { return }

                switch item {
                case .smartSearch(_, let smartSearch):
                    smartSearch.delete()
                default:
                    return
                }
            }
        }

        override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            guard let item = itemIdentifier(for: sourceIndexPath) else { return }

            switch item {
            case .smartSearch(_, let smartSearch):
                smartSearch.move(at: destinationIndexPath.row)
            default:
                return
            }
        }
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard let item = dataSource.sectionIdentifier(for: indexPath.section) else { return .none }

        switch item {
        case .editingSeries, .editingMovies:
            return .delete
        default:
            return .none
        }
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section == 0 && proposedDestinationIndexPath.section == 0 {
            return proposedDestinationIndexPath
        }
        if sourceIndexPath.section == 1 && proposedDestinationIndexPath.section == 1 {
            return proposedDestinationIndexPath
        }

        if sourceIndexPath.section == 0 && proposedDestinationIndexPath.section > 0 {
            return IndexPath(item: moviesSmartSearches.count - 1, section: 0)
        }

        if sourceIndexPath.section == 1 && proposedDestinationIndexPath.section == 0 {
            return IndexPath(item: 0, section: 1)
        }

        if sourceIndexPath.section == 1 && proposedDestinationIndexPath.section == 2 {
            return IndexPath(item: showsSmartSearches.count - 1, section: 1)
        }

        return sourceIndexPath
    }

    private func cardType(for object: SmartSearch, in collection: [SmartSearch]) -> CardType {
        if collection.count == 1 { return .alone }
        if collection.first == object { return .top }
        if collection.last == object { return .bottom }
        return .middle
    }

    private func cardType(for object: TMDbResult, in collection: [TMDbResult]) -> CardType {
        if collection.count == 1 { return .alone }
        if collection.first == object { return .top }
        if collection.last == object { return .bottom }
        return .middle
    }

    private func cardType(for object: SavedFilter, in collection: [SavedFilter]) -> CardType {
        if collection.count == 1 { return .alone }
        if collection.first == object { return .top }
        if collection.last == object { return .bottom }
        return .middle
    }

    private func baseSuggestionTitle(for item: TMDbResult) -> String {
        return item.title ?? item.name ?? ""
    }

    private func suggestionTitle(for item: TMDbResult, in collection: [TMDbResult]) -> String {
        let title = baseSuggestionTitle(for: item)
        guard item.mediaType == "movie" || item.mediaType == "tv" else { return title }

        let matchingTitleCount = collection.filter {
            $0.mediaType == item.mediaType && baseSuggestionTitle(for: $0) == title
        }.count

        guard matchingTitleCount > 1 else { return title }

        var titleElements = [String]()
        if item.mediaType == "tv",
           let firstAirDate = item.firstAirDate,
           firstAirDate.isEmpty == false {
            titleElements.append(String(firstAirDate.prefix(4)))
        }
        if item.mediaType == "movie",
           let releaseDate = item.releaseDate,
           releaseDate.isEmpty == false {
            titleElements.append(String(releaseDate.prefix(4)))
        }
        if item.mediaType == "tv",
           let originCountry = item.originCountry?.first,
           let country = Locale(identifier: "en_US").localizedString(forRegionCode: originCountry) {
            titleElements.append(country)
        }

        if titleElements.isEmpty {
            return title
        }

        return "\(title) · \(titleElements.joined(separator: " · "))"
    }

    private func recentSearchPath(for service: TraktAPIService?) -> String {
        if let service = service,
           case .search(let type, _) = service {
            return "/search/\(type.rawValue)"
        }

        return "/search/\(SearchType.moviesAndShow.rawValue)"
    }

    private func recentSearchPath(for item: TMDbResult) -> String {
        switch item.mediaType {
        case "movie":
            return "/search/\(SearchType.movie.rawValue)"
        case "tv":
            return "/search/\(SearchType.show.rawValue)"
        case "person":
            return "/search/\(SearchType.person.rawValue)"
        default:
            return "/search/\(SearchType.moviesAndShow.rawValue)"
        }
    }

    private func saveRecentSearch(title: String, query: String, path: String = "/search/\(SearchType.moviesAndShow.rawValue)") {
        RecentSearchManager.shared.save(title: title, query: query, path: path)
    }

    private func saveRecentSearch(config: CellConfig, service: TraktAPIService? = nil) {
        let query = config.query ?? config.title
        saveRecentSearch(title: query,
                         query: query,
                         path: recentSearchPath(for: service))
    }

    private func applyRecentSearch(_ recentSearch: RecentSearch) {
        let query = recentSearch.searchFieldQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return }

        searchController.isActive = true
        searchController.searchBar.searchTextField.text = query
        suggestions.removeAll()
        searchQuery = query
        RecentSearchManager.shared.recentSearches.insert(recentSearch, at: 0)
        fetchSuggestions()

        DispatchQueue.main.async {
            self.searchController.searchBar.becomeFirstResponder()
            self.tableView.scrollRectToVisible(CGRect(x: 0,
                                                      y: 0,
                                                      width: 1,
                                                      height: 1),
                                               animated: true)
        }
    }

    private func updateDatasource() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()

        if tableView.isEditing {
            snapshot.appendSections([.editingMovies])
            snapshot.appendItems(moviesSmartSearches.map { .smartSearch(CellConfig(identifier: "Edit \($0.uuid)",
                                                                                   cardType: cardType(for: $0, in: moviesSmartSearches),
                                                                                   title: $0.name!,
                                                                                   subtitle: nil,
                                                                                   query: nil,
                                                                                   segue: "browse"), $0) })

            snapshot.appendSections([.editingSeries])
            snapshot.appendItems(showsSmartSearches.map { .smartSearch(CellConfig(identifier: "Edit \($0.uuid)",
                                                                                  cardType: cardType(for: $0, in: showsSmartSearches),
                                                                                  title: $0.name!,
                                                                                  subtitle: nil,
                                                                                  query: nil,
                                                                                  segue: "browse"), $0) })

            DispatchQueue.main.async {
                self.dataSource.applySnapshotUsingReloadData(snapshot)
            }
            return
        }

        if searchController.isActive, searchQuery.isEmpty == false {
            snapshot.appendSections([.search])
            snapshot.appendItems([.search(CellConfig(identifier: "Movies & TV with \"\(searchQuery)\"",
                                                     cardType: .top,
                                                     title: "Movies & TV with \"\(searchQuery)\"",
                                                     subtitle: nil,
                                                     query: searchQuery,
                                                     segue: "results"), .search(type: .moviesAndShow, query: searchQuery))])

            snapshot.appendItems([.search(CellConfig(identifier: "People with \"\(searchQuery)\"",
                                                     cardType: .middle,
                                                     title: "People with \"\(searchQuery)\"",
                                                     subtitle: nil,
                                                     query: searchQuery,
                                                     segue: "people"), .search(type: .person, query: searchQuery))])

            if NSPredicate(format: "SELF MATCHES %@", "^[A-Za-z0-9]+([-.!_]{1}[A-Za-z0-9]+)*").evaluate(with: searchQuery.lowercased()) {
                snapshot.appendItems([.search(CellConfig(identifier: "Lists with \"\(searchQuery)\"",
                                                         cardType: .middle,
                                                         title: "Lists with \"\(searchQuery)\"",
                                                         subtitle: nil,
                                                         query: searchQuery,
                                                         segue: "lists"), .search(type: .list, query: searchQuery))])

                snapshot.appendItems([.user(CellConfig(identifier: "Go to user @\(searchQuery.lowercased())",
                                                       cardType: .bottom,
                                                       title: "Go to user @\(searchQuery.lowercased())",
                                                       subtitle: nil,
                                                       query: searchQuery,
                                                       segue: ""))])
            } else {
                snapshot.appendItems([.search(CellConfig(identifier: "Lists with \"\(searchQuery)\"",
                                                         cardType: .bottom,
                                                         title: "Lists with \"\(searchQuery)\"",
                                                         subtitle: nil,
                                                         query: searchQuery,
                                                         segue: "lists"), .search(type: .list, query: searchQuery))])
            }

            if suggestions.isEmpty == false {
                snapshot.appendSections([.suggestions])
                for trendingItem in suggestions {
                    if trendingItem.mediaType == "movie" {
                        snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.id)",
                                                                     cardType: cardType(for: trendingItem, in: suggestions),
                                                                     title: suggestionTitle(for: trendingItem, in: suggestions),
                                                                     subtitle: " in Movies",
                                                                     query: nil,
                                                                     segue: "results"), trendingItem)])
                    } else if trendingItem.mediaType == "tv" {
                        snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.id)",
                                                                     cardType: cardType(for: trendingItem, in: suggestions),
                                                                     title: suggestionTitle(for: trendingItem, in: suggestions),
                                                                     subtitle: " in TV",
                                                                     query: nil,
                                                                     segue: "results"), trendingItem)])
                    } else {
                        snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.id)",
                                                                     cardType: cardType(for: trendingItem, in: suggestions),
                                                                     title: trendingItem.name!,
                                                                     subtitle: " in People",
                                                                     query: nil,
                                                                     segue: "people"), trendingItem)])
                    }
                }
            }

            DispatchQueue.main.async {
                self.dataSource.applySnapshotUsingReloadData(snapshot)
            }
            return
        }

        if searchController.isActive, searchQuery.isEmpty == true {
            let recentSearches = RecentSearchManager.shared.recentSearches
            if recentSearches.isEmpty == false {
                snapshot.appendSections([.recents])
                snapshot.appendItems(recentSearches.removingDuplicates().map { .recentSearch(CellConfig(identifier: UUID().uuidString,
                                                                                                        cardType: cardType(for: $0, in: recentSearches),
                                                                                                        title: $0.name,
                                                                                                        subtitle: nil,
                                                                                                        query: nil,
                                                                                                        segue: "results"), $0) })
            }

            snapshot.appendSections([.trending])
            for trendingItem in trending {
                if trendingItem.mediaType == "movie" {
                    snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.title!) in Movies",
                                                                 cardType: cardType(for: trendingItem, in: trending),
                                                                 title: trendingItem.title!,
                                                                 subtitle: " in Movies",
                                                                 query: nil,
                                                                 segue: "results"), trendingItem)])
                } else if trendingItem.mediaType == "tv" {
                    snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.name!) in TV",
                                                                 cardType: cardType(for: trendingItem, in: trending),
                                                                 title: trendingItem.name!,
                                                                 subtitle: " in TV",
                                                                 query: nil,
                                                                 segue: "results"), trendingItem)])
                } else {
                    snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.name!) in TV",
                                                                 cardType: cardType(for: trendingItem, in: trending),
                                                                 title: trendingItem.name!,
                                                                 subtitle: " in People",
                                                                 query: nil,
                                                                 segue: "people"), trendingItem)])
                }
            }

            DispatchQueue.main.async {
                self.dataSource.applySnapshotUsingReloadData(snapshot)
            }
            return
        }

        if savedFilters.isEmpty == false {
            snapshot.appendSections([.filters])
            snapshot.appendItems(savedFilters.map { .savedFilter(CellConfig(identifier: "\($0.name)\($0.query)\($0.path)",
                                                                            cardType: cardType(for: $0, in: savedFilters),
                                                                            title: $0.name,
                                                                            subtitle: nil,
                                                                            query: nil,
                                                                            segue: "results"), $0) })
        }

        snapshot.appendSections([.movies])
        snapshot.appendItems(moviesSmartSearches.map { .smartSearch(CellConfig(identifier: $0.uuid,
                                                                               cardType: cardType(for: $0, in: moviesSmartSearches),
                                                                               title: $0.name!,
                                                                               subtitle: nil,
                                                                               query: nil,
                                                                               segue: "results"), $0) })

        snapshot.appendSections([.series])
        snapshot.appendItems(showsSmartSearches.map { .smartSearch(CellConfig(identifier: $0.uuid,
                                                                              cardType: cardType(for: $0, in: showsSmartSearches),
                                                                              title: $0.name!,
                                                                              subtitle: nil,
                                                                              query: nil,
                                                                              segue: "results"), $0) })

        snapshot.appendSections([.lists])
        snapshot.appendItems([.search(CellConfig(identifier: "Popular Official Lists",
                                                 cardType: .top,
                                                 title: "Trakt Official Lists",
                                                 subtitle: nil,
                                                 query: nil,
                                                 segue: "lists"), TraktAPIService.popularLists(type: .official))])
        snapshot.appendItems([.search(CellConfig(identifier: "Trending Lists",
                                                 cardType: .middle,
                                                 title: "Trending Lists",
                                                 subtitle: nil,
                                                 query: nil,
                                                 segue: "lists"), TraktAPIService.trendingLists(type: .personal))])
        snapshot.appendItems([.search(CellConfig(identifier: "Popular Lists",
                                                 cardType: .bottom,
                                                 title: "Popular Lists",
                                                 subtitle: nil,
                                                 query: nil,
                                                 segue: "lists"), TraktAPIService.popularLists(type: .personal))])

        snapshot.appendSections([.trending])
        for trendingItem in trending {
            if trendingItem.mediaType == "movie" {
                snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.title!) in Movies",
                                                             cardType: cardType(for: trendingItem, in: trending),
                                                             title: trendingItem.title!,
                                                             subtitle: " in Movies",
                                                             query: nil,
                                                             segue: "results"), trendingItem)])
            } else if trendingItem.mediaType == "tv" {
                snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.name!) in TV",
                                                             cardType: cardType(for: trendingItem, in: trending),
                                                             title: trendingItem.name!,
                                                             subtitle: " in TV",
                                                             query: nil,
                                                             segue: "results"), trendingItem)])
            } else {
                snapshot.appendItems([.suggestion(CellConfig(identifier: "\(trendingItem.name!) in TV",
                                                             cardType: cardType(for: trendingItem, in: trending),
                                                             title: trendingItem.name!,
                                                             subtitle: " in People",
                                                             query: nil,
                                                             segue: "people"), trendingItem)])
            }
        }

        DispatchQueue.main.async {
            self.dataSource.applySnapshotUsingReloadData(snapshot)
        }
    }

    private lazy var dataSource = WatchlistDiffibleDataSource(tableView: tableView) { tableView, _, item in
        switch item {
        case .smartSearch(let config, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = false

            cell.card.alpha = tableView.isEditing ? 0.0 : 1.0
            cell.chevron.alpha = tableView.isEditing ? 0.0 : 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        case .savedFilter(let config, _), .search(let config, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = false

            cell.card.alpha = 1.0
            cell.chevron.alpha = 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        case .suggestion(let config, let tmdbResult):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = tmdbResult.mediaType == "movie" || tmdbResult.mediaType == "tv"

            cell.card.alpha = 1.0
            cell.chevron.alpha = 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        case .user(let config):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = true

            cell.card.alpha = 1.0
            cell.chevron.alpha = 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        case .recentSearch(let config, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = false

            cell.card.alpha = 1.0
            cell.chevron.alpha = 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsFocus = false
        tableView.allowsFocusDuringEditing = false
        tableView.register(UINib(nibName: "SearchTableViewCell", bundle: nil), forCellReuseIdentifier: "search")
        tableView.register(UINib(nibName: "SearchHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "header")

        tableView.separatorStyle = .none

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false

        searchController.searchBar.placeholder = "Movie, Show, People, List & User"
        searchController.searchBar.delegate = self

        tableView.dataSource = dataSource

        navigationItem.searchController = searchController
        navigationItem.style = .browser

        showsSmartSearches = SmartSearch.smartSearches(for: .show)
        moviesSmartSearches = SmartSearch.smartSearches(for: .movie)
        onShowSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.showsSmartSearches = SmartSearch.smartSearches(for: .show)
        }.disposed(by: disposeBag)

        onMovieSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.moviesSmartSearches = SmartSearch.smartSearches(for: .movie)
        }.disposed(by: disposeBag)

        fetchTrending()

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didBecomeActive:
                self.fetchTrending()
            case .didFinishLaunching: break
            case .didEnterBackground: break
            }
        }.disposed(by: disposeBag)

        onSavedFiltersChangedReceiver.listen { [weak self] savedFilters in
            guard let self = self else { return }
            self.savedFilters = savedFilters
        }.disposed(by: disposeBag)

        onRecentSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateDatasource()
        }.disposed(by: disposeBag)

        updateDatasource()
    }

    private var trending = [TMDbResult]() {
        didSet {
            updateDatasource()
        }
    }

    private func fetchTrending() {
        TmdbAPIProvider.provider.request(.trending, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map(TMDbResults.self, using: TmdbAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.trending = results.results
                    }
                } catch {
                    print("TmdbAPIService.trending Error: \(error)")
                }
            case .failure(let error):
                print("TmdbAPIService.trending Failure: \(error)")
            }
        }
    }

    private var suggestions = [TMDbResult]() {
        didSet {
            updateDatasource()
        }
    }

    private func fetchSuggestions() {
        TmdbAPIProvider.provider.request(.search(searchQuery), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map(TMDbResults.self, using: TmdbAPIProvider.decoder).results.filter { $0.mediaType == "movie" || $0.mediaType == "tv" || $0.mediaType == "person" }

                    DispatchQueue.main.async {
                        self.suggestions = results
                    }
                } catch {
                    print("TmdbAPIService.search Error: \(error)")
                }
            case .failure(let error):
                print("TmdbAPIService.search Failure: \(error)")
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, do not show a left bar button item.
        navigationItem.leftBarButtonItem = nil
        #else
        if UIDevice.current.userInterfaceIdiom == .pad, isDeeplink == false {
            // On iPad, do not show a left (profile) bar button item.
            navigationItem.leftBarButtonItem = nil
        }
        #endif

        if isDeeplink == true {
            searchController.searchBar.searchTextField.text = searchQuery
            shouldOpenKeyboard = true
        } else if navigationController?.presentingViewController?.presentedViewController == navigationController {
            shouldOpenKeyboard = true
            let buttonItem = UIBarButtonItem(systemItem: .close,
                                             primaryAction: UIAction(handler: { _ in
                                                 self.dismiss(animated: true, completion: nil)
                                             }))
            buttonItem.style = .plain
            navigationItem.leftBarButtonItem = buttonItem
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldOpenKeyboard {
            shouldOpenKeyboard = false
            DispatchQueue.main.async {
                self.searchController.searchBar.searchTextField.becomeFirstResponder()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let request = request {
            request.cancel()
        }
        request = nil
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as! SearchHeaderView

        guard let item = dataSource.sectionIdentifier(for: section) else { return nil }

        switch item {
        case .filters:
            header.title.text = "💾 Saved Filters"
            header.button.isHidden = true
        case .movies:
            header.title.text = "📽 Browse Movies"
            header.button.isHidden = false
            header.button.setTitle("Add Smart Search", for: .normal)
            header.button.removeTarget(self, action: nil, for: .touchUpInside)
            header.button.addTarget(self, action: #selector(smartMovie), for: .touchUpInside)
        case .series:
            header.title.text = "📺 Browse TV Shows"
            header.button.isHidden = false
            header.button.setTitle("Add Smart Search", for: .normal)
            header.button.removeTarget(self, action: nil, for: .touchUpInside)
            header.button.addTarget(self, action: #selector(smartShow), for: .touchUpInside)
        case .lists:
            header.title.text = "📝 Browse Lists"
            header.button.isHidden = true
        case .trending:
            header.title.text = "↗️ Trending Searches"
            header.button.isHidden = true
        case .suggestions:
            header.title.text = "✨ Search Suggestions"
            header.button.isHidden = true
        case .search:
            header.title.text = ""
            header.button.isHidden = true
        case .editingMovies:
            header.title.text = "📽 Browse Movies"
            header.button.isHidden = true
        case .editingSeries:
            header.title.text = "📺 Browse TV Shows"
            header.button.isHidden = true
        case .recents:
            header.title.text = "🕒 Recent Searches"
            header.button.isHidden = false
            header.button.setTitle("Clear All", for: .normal)
            header.button.removeTarget(self, action: nil, for: .touchUpInside)
            header.button.addTarget(self, action: #selector(clearRecents), for: .touchUpInside)
        }

        return header
    }

    @objc func clearRecents() {
        RecentSearchManager.shared.removeAll()
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc func smartMovie() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        performSegue(withIdentifier: "smartSearch", sender: SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/trending", count: 10))
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc func smartShow() {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        performSegue(withIdentifier: "smartSearch", sender: SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/trending", count: 10))
        UISelectionFeedbackGenerator().selectionChanged()
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let item = dataSource.sectionIdentifier(for: section) else { return 0 }

        switch item {
        case .filters:
            return 30
        case .movies:
            return 30
        case .series:
            return 30
        case .lists:
            return 30
        case .trending:
            return 30
        case .suggestions:
            return 30
        case .search:
            return 0
        case .editingMovies:
            return 30
        case .editingSeries:
            return 30
        case .recents:
            return 30
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .smartSearch(let config, let smartSearch):
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(config: config)
            performSegue(withIdentifier: config.segue, sender: smartSearch)
        case .savedFilter(let config, let savedFilter):
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(config: config)
            performSegue(withIdentifier: config.segue, sender: savedFilter)
        case .search(let config, let service):
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(config: config, service: service)
            performSegue(withIdentifier: config.segue, sender: service)
        case .user:
            searchController.searchBar.resignFirstResponder()
            let username = searchQuery.lowercased()
            saveRecentSearch(title: "@\(username)", query: username)
            fetchUser(with: username)
            return // don't deselectRow to show loading indicator
        case .suggestion(let config, let tmdbResult):
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(title: config.title,
                             query: config.title,
                             path: recentSearchPath(for: tmdbResult))
            if tmdbResult.mediaType == "movie" || tmdbResult.mediaType == "tv" {
                lookupSuggestion(tmdbResult, fallbackSegue: config.segue)
                return // don't deselectRow to show loading indicator
            } else {
                performSegue(withIdentifier: config.segue, sender: tmdbResult)
            }
        case .recentSearch(_, let recentSearch):
            applyRecentSearch(recentSearch)
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    private func lookupSuggestion(_ tmdbResult: TMDbResult, fallbackSegue: String) {
        let lookupType: TmdbType
        switch tmdbResult.mediaType {
        case "movie":
            lookupType = .movie
        case "tv":
            lookupType = .show
        default:
            performSegue(withIdentifier: fallbackSegue, sender: tmdbResult)
            return
        }

        if let request = request {
            request.cancel()
        }
        request = TraktAPIProvider.provider.request(.lookup(tmdbID: String(tmdbResult.id),
                                                            type: lookupType),
                                                    callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    guard let indexPathForSelectedRows = self.tableView.indexPathsForSelectedRows else { return }
                    for indexPath in indexPathForSelectedRows {
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                }
            }

            let fallback = {
                DispatchQueue.main.async {
                    self.request = nil
                    self.performSegue(withIdentifier: fallbackSegue, sender: tmdbResult)
                }
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    let searchResults = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)

                    let media: MediaModel?
                    switch lookupType {
                    case .movie:
                        media = searchResults.first(where: { $0.movie != nil })?.movie.map { .movie($0) }
                    case .show:
                        media = searchResults.first(where: { $0.show != nil })?.show.map { .show($0) }
                    case .episode, .person:
                        media = nil
                    }

                    guard let media = media else {
                        fallback()
                        return
                    }

                    DispatchQueue.main.async {
                        self.request = nil
                        self.performSegue(withIdentifier: "details", sender: media)
                    }
                } catch {
                    fallback()
                }
            case .failure:
                fallback()
            }
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if !PurchaseManager.shared.purchased {
            return nil
        }

        guard let item = dataSource.sectionIdentifier(for: indexPath.section) else { return nil }

        switch item {
        case .movies:
            if searchController.isActive { return nil }
            if tableView.isEditing { return nil }

            let remove = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.moviesSmartSearches[indexPath.row].delete()
                DispatchQueue.main.async {
                    self.tableView.isEditing = false
                    self.updateDatasource()
                }
                boolValue(true)
            }
            remove.backgroundColor = .systemRed
            remove.image = UIImage(systemName: "trash.circle.fill")

            let configuration = UISwipeActionsConfiguration(actions: [remove])
            configuration.performsFirstActionWithFullSwipe = false

            return configuration
        case .series:
            if searchController.isActive { return nil }
            if tableView.isEditing { return nil }

            let remove = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.showsSmartSearches[indexPath.row].delete()
                DispatchQueue.main.async {
                    self.tableView.isEditing = false
                    self.updateDatasource()
                }
                boolValue(true)
            }
            remove.backgroundColor = .systemRed
            remove.image = UIImage(systemName: "trash.circle.fill")

            let configuration = UISwipeActionsConfiguration(actions: [remove])
            configuration.performsFirstActionWithFullSwipe = false

            return configuration
        case .recents:
            guard let recentSearch = dataSource.itemIdentifier(for: indexPath) else { return nil }

            let remove = UIContextualAction(style: .destructive, title: nil) { [weak self] _, _, boolValue in
                guard let self = self else { return }
                if case .recentSearch(_, let recentSearch) = recentSearch {
                    RecentSearchManager.shared.recentSearches.removeAll(where: { $0 == recentSearch })
                    DispatchQueue.main.async {
                        self.tableView.isEditing = false
                        self.updateDatasource()
                    }
                }
                boolValue(true)
            }
            remove.backgroundColor = .systemRed
            remove.image = UIImage(systemName: "trash.circle.fill")

            let configuration = UISwipeActionsConfiguration(actions: [remove])
            configuration.performsFirstActionWithFullSwipe = false

            return configuration
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if searchController.isActive { return nil }
        if tableView.isEditing { return nil }

        guard let item = dataSource.sectionIdentifier(for: indexPath.section) else { return nil }

        switch item {
        case .movies:
            let edit = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.performSegue(withIdentifier: "smartSearch", sender: self.moviesSmartSearches[indexPath.row])
                boolValue(true)
            }
            edit.backgroundColor = UIColor(resource: .ripppleGray)
            edit.image = UIImage(systemName: "pencil.circle.fill")

            let configuration = UISwipeActionsConfiguration(actions: [edit])
            configuration.performsFirstActionWithFullSwipe = true

            return configuration
        case .series:
            let edit = UIContextualAction(style: .normal, title: nil) { [weak self] _, _, boolValue in
                guard let self = self else { return }
                self.performSegue(withIdentifier: "smartSearch", sender: self.showsSmartSearches[indexPath.row])
                boolValue(true)
            }
            edit.backgroundColor = UIColor(resource: .ripppleGray)
            edit.image = UIImage(systemName: "pencil.circle.fill")

            let configuration = UISwipeActionsConfiguration(actions: [edit])
            configuration.performsFirstActionWithFullSwipe = true

            return configuration
        default:
            return nil
        }
    }

    @IBOutlet var editBarButtonItem: UIBarButtonItem!
    @IBAction func editTableView(sender: UIBarButtonItem) {
        if !PurchaseManager.shared.purchased {
            UIApplication.shared.switchToPurchase()
            return
        }

        if tableView.isEditing {
            tableView.setEditing(false, animated: true)
            editBarButtonItem.title = "Edit"
        } else {
            tableView.setEditing(true, animated: true)
            editBarButtonItem.title = "Done"
        }
        updateDatasource()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "smartSearch" {
            if let navigationController = segue.destination as? UINavigationController,
               let smartSearchBuilder = navigationController.viewControllers.first as? SmartSearchBuilderViewController {
                smartSearchBuilder.smartSearch = sender as? SmartSearch
            }

            return
        }

        if segue.identifier == "user" {
            if let commentsViewController = segue.destination as? CommentsViewController,
               let coordinator = sender as? CommentsCoordinator {
                commentsViewController.coordinator = coordinator
            }

            return
        }

        if let smartSearch = sender as? SmartSearch {
            if let destination = segue.destination as? SearchResultsViewController {
                destination.aSmartSearch = smartSearch
                return
            }
        }

        if segue.identifier == "details",
           let destination = segue.destination as? MediaViewController,
           let media = sender as? MediaModel {
            destination.media = media
            return
        }

        if let service = sender as? TraktAPIService {
            if let destination = segue.destination as? SearchResultsViewController {
                destination.title = searchQuery.capitalized
                destination.service = service
            } else if let destination = segue.destination as? PeopleSearchResultsViewController {
                destination.title = searchQuery.capitalized
                destination.service = service
            } else if let destination = segue.destination as? ListSearchResultsViewController {
                switch service {
                case .trendingLists:
                    destination.title = "Trending Lists"
                case .popularLists(let type):
                    if type == .official {
                        destination.title = "Trakt Official Lists"
                    } else {
                        destination.title = "Popular Lists"
                    }
                default:
                    destination.title = searchQuery
                }
                destination.service = service
            }
        } else if let trendingItem = sender as? TMDbResult,
                  let destination = segue.destination as? SearchResultsViewController {
            if trendingItem.mediaType == "movie" {
                destination.title = trendingItem.title ?? ""
                destination.service = TraktAPIService.search(type: .movie,
                                                             query: destination.title!)
            } else if trendingItem.mediaType == "tv" {
                destination.title = trendingItem.name ?? ""
                destination.service = TraktAPIService.search(type: .show,
                                                             query: destination.title!)
            }
        } else if let trendingItem = sender as? TMDbResult,
                  let destination = segue.destination as? PeopleSearchResultsViewController {
            destination.title = trendingItem.name ?? ""
            destination.service = TraktAPIService.search(type: .person,
                                                         query: destination.title!)
        } else if let savedFilter = sender as? SavedFilter,
                  let destination = segue.destination as? SearchResultsViewController {
            destination.title = savedFilter.name
            // Real Saved Filter from Trakt can be added to shelf, otherwise it's a Saved Search and it cannot be added to shelf
            if savedFilters.contains(savedFilter) {
                destination.savedFilter = savedFilter
            } else {
                destination.service = TraktAPIService.savedFilter(section: savedFilter.section,
                                                                  path: savedFilter.path,
                                                                  query: savedFilter.query,
                                                                  pageInfo: PageInfo.firstPage(with: 50))
            }
        }
    }

    deinit {
        if let request = request {
            request.cancel()
        }
    }
}

extension SearchViewController {
    func fetchUser(with id: String) {
        if SessionManager.shared.isLoggedOut {
            return
        }

        if let request = request {
            request.cancel()
        }
        request = TraktAPIProvider.provider.request(.user(id: id.slugify()), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    guard let indexPathForSelectedRows = self.tableView.indexPathsForSelectedRows else { return }
                    for indexPath in indexPathForSelectedRows {
                        self.tableView.deselectRow(at: indexPath, animated: true)
                    }
                }
            }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let user = try response.map(User.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "user", sender: CommentsCoordinator(type: CommentsCoordinator.ListType.user(user)))
                    }
                } catch {
                    DispatchQueue.main.async {
                        let alertController = UIAlertController(title: "Oooops",
                                                                message: nil,
                                                                preferredStyle: .alert)

                        let ok = UIAlertAction(title: "Okay", style: .cancel)
                        alertController.addAction(ok)

                        switch moyaResponse.statusCode {
                        case 404:
                            alertController.message = "A profile for @\(id) could not be found."
                        case 401:
                            alertController.message = "This profile is private.\nFollow this profile on trakt and you'll be able to see this profile once your follow request is accepted."
                        default:
                            alertController.message = "Sorry, an unexpected error occurred (\(moyaResponse.statusCode))."
                        }

                        self.present(alertController, animated: true)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Oooops",
                                                            message: nil,
                                                            preferredStyle: .alert)

                    let ok = UIAlertAction(title: "Okay", style: .cancel)
                    alertController.addAction(ok)

                    alertController.message = "Sorry, an unexpected error occurred (\(error))."

                    self.present(alertController, animated: true)
                }
            }
        }
    }
}

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = (searchController.searchBar.text ?? "").capitalized.trimmingCharacters(in: .whitespacesAndNewlines)
        if searchQuery.isEmpty {
            suggestions.removeAll()
        } else {
            if suggestions.isEmpty {
                fetchSuggestions()
            } else {
                DispatchQueue.main.asyncDeduped(target: self, after: 0.25) { [weak self] in
                    guard let self = self else { return }
                    self.fetchSuggestions()
                }
            }
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        tableView.scrollRectToVisible(CGRect(x: 0, y: 0,
                                             width: 1, height: 1), animated: true)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        if tableView.isEditing {
            editTableView(sender: editBarButtonItem)
        }

        tableView.scrollRectToVisible(CGRect(x: 0, y: 0,
                                             width: 1, height: 1), animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchQuery.isEmpty { return }

        let searchType: SearchType = .moviesAndShow
        let service: TraktAPIService = .search(type: searchType, query: searchQuery)

        searchController.searchBar.resignFirstResponder()
        saveRecentSearch(title: searchQuery,
                         query: searchQuery,
                         path: "/search/\(searchType.rawValue)")

        performSegue(withIdentifier: "results", sender: service)
    }
}
