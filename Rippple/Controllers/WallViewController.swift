//
//  WallViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 25/11/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit
import Receiver

final class WallViewController: StyledNavigationController {

    private let disposeBag = DisposeBag()

    // The SavedFilter used to configure the embedded GridViewController.
    // If not provided, a default will be used and persisted.
    var savedFilter: SavedFilter? {
        didSet {
            guard let savedFilter = savedFilter else { return }
            apply(filter: savedFilter)
        }
    }

    private var gridViewController: GridViewController? {
        viewControllers.first as? GridViewController
    }

    private var likedLists: [List]?
    private var traktSavedFilters: [SavedFilter]?

    override func viewDidLoad() {
        super.viewDidLoad()

        savedFilter = loadPersistedFilter() ?? Self.defaultSavedFilter

        onLikedListsChangedReceiver.listen { [weak self] likedLists in
            guard let self = self else { return }
            self.likedLists = likedLists
        }.disposed(by: disposeBag)

        onSavedFiltersChangedReceiver.listen { [weak self] savedFilters in
            guard let self = self else { return }
            self.traktSavedFilters = savedFilters
        }.disposed(by: disposeBag)
    }

    func filterMenu() -> UIMenu {
        // Quick picks inspired by ShelfConfigView
        let watchlist = SavedFilter(section: "watchlist",
                                    name: "Watchlist",
                                    path: "/sync/watchlist",
                                    query: "",
                                    limit: 250)
        let favorites = SavedFilter(section: "favorites",
                                    name: "Favorites",
                                    path: "/sync/favorites",
                                    query: "",
                                    limit: 250)
        let watchedMovies = SavedFilter(section: "WatchedItem",
                                        name: "Watched Movies",
                                        path: "/users/me/watched/movies",
                                        query: "",
                                        limit: nil)
        let watchedShows = SavedFilter(section: "WatchedItem",
                                       name: "Watched TV Shows",
                                       path: "/users/me/watched/shows",
                                       query: "",
                                       limit: nil)
        let collectedMovies = SavedFilter(section: "movies",
                                          name: "Movie Library",
                                          path: "/users/me/collection/movies",
                                          query: "",
                                          limit: nil)
        let collectedShows = SavedFilter(section: "shows",
                                         name: "TV Show Library",
                                         path: "/users/me/collection/shows",
                                         query: "",
                                         limit: nil)

        func action(for filter: SavedFilter) -> UIAction {
            let current = (filter == savedFilter)
            return UIAction(title: filter.name,
                            state: current ? .on : .off) { [weak self] _ in
                self?.savedFilter = filter
            }
        }

        // Quick picks
        let quickPicks = UIMenu(options: .displayInline,
                                children: [
                                    action(for: watchlist),
                                    action(for: favorites),
                                    action(for: collectedMovies),
                                    action(for: collectedShows),
                                    action(for: watchedMovies),
                                    action(for: watchedShows)
                                ])

        // Deferred sections built similarly to ShelfConfigView
        // Saved Filters on Trakt.tv
        let savedFiltersDeferred = UIDeferredMenuElement.uncached { completion in
            guard let savedFilters = self.traktSavedFilters else {
                completion([UIAction(title: "No Saved Filters", attributes: [.disabled], handler: { _ in })])
                return
            }
            let elements = savedFilters.map { action(for: $0) }
            if elements.isEmpty {
                completion([UIAction(title: "No Saved Filters", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let savedFiltersMenu = UIMenu(title: "Saved Filters", children: [savedFiltersDeferred])

        // TV Shows Smart Searches
        let showsSmartDeferred = UIDeferredMenuElement.uncached { completion in
            let shows = SmartSearch.smartSearches(for: .show)
            let elements = shows.map { action(for: $0.savedFilter) }
            if elements.isEmpty {
                completion([UIAction(title: "No TV Shows Smart Searches", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let showsSmartMenu = UIMenu(title: "TV Smart Searches", children: [showsSmartDeferred])

        // Movies Smart Searches
        let moviesSmartDeferred = UIDeferredMenuElement.uncached { completion in
            let movies = SmartSearch.smartSearches(for: .movie)
            let elements = movies.map { action(for: $0.savedFilter) }
            if elements.isEmpty {
                completion([UIAction(title: "No Movies Smart Searches", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let moviesSmartMenu = UIMenu(title: "Movies Smart Searches", children: [moviesSmartDeferred])

        // Your Lists
        let yourListsDeferred = UIDeferredMenuElement.uncached { completion in
            let lists = ListsManager.shared.lists
            let elements = lists.map { action(for: $0.savedFilter) }
            if elements.isEmpty {
                completion([UIAction(title: "No Lists", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let yourListsMenu = UIMenu(title: "Custom Lists", children: [yourListsDeferred])

        // Liked Lists
        let likedListsDeferred = UIDeferredMenuElement.uncached { completion in
            guard let likedLists = self.likedLists else {
                completion([UIAction(title: "No Liked Lists", attributes: [.disabled], handler: { _ in })])
                return
            }
            let elements = likedLists.map { action(for: $0.savedFilter) }
            if elements.isEmpty {
                completion([UIAction(title: "No Liked Lists", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let likedListsMenu = UIMenu(title: "Liked Lists", children: [likedListsDeferred])

        // Collaborations
        let collaborationsDeferred = UIDeferredMenuElement.uncached { completion in
            let collaborations = CollaborationsManager.shared.collaborations
            let elements = collaborations.map { action(for: $0.savedFilter) }
            if elements.isEmpty {
                completion([UIAction(title: "No Collaborations", attributes: [.disabled], handler: { _ in })])
            } else {
                completion(elements)
            }
        }
        let collaborationsMenu = UIMenu(title: "Collaborations", children: [collaborationsDeferred])

        return UIMenu(children: [quickPicks, savedFiltersMenu, showsSmartMenu, moviesSmartMenu, yourListsMenu, likedListsMenu, collaborationsMenu])
    }

    private var profileButton: UIButton {
        let button = ProfileButton()
        let profileAction = UIAction(handler: { [weak self] _ in
            guard let self = self else { return }
            let profileViewController = UIStoryboard(name: "Profile", bundle: nil).instantiateInitialViewController()!
            self.present(profileViewController, animated: true)
            UISelectionFeedbackGenerator().selectionChanged()
        })
        button.addAction(profileAction, for: .touchUpInside)
        return button
    }

    private func apply(filter: SavedFilter) {
        if let gridViewController = gridViewController {
            gridViewController.savedFilter = filter
            gridViewController.reloadData()
        } else {
            guard let gridViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(withIdentifier: "GridViewController") as? GridViewController else { return }
            gridViewController.savedFilter = filter
            setViewControllers([gridViewController], animated: false)

            #if targetEnvironment(macCatalyst)
            // On Mac Catalyst, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                // On iPad, do not show a left bar button item.
                navigationItem.leftBarButtonItem = nil
            } else {
                gridViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
            }
            #endif
        }
        persist(filter: filter)
    }

    // MARK: - Persistence & Defaults

    private func persist(filter: SavedFilter) {
        if let data = try? PropertyListEncoder().encode(filter) {
            UserDefaults.standard.set(data, forKey: "WallViewController.savedFilter")
            UserDefaults.standard.synchronize()
        }
    }

    private func loadPersistedFilter() -> SavedFilter? {
        guard let data = UserDefaults.standard.data(forKey: "WallViewController.savedFilter"),
              let filter = try? PropertyListDecoder().decode(SavedFilter.self, from: data) else {
            return nil
        }
        return filter
    }

    private static var defaultSavedFilter: SavedFilter {
        return SavedFilter(section: "watchlist",
                           name: "Watchlist",
                           path: "/sync/watchlist",
                           query: "",
                           limit: 250)
    }
}
