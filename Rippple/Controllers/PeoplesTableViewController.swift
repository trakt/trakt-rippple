//
//  PeoplesTableViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 25/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class PeoplesTableViewController: UITableViewController {
    private enum PeopleFilter: String, CaseIterable {
        case all = "Cast & Crew"
        case cast = "Cast"
        case guest = "Guest Stars"
        case crew = "Crew"
    }

    private var currentFilter: PeopleFilter = .all {
        didSet {
            updateDatasource()
            updateTitle()
        }
    }

    private lazy var filterButtonItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: "line.3.horizontal.decrease"))
        item.menu = makeFilterMenu()
        return item
    }()

    private let disposeBag = DisposeBag()

    var media: MediaModel!

    private let searchController = UISearchController(searchResultsController: nil)
    private var searchQuery = ""

    private var people: People? {
        didSet {
            updateDatasource()
        }
    }

    private var filteredCast: [Cast] {
        if let people = people {
            return people.cast.filter { cast in
                if searchQuery.isEmpty { return true }
                if searchQuery == "" { return true }
                if let person = cast.person, person.name.localizedCaseInsensitiveContains(searchQuery) { return true }
                for character in cast.characters where character.localizedCaseInsensitiveContains(searchQuery) {
                    return true
                }
                return false
            }
        } else {
            return [Cast]()
        }
    }

    private var filteredCrew: [Job] {
        return allCrew.filter { crew in
            if searchQuery.isEmpty { return true }
            if searchQuery == "" { return true }
            if let person = crew.person, person.name.localizedCaseInsensitiveContains(searchQuery) { return true }
            for job in crew.jobs where job.localizedCaseInsensitiveContains(searchQuery) {
                return true
            }
            return false
        }
    }

    private var filteredGuestStars: [Cast] {
        if let people = people, let guestStars = people.guestStars, !guestStars.isEmpty {
            return guestStars.filter { cast in
                if searchQuery.isEmpty { return true }
                if searchQuery == "" { return true }
                if let person = cast.person, person.name.localizedCaseInsensitiveContains(searchQuery) { return true }
                for character in cast.characters where character.localizedCaseInsensitiveContains(searchQuery) {
                    return true
                }
                return false
            }
        } else {
            return [Cast]()
        }
    }

    private func updateDatasource() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])

        func appendCast() {
            guard !filteredCast.isEmpty else { return }
            snapshot.appendItems([.header("Cast", "\(filteredCast.count) member\(filteredCast.count > 1 ? "s" : "")")])
            for cast in filteredCast {
                snapshot.appendItems([.cast(cast)])
            }
        }

        func appendGuest() {
            guard !filteredGuestStars.isEmpty else { return }
            snapshot.appendItems([.header("Guest Stars", "\(filteredGuestStars.count) member\(filteredGuestStars.count > 1 ? "s" : "")")])
            for guest in filteredGuestStars {
                snapshot.appendItems([.guest(guest)])
            }
        }

        func appendCrew() {
            guard !filteredCrew.isEmpty else { return }
            snapshot.appendItems([.header("Crew", "\(filteredCrew.count) member\(filteredCrew.count > 1 ? "s" : "")")])
            for crew in filteredCrew {
                snapshot.appendItems([.crew(crew)])
            }
        }

        if searchQuery.isEmpty || searchQuery == "" {
            switch currentFilter {
            case .all:
                appendCast()
                appendCrew()
                appendGuest()
            case .cast:
                appendCast()
            case .guest:
                appendGuest()
            case .crew:
                appendCrew()
            }
        } else {
            appendCast()
            appendCrew()
            appendGuest()
        }

        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private var allCrew: [Job] {
        guard let people = people, let crew = people.crew else { return [Job]() }
        var jobs = [Job]()
        jobs += crew.createdBy ?? [Job]()
        jobs += crew.directing ?? [Job]()
        jobs += crew.writing ?? [Job]()
        jobs += crew.production ?? [Job]()
        jobs += crew.art ?? [Job]()
        jobs += crew.camera ?? [Job]()
        jobs += crew.visualEffects ?? [Job]()
        jobs += crew.sound ?? [Job]()
        jobs += crew.lighting ?? [Job]()
        jobs += crew.editing ?? [Job]()
        jobs += crew.crew ?? [Job]()
        return jobs
    }

    @IBOutlet var emptyView: UIView!

    @IBOutlet var errorView: UIView!

    private var cancellable: Cancellable?

    deinit {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    /// Empty
    private var showEmpty: Bool {
        return error != nil
    }

    /// Paging Management
    private var showLoading = true {
        didSet {
            updateTitle()
        }
    }

    /// Error Management
    private var error: Error?

    private enum Section: Int {
        case content
    }

    private enum Wrapper: Hashable {
        case cast(Cast)
        case guest(Cast)
        case crew(Job)
        case header(String, String)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .cast(let cast):
            let cell = tableView.dequeueReusableCell(withIdentifier: "people") as! PeopleTableViewCell
            cell.cast = cast
            return cell
        case .guest(let guest):
            let cell = tableView.dequeueReusableCell(withIdentifier: "people") as! PeopleTableViewCell
            cell.guest = guest
            return cell
        case .crew(let crew):
            let cell = tableView.dequeueReusableCell(withIdentifier: "people") as! PeopleTableViewCell
            cell.crew = crew
            return cell
        case .header(let title, let subtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = title
            cell.subtitle?.text = subtitle
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = media.mediaTitle
        navigationItem.subtitle = "Loading..."
        navigationItem.rightBarButtonItems = [filterButtonItem]

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "PeopleTableViewCell", bundle: nil), forCellReuseIdentifier: "people")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.separatorStyle = .none

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false

        searchController.searchBar.placeholder = "Search name, character, or job"
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        searchController.searchBar.delegate = self
        searchController.searchBar.barTintColor = nil
        searchController.searchBar.barStyle = .default
        searchController.searchBar.isTranslucent = true

        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = searchController

        fetchPeople()

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)
    }

    @objc func refresh(_ sender: Any) {
        fetchPeople()
    }

    @IBAction func retry(_ sender: Any) {
        showLoading = true
        error = nil
        tableView.reloadData()
        fetchPeople()
    }

    private func reset() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
        retry(self)
    }

    func fetchPeople() {
        switch media! {
        case .movie(let movie):
            cancellable = TraktAPIProvider.provider.request(TraktAPIService.peopleMovie(id: movie.identifiers.trakt!),
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                defer {
                    DispatchQueue.main.async {
                        self.refreshControl?.isEnabled = true
                        self.refreshControl?.endRefreshing()
                    }
                }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.showLoading = false
                            self.error = nil
                            self.people = people
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print("Failed fetching people \(error)")
                            self.error = error
                            self.showLoading = false
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("Failed fetching people \(error)")
                        self.error = error
                        self.showLoading = false
                        self.tableView.reloadData()
                    }
                }
            }
        case .show(let show):
            cancellable = TraktAPIProvider.provider.request(TraktAPIService.peopleShow(id: show.identifiers.trakt!, extended: .guestStars),
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                defer {
                    DispatchQueue.main.async {
                        self.refreshControl?.isEnabled = true
                        self.refreshControl?.endRefreshing()
                    }
                }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.showLoading = false
                            self.error = nil
                            self.people = people
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print("Error fetching people \(error)")
                            self.error = error
                            self.showLoading = false
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("Failed fetching people \(error)")
                        self.error = error
                        self.showLoading = false
                        self.tableView.reloadData()
                    }
                }
            }
        case .episode(let episode, let show):
            cancellable = TraktAPIProvider.provider.request(TraktAPIService.peopleEpisode(id: show.identifiers.trakt!, season: episode.season, episode: episode.number, extended: .guestStars),
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                defer {
                    DispatchQueue.main.async {
                        self.refreshControl?.isEnabled = true
                        self.refreshControl?.endRefreshing()
                    }
                }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.showLoading = false
                            self.error = nil
                            self.people = people
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print("Error fetching people \(error)")
                            self.error = error
                            self.showLoading = false
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("Failed fetching people \(error)")
                        self.error = error
                        self.showLoading = false
                        self.tableView.reloadData()
                    }
                }
            }
        case .season(let season, let show):
            cancellable = TraktAPIProvider.provider.request(TraktAPIService.peopleSeason(id: show.identifiers.trakt!, season: season.number, extended: .guestStars),
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }

                defer {
                    DispatchQueue.main.async {
                        self.refreshControl?.isEnabled = true
                        self.refreshControl?.endRefreshing()
                    }
                }

                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.showLoading = false
                            self.error = nil
                            self.people = people
                        }
                    } catch {
                        DispatchQueue.main.async {
                            print("Error fetching people \(error)")
                            self.error = error
                            self.showLoading = false
                            self.tableView.reloadData()
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("Failed fetching people \(error)")
                        self.error = error
                        self.showLoading = false
                        self.tableView.reloadData()
                    }
                }
            }
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    @IBSegueAction
    func makePeopleViewController(coder: NSCoder, sender: Any?) -> PeopleViewController? {
        PeopleViewController(coder: coder,
                             cast: sender as? Cast ?? nil,
                             job: sender as? Job ?? nil,
                             person: sender as? Person ?? nil)
    }
}

extension PeoplesTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .cast(let cast):
            performSegue(withIdentifier: "people", sender: cast)
        case .guest(let guest):
            performSegue(withIdentifier: "people", sender: guest)
        case .crew(let crew):
            performSegue(withIdentifier: "people", sender: crew)
        case .header:
            return
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            if cell.avatarImageView.image == nil { return nil }

            return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                              previewProvider: {
                                                  let mediaPreviewViewController = UIStoryboard(name: "PersonPreview",
                                                                                                bundle: nil).instantiateInitialViewController() as! PeoplePreviewViewController

                                                  switch item {
                                                  case .cast(let cast):
                                                      mediaPreviewViewController.person = cast.person
                                                  case .guest(let guest):
                                                      mediaPreviewViewController.person = guest.person
                                                  case .crew(let crew):
                                                      mediaPreviewViewController.person = crew.person
                                                  case .header:
                                                      fatalError()
                                                  }

                                                  mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                                                           height: 500 * 1.5)
                                                  return mediaPreviewViewController
                                              }, actionProvider: { _ -> UIMenu? in
                                                  return UIMenu(children: [])
                                              })
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .cast(let cast):
            performSegue(withIdentifier: "people", sender: cast)
        case .guest(let guest):
            performSegue(withIdentifier: "people", sender: guest)
        case .crew(let crew):
            performSegue(withIdentifier: "people", sender: crew)
        case .header:
            return
        }
    }
}

extension PeoplesTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        updateDatasource()
    }
}

extension PeoplesTableViewController: UISearchBarDelegate {}

private extension PeoplesTableViewController {
    func makeFilterMenu() -> UIMenu {
        let actions: [UIAction] = PeopleFilter.allCases.map { filter in
            UIAction(title: filter.rawValue, state: filter == currentFilter ? .on : .off) { [weak self] _ in
                self?.currentFilter = filter
                // Rebuild menu to reflect the new checkmark state
                self?.filterButtonItem.menu = self?.makeFilterMenu()
            }
        }
        return UIMenu(children: actions)
    }

    func updateTitle() {
        if showLoading {
            navigationItem.subtitle = "Loading..."
        } else {
            switch currentFilter {
            case .all:
                navigationItem.subtitle = "Cast & Crew"
            case .cast:
                navigationItem.subtitle = "Cast"
            case .crew:
                navigationItem.subtitle = "Crew"
            case .guest:
                navigationItem.subtitle = "Guest Stars"
            }
        }
    }
}
