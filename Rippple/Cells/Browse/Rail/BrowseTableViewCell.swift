//
//  L1BrowseTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 16/06/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

class BrowseTableViewCell: UITableViewCell {
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var pageControl: UIPageControl?

    weak var presentingViewController: UIViewController?

    var savedFilter: SavedFilter? {
        didSet {
            fetchItems()
        }
    }

    var actionButtonStyle: ShelfBrowseActionButtonStyle = .none {
        didSet {
            if actionButtonStyle != oldValue {
                collectionView?.reloadData()
            }
        }
    }

    private var task: Task<Void, Error>? {
        willSet {
            task?.cancel()
        }
    }

    deinit {
        task?.cancel()
    }

    var notes: [String?]?
    private var items: [MediaModel]? {
        didSet {
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
                self.pageControl?.numberOfPages = self.items?.count ?? 0
            }
        }
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()
    private var didConfigureCollectionView = false

    private func note(at indexPath: IndexPath) -> String? {
        guard let notes = notes, notes.indices.contains(indexPath.row) else { return nil }
        return notes[indexPath.row]
    }

    private func media(at indexPath: IndexPath) -> MediaModel? {
        guard let items = items, items.indices.contains(indexPath.row) else { return nil }
        return items[indexPath.row]
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        configureCollectionViewIfNeeded()
    }

    func configureCollectionViewIfNeeded() {
        guard !didConfigureCollectionView, collectionView != nil else { return }
        didConfigureCollectionView = true

        collectionView?.allowsFocus = false
        collectionView?.delegate = self
        collectionView?.dataSource = self
        collectionView?.dragDelegate = self

        backgroundColor = .clear
        collectionView.backgroundColor = .clear

        if reuseIdentifier == "C1" {
            collectionView.collectionViewLayout = carouselBannerSection()
            collectionView.prefetchDataSource = self
        } else if reuseIdentifier == "L3" {
            collectionView.collectionViewLayout = L3Section()
        } else if reuseIdentifier == "L1" || reuseIdentifier == "L2" {
            collectionView.collectionViewLayout = LSection()
        } else if reuseIdentifier == "G1" {
            collectionView.collectionViewLayout = GSection()
        } else if reuseIdentifier == "List" {
            collectionView.collectionViewLayout = listSection()
        }

        collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)

        collectionView.register(UINib(nibName: "L1BrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        collectionView.register(UINib(nibName: "C2BrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "C2")
        collectionView.register(UINib(nibName: "TopBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "T1")
        collectionView.register(UINib(nibName: "ToWatchBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ToWatch")
        collectionView.register(UINib(nibName: "StandardHistoryBrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "History")
        collectionView.register(UINib(nibName: "L2BrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell with notes")
        collectionView.register(UINib(nibName: "G1BrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "G1")
        collectionView.register(ListBrowseCollectionViewCell.self, forCellWithReuseIdentifier: "List")

        if let pageControl = pageControl {
            pageControl.numberOfPages = items?.count ?? 0
            let progress = UIPageControlTimerProgress(preferredDuration: 8)
            progress.delegate = self
            progress.resetsToInitialPageAfterEnd = true
            pageControl.progress = progress
            progress.resumeTimer()
        }

        onLastWatchedEpisodeActivitiesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.reuseIdentifier != "History" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onLastWatchedMovieActivitiesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.reuseIdentifier != "History" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60 * 60 * 1 {
                    self.fetchItems()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        onEpisodeToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section == "episodes_to_watch" {
                self.fetchItems()
            } else if self.savedFilter?.section == "pinned_to_watch" {
                self.fetchItems()
            } else if self.savedFilter?.section == "unpinned_to_watch" {
                self.fetchItems()
            }
        }.disposed(by: disposeBag)

        onMovieToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section == "movies_to_watch" {
                self.fetchItems()
            }
        }.disposed(by: disposeBag)

        onCompletedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section != "CompletedShows" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onDroppedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section != "DroppedShows" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onPinnedShowsToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section != "PinnedShows" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onPinnedMoviesToWatchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.section != "PinnedMovies" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.path != "/users/me/watched/movies" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter?.path != "/users/me/watched/shows" { return }
            self.fetchItems()
        }.disposed(by: disposeBag)
    }

    private func fetchItems() {
        notes = nil

        if reuseIdentifier == "History" {
            fetchHistory()
            return
        }

        guard let filter = savedFilter else { return }

        if filter.section == "episodes_to_watch" {
            items = EpisodeToWatchManager.shared.filteredMediaModels
            return
        }
        if filter.section == "movies_to_watch" {
            items = MovieToWatchManager.shared.filteredMediaModels
            return
        }
        if filter.section == "pinned_to_watch" {
            items = EpisodeToWatchManager.shared.filteredMediaModels.filter { $0.show?.isPinned == true }
            return
        }
        if filter.section == "unpinned_to_watch" {
            items = EpisodeToWatchManager.shared.filteredMediaModels.filter { $0.show?.isPinned == false }
            return
        }
        if filter.section == "CompletedShows" {
            items = CompletedShowsManager.shared.completedShowsModels
            return
        }
        if filter.section == "DroppedShows" {
            items = DroppedShowsManager.shared.droppedShowsModels
            return
        }
        if filter.section == "PinnedShows" {
            items = PinnedShowsManager.shared.pinnedShows.compactMap { $0.mediaModel }
            return
        }
        if filter.section == "PinnedMovies" {
            items = PinnedMoviesManager.shared.pinnedMovies.compactMap { $0.mediaModel }
            return
        }
        task = Task {
            var items: [MediaModel]?
            if filter.path.localizedStandardContains("27798283") || filter.path.localizedStandardContains("27798281") || filter.path.localizedStandardContains("27798291") || filter.path.localizedStandardContains("27798288") || filter.path.localizedStandardContains("27798292") {
                let mediaItems = try await self.fetch(filter: filter)
                items = mediaItems.compactMap { MediaModel(item: $0) }
                if Task.isCancelled { return }
                self.notes = mediaItems.map { $0.notes }
                self.items = items
            } else {
                items = try await self.fetch(filter: filter).compactMap { MediaModel(item: $0) }
                if Task.isCancelled { return }
                self.notes = nil
                self.items = items
            }
        }
    }

    private func fetchHistory() {
        TraktAPIProvider.provider.request(.history(slug: "me",
                                                   type: nil,
                                                   id: nil,
                                                   pageInfo: PageInfo.firstPage(with: 25),
                                                   endDate: nil), callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.items = fetchedActivities.compactMap { MediaModel(item: $0) }
                    }
                } catch {
                    print("Error Fetching History \(error)")
                }
            case let .failure(error):
                print("Error Fetching History \(error)")
            }
        }
    }

    private func fetch(filter: SavedFilter) async throws -> [MediaItem] {
        let filter = filter.normalized
        let result: [MediaItem] = try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(.savedFilter(section: filter.section,
                                                           path: filter.path,
                                                           query: filter.query,
                                                           pageInfo: PageInfo.firstPage(with: filter.limit ?? 30)),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in

                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if filter.path == "/shows/popular" {
                            let items = try response.map([Show].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: nil, show: $0, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                            continuation.resume(returning: items)
                        } else if filter.path == "/movies/popular" {
                            let items = try response.map([Movie].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                            continuation.resume(returning: items)
                        } else if filter.path == "/recommendations/shows" {
                            let items = try response.map([Show].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: nil, show: $0, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                            continuation.resume(returning: items)
                        } else if filter.path == "/recommendations/movies" {
                            let items = try response.map([Movie].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0, show: nil, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                            continuation.resume(returning: items)
                        } else if filter.section == "WatchedItem" {
                            let items = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder).map { MediaItem(movie: $0.movie, show: $0.show, episode: nil, season: nil, list: nil, watchers: nil, listedAt: nil, collectedAt: nil, lastCollectedAt: nil, hiddenAt: nil, notes: nil) }
                            continuation.resume(returning: items)
                        } else {
                            let items = try response.map([MediaItem].self, using: TraktAPIProvider.decoder).filter({ media in
                                media.movie != nil || media.season != nil || media.episode != nil || media.show != nil
                            })
                            continuation.resume(returning: items)
                        }
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
        return result
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            if let progress = pageControl?.progress as? UIPageControlTimerProgress {
                progress.pauseTimer()
            }
        } else {
            if let progress = pageControl?.progress as? UIPageControlTimerProgress {
                progress.resumeTimer()
            }
        }
    }

    fileprivate var shouldUpdatePageControl = true
    private func carouselBannerSection() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                     leading: 5,
                                                     bottom: 0,
                                                     trailing: 5)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.95),
            heightDimension: .fractionalHeight(1)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPagingCentered
        section.visibleItemsInvalidationHandler = { [weak self] (_, _, _) in
            guard let self = self else { return }
            if self.shouldUpdatePageControl == false { return }
            guard let progress = self.pageControl?.progress as? UIPageControlTimerProgress else { return }
            if progress.isProgressVisible == false { return }

            progress.delegate = nil
            progress.pauseTimer()
            if let indexPath = self.collectionView.indexPathForItem(at: self.collectionView.center) {
                self.pageControl?.currentPage = indexPath.row
            }
            progress.delegate = self
            progress.resumeTimer()
        }

        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }

    private func L3Section() -> UICollectionViewLayout {
        let smallItemSize = NSCollectionLayoutSize(widthDimension: .estimated(50),
                                                   heightDimension: .fractionalHeight(0.5))
        let smallItem = NSCollectionLayoutItem(layoutSize: smallItemSize)

        let nestedGroupSize = NSCollectionLayoutSize(widthDimension: .estimated(50),
                                                     heightDimension: .fractionalHeight(1))
        let nestedGroup = NSCollectionLayoutGroup.vertical(layoutSize: nestedGroupSize,
                                                           repeatingSubitem: smallItem,
                                                           count: 2)
        nestedGroup.interItemSpacing = .fixed(6)

        let outerGroupSize = NSCollectionLayoutSize(widthDimension: .estimated(collectionView.bounds.width),
                                                    heightDimension: .fractionalHeight(1))
        let outerGroup = NSCollectionLayoutGroup.horizontal(layoutSize: outerGroupSize,
                                                            subitems: [nestedGroup])

        let section = NSCollectionLayoutSection(group: outerGroup)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 6
        section.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

        let layout = UICollectionViewCompositionalLayout(section: section)

        return layout
    }

    private func LSection() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .estimated(50),
                                              heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(collectionView.bounds.width),
                                               heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])
        group.interItemSpacing = .fixed(8)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 6
        section.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

        let layout = UICollectionViewCompositionalLayout(section: section)

        return layout
    }

    private func GSection() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalHeight(1.6),
                                              heightDimension: .fractionalHeight(1))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(collectionView.bounds.width),
                                               heightDimension: .fractionalHeight(1))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       subitems: [item])
        group.interItemSpacing = .fixed(8)

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 6
        section.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

        let layout = UICollectionViewCompositionalLayout(section: section)

        return layout
    }

    private func listSection() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let width = environment.container.effectiveContentSize.width
            let isCompact = environment.traitCollection.horizontalSizeClass == .compact
            let groupWidth: CGFloat

            if isCompact {
                groupWidth = max(280, width - 64)
            } else {
                let twoColumnWidth = floor((width - 56) / 2)
                groupWidth = min(430, max(340, twoColumnWidth))
            }

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                  heightDimension: .fractionalHeight(1.0 / 3.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .absolute(groupWidth),
                                                   heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize,
                                                         repeatingSubitem: item,
                                                         count: 3)

            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = isCompact ? .groupPaging : .continuous
            section.interGroupSpacing = isCompact ? 16 : 32
            section.contentInsets = .init(top: 0, leading: 12, bottom: 0, trailing: 12)

            return section
        }

        return layout
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        notes = nil
        items = nil

        task?.cancel()

        guard let progress = self.pageControl?.progress as? UIPageControlTimerProgress else { return }
        progress.currentProgress = 0
    }
}

extension BrowseTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        if let progress = self.pageControl?.progress as? UIPageControlTimerProgress {
            progress.pauseTimer()
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? TopBrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return nil
                // return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? ToWatchBrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return nil
                // return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                let dynamicAction = UIDeferredMenuElement.uncached({ completion in
                    Task {
                        guard let progress = await self.contextMenu.media.progress() else {
                            completion(self.contextMenu.toWatchMenu.children)
                            return
                        }

                        if let nextToRewatch = progress.nextToRewatch {
                            TraktAPIProvider.provider.request(TraktAPIService.episode(id: String(self.contextMenu.media.show!.identifiers.trakt!),
                                                                                      season: nextToRewatch.0.number,
                                                                                      episode: nextToRewatch.1.number),
                                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                                guard let self = self else { return }
                                switch result {
                                case let .success(moyaResponse):
                                    do {
                                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                                        DispatchQueue.main.async {
                                            self.contextMenu.media = episode.mediaModel(given: self.contextMenu.media.show!)
                                            completion(self.contextMenu.toWatchMenu.children)
                                        }
                                    } catch {
                                        print("Error fetching episode \(error)")
                                        DispatchQueue.main.async {
                                            completion(self.contextMenu.toWatchMenu.children)
                                        }
                                    }
                                case let .failure(error):
                                    print("Failed fetching episode \(error)")
                                    DispatchQueue.main.async {
                                        completion(self.contextMenu.toWatchMenu.children)
                                    }
                                }
                            }
                        } else {
                            completion(self.contextMenu.toWatchMenu.children)
                        }
                    }
                })
                return UIMenu(title: "Up Next", image: nil, children: [dynamicAction])
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? StandardHistoryBrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return nil
                // return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? C1BrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return nil
                // return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? G1BrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return nil
                // return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        if let cell = collectionView.cellForItem(at: indexPath) as? ListBrowseCollectionViewCell {
            contextMenu.cell = cell
            contextMenu.controller = presentingViewController

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                return self.contextMenu.previewViewController
            }, actionProvider: { _ in
                return self.contextMenu.menu
            })
        }

        return nil
    }

    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        if let progress = self.pageControl?.progress as? UIPageControlTimerProgress {
            progress.resumeTimer()
        }
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        guard let presentingViewController = presentingViewController else { return }
        presentingViewController.navigationController?.show(controller, sender: self)
    }
}

extension BrowseTableViewCell: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let items = items {
            return items.count
        }

        return 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let media = media(at: indexPath) else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! L1BrowseCollectionViewCell
            return cell
        }

        if reuseIdentifier == "ToWatch" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ToWatch", for: indexPath) as! ToWatchBrowseCollectionViewCell

            cell.presentingViewController = presentingViewController
            cell.actionButtonStyle = actionButtonStyle
            cell.media = media

            return cell
        }

        if reuseIdentifier == "History" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "History", for: indexPath) as! StandardHistoryBrowseCollectionViewCell

            cell.media = media

            return cell
        }

        if reuseIdentifier == "T1" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "T1", for: indexPath) as! TopBrowseCollectionViewCell

            cell.notes = note(at: indexPath)
            cell.media = media
            cell.rank?.text = "\(indexPath.row + 1)"

            return cell
        }
        if reuseIdentifier == "C1" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "C2", for: indexPath) as! C1BrowseCollectionViewCell

            cell.notes = note(at: indexPath)
            cell.media = media

            return cell
        }
        if reuseIdentifier == "G1" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "G1", for: indexPath) as! G1BrowseCollectionViewCell

            cell.presentingViewController = presentingViewController
            cell.actionButtonStyle = actionButtonStyle
            cell.media = media

            return cell
        }
        if reuseIdentifier == "List" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "List", for: indexPath) as! ListBrowseCollectionViewCell

            cell.presentingViewController = presentingViewController
            cell.actionButtonStyle = actionButtonStyle
            cell.media = media
            cell.showsSeparator = indexPath.row % 3 != 2 && indexPath.row + 1 < (items?.count ?? 0)

            return cell
        }
        if notes != nil {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell with notes", for: indexPath) as! L1BrowseCollectionViewCell

            cell.notes = note(at: indexPath)
            cell.media = media

            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! L1BrowseCollectionViewCell

        cell.media = media

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let presentingViewController = presentingViewController else {
            return
        }

        guard let media = media(at: indexPath) else { return }
        let zoomSourceView = zoomSourceView(in: collectionView, at: indexPath)
        let showProgressZoomSourceView = reuseIdentifier == "List" ? zoomSourceView : nil

        if case let .showProgress(show, progress) = media {
            if let nextToRewatch = progress.nextToRewatch {
                TraktAPIProvider.provider.request(TraktAPIService.episode(id: String(show.identifiers.trakt!),
                                                                          season: nextToRewatch.0.number,
                                                                          episode: nextToRewatch.1.number),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                    switch result {
                    case let .success(moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.present(media: episode.mediaModel(given: show),
                                             from: presentingViewController,
                                             zoomSourceView: showProgressZoomSourceView)
                            }
                        } catch {
                            print("Error fetching episode \(error)")
                            DispatchQueue.main.async {
                                self.present(media: show.mediaModel,
                                             from: presentingViewController,
                                             zoomSourceView: showProgressZoomSourceView)
                            }
                        }
                    case let .failure(error):
                        print("Failed fetching episode \(error)")
                        DispatchQueue.main.async {
                            self.present(media: show.mediaModel,
                                         from: presentingViewController,
                                         zoomSourceView: showProgressZoomSourceView)
                        }
                    }
                }
            } else if let episode = progress.nextEpisodeToWatch {
                present(media: episode.mediaModel(given: show),
                        from: presentingViewController,
                        zoomSourceView: showProgressZoomSourceView)
            } else {
                present(media: show.mediaModel,
                        from: presentingViewController,
                        zoomSourceView: showProgressZoomSourceView)
            }
            return
        }

        present(media: media,
                from: presentingViewController,
                zoomSourceView: zoomSourceView)
    }

    private func zoomSourceView(in collectionView: UICollectionView, at indexPath: IndexPath) -> UIView? {
        if let cell = collectionView.cellForItem(at: indexPath) as? ListBrowseCollectionViewCell {
            return cell.poster
        }
        return collectionView.cellForItem(at: indexPath)
    }

    private func present(media: MediaModel, from presentingViewController: UIViewController, zoomSourceView: UIView?) {
        if UIDevice.current.userInterfaceIdiom == .phone, let zoomSourceView {
            presentingViewController.performSegue(withIdentifier: "details-zoom",
                                                  sender: MediaSegueObject(media: media,
                                                                           zoomSourceView: zoomSourceView))
        } else {
            presentingViewController.performSegue(withIdentifier: "details", sender: media)
        }
    }
}

extension BrowseTableViewCell: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let media: MediaModel?
        if let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell {
            media = cell.media
        } else if let cell = collectionView.cellForItem(at: indexPath) as? ListBrowseCollectionViewCell {
            media = cell.media
        } else {
            media = nil
        }
        guard let media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        let media: MediaModel?
        if let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell {
            media = cell.media
        } else if let cell = collectionView.cellForItem(at: indexPath) as? ListBrowseCollectionViewCell {
            media = cell.media
        } else {
            media = nil
        }
        guard let media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let poster: PosterImageView?
        let previewCell: UICollectionViewCell?
        if let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell {
            poster = cell.poster
            previewCell = cell
        } else if let cell = collectionView.cellForItem(at: indexPath) as? ListBrowseCollectionViewCell {
            poster = cell.poster
            previewCell = cell
        } else {
            poster = nil
            previewCell = nil
        }
        guard let poster, let previewCell else { return nil }

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.bounds, to: previewCell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}

extension BrowseTableViewCell: UIPageControlTimerProgressDelegate {

    private func scroll(to page: Int) {
        shouldUpdatePageControl = false
        contentView.isUserInteractionEnabled = false
        collectionView.scrollToItem(at: IndexPath(row: page, section: 0),
                                    at: .centeredVertically,
                                    animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.shouldUpdatePageControl = true
            self.contentView.isUserInteractionEnabled = true
        }
    }

    func pageControlTimerProgress(_ progress: UIPageControlTimerProgress, shouldAdvanceToPage page: Int) -> Bool {
        return true
    }

    func pageControlProgressVisibilityDidChange(_ progress: UIPageControlProgress) {
        if progress.isProgressVisible {
            (progress as? UIPageControlTimerProgress)?.resumeTimer()
        } else {
            (progress as? UIPageControlTimerProgress)?.pauseTimer()
        }
    }

    func pageControlProgress(_ progress: UIPageControlProgress, initialProgressForPage page: Int) -> Float {
        if pageControl!.numberOfPages == 0 { return 0 }
        scroll(to: page)
        return 0
    }
}

extension BrowseTableViewCell: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {

    }
}
