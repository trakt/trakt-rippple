//
//  ImageBrowserViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 21/12/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import Kingfisher
import Moya
import NVActivityIndicatorView
import UIKit

// MARK: - ImageItem

struct ImageItem: Hashable {
    let filePath: String
    let type: ImageType
    let language: String?

    enum ImageType: String, Hashable {
        case poster
        case backdrop
        case logo
        case still
    }
}

// MARK: - ImageBrowserViewController

final class ImageBrowserViewController: UIViewController {
    // MARK: - Public Properties

    var media: MediaModel!

    // MARK: - Private Properties

    private var allImages: [ImageItem] = []
    private var filteredImages: [ImageItem] = []
    private var currentFilter: ImageItem.ImageType?
    private var isLoading = false

    private enum Section: Hashable {
        case content
        case empty
    }

    private enum Item: Hashable {
        case content(ImageItem)
        case empty
    }

    private class ImageBrowserDiffibleDataSource: UICollectionViewDiffableDataSource<Section, Item> {}

    private lazy var collectionView: UICollectionView = {
        let layout = createLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.register(ImageBrowserCell.self, forCellWithReuseIdentifier: ImageBrowserCell.reuseIdentifier)
        collectionView.register(LogoImageBrowserCell.self, forCellWithReuseIdentifier: LogoImageBrowserCell.reuseIdentifier)
        collectionView.register(EmptyCollectionViewCell.self, forCellWithReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier)
        collectionView.register(FilterHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: FilterHeaderView.reuseIdentifier)
        return collectionView
    }()

    private lazy var dataSource = ImageBrowserDiffibleDataSource(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
        guard let self = self else { return UICollectionViewCell() }
        switch item {
        case .content(let imageItem):
            let size = self.calculateImageSize(for: imageItem.type, collectionViewWidth: collectionView.bounds.width)
            if imageItem.type == .logo {
                return self.dequeueLogoCell(at: indexPath, imageItem: imageItem, size: size)
            } else {
                return self.dequeueImageCell(at: indexPath, imageItem: imageItem, size: size)
            }
        case .empty:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmptyCollectionViewCell.reuseIdentifier, for: indexPath) as! EmptyCollectionViewCell
            cell.configure(emoji: "🫥",
                           title: "No image for this title yet",
                           subtitle: nil,
                           body: "This one’s camera-shy for now.")
            return cell
        }
    }

    private lazy var filterStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 8
        stackView.alignment = .fill
        return stackView
    }()

    private lazy var loadingIndicator: NVActivityIndicatorView = {
        let indicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 50, height: 50),
                                                type: .ballScaleMultiple,
                                                color: UIColor(asset: .globalTint),
                                                padding: nil)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Constants

    private enum Constants {
        static let posterAspectRatio: CGFloat = 1.5
        static let backdropAspectRatio: CGFloat = 1.78
        static let posterColumns: CGFloat = 3.0
        static let backdropColumns: CGFloat = 2.0
        static let logoColumns: CGFloat = 2.0
        static let cellSpacing: CGFloat = 4.0
        static let sectionInsets: CGFloat = 8.0
        static let headerHeight: CGFloat = 60.0
        static let logoPadding: CGFloat = 10.0
        static let cellSpacingTotal: CGFloat = 16.0
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationTitle()
        setupCloseButton()
        setupUI()
        loadImages()
    }

    // MARK: - Setup

    private func setupNavigationTitle() {
        navigationItem.style = .browser
        navigationItem.largeTitleDisplayMode = .never
        updateNavigationTitle()
    }

    private func setupCloseButton() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close,
                                                           target: self,
                                                           action: #selector(close))
    }

    @objc private func close() {
        dismiss(animated: true, completion: nil)
    }

    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        setupFilterButtons()
        configureDataSource()
    }

    private func configureDataSource() {
        dataSource.supplementaryViewProvider = { [weak self] collectionView, kind, indexPath in
            guard let self = self else { return nil }
            guard kind == UICollectionView.elementKindSectionHeader else { return nil }
            guard let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: FilterHeaderView.reuseIdentifier,
                for: indexPath
            ) as? FilterHeaderView else {
                return nil
            }

            let filters = self.availableFilters()
            headerView.configure(with: filters.count > 1 ? self.filterStackView : nil)
            return headerView
        }

        applySnapshot(animatingDifferences: false, forceHideEmpty: true)
    }

    private func setupFilterButtons() {
        let filters = availableFilters()
        filterStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let defaultFilterType = defaultFilter()
        currentFilter = defaultFilterType

        for filterType in filters {
            let button = createFilterButton(for: filterType, isSelected: filterType == defaultFilterType)
            filterStackView.addArrangedSubview(button)
        }
    }

    private func createFilterButton(for filterType: ImageItem.ImageType, isSelected: Bool) -> UIButton {
        var configuration = UIButton.Configuration.borderedProminent()
        configuration.title = filterType.rawValue.capitalized

        let button = UIButton(configuration: configuration)
        button.preferredBehavioralStyle = .pad
        button.tag = filterType.hashValue
        button.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
        updateButtonAppearance(button: button, isSelected: isSelected)
        return button
    }

    // MARK: - Navigation

    private func updateNavigationTitle() {
        guard let media = media else { return }

        switch media {
        case .movie:
            navigationItem.title = "Movie Images"
            navigationItem.subtitle = media.mediaTitle
        case .show:
            navigationItem.title = "Show Images"
            navigationItem.subtitle = media.mediaTitle
        case .episode:
            navigationItem.title = "Episode Images"
            navigationItem.subtitle = media.mediaTitle
        case .season:
            navigationItem.title = "Season Images"
            navigationItem.subtitle = media.mediaTitle
        case .list, .showProgress:
            break
        }
    }

    // MARK: - Filter Management

    private func defaultFilter() -> ImageItem.ImageType {
        guard let media = media else { return .poster }

        switch media {
        case .movie, .show, .season:
            return .poster
        case .episode:
            return .still
        case .list, .showProgress:
            return .poster
        }
    }

    private func availableFilters() -> [ImageItem.ImageType] {
        guard let media = media else { return [] }

        switch media {
        case .movie, .show:
            return [.poster, .backdrop, .logo]
        case .season:
            return [.poster]
        case .episode:
            return [.still]
        case .list, .showProgress:
            return []
        }
    }

    @objc private func filterButtonTapped(_ sender: UIButton) {
        let filters = availableFilters()
        guard let filterType = filters.first(where: { $0.hashValue == sender.tag }) else { return }

        currentFilter = filterType

        for subview in filterStackView.arrangedSubviews {
            if let button = subview as? UIButton {
                updateButtonAppearance(button: button, isSelected: button.tag == sender.tag)
            }
        }

        applyFilter()
    }

    private func updateButtonAppearance(button: UIButton, isSelected: Bool) {
        UIView.performWithoutAnimation {
            if isSelected {
                var configuration = UIButton.Configuration.borderedTinted()
                configuration.title = button.configuration?.title
                configuration.cornerStyle = .capsule
                button.configuration = configuration
            } else {
                var configuration = UIButton.Configuration.bordered()
                configuration.title = button.configuration?.title
                configuration.cornerStyle = .capsule
                button.configuration = configuration
            }
        }
    }

    private func applyFilter() {
        if let filter = currentFilter {
            filteredImages = allImages.filter { $0.type == filter }
        } else {
            filteredImages = allImages
        }

        applySnapshot(animatingDifferences: false)
        updateLayout()
    }

    private func updateLayout() {
        let newLayout = createLayout()
        collectionView.setCollectionViewLayout(newLayout, animated: false)
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.adjustedContentInset.top), animated: false)
    }

    private func applySnapshot(animatingDifferences: Bool = true, forceHideEmpty: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        let shouldShowEmpty = !forceHideEmpty && !isLoading && filteredImages.isEmpty

        if shouldShowEmpty {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty], toSection: .empty)
        } else {
            snapshot.appendSections([.content])
            snapshot.appendItems(filteredImages.map { .content($0) }, toSection: .content)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    // MARK: - Layout

    private func createLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let self = self else { return nil }
            guard let section = self.dataSource.sectionIdentifier(for: sectionIndex) else {
                return self.makeContentSection(for: self.currentFilter ?? self.defaultFilter())
            }

            switch section {
            case .content:
                return self.makeContentSection(for: self.currentFilter ?? self.defaultFilter())
            case .empty:
                return self.makeEmptySection()
            }
        }
    }

    private func makeContentSection(for filterType: ImageItem.ImageType) -> NSCollectionLayoutSection {
        let (itemSize, groupSize) = layoutSizes(for: filterType)

        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(
            top: Constants.cellSpacing,
            leading: Constants.cellSpacing,
            bottom: Constants.cellSpacing,
            trailing: Constants.cellSpacing
        )

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: Constants.sectionInsets,
            leading: Constants.sectionInsets,
            bottom: Constants.sectionInsets,
            trailing: Constants.sectionInsets
        )
        section.boundarySupplementaryItems = headerSupplementaryItems()
        return section
    }

    private func makeEmptySection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                              heightDimension: .estimated(140))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(140))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 100.0,
            leading: Constants.sectionInsets,
            bottom: Constants.sectionInsets,
            trailing: Constants.sectionInsets
        )
        section.boundarySupplementaryItems = headerSupplementaryItems()
        return section
    }

    private func headerSupplementaryItems() -> [NSCollectionLayoutBoundarySupplementaryItem] {
        guard availableFilters().count > 1 else { return [] }
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(Constants.headerHeight)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        return [header]
    }

    private func layoutSizes(for filterType: ImageItem.ImageType) -> (NSCollectionLayoutSize, NSCollectionLayoutSize) {
        switch filterType {
        case .poster:
            let fractionalWidth = 1.0 / Constants.posterColumns
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(fractionalWidth),
                heightDimension: .fractionalWidth(fractionalWidth * Constants.posterAspectRatio)
            )
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(fractionalWidth * Constants.posterAspectRatio)
            )
            return (itemSize, groupSize)

        case .backdrop, .still:
            let fractionalWidth = 1.0 / Constants.backdropColumns
            let aspectRatio = 1.0 / Constants.backdropAspectRatio
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(fractionalWidth),
                heightDimension: .fractionalWidth(fractionalWidth * aspectRatio)
            )
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(fractionalWidth * aspectRatio)
            )
            return (itemSize, groupSize)

        case .logo:
            let fractionalWidth = 1.0 / Constants.logoColumns
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(fractionalWidth),
                heightDimension: .fractionalWidth(fractionalWidth)
            )
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalWidth(fractionalWidth)
            )
            return (itemSize, groupSize)
        }
    }

    // MARK: - Data Loading

    private func loadImages() {
        guard !isLoading else { return }
        guard let media = media, let tmdbId = media.tmdbId else {
            showError("No TMDb identifier available.")
            return
        }

        isLoading = true
        loadingIndicator.startAnimating()
        applySnapshot(animatingDifferences: false)

        let service = makeService(for: media, tmdbId: tmdbId)
        guard let service = service else { return }

        TmdbAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false
                self.loadingIndicator.stopAnimating()
            }

            switch result {
            case .success(let moyaResponse):
                self.handleSuccessResponse(moyaResponse)
            case .failure(let error):
                print("Error loading images: \(error)")
                DispatchQueue.main.async {
                    self.showError("Failed to load images.")
                }
            }
        }
    }

    private func makeService(for media: MediaModel, tmdbId: Int64) -> TmdbAPIService? {
        switch media {
        case .movie:
            return .movieImages(tmdbId)
        case .show:
            return .tvImages(tmdbId)
        case .episode(let episode, let show):
            guard let showTmdbId = show.identifiers.tmdb else {
                showError("No TMDb identifier available for show.")
                isLoading = false
                loadingIndicator.stopAnimating()
                return nil
            }
            return .episode(showTmdbId, episode.season, episode.number)
        case .season(let season, let show):
            guard let showTmdbId = show.identifiers.tmdb else {
                showError("No TMDb identifier available for show.")
                isLoading = false
                loadingIndicator.stopAnimating()
                return nil
            }
            return .season(showTmdbId, season.number)
        case .list, .showProgress:
            showError("Images not available for this media type.")
            isLoading = false
            loadingIndicator.stopAnimating()
            return nil
        }
    }

    private func handleSuccessResponse(_ moyaResponse: Response) {
        do {
            let response = try moyaResponse.filterSuccessfulStatusCodes()
            let loadedImages = parseImages(from: response)

            DispatchQueue.main.async {
                let sortedImages = self.sortImages(loadedImages)
                self.allImages = sortedImages
                self.applyFilter()
            }
        } catch {
            print("Error decoding images: \(error)")
            DispatchQueue.main.async {
                self.showError("Failed to load images.")
            }
        }
    }

    private func parseImages(from response: Response) -> [ImageItem] {
        guard let media = media else { return [] }

        var loadedImages: [ImageItem] = []

        switch media {
        case .movie, .show:
            if let images = try? response.map(PostersImages.self, using: TmdbAPIProvider.decoder) {
                loadedImages.append(contentsOf: images.posters.map { ImageItem(filePath: $0.filePath, type: .poster, language: $0.language) })
                loadedImages.append(contentsOf: images.backdrops.map { ImageItem(filePath: $0.filePath, type: .backdrop, language: $0.language) })
                loadedImages.append(contentsOf: images.logos.map { ImageItem(filePath: $0.filePath, type: .logo, language: $0.language) })
            }
        case .season:
            if let images = try? response.map(PostersOnlyImages.self, using: TmdbAPIProvider.decoder) {
                loadedImages.append(contentsOf: images.posters.map { ImageItem(filePath: $0.filePath, type: .poster, language: $0.language) })
            }
        case .episode:
            if let images = try? response.map(StillsImages.self, using: TmdbAPIProvider.decoder) {
                loadedImages.append(contentsOf: images.stills.map { ImageItem(filePath: $0.filePath, type: .still, language: nil) })
            }
        default:
            break
        }

        return loadedImages
    }

    // MARK: - Image URL

    private func imageURL(for imageItem: ImageItem, size: CGSize) -> URL? {
        let imageType: ImagesManager.ImageType
        switch imageItem.type {
        case .poster:
            imageType = .poster
        case .backdrop:
            imageType = .backdrop
        case .logo:
            imageType = .logo
        case .still:
            imageType = .backdrop // Stills use backdrop sizing
        }
        return ImagesManager.shared.imageURL(with: imageItem.filePath, with: size, for: imageType)
    }

    // MARK: - Image Sorting

    private func sortImages(_ images: [ImageItem]) -> [ImageItem] {
        var grouped: [ImageItem.ImageType: [ImageItem]] = [:]
        for image in images {
            grouped[image.type, default: []].append(image)
        }

        var sorted: [ImageItem] = []
        let typeOrder: [ImageItem.ImageType] = [.poster, .backdrop, .logo, .still]

        for type in typeOrder {
            guard var items = grouped[type] else { continue }
            items.sort { compareImages($0, $1, for: type) }
            sorted.append(contentsOf: items)
        }

        return sorted
    }

    private func compareImages(_ item1: ImageItem, _ item2: ImageItem, for type: ImageItem.ImageType) -> Bool {
        let language1 = item1.language
        let language2 = item2.language

        switch type {
        case .poster:
            // Posters: English first, then no-language, then others
            if language1 == "en" && language2 != "en" { return true }
            if language1 != "en" && language2 == "en" { return false }
            if language1 == nil && language2 != nil && language2 != "en" { return true }
            if language1 != nil && language1 != "en" && language2 == nil { return false }
            return false

        case .backdrop, .still:
            // Backdrops and stills: No-language first, then English, then others
            if language1 == nil && language2 != nil { return true }
            if language1 != nil && language2 == nil { return false }
            if language1 == "en" && language2 != nil && language2 != "en" { return true }
            if language1 != nil && language1 != "en" && language2 == "en" { return false }
            return false

        case .logo:
            // Logos: English first, then others
            if language1 == "en" && language2 != "en" { return true }
            if language1 != "en" && language2 == "en" { return false }
            return false
        }
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Context Menu Actions

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
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.present(activityViewController)
    }
}

// MARK: - Collection View Cells

extension ImageBrowserViewController {
    private func calculateImageSize(for type: ImageItem.ImageType, collectionViewWidth: CGFloat) -> CGSize {
        switch type {
        case .poster:
            let cellSize = (collectionViewWidth / Constants.posterColumns) - Constants.cellSpacingTotal
            return CGSize(width: cellSize, height: cellSize * Constants.posterAspectRatio)
        case .backdrop, .still:
            let cellSize = (collectionViewWidth / Constants.backdropColumns) - Constants.cellSpacingTotal
            return CGSize(width: cellSize, height: cellSize * 9.0 / 16.0)
        case .logo:
            let cellSize = (collectionViewWidth / Constants.logoColumns) - Constants.cellSpacingTotal
            return CGSize(width: cellSize, height: cellSize)
        }
    }

    private func dequeueLogoCell(at indexPath: IndexPath, imageItem: ImageItem, size: CGSize) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LogoImageBrowserCell.reuseIdentifier, for: indexPath) as? LogoImageBrowserCell else {
            fatalError("Failed to dequeue LogoImageBrowserCell")
        }

        cell.imageView.kf.cancelDownloadTask()
        cell.imageView.image = nil

        if let url = imageURL(for: imageItem, size: size) {
            cell.configure(with: url)
        }

        return cell
    }

    private func dequeueImageCell(at indexPath: IndexPath, imageItem: ImageItem, size: CGSize) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageBrowserCell.reuseIdentifier, for: indexPath) as? ImageBrowserCell else {
            fatalError("Failed to dequeue ImageBrowserCell")
        }

        cell.imageView.kf.cancelDownloadTask()
        cell.imageView.image = nil
        cell.imageView.backgroundColor = .tertiarySystemFill

        if let url = imageURL(for: imageItem, size: size) {
            cell.configure(with: url)
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension ImageBrowserViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        guard let selectedItem = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case .content(let selectedImage) = selectedItem else { return }

        let fullScreenVC = FullScreenImageViewController()
        fullScreenVC.images = filteredImages
        fullScreenVC.currentIndex = filteredImages.firstIndex(of: selectedImage) ?? 0
        fullScreenVC.imageURLProvider = { [weak self] imageItem, size in
            guard let self = self else { return nil }
            return self.imageURL(for: imageItem, size: size)
        }
        fullScreenVC.previewImageProvider = { [weak self] imageItem in
            guard let self = self else { return nil }
            return self.zoomPreviewImage(for: imageItem)
        }

        let zoomOptions = UIViewController.Transition.ZoomOptions()
        zoomOptions.interactiveDismissShouldBegin = { [weak fullScreenVC] context in
            fullScreenVC?.shouldBeginInteractiveDismiss(
                location: context.location,
                velocity: context.velocity,
                willBegin: context.willBegin
            ) ?? context.willBegin
        }
        zoomOptions.alignmentRectProvider = { context in
            guard let fullScreenVC = context.zoomedViewController as? FullScreenImageViewController else {
                return nil
            }
            return fullScreenVC.zoomTransitionAlignmentRect()
        }

        fullScreenVC.modalPresentationStyle = .fullScreen
        fullScreenVC.preferredTransition = .zoom(options: zoomOptions, sourceViewProvider: { [weak self] context in
            guard let self = self else { return nil }
            guard let fullScreenVC = context.zoomedViewController as? FullScreenImageViewController,
                  let imageItem = fullScreenVC.currentImageItem else {
                return nil
            }
            return self.zoomSourceView(for: imageItem)
        })
        present(fullScreenVC, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }

        let image: UIImage?
        if let imageCell = cell as? ImageBrowserCell {
            image = imageCell.imageView.image
        } else if let logoCell = cell as? LogoImageBrowserCell {
            image = logoCell.imageView.image
        } else {
            return nil
        }

        guard let image = image else { return nil }

        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { _ -> UIMenu? in
            let copyAction = UIAction(
                title: "Copy Image",
                image: UIImage(systemName: "doc.on.doc"),
                identifier: nil
            ) { _ in
                UIPasteboard.general.image = image
            }

            let saveAction = UIAction(
                title: "Save Image",
                image: UIImage(systemName: "square.and.arrow.down"),
                identifier: nil
            ) { _ in
                self.writeToPhotoAlbum(image: image)
            }

            let shareAction = UIAction(
                title: "Share Image",
                image: UIImage(systemName: "square.and.arrow.up"),
                identifier: nil
            ) { _ in
                self.share(image: image)
            }

            return UIMenu(children: [copyAction, saveAction, shareAction])
        }
    }

    /*
     func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
         guard let indexPath = configuration.identifier as? IndexPath,
               let cell = collectionView.cellForItem(at: indexPath) else { return nil }

         let previewView: UIView?
         if let imageCell = cell as? ImageBrowserCell {
             previewView = imageCell.imageView
         } else if let logoCell = cell as? LogoImageBrowserCell {
             previewView = logoCell.imageView
         } else {
             return nil
         }

         guard let previewView = previewView else { return nil }
         return UITargetedPreview(view: previewView, parameters: UIPreviewParameters())
     }

     func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
         guard let indexPath = configuration.identifier as? IndexPath,
               let cell = collectionView.cellForItem(at: indexPath) else { return nil }

         let previewView: UIView?
         if let imageCell = cell as? ImageBrowserCell {
             previewView = imageCell.imageView
         } else if let logoCell = cell as? LogoImageBrowserCell {
             previewView = logoCell.imageView
         } else {
             return nil
         }

         guard let previewView = previewView else { return nil }
         return UITargetedPreview(view: previewView, parameters: UIPreviewParameters())
     }
      */
}

// MARK: - Zoom Transition

extension ImageBrowserViewController {
    private func zoomSourceView(for imageItem: ImageItem) -> UIView? {
        zoomSourceCell(for: imageItem)
    }

    private func zoomPreviewImage(for imageItem: ImageItem) -> UIImage? {
        guard let cell = zoomSourceCell(for: imageItem) else { return nil }

        if let imageCell = cell as? ImageBrowserCell {
            return imageCell.imageView.image
        } else if let logoCell = cell as? LogoImageBrowserCell {
            return logoCell.imageView.image
        } else {
            return nil
        }
    }

    private func zoomSourceCell(for imageItem: ImageItem) -> UICollectionViewCell? {
        guard let indexPath = dataSource.indexPath(for: .content(imageItem)) else { return nil }

        if collectionView.cellForItem(at: indexPath) == nil {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            collectionView.layoutIfNeeded()
        }

        return collectionView.cellForItem(at: indexPath)
    }
}

// MARK: - FilterHeaderView

final class FilterHeaderView: UICollectionReusableView {
    static let reuseIdentifier = "FilterHeaderView"

    private var filterStackView: UIStackView?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with stackView: UIStackView?) {
        filterStackView?.removeFromSuperview()
        filterStackView = nil

        guard let stackView = stackView else { return }

        if stackView.superview != self {
            stackView.removeFromSuperview()
            filterStackView = stackView
            addSubview(stackView)

            NSLayoutConstraint.activate([
                stackView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
                stackView.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }
}

// MARK: - ImageBrowserCell

final class ImageBrowserCell: UICollectionViewCell {
    static let reuseIdentifier = "ImageBrowserCell"

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .tertiarySystemFill
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        imageView.layer.cornerRadius = ViewRadius.large.rawValue
        imageView.layer.cornerCurve = .continuous
        imageView.layer.masksToBounds = true
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = UIColor.tertiarySystemFill.cgColor
    }

    func configure(with url: URL) {
        imageView.kf.setImage(with: url, placeholder: nil)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        imageView.backgroundColor = .tertiarySystemFill
    }
}

// MARK: - LogoImageBrowserCell

final class LogoImageBrowserCell: UICollectionViewCell {
    static let reuseIdentifier = "LogoImageBrowserCell"

    let imageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = .clear
        return iv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        let padding: CGFloat = 10.0
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: padding),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: padding),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -padding),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -padding)
        ])

        contentView.layer.cornerRadius = ViewRadius.large.rawValue
        contentView.layer.cornerCurve = .continuous
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.tertiarySystemFill.cgColor

        imageView.layer.masksToBounds = false
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOffset = CGSize(width: 0, height: 2)
        imageView.layer.shadowRadius = 8
        imageView.layer.shadowOpacity = 0.3
    }

    func configure(with url: URL) {
        contentView.backgroundColor = .secondarySystemBackground
        imageView.kf.setImage(with: url, placeholder: nil)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        contentView.backgroundColor = .secondarySystemBackground
    }
}
