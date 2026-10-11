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
    private let contextMenu = ContextMenuHelper()

    /// request
    private var request: Cancellable?

    var isDeeplink = false
    var searchQuery: String = "" {
        didSet {
            updateDatasource()
        }
    }

    private var isExplicitUserSearch: Bool {
        return searchQuery.hasPrefix("@")
    }

    private var userSearchQuery: String {
        guard isExplicitUserSearch else { return searchQuery }

        return String(searchQuery.dropFirst())
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
    }

    private var canSearchUser: Bool {
        return isExplicitUserSearch || NSPredicate(format: "SELF MATCHES %@", "^[A-Za-z0-9]+([-.!_]{1}[A-Za-z0-9]+)*").evaluate(with: userSearchQuery.lowercased())
    }

    private var shouldOpenKeyboard = false

    private enum Section: Int {
        case recents
        case trending
        case suggestions
        case search
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
        case search(CellConfig, TraktAPIService)
        case suggestion(CellConfig, TraktSearchResult)
        case user(CellConfig)
        case recents
        case smartSearches
        case status(String, retry: Bool)

        static func == (lhs: SearchViewController.Wrapper, rhs: SearchViewController.Wrapper) -> Bool {
            switch (lhs, rhs) {
            case (.search(let lhsConfig, _), .search(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.suggestion(let lhsConfig, _), .suggestion(let rhsConfig, _)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.user(let lhsConfig), .user(let rhsConfig)):
                return lhsConfig.identifier == rhsConfig.identifier
            case (.recents, .recents), (.smartSearches, .smartSearches):
                return true
            case (.status(let lhsTitle, let lhsRetry), .status(let rhsTitle, let rhsRetry)):
                return lhsTitle == rhsTitle && lhsRetry == rhsRetry
            default:
                return false
            }
        }

        func hash(into hasher: inout Hasher) {
            switch self {
            case .search(let config, _):
                hasher.combine(config.identifier)
            case .suggestion(let config, _):
                hasher.combine(config.identifier)
            case .user(let config):
                hasher.combine(config.identifier)
            case .recents:
                hasher.combine("recents")
            case .smartSearches:
                hasher.combine("smartSearches")
            case .status(let title, let retry):
                hasher.combine(title)
                hasher.combine(retry)
            }
        }
    }

    private func cardType<Item: Equatable>(for object: Item, in collection: [Item]) -> CardType {
        if collection.count == 1 { return .alone }
        if collection.first == object { return .top }
        if collection.last == object { return .bottom }
        return .middle
    }

    private func recentSearchPath(for service: TraktAPIService?) -> String {
        if let service = service,
           case .search(let type, _) = service {
            return "/search/\(type.rawValue)"
        }

        return "/search/\(SearchType.moviesAndShow.rawValue)"
    }

    private func recentSearchPath(for item: TraktSearchResult) -> String {
        return "/search/\(item.type.rawValue)"
    }

    private func suggestionItems(_ items: [TraktSearchResult], query: String? = nil) -> [Wrapper] {
        items.map { item in
            .suggestion(CellConfig(identifier: "\(item.key):\(query ?? "")",
                                   cardType: cardType(for: item, in: items),
                                   title: item.title,
                                   subtitle: " · \(item.subtitle)",
                                   query: query,
                                   segue: "details"), item)
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

    private func recentSearchQuery(for recentSearch: RecentSearch) -> String {
        let query = recentSearch.searchFieldQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if recentSearch.name.hasPrefix("@"), query.hasPrefix("@") == false {
            return "@\(query)"
        }
        return query
    }

    private func recentSearchType(for recentSearch: RecentSearch) -> SearchType {
        switch recentSearch.path {
        case "/search/\(SearchType.movie.rawValue)":
            return .movie
        case "/search/\(SearchType.show.rawValue)":
            return .show
        case "/search/\(SearchType.person.rawValue)":
            return .person
        case "/search/\(SearchType.list.rawValue)":
            return .list
        default:
            return .moviesAndShow
        }
    }

    private func applyRecentSearch(_ recentSearch: RecentSearch) {
        let query = recentSearchQuery(for: recentSearch)
        guard query.isEmpty == false else { return }

        searchController.searchBar.resignFirstResponder()
        RecentSearchManager.shared.recentSearches.insert(recentSearch, at: 0)

        if recentSearch.name.hasPrefix("@") {
            fetchUser(with: String(query.dropFirst()).lowercased())
            return
        }

        let searchType = recentSearchType(for: recentSearch)
        let service = TraktAPIService.search(type: searchType, query: query)
        switch searchType {
        case .person:
            performSegue(withIdentifier: "people", sender: service)
        case .list:
            performSegue(withIdentifier: "lists", sender: service)
        case .movie, .show, .moviesAndShow:
            performSegue(withIdentifier: "results", sender: service)
        }
    }

    private func updateDatasource() {
        if searchQuery.isEmpty {
            navigationItem.subtitle = "Trending searches"
        } else if isExplicitUserSearch {
            navigationItem.subtitle = nil
        } else {
            navigationItem.subtitle = isSearching ? "Loading..." : "\(suggestions.count) top result\(suggestions.count == 1 ? "" : "s")"
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()

        if searchQuery.isEmpty == false {
            snapshot.appendSections([.search])
            if isExplicitUserSearch {
                snapshot.appendItems([.user(CellConfig(identifier: "Go to user @\(userSearchQuery.lowercased())",
                                                       cardType: .alone,
                                                       title: "Go to user @\(userSearchQuery.lowercased())",
                                                       subtitle: nil,
                                                       query: userSearchQuery,
                                                       segue: ""))])

                dataSource.apply(snapshot, animatingDifferences: false)
                return
            }

            snapshot.appendItems([.search(CellConfig(identifier: "Movies with \"\(searchQuery)\"",
                                                     cardType: .top,
                                                     title: "Movies with \"\(searchQuery)\"",
                                                     subtitle: nil,
                                                     query: searchQuery,
                                                     segue: "results"), .search(type: .movie, query: searchQuery))])

            snapshot.appendItems([.search(CellConfig(identifier: "TV Shows with \"\(searchQuery)\"",
                                                     cardType: .middle,
                                                     title: "TV Shows with \"\(searchQuery)\"",
                                                     subtitle: nil,
                                                     query: searchQuery,
                                                     segue: "results"), .search(type: .show, query: searchQuery))])
            snapshot.appendItems([.search(CellConfig(identifier: "People with \"\(searchQuery)\"",
                                                     cardType: .middle,
                                                     title: "People with \"\(searchQuery)\"",
                                                     subtitle: nil,
                                                     query: searchQuery,
                                                     segue: "people"), .search(type: .person, query: searchQuery))])

            if canSearchUser {
                snapshot.appendItems([.search(CellConfig(identifier: "Lists with \"\(searchQuery)\"",
                                                         cardType: .middle,
                                                         title: "Lists with \"\(searchQuery)\"",
                                                         subtitle: nil,
                                                         query: searchQuery,
                                                         segue: "lists"), .search(type: .list, query: searchQuery))])

                snapshot.appendItems([.user(CellConfig(identifier: "Go to user @\(userSearchQuery.lowercased())",
                                                       cardType: .bottom,
                                                       title: "Go to user @\(userSearchQuery.lowercased())",
                                                       subtitle: nil,
                                                       query: userSearchQuery,
                                                       segue: ""))])
            } else {
                snapshot.appendItems([.search(CellConfig(identifier: "Lists with \"\(searchQuery)\"",
                                                         cardType: .bottom,
                                                         title: "Lists with \"\(searchQuery)\"",
                                                         subtitle: nil,
                                                         query: searchQuery,
                                                         segue: "lists"), .search(type: .list, query: searchQuery))])
            }

            snapshot.appendSections([.suggestions])
            if isSearching == false, suggestions.isEmpty || searchFailed {
                let message = searchFailed ? "Couldn’t load results. Tap to retry." : "No matches. Try another title."
                snapshot.appendItems([.status(message, retry: searchFailed)])
            }
            snapshot.appendItems(suggestionItems(suggestions.filter { $0.media != nil }, query: suggestionsQuery))

            dataSource.apply(snapshot, animatingDifferences: false)
            return
        }

        snapshot.appendSections([.recents])
        if RecentSearchManager.shared.recentSearches.isEmpty == false {
            snapshot.appendItems([.recents])
        }
        snapshot.appendItems([.smartSearches])
        if dataSource.snapshot().itemIdentifiers.contains(.smartSearches) {
            snapshot.reconfigureItems([.smartSearches])
        }
        snapshot.appendSections([.trending])
        snapshot.appendItems(suggestionItems(trending))
        let existingItems = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter {
            if case .suggestion = $0 { return existingItems.contains($0) }
            return false
        })

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private final class SearchDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            switch itemIdentifier(for: indexPath) {
            case .recents:
                return true
            case .suggestion(_, let result):
                return result.media != nil
            default:
                return false
            }
        }
    }

    private lazy var dataSource = SearchDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }
        switch item {
        case .recents, .smartSearches:
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell
            cell.shouldShowActivityIndicator = false
            cell.card.alpha = 1
            cell.chevron.alpha = 1
            if item == .recents {
                cell.card.cardType = .top
                cell.setup(with: "Recent Searches")
            } else {
                cell.card.cardType = RecentSearchManager.shared.recentSearches.isEmpty ? .alone : .bottom
                cell.setup(with: "Smart Searches")
            }
            return cell
        case .status(let title, let retry):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "status") else { return nil }
            var content = cell.defaultContentConfiguration()
            content.text = title
            content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.textProperties.color = retry ? .tintColor : .secondaryLabel
            content.textProperties.numberOfLines = 0
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .clear()
            cell.selectionStyle = retry ? .default : .none
            cell.accessibilityTraits = retry ? .button : .staticText
            return cell
        case .search(let config, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell

            cell.shouldShowActivityIndicator = false

            cell.card.alpha = 1.0
            cell.chevron.alpha = 1.0

            cell.card.cardType = config.cardType
            cell.setup(with: config.title, and: config.subtitle, searchQuery: config.query)

            return cell
        case .suggestion(let config, let result):
            if let media = result.media {
                let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! MediaTableViewCell
                cell.dimmedIfWatched = false
                cell.media = media
                cell.delegate = self
                return cell
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: "search") as! SearchTableViewCell
            cell.shouldShowActivityIndicator = false
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
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsFocus = false
        tableView.allowsFocusDuringEditing = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.keyboardDismissMode = .interactive
        tableView.register(UINib(nibName: "SearchTableViewCell", bundle: nil), forCellReuseIdentifier: "search")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "status")
        tableView.sectionHeaderTopPadding = 0
        tableView.sectionHeaderHeight = .leastNonzeroMagnitude
        tableView.sectionFooterHeight = .leastNonzeroMagnitude
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0

        tableView.separatorStyle = .none

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false

        searchController.searchBar.placeholder = "Movie, Show, People, List & User"
        searchController.searchBar.delegate = self

        tableView.dataSource = dataSource

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.style = .browser

        trending = TrendingSearchManager.shared.results
        onTrendingSearchChangedReceiver.listen { [weak self] results in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.trending = results
            }
        }.disposed(by: disposeBag)

        onRecentSearchChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.updateDatasource()
            }
        }.disposed(by: disposeBag)

        updateDatasource()
    }

    private var trending = [TraktSearchResult]() {
        didSet { updateDatasource() }
    }

    private var suggestions = [TraktSearchResult]()
    private var suggestionsQuery = ""

    private var suggestionRequest: Cancellable?
    private var suggestionWorkItem: DispatchWorkItem?
    private var isSearching = false
    private var searchFailed = false

    @objc private func fetchSuggestions() {
        let query = searchQuery
        guard query.isEmpty == false, isExplicitUserSearch == false else { return }
        suggestionRequest?.cancel()
        isSearching = true
        searchFailed = false
        updateDatasource()
        suggestionRequest = TraktAPIProvider.search(query: query, includeLocal: true, onUpdate: { [weak self] results in
            guard let self = self, self.searchQuery == query else { return }
            self.showSuggestions(results, query: query)
        }) { [weak self] result in
            guard let self = self, self.searchQuery == query else { return }
            self.isSearching = false
            switch result {
            case .success(let results):
                self.showSuggestions(results, query: query)
            case .failure:
                self.searchFailed = true
                self.updateDatasource()
            }
        }
    }

    private func showSuggestions(_ results: [TraktSearchResult], query: String) {
        suggestions = Array(results.filter { $0.media != nil }.prefix(50))
        suggestionsQuery = query
        updateDatasource()
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
            if suggestions.isEmpty { fetchSuggestions() }
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
                self.focusSearchField()
            }
        }
    }

    func focusSearchField() {
        searchController.searchBar.searchTextField.becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if let request = request {
            request.cancel()
        }
        request = nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? .leastNonzeroMagnitude : 12
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return section == 0 ? nil : UIView()
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else { return nil }
        contextMenu.cell = cell
        contextMenu.controller = self

        return UIContextMenuConfiguration(identifier: nil, previewProvider: { [weak self] in
            guard let self = self else { return nil }
            return self.contextMenu.previewViewController
        }, actionProvider: { [weak self] _ in
            guard let self = self else { return nil }
            return self.contextMenu.menu
        })
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        if let cell = contextMenu.cell as? MediaTableViewCell,
           let indexPath = tableView.indexPath(for: cell),
           case .suggestion(let config, let result) = dataSource.itemIdentifier(for: indexPath) {
            recordSelection(result, query: config.query ?? "")
        }
        navigationController?.show(controller, sender: self)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        if case .suggestion(_, let result) = item {
            return result.media?.trailingSwipeActions(for: self)
        }
        guard item == .recents else { return nil }
        let clear = UIContextualAction(style: .destructive, title: "Clear All") { _, _, completion in
            completion(true)
            RecentSearchManager.shared.removeAll()
            UISelectionFeedbackGenerator().selectionChanged()
        }
        clear.image = UIImage(systemName: "trash.circle.fill")
        let configuration = UISwipeActionsConfiguration(actions: [clear])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .suggestion(_, let result) = dataSource.itemIdentifier(for: indexPath) else { return nil }
        return result.media?.leadingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .search(let config, let service):
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(config: config, service: service)
            performSegue(withIdentifier: config.segue, sender: service)
        case .user(let config):
            let username = (config.query ?? userSearchQuery).lowercased()
            guard username.isEmpty == false else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            searchController.searchBar.resignFirstResponder()
            saveRecentSearch(title: "@\(username)", query: username)
            fetchUser(with: username)
            return // don't deselectRow to show loading indicator
        case .suggestion(let config, let result):
            openSuggestion(result, query: config.query ?? "")
        case .status(_, let retry):
            if retry { fetchSuggestions() }
        case .smartSearches:
            searchController.searchBar.resignFirstResponder()
            navigationController?.show(SmartSearchViewController(style: .grouped), sender: self)
        case .recents:
            searchController.searchBar.resignFirstResponder()
            let controller = RecentSearchViewController(style: .grouped)
            controller.onSelect = { [weak self] recent in
                guard let self = self else { return }
                self.applyRecentSearch(recent)
            }
            navigationController?.show(controller, sender: self)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    private func recordSelection(_ result: TraktSearchResult, query: String) {
        searchController.searchBar.resignFirstResponder()
        TraktAPIProvider.recordSearchSelection(query: query, type: result.type, id: result.id)
        saveRecentSearch(title: result.title, query: result.title, path: recentSearchPath(for: result))
    }

    private func openSuggestion(_ result: TraktSearchResult, query: String) {
        recordSelection(result, query: query)
        if let media = result.media {
            performSegue(withIdentifier: "details", sender: media)
        } else if let person = result.person {
            let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "PeopleViewController") { coder in
                PeopleViewController(coder: coder, cast: nil, job: nil, person: person)
            }
            navigationController?.show(controller, sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "user" {
            if let commentsViewController = segue.destination as? CommentsViewController,
               let coordinator = sender as? CommentsCoordinator {
                commentsViewController.coordinator = coordinator
            }

            return
        }

        if segue.identifier == "details",
           let destination = segue.destination as? MediaViewController,
           let media = sender as? MediaModel {
            destination.media = media
            return
        }

        if let service = sender as? TraktAPIService {
            let serviceQuery: String?
            if case .search(_, let query) = service {
                serviceQuery = query
            } else {
                serviceQuery = nil
            }

            if let destination = segue.destination as? SearchResultsViewController {
                destination.title = serviceQuery?.capitalized ?? searchQuery.capitalized
                destination.service = service
            } else if let destination = segue.destination as? PeopleSearchResultsViewController {
                destination.title = serviceQuery?.capitalized ?? searchQuery.capitalized
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
                    destination.title = serviceQuery ?? searchQuery
                }
                destination.service = service
            }
        }
    }

    deinit {
        suggestionWorkItem?.cancel()
        suggestionRequest?.cancel()
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
        request = TraktAPIProvider.fetchUser(with: id, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
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
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != searchQuery else { return }
        suggestionWorkItem?.cancel()
        suggestionRequest?.cancel()
        isSearching = query.isEmpty == false && query.hasPrefix("@") == false
        searchFailed = false
        suggestions = []
        suggestionsQuery = query
        searchQuery = query
        guard isSearching else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.searchQuery == query else { return }
            self.fetchSuggestions()
        }
        suggestionWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        tableView.scrollRectToVisible(CGRect(x: 0, y: 0,
                                             width: 1, height: 1), animated: true)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        tableView.scrollRectToVisible(CGRect(x: 0, y: 0,
                                             width: 1, height: 1), animated: true)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchQuery.isEmpty { return }
        if isExplicitUserSearch {
            searchController.searchBar.resignFirstResponder()
            guard userSearchQuery.isEmpty == false else { return }
            saveRecentSearch(title: "@\(userSearchQuery)", query: userSearchQuery)
            fetchUser(with: userSearchQuery.lowercased())
            return
        }

        let searchType: SearchType = .moviesAndShow
        let service: TraktAPIService = .search(type: searchType, query: searchQuery)

        searchController.searchBar.resignFirstResponder()
        saveRecentSearch(title: searchQuery,
                         query: searchQuery,
                         path: "/search/\(searchType.rawValue)")

        performSegue(withIdentifier: "results", sender: service)
    }
}

extension SearchViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard action == .details,
              let indexPath = tableView.indexPath(for: cell),
              case .suggestion(let config, let result) = dataSource.itemIdentifier(for: indexPath) else { return }
        openSuggestion(result, query: config.query ?? "")
    }
}
