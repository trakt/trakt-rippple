//
//  GridViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 21/06/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

import NVActivityIndicatorView

import Moya

private final class LoadingSupplementaryView: UICollectionReusableView {

    static let reuseIdentifier = "LoadingSupplementaryView"

    let activityIndicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 80, height: 80),
                                                    type: .ballScaleMultiple,
                                                    color: UIColor(asset: .globalTint),
                                                    padding: nil)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    func configure() {
        backgroundColor = .clear
        addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            activityIndicator.heightAnchor.constraint(equalToConstant: 50),
            activityIndicator.widthAnchor.constraint(equalToConstant: 50)])
        activityIndicator.startAnimating()
    }
}

struct MediaSegueObject {
    let media: MediaModel
    let zoomSourceView: UIView?
}

final class GridViewController: UICollectionViewController {
    var savedFilter: SavedFilter!

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        cancelCancellable()
        print("deiniting GridViewController")
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private var edgeToEdgeLayout = true {
        didSet {
            UserDefaults.standard.set(edgeToEdgeLayout, forKey: "GridViewController.edgeToEdgeLayout")
            UserDefaults.standard.synchronize()
        }
    }

    private var possibleValuesForItemsPerRow: [Int] = {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return [0, 1, 2, 3, 4, 5, 6]
        } else if UIDevice.current.userInterfaceIdiom == .pad {
            return [0, 4, 6, 8, 10, 12, 14]
        } else { // .mac
            return [0, 6, 8, 10, 12, 14, 16, 18]
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        title = "Browse"

        dataSource.supplementaryViewProvider = { (collectionView: UICollectionView, kind: String, indexPath: IndexPath) -> UICollectionReusableView? in
            let header: LoadingSupplementaryView = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                                                       withReuseIdentifier: LoadingSupplementaryView.reuseIdentifier,
                                                                                                       for: indexPath) as! LoadingSupplementaryView
            return header
        }

        let storedItemsPerRow = UserDefaults.standard.integer(forKey: "GridViewController.itemsPerRow")
        if possibleValuesForItemsPerRow.firstIndex(of: storedItemsPerRow) != nil {
            itemsPerRow = storedItemsPerRow
        }
        edgeToEdgeLayout = UserDefaults.standard.bool(forKey: "GridViewController.edgeToEdgeLayout")

        collectionView.collectionViewLayout = compositionalLayout()

        collectionView.register(UINib(nibName: "L1BrowseCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cell")
        collectionView.register(EmptyCollectionViewCell.self, forCellWithReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier)
        collectionView.register(LoadingSupplementaryView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: LoadingSupplementaryView.reuseIdentifier)

        collectionView.allowsFocus = false
        collectionView.dragDelegate = self

        collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")

        dragEnabledReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.collectionView?.dragInteractionEnabled = UserDefaults.standard.bool(forKey: "GeneralSettings.dragging")
        }.disposed(by: disposeBag)

        var snapshot = dataSource.snapshot()
        snapshot.appendSections([.content, .empty])
        dataSource.apply(snapshot, animatingDifferences: false)

        reloadData()

        if navigationController?.viewControllers.first == self {
            title = "Wall"
        }

        onMovieCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path == "/users/me/collection/movies" {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path == "/users/me/collection/shows" {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }
        }.disposed(by: disposeBag)

        onWatchlistChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path == "/sync/watchlist" {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }
        }.disposed(by: disposeBag)

        onRecommendedChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path == "/sync/favorites" {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }
        }.disposed(by: disposeBag)

        onListChangedReceiver.hotOnly().listen { [weak self] lists in
            guard let self = self else { return }
            for list in lists where self.savedFilter.path.localizedStandardContains("/lists/\(list.identifiers.trakt!)") {
                DispatchQueue.main.async {
                    self.reloadData()
                }
            }
        }.disposed(by: disposeBag)

        onWatchedMoviesChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path != "/users/me/watched/movies" { return }
            DispatchQueue.main.async {
                self.reloadData()
            }
        }.disposed(by: disposeBag)

        onWatchedShowsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            if self.savedFilter.path != "/users/me/watched/shows" { return }
            DispatchQueue.main.async {
                self.reloadData()
            }
        }.disposed(by: disposeBag)
    }

    func reloadData() {
        reloadMenu()

        navigationItem.subtitle = "Loading..."
        nextPage = nil

        _Concurrency.Task.init {
            do {
                let mediaCollection = try await self.fetch(filter: savedFilter, pageInfo: PageInfo.firstPage(with: 100)).compactMap { MediaModel(item: $0) }
                self.rebuildDatasource(with: mediaCollection, appending: false)
                navigationItem.subtitle = savedFilter.name
            } catch {
                print("error fetching : \(error)")
                navigationItem.subtitle = "\(error)"
            }
        }
    }

    private func reloadMenu() {
        let gridSizes = possibleValuesForItemsPerRow
        var actions = [UIAction]()
        for gridSize in gridSizes {
            let title = if gridSize == 0 {
                "Automatic"
            } else {
                "\(gridSize) per line"
            }
            let action = UIAction(title: title, state: gridSize == itemsPerRow ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                if self.itemsPerRow != gridSize {
                    self.itemsPerRow = gridSize
                    self.collectionView.setCollectionViewLayout(self.compositionalLayout(),
                                                                animated: true)
                    self.reloadMenu()
                }
            }
            actions.append(action)
        }

        let action = UIAction(title: "Edge-to-Edge Layout", state: edgeToEdgeLayout == true ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.edgeToEdgeLayout = !self.edgeToEdgeLayout
            self.collectionView.setCollectionViewLayout(self.compositionalLayout(),
                                                        animated: true)
            var snapshot = self.dataSource.snapshot()
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
            self.dataSource.apply(snapshot, animatingDifferences: true)
            self.reloadMenu()
        }

        let displayOptions = UIBarButtonItem(title: "Display Options",
                                             image: UIImage(systemName: "line.3.horizontal.decrease"),
                                             menu: UIMenu(children: [UIMenu(options: .displayInline,
                                                                              children: actions), action]))

        actions = [UIAction]()
        let shelved = savedFilter.isShelved

        let shelfOnTop = UIAction(title: "Shelf On Top",
                                  image: UIImage(systemName: "text.line.first.and.arrowtriangle.forward")) { [weak self] _ in
            guard let self = self else { return }
            self.savedFilter.shelf(onTop: true)
            self.reloadMenu()
        }
        let shelfUnder = UIAction(title: "Shelf Under",
                                  image: UIImage(systemName: "text.line.last.and.arrowtriangle.forward")) { [weak self] _ in
            guard let self = self else { return }
            self.savedFilter.shelf(onTop: false)
            self.reloadMenu()
        }

        let unshelf = UIAction(title: "Remove from Shelf",
                               image: UIImage(systemName: "minus.circle.fill"),
                               attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.savedFilter.unshelf()
            self.reloadMenu()
        }

        if shelved {
            actions = [unshelf]
        } else {
            actions = [shelfOnTop, shelfUnder]
        }

        let more = UIBarButtonItem(title: "More",
                                             image: UIImage(systemName: "ellipsis"),
                                             menu: UIMenu(options: .displayInline,
                                                                            children: actions))

        if let wallViewController = navigationController as? WallViewController {
            let wallFilter = UIBarButtonItem(title: "Filter",
                                             image: UIImage(systemName: "slider.horizontal.3"),
                                             menu: wallViewController.filterMenu())

            navigationItem.rightBarButtonItems = [wallFilter, .fixedSpace(), displayOptions]
        } else {
            navigationItem.rightBarButtonItems = [more, .fixedSpace(), displayOptions]
        }
    }

    private func rebuildDatasource(with mediaCollection: [MediaModel], appending: Bool = true) {
        var snapshot = dataSource.snapshot()

        // Reset content items if not appending
        if !appending {
            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .content))
        }

        // Append content items
        for media in mediaCollection {
            snapshot.appendItems([.content(media)], toSection: .content)
        }

        // Manage empty section items
        let isEmpty = snapshot.itemIdentifiers(inSection: .content).isEmpty
        // Clear previous empty items
        snapshot.deleteItems(snapshot.itemIdentifiers(inSection: .empty))
        if isEmpty {
            snapshot.appendItems([.empty("🫙", "Nothing here", "We couldn't find anything right now.", "Try adjusting your filters or come back later.")], toSection: .empty)
        }

        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: true)
        }
    }

    private lazy var itemsPerRow = 0 {
        didSet {
            UserDefaults.standard.set(itemsPerRow, forKey: "GridViewController.itemsPerRow")
            UserDefaults.standard.synchronize()
        }
    }
    private func compositionalLayout() -> UICollectionViewCompositionalLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }
            guard let section = self.dataSource.sectionIdentifier(for: sectionIndex) else {
                // Fallback to content layout
                return self.makeContentSection(environment: environment)
            }
            switch section {
            case .content:
                return self.makeContentSection(environment: environment)
            case .empty:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                      heightDimension: .estimated(100))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                       heightDimension: .estimated(100))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                return section
            }
        }
        return layout
    }

    private func makeContentSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemsPerRow: Int = if itemsPerRow == 0 {
            Int(round(environment.container.effectiveContentSize.width/110.0))
        } else {
            itemsPerRow
        }

        let itemInset = edgeToEdgeLayout ? 0.0 : 6.0
        let sectionInset = edgeToEdgeLayout ? 0.0 : 6.0

        let dimention: NSCollectionLayoutDimension = if edgeToEdgeLayout {
            .absolute(environment.container.effectiveContentSize.width/CGFloat(itemsPerRow))
        } else {
            .fractionalWidth(1/CGFloat(itemsPerRow))
        }
        let itemSize = NSCollectionLayoutSize(widthDimension: dimention,
                                              heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                               heightDimension: .estimated(100))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize,
                                                       repeatingSubitem: item,
                                                       count: itemsPerRow)
        group.interItemSpacing = .fixed(itemInset)

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: sectionInset,
                                                        leading: sectionInset,
                                                        bottom: sectionInset,
                                                        trailing: sectionInset)

        let footerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                heightDimension: .absolute(80.0))
        let footer = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: footerSize,
                                                                 elementKind: UICollectionView.elementKindSectionFooter,
                                                                 alignment: .bottom)
        section.boundarySupplementaryItems = [footer]
        section.interGroupSpacing = itemInset
        return section
    }

    enum Section: Hashable {
        case content
        case empty
    }

    enum Wrapper: Hashable {
        case content(MediaModel)
        case empty(String, String, String?, String)
    }

    private class GridViewDiffibleDataSource: UICollectionViewDiffableDataSource<Section, Wrapper> { }

    private lazy var dataSource = GridViewDiffibleDataSource(collectionView: collectionView) { collectionView, indexPath, wrapper in
        switch wrapper {
        case .content(let media):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! L1BrowseCollectionViewCell
            cell.media = media
            cell.edgeToEdgeLayout = self.edgeToEdgeLayout
            return cell
        case .empty(let emoji, let title, let subtitle, let body):
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier, for: indexPath) as! EmptyCollectionViewCell
            cell.configure(emoji: emoji, title: title, subtitle: subtitle, body: body)
            return cell
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        let wrapper = dataSource.itemIdentifier(for: indexPath)
        guard case let .content(media) = wrapper else { return }

        if media.season != nil {
            performSegue(withIdentifier: "comments", sender: media)
        } else {
            if UIDevice.current.userInterfaceIdiom == .phone {
                performSegue(withIdentifier: "details-zoom", sender: MediaSegueObject(media: media,
                                                                                 zoomSourceView: collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell))
            } else {
                performSegue(withIdentifier: "details", sender: media)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
                  let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: .media(media))
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaSegueObject {
            mediaViewController.media = media.media
            if let zoomSourceView = media.zoomSourceView {
                mediaViewController.preferredTransition = .zoom { _ in
                    zoomSourceView
                }
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell
        contextMenu.cell = cell
        contextMenu.controller = presentingViewController

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            return self.contextMenu.previewViewController
        }, actionProvider: { _ in
            return self.contextMenu.menu
        })
    }

    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        if let cell = contextMenu.cell {
            cell.layer.zPosition = 100
        }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        if let cell = contextMenu.cell {
            cell.layer.zPosition = 0
        }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }
        guard let presentingViewController = presentingViewController else { return }
        presentingViewController.navigationController?.show(controller, sender: self)
    }

    private var nextPage: PageInfo?
    private func fetch(filter: SavedFilter, pageInfo: PageInfo) async throws -> [MediaItem] {
        let result: [MediaItem] = try await withCheckedThrowingContinuation { continuation in
            cancellable = TraktAPIProvider.provider.request(.savedFilter(section: filter.section,
                                                                         path: filter.path,
                                                                         query: filter.query,
                                                                         pageInfo: pageInfo),
                                                            callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        if let response = response.response,
                           let pageInfo = PageInfo(headers: response.allHeaderFields)?.nextPage {
                            if pageInfo.page <= pageInfo.pageCount {
                                self.nextPage = pageInfo
                            }
                        }

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

    override func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        guard let loadingSupplementaryView = view as? LoadingSupplementaryView else { return }
        guard let theNextPageToLoad = nextPage else {
            loadingSupplementaryView.activityIndicator.isHidden = true
            return
        }
        nextPage = nil
        if theNextPageToLoad.page > theNextPageToLoad.pageCount {
            loadingSupplementaryView.activityIndicator.isHidden = true
            return
        }
        loadingSupplementaryView.activityIndicator.isHidden = false

        _Concurrency.Task.init {
            do {
                let mediaCollection = try await self.fetch(filter: savedFilter, pageInfo: theNextPageToLoad).compactMap { MediaModel(item: $0) }
                self.rebuildDatasource(with: mediaCollection)
                loadingSupplementaryView.activityIndicator.isHidden = true
            } catch {
                print("error fetching : \(error)")
                loadingSupplementaryView.activityIndicator.isHidden = true
            }
        }
    }
}

extension GridViewController: UICollectionViewDragDelegate {
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell else { return [] }
        guard let media = cell.media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, itemsForAddingTo session: UIDragSession, at indexPath: IndexPath, point: CGPoint) -> [UIDragItem] {
        guard let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell else { return [] }
        guard let media = cell.media else { return [] }

        let itemProvider = NSItemProvider(object: media.traktWebsiteMediaLink! as NSURL)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = media

        return [dragItem]
    }

    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? L1BrowseCollectionViewCell else { return nil }
        guard let poster = cell.poster else { return nil }

        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: poster.convert(poster.frame, to: cell), cornerRadius: poster.layer.cornerRadius)
        return parameters
    }
}
