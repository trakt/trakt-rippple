//
//  FullScreenImageViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 21/12/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import UIKit
import Kingfisher

// MARK: - FullScreenImageViewController

final class FullScreenImageViewController: UIViewController {

    // MARK: - Public Properties

    var images: [ImageItem] = []
    var currentIndex: Int = 0
    var imageURLProvider: ((ImageItem, CGSize) -> URL?)?
    var previewImageProvider: ((ImageItem) -> UIImage?)?

    var currentImageItem: ImageItem? {
        guard images.indices.contains(currentIndex) else { return nil }
        return images[currentIndex]
    }

    // MARK: - Private Properties

    private var pageScrollView: UIScrollView!
    private var pageControl: UIPageControl!
    private var closeButton: UIButton!
    private var menuButton: UIButton!

    private var containerView: UIView!
    private var loadedViews: [Int: ZoomableScrollView] = [:]
    private var placeholderViews: [Int: UIView] = [:]
    private var hasLoadedInitialImages = false
    private var hasScrolledToInitialIndex = false
    private var imageSize: CGSize = .zero

    // MARK: - Constants

    fileprivate enum Constants {
        static let buttonSize: CGFloat = 40.0
        static let buttonCornerRadius: CGFloat = 20.0
        static let buttonTopPadding: CGFloat = 16.0
        static let buttonHorizontalPadding: CGFloat = 16.0
        static let pageControlBottomPadding: CGFloat = 20.0
        static let animationDuration: TimeInterval = 0.2
        static let imageFadeDuration: TimeInterval = 0.25
        static let minimumZoomScale: CGFloat = 1.0
        static let maximumZoomScale: CGFloat = 4.0
        static let shadowOffset = CGSize(width: 0, height: 2)
        static let shadowRadius: CGFloat = 8.0
        static let shadowOpacity: Float = 0.3
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPageScrollView()
        setupPageControl()
        setupCloseButton()
        setupMenuButton()
        setupGestureRecognizers()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !hasLoadedInitialImages && pageScrollView.bounds.width > 0 {
            loadImages()
            hasLoadedInitialImages = true
        }

        if hasLoadedInitialImages && !hasScrolledToInitialIndex {
            scrollToIndex(currentIndex, animated: false)
            hasScrolledToInitialIndex = true
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            cleanup()
        }
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupPageScrollView() {
        pageScrollView = UIScrollView()
        pageScrollView.translatesAutoresizingMaskIntoConstraints = false
        pageScrollView.isPagingEnabled = true
        pageScrollView.showsHorizontalScrollIndicator = false
        pageScrollView.showsVerticalScrollIndicator = false
        pageScrollView.delegate = self

        view.addSubview(pageScrollView)

        NSLayoutConstraint.activate([
            pageScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            pageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupPageControl() {
        pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = images.count
        pageControl.currentPage = currentIndex
        pageControl.hidesForSinglePage = true
        pageControl.pageIndicatorTintColor = .systemGray
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.addTarget(self, action: #selector(pageControlValueChanged), for: .valueChanged)

        view.addSubview(pageControl)

        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -Constants.pageControlBottomPadding),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func setupCloseButton() {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: "xmark")

        closeButton = UIButton(configuration: configuration)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.buttonTopPadding),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: Constants.buttonHorizontalPadding),
            closeButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize)
        ])
    }

    private func setupMenuButton() {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: "ellipsis")

        menuButton = UIButton(configuration: configuration)
        menuButton.preferredBehavioralStyle = .pad
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = createImageMenu()

        view.addSubview(menuButton)

        NSLayoutConstraint.activate([
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: Constants.buttonTopPadding),
            menuButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -Constants.buttonHorizontalPadding),
            menuButton.widthAnchor.constraint(equalToConstant: Constants.buttonSize),
            menuButton.heightAnchor.constraint(equalToConstant: Constants.buttonSize)
        ])
    }

    private func createImageMenu() -> UIMenu {
        let copyAction = UIAction(
            title: "Copy Image",
            image: UIImage(systemName: "doc.on.doc"),
            identifier: nil
        ) { [weak self] _ in
            self?.copyCurrentImage()
        }

        let saveAction = UIAction(
            title: "Save Image",
            image: UIImage(systemName: "square.and.arrow.down"),
            identifier: nil
        ) { [weak self] _ in
            self?.saveCurrentImage()
        }

        let shareAction = UIAction(
            title: "Share Image",
            image: UIImage(systemName: "square.and.arrow.up"),
            identifier: nil
        ) { [weak self] _ in
            self?.shareCurrentImage()
        }

        return UIMenu(children: [copyAction, saveAction, shareAction])
    }

    private func setupGestureRecognizers() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        view.addGestureRecognizer(singleTap)
    }

    // MARK: - Actions

    @objc private func pageControlValueChanged() {
        let newIndex = pageControl.currentPage
        guard newIndex != currentIndex && newIndex < images.count else { return }
        scrollToIndex(newIndex, animated: true)
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let isHidden = pageControl.isHidden
        UIView.animate(withDuration: Constants.animationDuration) {
            self.pageControl.alpha = isHidden ? 1.0 : 0.0
            self.closeButton.alpha = isHidden ? 1.0 : 0.0
            self.menuButton.alpha = isHidden ? 1.0 : 0.0
        } completion: { _ in
            self.pageControl.isHidden = !isHidden
            self.closeButton.isHidden = !isHidden
            self.menuButton.isHidden = !isHidden
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Image Loading

    private func loadImages() {
        guard !images.isEmpty, pageScrollView.bounds.width > 0 else { return }

        let screenSize = view.bounds.size
        let scale = view.traitCollection.displayScale
        imageSize = CGSize(width: screenSize.width * scale, height: screenSize.height * scale)

        createContainerView()
        createPlaceholderViews()
        loadImagesForIndex(currentIndex)
    }

    private func createContainerView() {
        containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        pageScrollView.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: pageScrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: pageScrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: pageScrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: pageScrollView.bottomAnchor),
            containerView.heightAnchor.constraint(equalTo: pageScrollView.heightAnchor)
        ])
    }

    private func createPlaceholderViews() {
        var previousView: UIView?

        for index in 0..<images.count {
            let placeholderView = UIView()
            placeholderView.translatesAutoresizingMaskIntoConstraints = false
            placeholderView.backgroundColor = .black
            containerView.addSubview(placeholderView)
            placeholderViews[index] = placeholderView

            NSLayoutConstraint.activate([
                placeholderView.topAnchor.constraint(equalTo: containerView.topAnchor),
                placeholderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                placeholderView.widthAnchor.constraint(equalTo: pageScrollView.widthAnchor),
                placeholderView.heightAnchor.constraint(equalTo: pageScrollView.heightAnchor)
            ])

            if let previous = previousView {
                placeholderView.leadingAnchor.constraint(equalTo: previous.trailingAnchor).isActive = true
            } else {
                placeholderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
            }

            if index == images.count - 1 {
                placeholderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
            }

            previousView = placeholderView
        }
    }

    private func loadImagesForIndex(_ index: Int) {
        let indicesToLoad = [index - 1, index, index + 1].filter { $0 >= 0 && $0 < images.count }

        for imageIndex in indicesToLoad where loadedViews[imageIndex] == nil {
            loadImageAtIndex(imageIndex)
        }

        let indicesToKeep = Set(indicesToLoad)
        for (imageIndex, _) in loadedViews where !indicesToKeep.contains(imageIndex) {
            unloadImageAtIndex(imageIndex)
        }
    }

    private func loadImageAtIndex(_ index: Int) {
        guard index >= 0 && index < images.count,
              let placeholderView = placeholderViews[index] else { return }

        let imageItem = images[index]
        let zoomScrollView = ZoomableScrollView()
        zoomScrollView.translatesAutoresizingMaskIntoConstraints = false
        zoomScrollView.backgroundColor = .black

        placeholderView.addSubview(zoomScrollView)
        loadedViews[index] = zoomScrollView

        NSLayoutConstraint.activate([
            zoomScrollView.topAnchor.constraint(equalTo: placeholderView.topAnchor),
            zoomScrollView.leadingAnchor.constraint(equalTo: placeholderView.leadingAnchor),
            zoomScrollView.trailingAnchor.constraint(equalTo: placeholderView.trailingAnchor),
            zoomScrollView.bottomAnchor.constraint(equalTo: placeholderView.bottomAnchor)
        ])

        let previewImage = previewImageProvider?(imageItem)
        if let url = imageURLProvider?(imageItem, imageSize) {
            zoomScrollView.loadImage(url: url, isLogo: imageItem.type == .logo, previewImage: previewImage)
        } else if let previewImage {
            zoomScrollView.displayPreviewImage(previewImage, isLogo: imageItem.type == .logo)
        }
    }

    private func unloadImageAtIndex(_ index: Int) {
        guard let zoomScrollView = loadedViews[index] else { return }
        zoomScrollView.clearImage()
        zoomScrollView.removeFromSuperview()
        loadedViews.removeValue(forKey: index)
    }

    // MARK: - Navigation

    private func scrollToIndex(_ index: Int, animated: Bool) {
        guard index >= 0 && index < images.count,
              pageScrollView.bounds.width > 0 else { return }

        let offsetX = CGFloat(index) * pageScrollView.bounds.width
        pageScrollView.setContentOffset(CGPoint(x: offsetX, y: 0), animated: animated)
        currentIndex = index

        updatePageControl(index)
        loadImagesForIndex(index)

        if let currentView = loadedViews[index] {
            currentView.resetZoom()
        }
    }

    private func updatePageControl(_ index: Int) {
        pageControl.removeTarget(self, action: #selector(pageControlValueChanged), for: .valueChanged)
        pageControl.currentPage = index
        pageControl.addTarget(self, action: #selector(pageControlValueChanged), for: .valueChanged)
    }

    // MARK: - Image Actions

    private func getCurrentImage() -> UIImage? {
        guard let currentView = loadedViews[currentIndex] else { return nil }
        return currentView.imageView.image
    }

    private func copyCurrentImage() {
        guard let image = getCurrentImage() else { return }
        UIPasteboard.general.image = image
    }

    private func saveCurrentImage() {
        guard let image = getCurrentImage() else { return }
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

    private func shareCurrentImage() {
        guard let image = getCurrentImage() else { return }
        let activityViewController = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        UIApplication.shared.present(activityViewController)
    }

    // MARK: - Zoom Transition

    func shouldBeginInteractiveDismiss(location: CGPoint, velocity: CGVector, willBegin: Bool) -> Bool {
        guard let currentView = loadedViews[currentIndex],
              currentView.zoomScale <= currentView.minimumZoomScale + 0.01 else {
            return false
        }

        let isDraggingDown = velocity.dy > 0
        let isMostlyVertical = abs(velocity.dy) > abs(velocity.dx)
        return willBegin || (isDraggingDown && isMostlyVertical)
    }

    func zoomTransitionAlignmentRect() -> CGRect? {
        view.layoutIfNeeded()

        guard let currentView = loadedViews[currentIndex] else {
            return view.bounds
        }

        guard let image = currentView.imageView.image else {
            return currentView.imageView.convert(currentView.imageView.bounds, to: view)
        }

        let imageRect = aspectFitRect(for: image.size, in: currentView.imageView.bounds)
        return currentView.imageView.convert(imageRect, to: view)
    }

    private func aspectFitRect(for imageSize: CGSize, in bounds: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              bounds.width > 0, bounds.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / imageSize.width, bounds.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: bounds.midX - size.width / 2.0,
            y: bounds.midY - size.height / 2.0
        )
        return CGRect(origin: origin, size: size)
    }

    // MARK: - Cleanup

    private func cleanup() {
        for (_, view) in loadedViews {
            view.clearImage()
        }
        loadedViews.removeAll()
        placeholderViews.removeAll()
    }
}

// MARK: - UIScrollViewDelegate

extension FullScreenImageViewController: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPage()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        updateCurrentPage()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let pageIndex = Int(pageScrollView.contentOffset.x / pageScrollView.bounds.width + 0.5)
        guard pageIndex != currentIndex,
              pageIndex >= 0 && pageIndex < images.count else { return }
        loadImagesForIndex(pageIndex)
    }

    private func updateCurrentPage() {
        let pageIndex = Int(pageScrollView.contentOffset.x / pageScrollView.bounds.width + 0.5)
        guard pageIndex != currentIndex && pageIndex < images.count else { return }

        currentIndex = pageIndex
        pageControl.currentPage = pageIndex
        loadImagesForIndex(pageIndex)

        if let currentView = loadedViews[pageIndex] {
            currentView.resetZoom()
        }
    }
}

// MARK: - ZoomableScrollView

final class ZoomableScrollView: UIScrollView {
    var imageView: UIImageView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        minimumZoomScale = FullScreenImageViewController.Constants.minimumZoomScale
        maximumZoomScale = FullScreenImageViewController.Constants.maximumZoomScale
        bouncesZoom = true
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        delegate = self

        imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: widthAnchor),
            imageView.heightAnchor.constraint(equalTo: heightAnchor)
        ])

        setZoomScale(minimumZoomScale, animated: false)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    func loadImage(url: URL, isLogo: Bool = false, previewImage: UIImage? = nil) {
        configureAppearance(isLogo: isLogo)

        imageView.kf.cancelDownloadTask()
        imageView.image = previewImage
        imageView.alpha = previewImage == nil ? 0.0 : 1.0

        let options: KingfisherOptionsInfo = previewImage == nil ? [] : [
            .forceTransition,
            .transition(.fade(FullScreenImageViewController.Constants.imageFadeDuration))
        ]
        imageView.kf.setImage(with: url, placeholder: previewImage, options: options) { [weak self] result in
            guard previewImage == nil,
                  case .success = result else { return }
            self?.fadeImageIn()
        }
    }

    func displayPreviewImage(_ image: UIImage, isLogo: Bool = false) {
        configureAppearance(isLogo: isLogo)
        imageView.kf.cancelDownloadTask()
        imageView.image = image
        imageView.alpha = 1.0
    }

    private func configureAppearance(isLogo: Bool) {
        if isLogo {
            imageView.backgroundColor = .clear
            backgroundColor = .secondarySystemBackground
            imageView.layer.shadowColor = UIColor.black.cgColor
            imageView.layer.shadowOffset = FullScreenImageViewController.Constants.shadowOffset
            imageView.layer.shadowRadius = FullScreenImageViewController.Constants.shadowRadius
            imageView.layer.shadowOpacity = FullScreenImageViewController.Constants.shadowOpacity
            imageView.layer.masksToBounds = false
        } else {
            backgroundColor = .black
            imageView.layer.shadowOpacity = 0
            imageView.layer.masksToBounds = true
        }
    }

    private func fadeImageIn() {
        imageView.alpha = 0.0
        UIView.animate(
            withDuration: FullScreenImageViewController.Constants.imageFadeDuration,
            delay: 0,
            options: [.curveEaseIn, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.imageView.alpha = 1.0
        }
    }

    func clearImage() {
        imageView.kf.cancelDownloadTask()
        imageView.image = nil
        imageView.alpha = 1.0
        imageView.layer.shadowOpacity = 0
        resetZoom()
    }

    func resetZoom() {
        setZoomScale(minimumZoomScale, animated: false)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let zoomRect = zoomRectForScale(scale: maximumZoomScale, center: point)
            zoom(to: zoomRect, animated: true)
        }
    }

    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = bounds.size.height / scale
        zoomRect.size.width = bounds.size.width / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
}

// MARK: - ZoomableScrollView UIScrollViewDelegate

extension ZoomableScrollView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let boundsSize = scrollView.bounds.size
        let imageSize = imageView.frame.size

        scrollView.contentSize = imageSize

        var frameToCenter = imageView.frame

        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }

        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }

        imageView.frame = frameToCenter
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale == minimumZoomScale {
            scrollView.contentSize = scrollView.bounds.size
        }
    }
}
