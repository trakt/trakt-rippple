//
//  PeopleViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Receiver

import SafariServices

final class PeopleViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    private var searchController = UISearchController(searchResultsController: PeopleChronologyTableViewController())

    private struct Jobs {
        let title: String
        let isRecentlyWatched: Bool
        let crew: [Job]?
        let cast: [Cast]?
        let knownFor: [MediaItem]?
    }

    private let cast: Cast?
    private let job: Job?

    private var socials = 0

    // fetched for full info
    private var person: Person? {
        didSet {
            socials = 0
            socials += (person?.ids.trakt != nil ? 1 : 0)
            socials += (person?.ids.tmdb != nil ? 1 : 0)
            socials += (person?.ids.imdb != nil ? 1 : 0)
            socials += (person?.homepage != nil ? 1 : 0)
            socials += (person?.socialIds?.twitter != nil ? 1 : 0)
            socials += (person?.socialIds?.instagram != nil ? 1 : 0)
            socials += (person?.socialIds?.facebook != nil ? 1 : 0)
            socials += (person?.socialIds?.wikipedia != nil ? 1 : 0)

            fetchMovies()
            fetchShows()
            fetchKnownFor()
        }
    }

    private var movies: People? {
        didSet {
            isFinished()
        }
    }

    private var shows: People? {
        didSet {
            isFinished()
        }
    }

    private var knownFor: [MediaItem]? {
        didSet {
            isFinished()
        }
    }

    private func isFinished() {
        if shows != nil, movies != nil, knownFor != nil {
            buildPeopleView()
            isLoading = false
            configureFloatingButton()
        }
    }

    private var allJobs = [Jobs]()

    private var isLoading = true {
        didSet {
            if isLoading {
                navigationItem.subtitle = "Loading..."
            } else {
                var count = 0
                count += movies?.allMovies.count ?? 0
                count += shows?.allShows.count ?? 0
                navigationItem.subtitle = "\(count) Known Credits"
            }
            if isLoading == false,
                let person = person,
                let birthday = person.birthday,
                person.death == nil {
                let components1 = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                let components2 = Calendar.current.dateComponents([.year, .month, .day], from: birthday)

                if components1.month == components2.month, components1.day == components2.day {
                    AppManager.shared.emitConfetti()
                }
            }
            refreshControl?.endRefreshing()
            tableView.reloadData()
        }
    }

    private var error: Error? {
        didSet {
            if let error = error {
                navigationItem.subtitle = "Error!"
                errorLabel.text = error.localizedDescription
            }
            tableView.reloadData()
        }
    }

    @IBOutlet var loadingView: UIView!
    @IBOutlet var animationViewContainer: UIView!

    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!

    private func buildPeopleView() {
        guard let shows = shows, let movies = movies else { return }

        allJobs.append(Jobs(title: "Actor in Movies",
                            isRecentlyWatched: false,
                            crew: nil,
                            cast: movies.cast,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Actor in TV shows", isRecentlyWatched: false, crew: nil, cast: shows.cast.filter { ($0.episodeCount ?? 0) != 0 }.sorted { $0.episodeCount ?? 0 > $1.episodeCount ?? 0 },
                            knownFor: nil))

        allJobs.append(Jobs(title: "Creator for Movies", isRecentlyWatched: false, crew: movies.crew?.createdBy, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Creator for TV shows", isRecentlyWatched: false, crew: shows.crew?.createdBy, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Director for Movies", isRecentlyWatched: false, crew: movies.crew?.directing, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Director for TV shows", isRecentlyWatched: false, crew: shows.crew?.directing, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Writing for Movies", isRecentlyWatched: false, crew: movies.crew?.writing, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Writing for TV shows", isRecentlyWatched: false, crew: shows.crew?.writing, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Producer for Movies", isRecentlyWatched: false, crew: movies.crew?.production, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Producer for TV shows", isRecentlyWatched: false, crew: shows.crew?.production, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Art for Movies", isRecentlyWatched: false, crew: movies.crew?.art, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Art for TV shows", isRecentlyWatched: false, crew: shows.crew?.art, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Camera for Movies", isRecentlyWatched: false, crew: movies.crew?.camera, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Camera for TV shows", isRecentlyWatched: false, crew: shows.crew?.camera, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Costume & Make-up for Movies", isRecentlyWatched: false, crew: movies.crew?.costumeAndMakeUp, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Costume & Make-up for TV shows", isRecentlyWatched: false, crew: shows.crew?.costumeAndMakeUp, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Sound for Movies", isRecentlyWatched: false, crew: movies.crew?.sound, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Sound for TV shows", isRecentlyWatched: false, crew: shows.crew?.sound, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Visual Effects for Movies", isRecentlyWatched: false, crew: movies.crew?.visualEffects, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Visual Effects for TV shows", isRecentlyWatched: false, crew: shows.crew?.visualEffects, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Lighting for Movies", isRecentlyWatched: false, crew: movies.crew?.lighting, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Lighting for TV shows", isRecentlyWatched: false, crew: shows.crew?.lighting, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Editing for Movies", isRecentlyWatched: false, crew: movies.crew?.editing, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Editing for TV shows", isRecentlyWatched: false, crew: shows.crew?.editing, cast: nil,
                            knownFor: nil))

        allJobs.append(Jobs(title: "Crew for Movies", isRecentlyWatched: false, crew: movies.crew?.crew, cast: nil,
                            knownFor: nil))
        allJobs.append(Jobs(title: "Crew for TV shows",
                            isRecentlyWatched: false,
                            crew: shows.crew?.crew,
                            cast: nil,
                            knownFor: nil))

        allJobs = allJobs.filter { $0.crew?.isEmpty == false || $0.cast?.isEmpty == false }

        allJobs.sort { ($0.cast != nil ? $0.cast!.count : $0.crew!.count) > ($1.cast != nil ? $1.cast!.count : $1.crew!.count) }

        let inHistory = (movies.cast + shows.cast).filter { $0.isRencentlyWatched }.sorted { $0.recentlyWatchedAt ?? Date.distantPast > $1.recentlyWatchedAt ?? Date.distantPast }
        if !inHistory.isEmpty {
            allJobs.insert(Jobs(title: "From your History",
                                isRecentlyWatched: true,
                                crew: nil,
                                cast: inHistory,
                                knownFor: nil), at: 0)
        }
        if knownFor?.isEmpty == false {
            allJobs.insert(Jobs(title: "Known For",
                                isRecentlyWatched: false,
                                crew: nil,
                                cast: nil,
                                knownFor: knownFor), at: 0)
        }

        if let controller = searchController.searchResultsController as? PeopleChronologyTableViewController {
            controller.displayingViewController = self
            controller.inMovies = movies
            controller.inShows = shows
        }
    }

    init?(coder: NSCoder, cast: Cast?, job: Job?, person: Person?) {
        self.cast = cast
        self.job = job
        self.person = person

        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureFloatingButton() {
        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: buildActionsMenu())]
    }

    private func buildActionsMenu() -> UIMenu {
        let share = UIAction(title: "Share",
                             image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
            guard let self = self else { return }
            guard let sharedURL = URL(string: "https://trakt.tv/people/\(person!.ids.slugOrTraktId)") else { return }
            let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
            UIApplication.shared.present(activityViewController)
        }

        let privateNotes = UIAction(title: person!.noteItem == nil ? "Add Private Notes" : "Update Private Notes", image: UIImage(systemName: "note.text")) { [weak self] _ in
            guard let self = self else { return }
            if let notes = person!.noteItem {
                NotesManager.shared.showNotes(for: notes)
            } else {
                NotesManager.shared.showNotes(for: person!)
            }
        }
        return UIMenu(children: [UIMenu(options: .displayInline, children: [privateNotes]), UIMenu(options: .displayInline, children: [share])])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."

        searchController.searchResultsUpdater = self
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.showsSearchResultsController = true

        searchController.searchBar.placeholder = "Search title, role or character name"
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        searchController.searchBar.delegate = self
        searchController.searchBar.barTintColor = nil
        searchController.searchBar.barStyle = .default
        searchController.searchBar.isTranslucent = true

        navigationItem.hidesSearchBarWhenScrolling = true
        navigationItem.searchController = searchController

        tableView.allowsFocus = false
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "PeopleTableViewCell", bundle: nil), forCellReuseIdentifier: "people")
        tableView.register(UINib(nibName: "PeopleBioTableViewCell", bundle: nil), forCellReuseIdentifier: "bio")
        tableView.register(UINib(nibName: "PeopleInfoTableViewCell", bundle: nil), forCellReuseIdentifier: "info")
        tableView.register(UINib(nibName: "PeopleMediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "LinkTableViewCell", bundle: nil), forCellReuseIdentifier: "link")
        tableView.register(UINib(nibName: "PrivateNotesTableViewCell", bundle: nil), forCellReuseIdentifier: "notes")
        tableView.register(UINib(nibName: "SpacerTableViewCell", bundle: nil), forCellReuseIdentifier: "spacer")

        if let cast = cast {
            title = cast.person!.name
        } else if let job = job {
            title = job.person!.name
        } else if let person = person {
            title = person.name
        }

        fetchPerson()

        #if !targetEnvironment(macCatalyst)
        self.refreshControl = UIRefreshControl()
        #endif
        self.refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        onNotesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.isFinished()
        }.disposed(by: disposeBag)

        errorView.removeFromSuperview()
        loadingView.removeFromSuperview()
    }

    @objc func refresh(_ sender: Any) {
        fetchPerson()
    }

    @IBAction func retry(_ sender: Any) {
        isLoading = true
        error = nil
        fetchPerson()
    }

    private var identifier: Int64 {
        if let cast = cast {
            return cast.person!.ids.trakt!
        } else if let job = job {
            return job.person!.ids.trakt!
        } else if let person = person {
            return person.ids.trakt!
        }
        fatalError()
    }

    private func fetchPerson() {
        TraktAPIProvider.provider.request(TraktAPIService.people(id: identifier),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }

                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let person = try response.map(Person.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.person = person
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        print("Failed fetching full person \(error)")
                                                        self.error = error
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    print("Failed fetching full person \(error)")
                                                    self.error = error
                                                }
                                            }
        }
    }

    private func fetchKnownFor() {
        TraktAPIProvider.provider.request(.knownFor(id: identifier),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let knownFor = try response.map([MediaItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.knownFor = knownFor
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Failed fetching known for for person \(error)")
                        self.error = error
                    }
                }
            case let .failure(error):
                DispatchQueue.main.async {
                    print("Failed fetching known for for person \(error)")
                    self.error = error
                }
            }
        }
    }

    private func fetchMovies() {
        TraktAPIProvider.provider.request(TraktAPIService.peopleMovies(id: person!.ids.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }

                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.movies = people
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        print("Failed fetching movies for person \(error)")
                                                        self.error = error
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    print("Failed fetching movies for person \(error)")
                                                    self.error = error
                                                }
                                            }
        }
    }

    private func fetchShows() {
        TraktAPIProvider.provider.request(TraktAPIService.peopleShows(id: person!.ids.trakt!),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }

                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.shows = people
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        print("Failed fetching shows for person \(error)")
                                                        self.error = error
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    print("Failed fetching shows for person \(error)")
                                                    self.error = error
                                                }
                                            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController {
            if let movie = sender as? Movie {
                mediaViewController.media = movie.mediaModel
            }
            if let show = sender as? Show {
                mediaViewController.media = show.mediaModel
            }
            if let media = sender as? MediaModel {
                mediaViewController.media = media
            }
        }

        if let chronology = segue.destination as? PeopleChronologyTableViewController {
            if let filtered = sender as? [MediaModel] {
                chronology.filteredMedia = filtered
            }
            chronology.inMovies = movies
            chronology.inShows = shows
            chronology.navigationItem.style = .browser
            chronology.navigationItem.title = navigationItem.title
            chronology.navigationItem.subtitle = navigationItem.subtitle
        }
    }
}

extension PeopleViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        if isLoading { return 1 }
        return 4 + allJobs.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 1 {
            if person?.noteItem == nil { return 1 }
            return 2
        }
        if section == allJobs.count + 2 {
            return socials + 2
        }
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "people") as! PeopleTableViewCell

            if let person = person {
                cell.person = person
            } else if let cast = cast {
                cell.person = cast.person
            } else if let job = job {
                cell.person = job.person
            }

            return cell
        } else if indexPath.section == 1 {
            if indexPath.item == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: "info") as! PeopleInfoTableViewCell

                if let person = person {
                    cell.person = person
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "notes") as! PrivateNotesTableViewCell

                if let person = person {
                    cell.person = person
                }

                return cell
            }
        } else if indexPath.section < 2 + allJobs.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! PeopleMediaTableViewCell

            let job = allJobs[indexPath.section - 2]

            cell.isRecentlyWatched = job.isRecentlyWatched
            cell.title.text = job.title
            cell.casts = job.cast
            cell.crews = job.crew
            cell.knownFor = job.knownFor
            cell.delegate = self
            cell.moreButton.isHidden = job.isRecentlyWatched == true || job.knownFor != nil ? false : true

            return cell
        } else if indexPath.section == 2 + allJobs.count {
            let cell = tableView.dequeueReusableCell(withIdentifier: "link") as! LinkTableViewCell

            var index = 0
            if index == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as! SpacerTableViewCell
                cell.space = 5
                return cell
            }
            index += 1
            if person?.ids.trakt != nil {
                if index == indexPath.row {
                    cell.title.text = "Open on Trakt"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.ids.tmdb != nil {
                if index == indexPath.row {
                    cell.title.text = "Open on TMDb"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.ids.imdb != nil {
                if index == indexPath.row {
                    cell.title.text = "Open on IMDb"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.homepage != nil {
                if index == indexPath.row {
                    cell.title.text = "Open Official Website"
                    cell.linkImage.image = UIImage(systemName: "network")
                }
                index += 1
            }
            if person?.socialIds?.twitter != nil {
                if index == indexPath.row {
                    cell.title.text = "X"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.socialIds?.instagram != nil {
                if index == indexPath.row {
                    cell.title.text = "Instagram"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.socialIds?.facebook != nil {
                if index == indexPath.row {
                    cell.title.text = "Facebook"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if person?.socialIds?.wikipedia != nil {
                if index == indexPath.row {
                    cell.title.text = "Wikipedia"
                    cell.linkImage.image = UIImage(systemName: "link")
                }
                index += 1
            }
            if index == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as! SpacerTableViewCell
                cell.space = 5
                return cell
            }

            if socials == 1 {
                cell.cardType = .alone
            } else if indexPath.row == 1 {
                cell.cardType = .top
            } else if indexPath.row == socials {
                cell.cardType = .bottom
            } else {
                cell.cardType = .middle
            }

            cell.delegate = self
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "bio") as! PeopleBioTableViewCell

            if let person = person {
                cell.person = person
            }

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section >= 2 && indexPath.section < 2 + allJobs.count {
            let job = allJobs[indexPath.section - 2]

            if let knownFor = job.knownFor {
                performSegue(withIdentifier: "chronology", sender: knownFor.map { MediaModel(item: $0) })
            }
            if job.isRecentlyWatched {
                let inHistory = (movies!.cast + shows!.cast).filter { $0.isRencentlyWatched }
                performSegue(withIdentifier: "chronology", sender: inHistory.compactMap { $0.movie?.mediaModel ?? $0.show?.mediaModel })
            }
        }

        if indexPath.section == 1, indexPath.item == 1, let noteItem = person?.noteItem {
            NotesManager.shared.showNotes(for: noteItem)
        }

        if indexPath.section == 2 + allJobs.count {
            var index = 1
            if let url = person?.traktURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.tmdbURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.imdbURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.homepageURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.twitterURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.instagramURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.facebookURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
            if let url = person?.wikipediaURL {
                if index == indexPath.row {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        present(SFSafariViewController(url: url), animated: true, completion: nil)
                    }
                }
                index += 1
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section >= 2 && indexPath.section < 2 + allJobs.count {
            return 200 + 30
        }

        if indexPath.section == 1,
           indexPath.item == 0,
            let person = person,
            person.birthday == nil,
            person.birthplace == nil,
            person.death == nil {
            return 0
        }

        if indexPath.section == 3 + allJobs.count,
            let person = person,
            person.biography?.isEmpty == true {
            return 0
        }

        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if section != 0 { return nil }
        if error != nil {
            return errorView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section != 0 { return 0 }
        if error != nil {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            guard let person = cell.person else { return nil }
            if cell.avatarImageView.image == nil { return nil }

            return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                              previewProvider: {
                let mediaPreviewViewController = UIStoryboard(name: "PersonPreview", bundle: nil).instantiateInitialViewController() as! PeoplePreviewViewController

                mediaPreviewViewController.person = person
                mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                         height: 500 * 1.5)
                return mediaPreviewViewController
            }, actionProvider: { _ -> UIMenu? in
                let menu = UIMenu(children: [])
                return menu
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
}

extension PeopleViewController: PeopleMediaTableViewCellDelegate {
    func cell(_ cell: PeopleMediaTableViewCell, action: PeopleMediaTableViewCell.Action) {
        switch action {
        case .showCast(let cast):
            performSegue(withIdentifier: "media", sender: cast.movie != nil ? cast.movie! : cast.show!)
        case .showCrew(let job):
            performSegue(withIdentifier: "media", sender: job.movie != nil ? job.movie! : job.show!)
        case .showMedia(let mediaItem):
            performSegue(withIdentifier: "media", sender: mediaItem.movie != nil ? mediaItem.movie! : mediaItem.show!)
        }
    }
}

extension PeopleViewController: LinkTableViewCellDelegate {
    func cell(_ cell: LinkTableViewCell, action: LinkTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        var theUrl: URL!
        var index = 1
        if let url = person?.traktURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.tmdbURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.imdbURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.homepageURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.twitterURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.instagramURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.facebookURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        if let url = person?.wikipediaURL {
            if index == indexPath.row {
                theUrl = url
            }
            index += 1
        }
        let alertController = UIAlertController(title: "What do you want to do?",
                                                message: theUrl.absoluteString,
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Do nothing", style: .cancel))

        alertController.addAction(UIAlertAction(title: "Share the link", style: .default, handler: { _ in
            UIApplication.shared.present(UIActivityViewController(activityItems: [theUrl!],
                                                                  applicationActivities: nil))
        }))

        alertController.addAction(UIAlertAction(title: "Open in Safari", style: .default, handler: { _ in
            UIApplication.shared.open(theUrl)
        }))

        alertController.addAction(UIAlertAction(title: "Open in app", style: .default, handler: { _ in
            self.present(SFSafariViewController(url: theUrl), animated: true, completion: nil)
        }))

        present(alertController, animated: true)
    }
}

extension Person {
    var traktURL: URL? {
        guard let info = ids.trakt else { return nil }
        return URL(string: "https://trakt.tv/people/\(info)")
    }

    var tmdbURL: URL? {
        guard let info = ids.tmdb else { return nil }
        return URL(string: "https://www.themoviedb.org/person/\(info)")
    }

    var imdbURL: URL? {
        guard let info = ids.imdb else { return nil }
        return URL(string: "https://www.imdb.com/name/\(info)")
    }

    var twitterURL: URL? {
        guard let info = socialIds?.twitter else { return nil }
        return URL(string: "https://x.com/\(info)")
    }

    var instagramURL: URL? {
        guard let info = socialIds?.instagram else { return nil }
        return URL(string: "https://www.instagram.com/\(info)")
    }

    var facebookURL: URL? {
        guard let info = socialIds?.facebook else { return nil }
        return URL(string: "https://www.facebook.com/\(info)")
    }

    var wikipediaURL: URL? {
        guard let info = socialIds?.wikipedia else { return nil }
        return URL(string: "https://wikipedia.org/wiki/\(info)")
    }

    var homepageURL: URL? {
        guard let info = homepage else { return nil }
        return URL(string: info)
    }
}

extension PeopleViewController: UISearchResultsUpdating {

    func updateSearchResults(for searchController: UISearchController) {
        let searchQuery = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let controller = searchController.searchResultsController as? PeopleChronologyTableViewController {
            controller.searchQuery = searchQuery
        }
    }
}

extension PeopleViewController: UISearchBarDelegate {

}
