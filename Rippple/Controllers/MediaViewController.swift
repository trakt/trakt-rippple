//
//  MediaViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/01/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import Receiver

import SafariServices

import Moya

let (onRemoveWatchTransmitter, onRemoveWatchReceiver) = Receiver<Int64>.make(with: .hot)
let (onRemoveWatchMediaTransmitter, onRemoveWatchMediaReceiver) = Receiver<MediaModel>.make(with: .hot)
let (onRemoveMultipleMediaTransmitter, onRemoveMultipleMediaReceiver) = Receiver<MediaModel>.make(with: .hot)

final class MediaViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    private var didDownloadFull = false {
        didSet {
            if didDownloadFull == true {
                var snapshot = dataSource.snapshot()
                snapshot.reloadItems([Wrapper.title, Wrapper.summary])
                DispatchQueue.main.async {
                    self.dataSource.apply(snapshot,
                                          animatingDifferences: false)
                }
            }
        }
    }
    private var didDownloadPoster = true {
        didSet {
            if didDownloadPoster == false {
                updateDatasource()
            }
        }
    }
    var media: MediaModel! {
        didSet {
            if isViewLoaded {
                updateDatasource()
            }
        }
    }

    private var officialList: List? {
        didSet {
            updateDatasource()
        }
    }

    private var seasons = [Season]()

    private var progress: ShowProgress? {
        didSet {
            if progress != oldValue {
                updateDatasource()
            }
        }
    }
    private func progress(for season: Season) -> SeasonProgress? {
        guard let progress = progress else { return nil }
        for seasonProgress in progress.seasons where seasonProgress.number == season.number {
            return seasonProgress
        }
        return nil
    }
    private func progress(for episode: Episode, in season: Season) -> EpisodeProgress? {
        guard let seasonProgress = progress(for: season) else { return nil }
        for episodeProgress in seasonProgress.episodes where episodeProgress.number == episode.number {
            return episodeProgress
        }
        return nil
    }

    private var linkCount = 0
    private func updateDatasource() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        switch media! {
        case .movie:
            if didDownloadPoster {
                snapshot.appendItems([.header, .poster, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
            } else {
                snapshot.appendItems([.header, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
            }
        case .show:
            if UserManager.shared.currentUser != nil {
                if didDownloadPoster {
                    snapshot.appendItems([.header, .poster, .title, .activity, .whereToWatch, .seasons, .rating, .comments, .cast, .stats, .summary])
                } else {
                    snapshot.appendItems([.header, .title, .activity, .whereToWatch, .seasons, .rating, .comments, .cast, .stats, .summary])
                }
            } else {
                if didDownloadPoster {
                    snapshot.appendItems([.header, .poster, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                } else {
                    snapshot.appendItems([.header, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                }
            }
        case .episode:
            if didDownloadPoster {
                snapshot.appendItems([.header, .backdrop, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
            } else {
                snapshot.appendItems([.header, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
            }
        case .season(let season, let show):
            if UserManager.shared.currentUser != nil {
                if didDownloadPoster {
                    snapshot.appendItems([.header, .poster, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                } else {
                    snapshot.appendItems([.header, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                }

                var episodeWrappers = [Wrapper]()
                if let episodes = season.episodes {
                    episodeWrappers.append(.spacer(5.003))
                    for episode in episodes {
                        let media = episode.mediaModel(given: show)
                        if episode == episodes.first, episode == episodes.last {
                            episodeWrappers.append(.episode(media, .alone, progress(for: episode, in: season), progress?.resetAt))
                        } else if episodes.first == episode {
                            episodeWrappers.append(.episode(media, .top, progress(for: episode, in: season), progress?.resetAt))
                        } else if episodes.last == episode {
                            episodeWrappers.append(.episode(media, .bottom, progress(for: episode, in: season), progress?.resetAt))
                        } else {
                            episodeWrappers.append(.episode(media, .middle, progress(for: episode, in: season), progress?.resetAt))
                        }
                    }
                    episodeWrappers.append(.spacer(5.004))
                }
                snapshot.insertItems(episodeWrappers, afterItem: .whereToWatch)
            } else {
                if didDownloadPoster {
                    snapshot.appendItems([.header, .poster, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                } else {
                    snapshot.appendItems([.header, .title, .activity, .whereToWatch, .rating, .comments, .cast, .stats, .summary])
                }
            }
        case .list:
            break
        case .showProgress:
            break
        }

        if CountryManager.shared.disabled {
            snapshot.deleteItems([.whereToWatch])
        }

        if media.noteItem != nil {
            snapshot.insertItems([.notes], afterItem: .rating)
        }

        linkCount = 0
        snapshot.appendSections([.links])

        switch media! {
        case .movie:
            snapshot.appendItems([.link("Watch Trailers & more", "play.rectangle", URL(string: "https://trailers")!)])
            linkCount += 1
        case .show:
            snapshot.appendItems([.link("Watch Opening Credits & more", "play.rectangle", URL(string: "https://trailers")!)])
            linkCount += 1
        case .season:
            snapshot.appendItems([.link("Watch Recaps & more", "play.rectangle", URL(string: "https://trailers")!)])
            linkCount += 1
        case .episode:
            snapshot.appendItems([.link("Watch Clips & more", "play.rectangle", URL(string: "https://trailers")!)])
            linkCount += 1
        case .list, .showProgress:
            break
        }

        if let trakt = media.traktWebsiteMediaLink {
            snapshot.appendItems([.link("Open on Trakt", "link", trakt)])
            linkCount += 1
        }
        if let tmdb = media.tmdbURL {
            snapshot.appendItems([.link("Open on TMDb", "link", tmdb)])
            linkCount += 1
        }
        if let imdb = media.imdbURL {
            snapshot.appendItems([.link("Open on IMDb", "link", imdb)])
            linkCount += 1
        }
        if let homepage = media.homepageURL {
            snapshot.appendItems([.link("Open Official Website", "network", homepage)])
            linkCount += 1
        }

        if linkCount > 0 {
            snapshot.insertItems([.spacer(5.001)], afterItem: .summary)
        }

        if let officialList = officialList {
            snapshot.appendItems([.spacer(5.002)])
            snapshot.appendItems([.collection(officialList)])
        }

        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    var isDeeplink = false

    private enum Section: Int {
        case content
        case links
        case episodes
    }

    private enum Wrapper: Hashable {
        case poster
        case backdrop
        case title
        case activity
        case rating
        case comments
        case cast
        case summary
        case seasons
        case episode(MediaModel, CardType, EpisodeProgress?, Date?)
        case stats
        case whereToWatch
        case link(String, String, URL)
        case collection(List)
        case notes
        case spacer(Float)
        case header
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, indexPath, item in
        guard let self = self else { return nil }

        switch item {
        case .backdrop:
            let cell = tableView.dequeueReusableCell(withIdentifier: "backdrop") as! MediaBackdropTableViewCell
            cell.backdropDownloadResultReceiver.listen { [weak self] didDownload in
                guard let self = self else { return }
                self.didDownloadPoster = didDownload
            }.disposed(by: self.disposeBag)
            cell.media = self.media
            return cell
        case .poster:
            let cell = tableView.dequeueReusableCell(withIdentifier: "poster") as! MediaPosterTableViewCell
            cell.posterDownloadResultReceiver.listen { [weak self] didDownload in
                guard let self = self else { return }
                self.didDownloadPoster = didDownload
            }.disposed(by: self.disposeBag)
            cell.media = self.media
            return cell
        case .title:
            let cell = tableView.dequeueReusableCell(withIdentifier: "title") as! MediaTitleTableViewCell
            cell.media = self.media
            cell.delegate = self
            return cell
        case .activity:
            let cell = tableView.dequeueReusableCell(withIdentifier: "activity") as! PulsePreviewTableViewCell
            cell.media = self.media
            return cell
        case .rating:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ratings") as! RatingsTableViewCell
            cell.media = self.media
            cell.viewController = self
            return cell
        case .comments:
            let cell = tableView.dequeueReusableCell(withIdentifier: "comments") as! MediaCommentsTableViewCell
            cell.media = self.media
            cell.delegate = self
            return cell
        case .cast:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cast") as! CastTableViewCell
            cell.media = self.media
            cell.delegate = self
            return cell
        case .summary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "overview") as! MediaOverviewTableViewCell
            cell.media = self.media
            return cell
        case .seasons:
            let cell = tableView.dequeueReusableCell(withIdentifier: "more") as! MediaMoreTableViewCell
            cell.show = self.media.show
            cell.delegate = self
            return cell
        case .episode(let media, let cardType, let progress, let resetDate):
            let cell = tableView.dequeueReusableCell(withIdentifier: "episode") as! EpisodeShowTableViewCell
            cell.resetDate = resetDate // needs to be set before other properties
            cell.media = media
            cell.card.cardType = cardType
            cell.progress = progress
            if let progress = self.progress {
                if progress.nextEpisodeToWatch == media.episode {
                    cell.additionalInfo.isHidden = false
                } else {
                    cell.additionalInfo.isHidden = true
                }
            } else {
                cell.additionalInfo.isHidden = true
            }
            return cell
        case .stats:
            let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as! StatsTableViewCell
            cell.media = self.media
            return cell
        case .whereToWatch:
            let cell = tableView.dequeueReusableCell(withIdentifier: "where to watch") as! WhereToWatchTableViewCell
            cell.media = self.media
            return cell
        case .link(let title, let imageName, let url):
            let cell = tableView.dequeueReusableCell(withIdentifier: "link") as! LinkTableViewCell
            cell.title.text = title
            cell.linkImage.image = UIImage(systemName: imageName)
            if self.linkCount == 1 {
                cell.cardType = .alone
            } else if indexPath.row == 0 {
                cell.cardType = .top
            } else if indexPath.row == self.linkCount - 1 {
                cell.cardType = .bottom
            } else {
                cell.cardType = .middle
            }
            if url.absoluteString == "https://trailers" {
                cell.actions.setImage(UIImage(systemName: "chevron.right"), for: .normal)
                cell.actions.isEnabled = false
            } else {
                cell.actions.setImage(UIImage(systemName: "ellipsis"), for: .normal)
                cell.actions.isEnabled = true
            }
            cell.delegate = self
            return cell
        case .collection(let list):
            let cell = tableView.dequeueReusableCell(withIdentifier: "custom list") as! ListTableViewCell
            cell.user = list.user
            cell.list = list
            cell.isEditingMode = false
            cell.delegate = self
            return cell
        case .notes:
            let cell = tableView.dequeueReusableCell(withIdentifier: "notes") as! PrivateNotesTableViewCell
            cell.media = media
            return cell
        case .spacer(let space):
            let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as! SpacerTableViewCell
            cell.space = space
            return cell
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! MediaHeaderTableViewCell
            cell.media = media
            cell.delegate = self
            return cell
        }
    }

    private let menuDelegate = MediaContextMenuInteractionDelegate()

    override func viewDidLoad() {
        super.viewDidLoad()

        if let presentationController = navigationController?.presentationController as? UISheetPresentationController {
            presentationController.animateChanges {
                presentationController.selectedDetentIdentifier = .large
                presentationController.detents = [.large()]
                presentationController.prefersGrabberVisible = false
            }
        }

        navigationItem.style = .browser
        navigationItem.largeTitleDisplayMode = .never

        precondition(media != nil, "Media should not be nil")

        // reset the cache for that show
        if case .show(let show) = media {
            ProgressManager.shared.refreshProgress(for: show)
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "PulsePreviewTableViewCell", bundle: nil), forCellReuseIdentifier: "activity")
        tableView.register(UINib(nibName: "MediaBackdropTableViewCell", bundle: nil), forCellReuseIdentifier: "backdrop")
        tableView.register(UINib(nibName: "MediaPosterTableViewCell", bundle: nil), forCellReuseIdentifier: "poster")
        tableView.register(UINib(nibName: "MediaOverviewTableViewCell", bundle: nil), forCellReuseIdentifier: "overview")
        tableView.register(UINib(nibName: "RatingsTableViewCell", bundle: nil), forCellReuseIdentifier: "ratings")
        tableView.register(UINib(nibName: "MediaTitleTableViewCell", bundle: nil), forCellReuseIdentifier: "title")
        tableView.register(UINib(nibName: "MediaCommentsTableViewCell", bundle: nil), forCellReuseIdentifier: "comments")
        tableView.register(UINib(nibName: "MediaMoreTableViewCell", bundle: nil), forCellReuseIdentifier: "more")
        tableView.register(UINib(nibName: "CastTableViewCell", bundle: nil), forCellReuseIdentifier: "cast")
        tableView.register(UINib(nibName: "StatsTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.register(UINib(nibName: "WhereToWatchTableViewCell", bundle: nil), forCellReuseIdentifier: "where to watch")
        tableView.register(UINib(nibName: "LinkTableViewCell", bundle: nil), forCellReuseIdentifier: "link")
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.register(UINib(nibName: "PrivateNotesTableViewCell", bundle: nil), forCellReuseIdentifier: "notes")
        tableView.register(UINib(nibName: "SpacerTableViewCell", bundle: nil), forCellReuseIdentifier: "spacer")
        tableView.register(UINib(nibName: "MediaHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "EpisodeShowTableViewCell", bundle: nil), forCellReuseIdentifier: "episode")

        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        tableView.separatorStyle = .none

        tableView.dragDelegate = self

        tableView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.tableView.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)

        if dataSource.snapshot().numberOfItems == 0 {
            updateDatasource()
        }
        tableView.dataSource = dataSource

        updateButtonItem()

        switch media! {
        case .movie:
            if !didDownloadFull {
                loadFullMovie()
            }
            fetchMovieOfficialList()
            // fetchMovieTranslations()
        case .show:
            if !didDownloadFull {
                loadFullShow()
            }
            fetchShowOfficialList()
            fetchSeasons()
        case .episode:
            if !didDownloadFull {
                loadFullEpisode()
            }
            fetchSeasons()
        case .season:
            fetchSeasons()
        case .list:
            break
        case .showProgress:
            break
        }

        if navigationController?.viewControllers.first == self || isDeeplink {
            navigationController?.isNavigationBarHidden = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                               target: self,
                                                               action: #selector(done))
        }

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            let media = self.media
            self.media = media
        }.disposed(by: disposeBag)

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            let media = self.media
            self.media = media
        }.disposed(by: disposeBag)

        onCommentsDisplayReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.updateDatasource()
        }.disposed(by: disposeBag)

        episodeDetailTitlesReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            var snapshot = self.dataSource.snapshot()
            for identifier in snapshot.itemIdentifiers {
                switch identifier {
                case .title, .backdrop:
                    snapshot.reloadItems([identifier])
                default:
                    continue
                }
            }
            self.dataSource.apply(snapshot)
        }.disposed(by: disposeBag)

        onNotesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            let media = self.media
            self.media = media
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            if progress.show == self.media.show {
                self.progress = progress.showProgress
            }
        }.disposed(by: disposeBag)

        media.progress { [weak self] progress in
            guard let self = self else { return }
            self.progress = progress
        }

        episodeListTitlesReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            var snapshot = self.dataSource.snapshot()
            for identifiers in snapshot.sectionIdentifiers {
                switch identifiers {
                case .content:
                    snapshot.reloadSections([identifiers])
                default:
                    continue
                }
            }
            self.dataSource.apply(snapshot)
        }.disposed(by: disposeBag)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(respondToSwipeGesture))
        swipeLeft.direction = .left
        view.addGestureRecognizer(swipeLeft)

        navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
    }

    @objc func respondToSwipeGesture(gesture: UIGestureRecognizer) {
        if view.window == nil { return }

        let trans = CATransition()
        trans.type = .push
        trans.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        trans.duration = 0.3

        guard let swipeGesture = gesture as? UISwipeGestureRecognizer else {
            return
        }

        switch swipeGesture.direction {
        case .right:
            trans.subtype = .fromLeft
        case .left:
            trans.subtype = .fromRight
        default:
            return
        }

        switch media! {
        case .movie(let movie):
            // Get the next movie in the collection (if any)
            print(movie)
        case .show(let show):
            // Get the first season (if any)
            if swipeGesture.direction == .left {
                guard let firstSeason = seasons.first else { return }
                guard let firstEpisode = firstSeason.episodes?.first else { return }

                navigationController!.view.layer.add(trans, forKey: nil)

                guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                    fatalError()
                }

                mediaViewController.media = firstEpisode.mediaModel(given: show)

                var stack = navigationController!.viewControllers
                stack.removeLast()
                stack.append(mediaViewController)
                navigationController!.setViewControllers(stack, animated: false)

                return
            }
        case .episode(let episode, let show):
            // Get the next episode or seasons (if any)
            if swipeGesture.direction == .right {
                guard let firstSeason = seasons.first else { return }
                guard let firstEpisode = firstSeason.episodes?.first else { return }

                if episode == firstEpisode {
                    navigationController!.view.layer.add(trans, forKey: nil)

                    guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                        fatalError()
                    }

                    mediaViewController.media = show.mediaModel

                    var stack = navigationController!.viewControllers
                    stack.removeLast()
                    stack.append(mediaViewController)
                    navigationController!.setViewControllers(stack, animated: false)

                    return
                }

                var before = firstEpisode
                for season in seasons {
                    if season.episodes == nil { continue }
                    for nextEpisode in season.episodes! {
                        if nextEpisode == episode {
                            navigationController!.view.layer.add(trans, forKey: nil)

                            guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                                fatalError()
                            }

                            mediaViewController.media = before.mediaModel(given: show)

                            var stack = navigationController!.viewControllers
                            stack.removeLast()
                            stack.append(mediaViewController)
                            navigationController!.setViewControllers(stack, animated: false)

                            return
                        }
                        before = nextEpisode
                    }
                }
                return
            } else {
                guard let lastSeason = seasons.last else { return }
                guard let lastEpisode = lastSeason.episodes?.last else { return }

                if episode == lastEpisode { return }

                var after = lastEpisode
                for season in seasons.reversed() {
                    if season.episodes == nil { continue }
                    for nextEpisode in season.episodes!.reversed() {
                        if nextEpisode == episode {
                            navigationController!.view.layer.add(trans, forKey: nil)

                            guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                                fatalError()
                            }

                            mediaViewController.media = after.mediaModel(given: show)

                            var stack = navigationController!.viewControllers
                            stack.removeLast()
                            stack.append(mediaViewController)
                            navigationController!.setViewControllers(stack, animated: false)

                            return
                        }
                        after = nextEpisode
                    }
                }
                return
            }
        case .season(let season, let show):
            // Get the next season (if any)
            if swipeGesture.direction == .right {
                guard let firstSeason = seasons.first else { return }

                if firstSeason == season { return }

                var before = firstSeason
                for nextSeason in seasons {
                    if nextSeason == season {
                        navigationController!.view.layer.add(trans, forKey: nil)

                        guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                            fatalError()
                        }

                        mediaViewController.media = before.mediaModel(given: show)

                        var stack = navigationController!.viewControllers
                        stack.removeLast()
                        stack.append(mediaViewController)
                        navigationController!.setViewControllers(stack, animated: false)

                        return
                    }
                    before = nextSeason
                }
                return
            } else {
                guard let lastSeason = seasons.last else { return }

                if season == lastSeason { return }

                var after = lastSeason
                for nextSeason in seasons.reversed() {
                    if nextSeason == season {
                        navigationController!.view.layer.add(trans, forKey: nil)

                        guard let mediaViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else {
                            fatalError()
                        }

                        mediaViewController.media = after.mediaModel(given: show)

                        var stack = navigationController!.viewControllers
                        stack.removeLast()
                        stack.append(mediaViewController)
                        navigationController!.setViewControllers(stack, animated: false)

                        return
                    }
                    after = nextSeason
                }
                return
            }
        case .list:
            fatalError("Not a valid media type for a swipe gesture.")
        case .showProgress:
            fatalError("Not a valid media type for a swipe gesture.")
        }
    }

    private func updateButtonItem() {
        menuDelegate.media = media
        let deferredElement = UIDeferredMenuElement.uncached { completion in
            completion(self.menuDelegate.menu.children)
        }
        let menu = UIMenu(title: menuDelegate.menu.title,
                          children: [deferredElement])
        let mainActions = UIBarButtonItem(image: UIImage(systemName: "ellipsis"),
                                          menu: menu)
        mainActions.tintColor = UIColor(asset: .globalTint)
        mainActions.style = .prominent
        navigationItem.rightBarButtonItems = [mainActions]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if let navigationController = navigationController, media.episode != nil {
            let index = navigationController.viewControllers.count - 2

            // if the previous is also an episode, then remove it from the stack
            if index > 0, let previousViewController = navigationController.viewControllers[index] as? MediaViewController, previousViewController.media.episode != nil {
                var controllers = navigationController.viewControllers
                controllers.remove(at: index)
                navigationController.setViewControllers(controllers, animated: false)
            }
        }
    }

    private func loadFullMovie() {
        guard let movie = media.movie else { fatalError("Media should be a Movie") }
        TraktAPIProvider.provider.request(TraktAPIService.movie(id: movie.identifiers.traktIdOrSlug, extended: .full),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let movie = try response.map(Movie.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.media = MediaModel.movie(movie)
                                                        self.didDownloadFull = true
                                                    }
                                                } catch {
                                                    print("Error fetching movie \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching movie \(error)")
                                            }
        }
    }

    private func loadFullShow() {
        guard let show = media.show else { fatalError("Media should be a Show") }
        TraktAPIProvider.provider.request(TraktAPIService.show(id: show.identifiers.traktIdOrSlug, extended: .full),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let show = try response.map(Show.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.media = MediaModel.show(show)
                                                        self.didDownloadFull = true
                                                    }
                                                } catch {
                                                    print("Error fetching movie \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching movie \(error)")
                                            }
        }
    }

    private func loadFullEpisode() {
        guard case let .episode(episode, show) = media else { fatalError("Media should be an episode") }
        TraktAPIProvider.provider.request(TraktAPIService.episode(id: show.identifiers.traktIdOrSlug, season: episode.season, episode: episode.number),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.media = MediaModel.episode(episode, show)
                                                        self.didDownloadFull = true
                                                    }
                                                } catch {
                                                    print("Error fetching movie \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching movie \(error)")
                                            }
        }
    }

    @objc func done() {
        dismiss(animated: true, completion: nil)
    }

    @IBSegueAction
    func makeListViewController(coder: NSCoder, sender: Any?) -> ListViewController? {
        guard let list = sender as? List else { return nil }
        return ListViewController(coder: coder,
                                  list: list,
                                  user: list.user)
    }

    private let actionButtons = UIStackView()

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        view.bringSubviewToFront(actionButtons)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            if let comment = sender as? Comment {
                commentsViewController.coordinator = CommentsCoordinator(type: .replies(CommentModel(media: media, comment: comment, spoilerStrategy: .showAllSpoilers), false))
            } else {
                commentsViewController.coordinator = CommentsCoordinator(type: .media(media))
            }
        }

        if let seasonsViewController = segue.destination as? SeasonsViewController {
            if let show = sender as? Show {
                seasonsViewController.show = show
            } else if let season = sender as? Season {
                seasonsViewController.show = media.show
                seasonsViewController.season = season
            } else {
                fatalError()
            }
        }

        if let peoplesViewController = segue.destination as? PeoplesTableViewController {
            peoplesViewController.media = media
        }

        if let mediaViewController = segue.destination as? MediaViewController {
            if let media = sender as? MediaModel {
                mediaViewController.media = media
                return
            }
            switch media! {
            case .episode(_, let show), .season(_, let show):
                mediaViewController.media = MediaModel.show(show)
            default:
                fatalError()
            }
        }

        if let seasonsRatingsViewController = segue.destination as? SeasonsRatingsViewController {
            seasonsRatingsViewController.media = media
        }

        if let navigationController = segue.destination as? UINavigationController, let certificationsViewController = navigationController.topViewController as? CertificationsViewController {
            certificationsViewController.media = media
        }

        if let mediaActivities = segue.destination as? PulseViewController, let media = sender as? MediaModel {
            mediaActivities.media = media
        }
    }

    @IBSegueAction
    func makePeopleViewController(coder: NSCoder, sender: Any?) -> PeopleViewController? {
        PeopleViewController(coder: coder,
                             cast: sender as? Cast ?? nil,
                             job: sender as? Job ?? nil,
                             person: sender as? Person ?? nil)
    }

    deinit {
        print("deinit MediaViewController")
    }

    private func fetchMovieOfficialList() {
        guard let traktId = media.movie?.identifiers.trakt else { fatalError("Media should be a Movie with a valid id") }
        TraktAPIProvider.provider.request(TraktAPIService.movieLists(id: traktId, type: .official),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.officialList = lists.first
                                                    }
                                                } catch {
                                                    print("Error fetching movie lists \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching movie lists \(error)")
                                            }
        }
    }

    private func fetchShowOfficialList() {
        guard let traktId = media.show?.identifiers.trakt else { fatalError("Media should be a Show with a valid id") }
        TraktAPIProvider.provider.request(TraktAPIService.showLists(id: traktId, type: .official),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.officialList = lists.first
                                                    }
                                                } catch {
                                                    print("Error fetching show lists \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching show lists \(error)")
                                            }
        }
    }

    private func fetchSeasons() {
        guard let traktId = media.show?.identifiers.trakt else { return }
        TraktAPIProvider.provider.request(.seasons(id: traktId), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    // Filter seasons without episodes or special seasons
                    let seasons = try response.map([Season].self, using: TraktAPIProvider.decoder).filter { $0.number != 0 && $0.episodes?.isEmpty == false }

                    DispatchQueue.main.async {
                        self.seasons = seasons
                    }
                } catch {
                    print("Seasons request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("Seasons request failure \(error)")
            }
        }
    }

    /*
    private func fetchMovieTranslations() {
        guard let traktId = media.movie?.identifiers.traktIdOrSlug else { fatalError("Media should be a Movie with a valid id") }
        TraktAPIProvider.provider.request(.movieTranslations(id: traktId),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                            guard let self = self else { return }
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let translations = try response.map([Translation].self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        print("Translations fetched: \(translations)")
                                                    }
                                                } catch {
                                                    print("Error fetching movie translations \(error)")
                                                }
                                            case let .failure(error):
                                                print("Failed fetching movie translations \(error)")
                                            }
        }
    }
     */

    private var firstEverScrollOffset: CGPoint?
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if firstEverScrollOffset == nil {
            firstEverScrollOffset = scrollView.contentOffset
        }

        if let indexPath = dataSource.indexPath(for: .header), let cell = tableView.cellForRow(at: indexPath) as? MediaHeaderTableViewCell {
            let contentOffsetY = tableView.contentOffset.y + tableView.adjustedContentInset.top
            if contentOffsetY <= 0 {
                cell.contentView.alpha = 1.0
            } else {
                cell.contentView.alpha = 1.0 - (contentOffsetY/60.0)
            }
        }

        if tableView.contentOffset.y + tableView.adjustedContentInset.top < 40.0 {
            navigationItem.title = nil
            navigationItem.subtitle = nil
            return
        }

        switch media! {
        case .movie:
            navigationItem.title = "Movie"
            navigationItem.subtitle = media.mediaTitle
        case .show:
            navigationItem.title = "Show"
            navigationItem.subtitle = media.mediaTitle
        case .episode:
            navigationItem.title = "Episode"
            navigationItem.subtitle = media.mediaTitle
        case .season:
            navigationItem.title = "Season"
            navigationItem.subtitle = media.mediaTitle
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }
}

extension MediaViewController {
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return UITableView.automaticDimension }

        switch item {
        case .backdrop:
            return view.frame.width * 0.5
        case .poster:
            return min((tableView.bounds.width - 18.0) * 1.5, 650.0)
        case .title:
            return UITableView.automaticDimension
        case .activity:
            return UITableView.automaticDimension
        case .rating:
            return UITableView.automaticDimension
        case .comments:
            return UITableView.automaticDimension
        case .cast:
            return UITableView.automaticDimension
        case .summary:
            return UITableView.automaticDimension
        case .seasons:
            return UITableView.automaticDimension
        case .episode:
            return UITableView.automaticDimension
        case .stats:
            return UITableView.automaticDimension
        case .whereToWatch:
            return UITableView.automaticDimension
        case .link:
            return UITableView.automaticDimension
        case .collection:
            return UITableView.automaticDimension
        case .notes:
            return UITableView.automaticDimension
        case .spacer:
            return UITableView.automaticDimension
        case .header:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .poster, .backdrop:
            let imageBrowserViewController = ImageBrowserViewController()
            imageBrowserViewController.media = media
            let browserNavigationController = UINavigationController(rootViewController: imageBrowserViewController)
            browserNavigationController.modalPresentationStyle = .formSheet
            present(browserNavigationController, animated: true, completion: nil)
        case .activity:
            performSegue(withIdentifier: "activities", sender: media)
        case .rating:
            return
        case .comments:
            performSegue(withIdentifier: "comments", sender: nil)
        case .seasons:
            if media.season == nil {
                performSegue(withIdentifier: "seasons", sender: media.show)
            } else {
                performSegue(withIdentifier: "seasons", sender: media.season)
            }
        case .link(_, _, let url):
            if url.absoluteString == "https://trailers" {
                let trailersViewController = TrailersViewController()
                trailersViewController.media = media
                navigationController?.pushViewController(trailersViewController, animated: true)
                return
            }
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                present(SFSafariViewController(url: url), animated: true, completion: nil)
            }
        case .collection(let list):
            performSegue(withIdentifier: "list", sender: list)
        case .notes:
            NotesManager.shared.showNotes(for: media)
        case .episode(let media, _, _, _):
            performSegue(withIdentifier: "media", sender: media)
        default:
            return
        }
    }
}

extension MediaViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            guard let image = cell.posterImageView.image else { return [] }
            guard let media = cell.media else { return [] }

            let provider = NSItemProvider(object: image)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = media

            return [item]
        }

        if let cell = tableView.cellForRow(at: indexPath) as? MediaTitleTableViewCell {
            guard let media = cell.media else { return [] }

            let textProvider = NSItemProvider(object: media.mediaTitle as NSString)
            let textItem = UIDragItem(itemProvider: textProvider)
            textItem.localObject = media

            if let traktURL = media.traktWebsiteMediaLink {
                let linkProvider = NSItemProvider(object: traktURL as NSURL)
                let linkItem = UIDragItem(itemProvider: linkProvider)
                linkItem.localObject = media
                return [textItem, linkItem]
            }

            return [textItem]
        }

        return []
    }

    func tableView(_ tableView: UITableView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            guard let image = cell.posterImageView.image else { return [] }

            let provider = NSItemProvider(object: image)
            let item = UIDragItem(itemProvider: provider)
            item.localObject = image

            return [item]
        }

        if let cell = tableView.cellForRow(at: indexPath) as? MediaTitleTableViewCell {
            guard let media = cell.media else { return [] }

            let textProvider = NSItemProvider(object: media.mediaTitle as NSString)
            let textItem = UIDragItem(itemProvider: textProvider)
            textItem.localObject = media

            if let traktURL = media.traktWebsiteMediaLink {
                let linkProvider = NSItemProvider(object: traktURL as NSURL)
                let linkItem = UIDragItem(itemProvider: linkProvider)
                linkItem.localObject = media
                return [textItem, linkItem]
            }

            return [textItem]
        }

        return []
    }

    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: cell.cardView.frame, cornerRadius: cell.cardView.layer.cornerRadius)
            return parameters
        }

        if let cell = tableView.cellForRow(at: indexPath) as? MediaTitleTableViewCell {
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            parameters.visiblePath = UIBezierPath(roundedRect: cell.cardView.frame, cornerRadius: cell.cardView.layer.cornerRadius)
            return parameters
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            guard let image = cell.posterImageView.image else { return nil }

            return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                              previewProvider: nil) { _ -> UIMenu? in
                let copyAction = UIAction(title: "Copy Image",
                                          image: UIImage(systemName: "doc.on.doc"),
                                          identifier: nil) { _ in
                    UIPasteboard.general.image = image
                }
                let saveAction = UIAction(title: "Save Image",
                                          image: UIImage(systemName: "square.and.arrow.down"),
                                          identifier: nil) { _ in
                    self.writeToPhotoAlbum(image: image)
                }
                let shareAction = UIAction(title: "Share Image",
                                          image: UIImage(systemName: "square.and.arrow.up"),
                                          identifier: nil) { _ in
                    self.share(image: image)
                }
                let menu = UIMenu(children: [copyAction, saveAction, shareAction])
                return menu
            }
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            return UITargetedPreview(view: cell.posterImageView, parameters: UIPreviewParameters())
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? MediaPosterTableViewCell {
            return UITargetedPreview(view: cell.posterImageView, parameters: UIPreviewParameters())
        }
        return nil
    }

    private func writeToPhotoAlbum(image: UIImage) {
        SwiftMessages.show(message: "Saving image...", style: .loading)
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(saveCompleted), nil)
    }

    @objc private func saveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            SwiftMessages.show(message: "Image not saved!", style: .error(error))
        } else {
            SwiftMessages.show(message: "Image saved!", style: .content)
        }
    }

    private func share(image: UIImage) {
        let activityViewController = UIActivityViewController(activityItems: [image],
                                                              applicationActivities: nil)
        UIApplication.shared.present(activityViewController)
    }
}

extension MediaViewController: CastTableViewCellDelegate {
    func cell(_ cell: CastTableViewCell, action: CastTableViewCell.Action) {
        switch action {
        case .showAll:
            performSegue(withIdentifier: "peoples", sender: self)
        case .showCast(let cast):
            performSegue(withIdentifier: "people", sender: cast)
        case .showCrew(let crew):
            performSegue(withIdentifier: "people", sender: crew)
        }
    }
}

extension MediaViewController: MediaTitleTableViewCellDelegate {
    func cell(_ cell: MediaTitleTableViewCell, action: MediaTitleTableViewCell.Action) {
        switch action {
        case .presentShow:
            performSegue(withIdentifier: "media", sender: nil)
        case .presentCertifications:
            performSegue(withIdentifier: "certifications", sender: nil)
        case .presentMedia(let media):
            performSegue(withIdentifier: "media", sender: media)
        }
    }
}

extension MediaViewController: MediaCommentsTableViewCellDelegate {
    func cell(_ cell: MediaCommentsTableViewCell, action: MediaCommentsTableViewCell.Action) {
        switch action {
        case .showAll:
            performSegue(withIdentifier: "comments", sender: nil)
        case .showComment(let comment):
            performSegue(withIdentifier: "comments", sender: comment)
        }
    }
}

extension MediaViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        guard let list = cell.list else { return }
        if action == .touch {
            performSegue(withIdentifier: "list", sender: list)
        } else if action == .user {
            if let type = list.type, type == "official" {
                let alert = UIAlertController(title: "Trakt Official List",
                                              message: "This is an official list created and maintained by Trakt.",
                                              preferredStyle: .alert)
                let okay = UIAlertAction(title: "Okay", style: .default) { [weak self] _ in
                    guard let self = self else { return }

                    self.dismiss(animated: true)
                }
                alert.addAction(okay)
                present(alert, animated: true)
            } else {
                if let user = cell.user {
                    performSegue(withIdentifier: "user", sender: user)
                } else {
                    performSegue(withIdentifier: "user", sender: list)
                }
            }
        }
    }
}

extension MediaViewController: LinkTableViewCellDelegate {
    func cell(_ cell: LinkTableViewCell, action: LinkTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .link(_, _, let url):
            let alertController = UIAlertController(title: "What do you want to do?",
                                                    message: url.absoluteString,
                                                    preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: "Do nothing", style: .cancel))

            alertController.addAction(UIAlertAction(title: "Share the link", style: .default, handler: { _ in
                UIApplication.shared.present(UIActivityViewController(activityItems: [url],
                                                                      applicationActivities: nil))
            }))

            alertController.addAction(UIAlertAction(title: "Open in Safari", style: .default, handler: { _ in
                UIApplication.shared.open(url)
            }))

            alertController.addAction(UIAlertAction(title: "Open in app", style: .default, handler: { _ in
                self.present(SFSafariViewController(url: url), animated: true, completion: nil)
            }))

            present(alertController, animated: true)
        default:
            return
        }
    }
}

extension MediaViewController: MediaMoreTableViewCellDelegate {
    func cell(_ cell: MediaMoreTableViewCell, didSelect season: Season) {
        performSegue(withIdentifier: "media", sender: season.mediaModel(given: media.show!))
    }
}

extension MediaViewController: MediaHeaderTableViewCellDelegate {
    func cell(_ cell: MediaHeaderTableViewCell, action: MediaHeaderTableViewCell.Action) {
        if action == .presentEpisodeList {
            if media.season == nil {
                performSegue(withIdentifier: "seasons", sender: media.show)
            } else {
                performSegue(withIdentifier: "seasons", sender: media.season)
            }
        }
    }
}
