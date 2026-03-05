//
//  DeeplinkLoadingViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import Moya

final class DeeplinkLoadingViewController: UIViewController, UINavigationControllerDelegate {

    enum DeeplinkError: Error {
        case parsingError(error: Error)
        case fetchingError(error: Error)
        case unsupportedLinkError
        case deeplinkNotFoundError
    }

    @IBOutlet weak var loadingLabel: UILabel!

    private var migrationLoadingTimer: Timer?

    private var migrationLoadingMessages = [
        "Snapping data into place...",
        "Crossing multiverses...",
        "Entering the next phase...",
        "Loading the sequel...",
        "Rewriting the canon...",
        "Refactoring reality...",
        "Balancing the Force...",
        "Consulting the Jedi Council...",
        "Adjusting the Matrix...",
        "Following the white rabbit...",
        "Executing Order 66... just kidding.",
        "No data was harmed...",
        "Restoring the Sacred Timeline..."
    ]

    private var migrationLoadingMessageQueue: [String] = []

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            let type = sender as! CommentsCoordinator.ListType
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }

        if let mediaViewController = segue.destination as? MediaViewController {
            let media = sender as! MediaModel
            mediaViewController.media = media
            mediaViewController.isDeeplink = true
        }

        if let seasonsViewController = segue.destination as? SeasonsViewController {
            let media = sender as! MediaModel
            seasonsViewController.show = media.show!
            seasonsViewController.season = media.season
        }

        if let browseViewController = segue.destination as? BrowseViewController,
           segue.identifier == "browse this week" {
            browseViewController.model = BrowseConfigManager.shared.newAndHot
        }

        if let searchViewController = segue.destination as? SearchViewController,
           let query = sender as? String {
            searchViewController.searchQuery = query
            searchViewController.isDeeplink = true
        }
    }

    @IBSegueAction
    func makePeopleViewController(coder: NSCoder, sender: Any?) -> PeopleViewController? {
        PeopleViewController(coder: coder,
                             cast: sender as? Cast ?? nil,
                             job: sender as? Job ?? nil,
                             person: sender as? Person ?? nil)
    }

    @IBSegueAction
    func makeListViewController(coder: NSCoder, sender: Any?) -> ListViewController? {
        guard let list = sender as? List else { return nil }
        return ListViewController(coder: coder,
                                  list: list,
                                  user: list.user)
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        navigationController?.delegate = self

        guard let deeplink = DeeplinkManager.shared.handleDeeplink() else {
            backToMainApp(withError: .deeplinkNotFoundError)
            return
        }

        process(deeplink: deeplink)
    }

    private func process(deeplink: DeeplinkType) {
        switch deeplink {
        case .show(let id):
            loadingLabel.text = "Looking for show..."
            TraktAPIProvider.provider.request(TraktAPIService.show(id: id, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let show = try response.map(Show.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "media", sender: show.mediaModel)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .season(let showId, let seasonNumber):
            loadingLabel.text = "Looking for season..."
            TraktAPIProvider.provider.request(TraktAPIService.show(id: showId, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let show = try response.map(Show.self, using: TraktAPIProvider.decoder)

                        TraktAPIProvider.provider.request(TraktAPIService.seasons(id: show.identifiers.trakt!),
                                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                    let seasons = try response.map([Season].self, using: TraktAPIProvider.decoder)

                                    for season in seasons where season.number == seasonNumber {
                                        DispatchQueue.main.async {
                                            self.performSegue(withIdentifier: "media",
                                                              sender: season.mediaModel(given: show))
                                        }
                                        return
                                    }

                                    DispatchQueue.main.async {
                                        if let season = seasons.first {
                                            self.performSegue(withIdentifier: "media",
                                                              sender: season.mediaModel(given: show))
                                        } else {
                                            self.performSegue(withIdentifier: "media",
                                                              sender: show.mediaModel)
                                        }
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        self.backToMainApp(withError: .parsingError(error: error))
                                    }
                                }
                            case let .failure(error):
                                DispatchQueue.main.async {
                                    self.backToMainApp(withError: .fetchingError(error: error))
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .episode(let showId, let season, let episode):
            loadingLabel.text = "Looking for episode..."
            TraktAPIProvider.provider.request(TraktAPIService.show(id: showId, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let show = try response.map(Show.self, using: TraktAPIProvider.decoder)

                        TraktAPIProvider.provider.request(TraktAPIService.episode(id: showId, season: season, episode: episode),
                                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                    let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                                    DispatchQueue.main.async {
                                        self.performSegue(withIdentifier: "media",
                                                          sender: episode.mediaModel(given: show))
                                    }
                                } catch {
                                    DispatchQueue.main.async {
                                        self.backToMainApp(withError: .parsingError(error: error))
                                    }
                                }
                            case let .failure(error):
                                DispatchQueue.main.async {
                                    self.backToMainApp(withError: .fetchingError(error: error))
                                }
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .movie(let id):
            loadingLabel.text = "Looking for movie..."
            TraktAPIProvider.provider.request(TraktAPIService.movie(id: id, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let movie = try response.map(Movie.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "media",
                                              sender: movie.mediaModel)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .comment(let id):
            openComment(with: id)
            return
        case .user(let id):
            loadingLabel.text = "Looking for user..."
            TraktAPIProvider.provider.request(TraktAPIService.user(id: id.slugify()),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let user = try response.map(User.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "deeplink",
                                              sender: CommentsCoordinator.ListType.user(user))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .people(let slug):
            loadingLabel.text = "Looking for people..."
            TraktAPIProvider.provider.request(TraktAPIService.peopleSlug(slug: slug),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let person = try response.map(Person.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "people",
                                              sender: person)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .notificationsSettings:
            performSegue(withIdentifier: "notifications", sender: nil)
        case .whereToWatchSettings:
            performSegue(withIdentifier: "wheretowatch", sender: nil)
        case .appIconSettings:
            performSegue(withIdentifier: "appicon", sender: nil)
        case .whatsNew:
            performSegue(withIdentifier: "what's new", sender: nil)
        case .tmdbShow(let tmdbShowId):
            loadingLabel.text = "Looking for show..."
            TraktAPIProvider.provider.request(.lookup(tmdbID: tmdbShowId, type: .show),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        guard let show = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).first(where: { $0.show != nil })?.show else {
                            DispatchQueue.main.async {
                                self.backToMainApp(withError: DeeplinkError.deeplinkNotFoundError)
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "media", sender: show.mediaModel)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .tmdbSeason(let tmdbShowId, let season):
            loadingLabel.text = "Looking for season..."
            TraktAPIProvider.provider.request(.lookup(tmdbID: tmdbShowId, type: .show),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        guard let show = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).first(where: { $0.show != nil })?.show else {
                            DispatchQueue.main.async {
                                self.backToMainApp(withError: DeeplinkError.deeplinkNotFoundError)
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            self.process(deeplink: DeeplinkType.season(showId: "\(show.identifiers.trakt!)", season: season))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .tmdbEpisode(let tmdbShowId, let season, let episode):
            loadingLabel.text = "Looking for episode..."
            TraktAPIProvider.provider.request(.lookup(tmdbID: tmdbShowId, type: .show),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        guard let show = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).first(where: { $0.show != nil })?.show else {
                            DispatchQueue.main.async {
                                self.backToMainApp(withError: DeeplinkError.deeplinkNotFoundError)
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            self.process(deeplink: DeeplinkType.episode(showId: "\(show.identifiers.trakt!)", season: season, episode: episode))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .tmdbPeople(let peopleId):
            loadingLabel.text = "Looking for people..."
            TraktAPIProvider.provider.request(.lookup(tmdbID: peopleId, type: .person),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let person = try response.map([PersonItem].self, using: TraktAPIProvider.decoder).first?.person

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "people",
                                              sender: person)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .tmdbMovie(let id):
            loadingLabel.text = "Looking for movie..."
            TraktAPIProvider.provider.request(.lookup(tmdbID: id, type: .movie),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        guard let movie = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).first(where: { $0.movie != nil })?.movie else {
                            DispatchQueue.main.async {
                                self.backToMainApp(withError: DeeplinkError.deeplinkNotFoundError)
                            }
                            return
                        }

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "media",
                                              sender: movie.mediaModel)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .browseThisWeek:
            performSegue(withIdentifier: "browse this week", sender: nil)
        case .toWatchMovies:
            performSegue(withIdentifier: "toWatchMovies", sender: nil)
        case .toWatchEpisodes:
            performSegue(withIdentifier: "toWatchEpisodes", sender: nil)
        case .history:
            performSegue(withIdentifier: "history", sender: nil)
        case .calendar:
            performSegue(withIdentifier: "calendar", sender: nil)
        case .search(let query):
            performSegue(withIdentifier: "search", sender: query)
        case .list(let userSlug, let listSlug):
            loadingLabel.text = "Looking for list..."
            TraktAPIProvider.provider.request(.customList(userSlug: userSlug, listSlug: listSlug),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                guard let self = self else { return }
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let list = try response.map(List.self, using: TraktAPIProvider.decoder)

                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "list", sender: list)
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.backToMainApp(withError: .parsingError(error: error))
                        }
                    }
                case let .failure(error):
                    DispatchQueue.main.async {
                        self.backToMainApp(withError: .fetchingError(error: error))
                    }
                }
            }
            return
        case .migrate(let components):
            startMigrationLoadingTimer()
            handleMigrationDeeplink(components: components)

            UserDefaults.standard.synchronize()
            NSUbiquitousKeyValueStore.default.synchronize()

            DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                guard let self = self else { return }
                self.stopMigrationLoadingTimer()
                self.dismiss(animated: true) {
                    if let url = URL(string: "rippple://") {
                        if UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        } else {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        exit(0)
                    }
                }
            }
            return
        }
    }

    private func nextMigrationLoadingMessage() -> String {
        if migrationLoadingMessageQueue.isEmpty {
            migrationLoadingMessageQueue = migrationLoadingMessages.shuffled()
        }
        return migrationLoadingMessageQueue.removeFirst()
    }

    private func startMigrationLoadingTimer() {
        stopMigrationLoadingTimer()
        migrationLoadingMessageQueue = migrationLoadingMessages.shuffled()
        loadingLabel.text = nextMigrationLoadingMessage()

        migrationLoadingTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.loadingLabel.text = self.nextMigrationLoadingMessage()
        }
    }

    private func stopMigrationLoadingTimer() {
        migrationLoadingTimer?.invalidate()
        migrationLoadingTimer = nil
    }

    private func backToMainApp(withError error: DeeplinkError) {

        let alertController = UIAlertController(title: "Oooops",
                                                message: nil,
                                                preferredStyle: .alert)

        let ok = UIAlertAction(title: "Okay", style: .cancel) { _ in
            self.dismiss(animated: true, completion: nil)
        }
        alertController.addAction(ok)

        switch error {
        case .parsingError(let error), .fetchingError(let error):
            print("Deeplink underlying error: \(error)")
            title = "Error"
            alertController.message = "An error occurred while loading your content. Please try again later. If the problem persists, please contact us (@ripppleapp) with a way to reproduce the issue."
        case .unsupportedLinkError:
            alertController.message = "Sorry, this type of link is not supported by Rippple."
        case .deeplinkNotFoundError:
            alertController.message = "Sorry, something impossible happened when trying to open something in Rippple."
        }

        present(alertController, animated: true)
    }

    private func openComment(with id: Int64) {
        loadingLabel.text = "Opening comment..."
        TraktAPIProvider.provider.request(TraktAPIService.commentMediaItem(id: id),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let mediaItem = try response.map(MediaItem.self, using: TraktAPIProvider.decoder)

                                                    let mediaModel = MediaModel(item: mediaItem)
                                                    switch mediaModel {
                                                    case .list:
                                                        DispatchQueue.main.async {
                                                            self.backToMainApp(withError: .unsupportedLinkError)
                                                        }
                                                    default:
                                                        break
                                                    }

                                                    DispatchQueue.main.async {
                                                        self.openComment(with: id, mediaModel: mediaModel)
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        self.backToMainApp(withError: .parsingError(error: error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    self.backToMainApp(withError: .fetchingError(error: error))
                                                }
                                            }
        }
    }

    private func openComment(with id: Int64, mediaModel: MediaModel) {
        TraktAPIProvider.provider.request(TraktAPIService.comment(id: id),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let comment = try response.map(Comment.self, using: TraktAPIProvider.decoder)

                                                    if comment.parentIdentifier != 0 {
                                                        self.openComment(with: comment.parentIdentifier,
                                                                               mediaModel: mediaModel)
                                                        return
                                                    }

                                                    let commentModel = CommentModel(media: mediaModel,
                                                                                    comment: comment,
                                                                                    spoilerStrategy: SpoilerStrategy.showAllSpoilers)

                                                    DispatchQueue.main.async {
                                                        self.performSegue(withIdentifier: "deeplink",
                                                                                sender: CommentsCoordinator.ListType.replies(commentModel, false))
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        self.backToMainApp(withError: .parsingError(error: error))
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    self.backToMainApp(withError: .fetchingError(error: error))
                                                }
                                            }
        }
    }

    func navigationController(_ navigationController: UINavigationController,
                              willShow viewController: UIViewController,
                              animated: Bool) {
        if navigationController.viewControllers.first == self && viewController != self {
            navigationController.isNavigationBarHidden = false
            navigationController.setViewControllers([viewController], animated: false)
            let buttonItem = UIBarButtonItem(systemItem: .close,
                                             primaryAction: UIAction(handler: { _ in
                viewController.dismiss(animated: true, completion: nil)
            }))
            buttonItem.style = .plain
            viewController.navigationItem.leftBarButtonItems = [buttonItem]
        }
    }

    private func handleMigrationDeeplink(components: URLComponents) {
        guard let queryItems = components.queryItems else {
            print("[Migration Deeplink] No query items found")
            return
        }

        // Define allowed UserDefaults keys
        let allUserDefaultsKeys: Set<String> = ["ActivityViewController.currentFilter",
                                                "Badge.mode",
                                                "BrowseConfigManager.currentConfig",
                                                "CalendarSettings.addAnticipatedMovies",
                                                "CalendarSettings.addAnticipatedShows",
                                                "CalendarSettings.addTrendingMovies",
                                                "CalendarSettings.addTrendingShows",
                                                "CalendarSettings.filtersShowToWatch",
                                                "CalendarSettings.hideHiddenMovies",
                                                "CalendarSettings.hideHiddenShows",
                                                "CalendarSettings.myMovies",
                                                "CalendarSettings.myShows",
                                                "CollectionViewController.currentFilter",
                                                "CollectionViewController.currentSorting",
                                                "CommentsCoordinator.sort",
                                                "CountryManager.userCountry",
                                                "CustomListsViewController.customList",
                                                "CustomListsViewController.displayList",
                                                "CustomListsViewController.standardList",
                                                "EpisodeNotificationsManager.groupEpisodes",
                                                "EpisodeNotificationsManager.toWatchEpisodeRelease",
                                                "EpisodeNotificationsManager.toWatchSeasonPremiere",
                                                "EpisodeNotificationsManager.toWatchShowPremiere",
                                                "EpisodeNotificationsManager.watchlistEpisodeRelease",
                                                "EpisodeNotificationsManager.watchlistSeasonPremiere",
                                                "EpisodeNotificationsManager.watchlistShowPremiere",
                                                "EpisodeToWatchSettings.allWatched",
                                                "EpisodeToWatchSettings.collected",
                                                "EpisodeToWatchSettings.likedLists",
                                                "EpisodeToWatchSettings.lists",
                                                "EpisodeToWatchSettings.otherLists",
                                                "EpisodeToWatchSettings.recommended",
                                                "EpisodeToWatchSettings.reverse",
                                                "EpisodeToWatchSettings.smartSearches",
                                                "EpisodeToWatchSettings.sort",
                                                "EpisodeToWatchSettings.upcoming",
                                                "EpisodeToWatchSettings.watched",
                                                "EpisodeToWatchSettings.watchlist",
                                                "ForYouViewController.currentFilter",
                                                "GeneralSettings.addtowatchlistautolistsync",
                                                "GeneralSettings.addtowatchlistautowatchedsync",
                                                "GeneralSettings.comments",
                                                "GeneralSettings.commentscount",
                                                "GeneralSettings.detailepisodetitle",
                                                "GeneralSettings.dragging",
                                                "GeneralSettings.droppedshows",
                                                "GeneralSettings.listsepisodetitle",
                                                "GeneralSettings.towatchepisodetitle",
                                                "GeneralSettings.watchlistaddback",
                                                "GridViewController.edgeToEdgeLayout",
                                                "GridViewController.itemsPerRow",
                                                "LibrarySideBarExpanded",
                                                "LikedListsSideBarExpanded",
                                                "ListsSideBarExpanded",
                                                "MainTabBarController.selectedTab",
                                                "MainTabBarController.tab.positions",
                                                "ManualRemoteNotificationsManager.appUpdate",
                                                "ManualRemoteNotificationsManager.blogPost",
                                                "MovieNotificationsManager.toWatchMovieRelease",
                                                "MovieNotificationsManager.watchlistMovieRelease",
                                                "MovieToWatchSettings.collected",
                                                "MovieToWatchSettings.likedLists",
                                                "MovieToWatchSettings.lists",
                                                "MovieToWatchSettings.otherLists",
                                                "MovieToWatchSettings.recommended",
                                                "MovieToWatchSettings.reverse",
                                                "MovieToWatchSettings.smartSearches",
                                                "MovieToWatchSettings.sort",
                                                "MovieToWatchSettings.upcoming",
                                                "MovieToWatchSettings.watchlist",
                                                "RecommendedNotificationsManager.recommendedMovies",
                                                "RecommendedNotificationsManager.recommendedShows",
                                                "RecommendedViewController.currentFilter",
                                                "RecommendedViewController.currentSorting",
                                                "SeasonsRatingsViewController.currentFilter",
                                                "SidebarViewController.selectedIndex.row",
                                                "SidebarViewController.selectedIndex.section",
                                                "Swipe.ToWatch.default",
                                                "Swipe.ToWatch.secondary",
                                                "ToWatchViewController.currentType",
                                                "TrendingNotificationsManager.trendingMovies",
                                                "TrendingNotificationsManager.trendingShows",
                                                "UpcomingLabelManager.labelStyle",
                                                "WallViewController.savedFilter",
                                                "WatchlistViewController.currentFilter",
                                                "WatchlistViewController.currentSorting",
                                                "WatchedViewController.currentFilter",
                                                "WatchedViewController.currentSorting",
                                                "DVDMovieNotificationsManager.toWatchMovieRelease",
                                                "ActivityNotificationsManager.activityNewFollower",
                                                "ActivityNotificationsManager.commentNewMention",
                                                "ActivityNotificationsManager.commentNewReply",
                                                "ActivityNotificationsManager.commentNewLikes",
                                                "AnticipatedNotificationsManager.anticipatedShows",
                                                "AnticipatedNotificationsManager.anticipatedMovies",
                                                "CountryManager.displayInLists",
                                                "Stinger.alert.type",
                                                "AppManager.currentUserInterfaceStyle",
                                                "AppManager.currentTint"]

        let ubiquitousKeys: Set<String> = ["ShelfManager.shelf",
                                           "EpisodeToWatchManager.pinnedShows",
                                           "MovieToWatchManager.pinnedMovies",
                                           "SmartSearch.movies",
                                           "SmartSearch.shows",
                                           "RecentSearchManager.recentSearches",
                                           "CommentDraftManager.drafts"]

        // Combine all allowed keys
        let allowedKeys = allUserDefaultsKeys.union(ubiquitousKeys)

        print("[Migration Deeplink] Processing \(queryItems.count) key-value pairs")

        for queryItem in queryItems {
            let key = queryItem.name
            let isUbiquitousKey = ubiquitousKeys.contains(key)

            // Validate key is in allowed set (or is a dynamic ListViewController key)
            let isDynamicListViewControllerKey = key.hasPrefix("ListViewController.") &&
                                                 (key.contains(".currentFilter") || key.contains(".currentSorting"))

            guard isDynamicListViewControllerKey || allowedKeys.contains(key) else {
                print("[Migration Deeplink] Skipping unknown key: \(key)")
                continue
            }

            guard let valueString = queryItem.value else {
                print("[Migration Deeplink] \(key): <nil>")
                continue
            }

            // Handle dynamic ListViewController keys (currentFilter/currentSorting)
            if isDynamicListViewControllerKey {
                handleListViewControllerKey(key: key, valueString: valueString)
                continue
            }

            // AppManager.currentTint: store in app group and apply via UIApplication
            if key == "AppManager.currentTint", let rawValue = Int(valueString),
               let tint = RipppleTintColor(rawValue: rawValue) {
                UserDefaults(suiteName: "group.tv.trakt.rippple")?.set(rawValue, forKey: key)
                DispatchQueue.main.async {
                    UIApplication.shared.setTintColor(tint: tint)
                }
                print("[Migration Deeplink] \(key): \(tint.name) (RipppleTintColor), applied via setTintColor")
                continue
            }

            // Try to detect if this is a base64-encoded Data object
            if let data = Data(base64Encoded: valueString) {
                print("[Migration Deeplink] \(key): <Data> (base64 length: \(valueString.count))")

                // Store Data value in the appropriate store
                if isUbiquitousKey {
                    NSUbiquitousKeyValueStore.default.set(data, forKey: key)
                } else {
                    UserDefaults.standard.set(data, forKey: key)
                }
            } else {
                // Best-effort type inference for scalar values
                if let boolValue = Bool(valueString.lowercased()) {
                    if isUbiquitousKey {
                        NSUbiquitousKeyValueStore.default.set(boolValue, forKey: key)
                    } else {
                        UserDefaults.standard.set(boolValue, forKey: key)
                    }
                    print("[Migration Deeplink] \(key): \(boolValue) (Bool)")
                } else if let intValue = Int(valueString) {
                    if isUbiquitousKey {
                        NSUbiquitousKeyValueStore.default.set(intValue, forKey: key)
                    } else {
                        UserDefaults.standard.set(intValue, forKey: key)
                    }
                    print("[Migration Deeplink] \(key): \(intValue) (Int)")
                } else if let doubleValue = Double(valueString) {
                    if isUbiquitousKey {
                        NSUbiquitousKeyValueStore.default.set(doubleValue, forKey: key)
                    } else {
                        UserDefaults.standard.set(doubleValue, forKey: key)
                    }
                    print("[Migration Deeplink] \(key): \(doubleValue) (Double)")
                } else {
                    if isUbiquitousKey {
                        NSUbiquitousKeyValueStore.default.set(valueString, forKey: key)
                    } else {
                        UserDefaults.standard.set(valueString, forKey: key)
                    }
                    print("[Migration Deeplink] \(key): \(valueString) (String)")
                }
            }
        }
    }

    private func handleListViewControllerKey(key: String, valueString: String) {
        // Extract trakt ID from key pattern: ListViewController.{trakt_id}.currentFilter/Sorting
        let components = key.components(separatedBy: ".")
        guard components.count == 3 else {
            print("[Migration Deeplink] \(key): \(valueString)")
            return
        }

        let traktId = components[1]

        guard let intValue = Int(valueString) else {
            print("[Migration Deeplink] \(key): \(valueString)")
            return
        }

        if key.contains(".currentFilter") {
            // Filter enum: none=0, movies=1, shows=2, seasons=3, episodes=4
            let filterNames = ["none", "movies", "shows", "seasons", "episodes"]
            let filterName = intValue < filterNames.count ? filterNames[intValue] : "unknown(\(intValue))"
            print("[Migration Deeplink] \(key) - ListViewController filter for list ID \(traktId): \(filterName) (rawValue: \(intValue))")
        } else if key.contains(".currentSorting") {
            // Sort enum: rank=0, listed=1, title=2, releaseDate=3, runtime=4, rating=5, votes=6, weightedRating=7, random=8
            let sortNames = ["rank", "listed", "title", "releaseDate", "runtime", "rating", "votes", "weightedRating", "random"]
            let sortName = intValue < sortNames.count ? sortNames[intValue] : "unknown(\(intValue))"
            print("[Migration Deeplink] \(key) - ListViewController sorting for list ID \(traktId): \(sortName) (rawValue: \(intValue))")
        }
    }
}
