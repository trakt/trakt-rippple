//
//  ToWatchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2019.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class ToWatchViewController: UIViewController {
    private enum ViewControllerSegue: String {
        case results
    }

    @IBOutlet var moviesContainerView: UIView!
    @IBOutlet var episodesContainerView: UIView!

    private let disposeBag = DisposeBag()

    private let searchController = UISearchController(searchResultsController: nil)

    enum ToWatchType: Int {
        case movies
        case episodes
    }

    var currentType = ToWatchType.movies {
        didSet {
            UserDefaults.standard.set(currentType.rawValue, forKey: "ToWatchViewController.currentType")
            UserDefaults.standard.synchronize()

            navigationItem.style = .browser
            navigationItem.title = "To Watch"

            if isViewLoaded {
                switch currentType {
                case .movies:
                    navigationItem.subtitle = "Movies"
                    moviesContainerView.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(moviesContainerView)
                    episodesContainerView.removeFromSuperview()
                    NSLayoutConstraint.activate([
                        moviesContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        moviesContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        moviesContainerView.topAnchor.constraint(equalTo: view.topAnchor),
                        moviesContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                case .episodes:
                    navigationItem.subtitle = "Episodes"
                    episodesContainerView.translatesAutoresizingMaskIntoConstraints = false
                    view.addSubview(episodesContainerView)
                    moviesContainerView.removeFromSuperview()
                    NSLayoutConstraint.activate([
                        episodesContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                        episodesContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                        episodesContainerView.topAnchor.constraint(equalTo: view.topAnchor),
                        episodesContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
                    ])
                }
                navigationController?.view.setNeedsLayout()

                updateBarButtonItems()
                updateSearchTarget()
            }
        }
    }

    private var switchBarButtonItem = UIBarButtonItem()

    override func viewDidLoad() {
        super.viewDidLoad()

        if let type = ToWatchType(rawValue: UserDefaults.standard.integer(forKey: "ToWatchViewController.currentType")) {
            currentType = type
        }

        updateBarButtonItems()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        definesPresentationContext = true
        updateSearchTarget()

        onMovieToWatchStatusChangedReceiver.listen { [weak self] status in
            guard let self = self else { return }
            if currentType == .episodes { return }
            DispatchQueue.main.async {
                switch status {
                case .loading:
                    // self.loadingView.alpha = 1.0
                    self.navigationItem.subtitle = "Checking for new Movies..."
                case .content:
                    self.navigationItem.subtitle = "Movies"
                }
            }
        }.disposed(by: disposeBag)

        onEpisodeToWatchStatusChangedReceiver.listen { [weak self] status in
            guard let self = self else { return }
            if currentType == .movies { return }
            DispatchQueue.main.async {
                switch status {
                case .loading:
                    // self.loadingView.alpha = 1.0
                    self.navigationItem.subtitle = "Checking for new Episodes..."
                case .content:
                    self.navigationItem.subtitle = "Episodes"
                }
            }
        }.disposed(by: disposeBag)
    }

    private func updateBarButtonItems() {
        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "slider.horizontal.3"),
                                                              primaryAction: UIAction { _ in
                                                                  switch self.currentType {
                                                                  case .movies:
                                                                      self.performSegue(withIdentifier: "movies settings", sender: self)
                                                                  case .episodes:
                                                                      self.performSegue(withIdentifier: "episodes settings", sender: self)
                                                                  }
                                                              }),
                                              .fixedSpace(),
                                              UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease"),
                                                              primaryAction: UIAction { _ in
                                                                  switch self.currentType {
                                                                  case .movies:
                                                                      self.currentType = .episodes
                                                                  case .episodes:
                                                                      self.currentType = .movies
                                                                  }

                                                              })]
    }

    private func updateSearchTarget() {
        guard isViewLoaded else { return }

        searchController.searchBar.placeholder = "Quick Search"

        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let moviesSearchController = children.first(where: { $0 is MoviesToWatchViewController }) as? ToWatchSearchable
        let episodesSearchController = children.first(where: { $0 is EpisodesToWatchViewController }) as? ToWatchSearchable
        moviesSearchController?.updateSearchQuery(currentType == .movies ? query : "")
        episodesSearchController?.updateSearchQuery(currentType == .episodes ? query : "")
    }

    private var activeSearchController: ToWatchSearchable? {
        switch currentType {
        case .movies:
            return children.first(where: { $0 is MoviesToWatchViewController }) as? ToWatchSearchable
        case .episodes:
            return children.first(where: { $0 is EpisodesToWatchViewController }) as? ToWatchSearchable
        }
    }

    func continueSearch(for query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return }

        searchController.searchBar.resignFirstResponder()
        performSegue(withIdentifier: ViewControllerSegue.results.rawValue, sender: query)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == ViewControllerSegue.results.rawValue,
              let searchResultsViewController = segue.destination as? SearchResultsViewController,
              let query = sender as? String else { return }

        searchResultsViewController.title = query.capitalized
        searchResultsViewController.service = TraktAPIService.search(type: .moviesAndShow, query: query)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, do not show a left bar button item.
        navigationItem.leftBarButtonItem = nil
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
        }
        #endif

        if navigationController?.viewControllers.first != self {
            navigationItem.leftBarButtonItem = nil
        }
    }
}

extension ToWatchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        activeSearchController?.updateSearchQuery(query)
    }
}

protocol ToWatchSearchable: AnyObject {
    func updateSearchQuery(_ query: String)
}
