//
//  ComposerInsertViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import UIKit

final class ComposerInsertViewController: UIViewController, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate {
    private enum Mode: Equatable {
        case link(ComposerLinkSearch.Mode)
        case gif

        var title: String {
            switch self {
            case .link(.people): return "People"
            case .link(.characters): return "Characters"
            case .link(.media): return "Media"
            case .gif: return "GIF"
            }
        }

        var placeholder: String {
            switch self {
            case .link(.people): return "Search people"
            case .link(.characters): return "Search characters"
            case .link(.media): return "Search movies and shows"
            case .gif: return "Search KLIPY"
            }
        }

        var hint: String {
            switch self {
            case .link(.people): return "Type to search people"
            case .link(.characters): return "No characters to suggest for this item"
            case .link(.media): return "Type to search movies and shows"
            case .gif: return ""
            }
        }
    }

    var onSelectLink: ((ComposerLink, String) -> Void)?
    var onSelectGIF: ((ComposerGIFItem) -> Void)?
    var onClose: (() -> Void)?

    private let linkSearch: ComposerLinkSearch
    private let modes: [Mode]
    private let subjectTitle: String?
    private var mode: Mode
    private var gifs = [ComposerGIFItem]()
    private var gifQuery: String?
    private var gifPage = 0
    private var gifHasNext = false
    private var gifRequest: Cancellable?
    private var gifHeader = ComposerInsertViewController.klipyAttribution {
        didSet {
            for case let header as ComposerGIFHeaderView in gifCollectionView.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader) {
                configure(header)
            }
        }
    }

    private lazy var searchDebouncer = Debouncer(delay: 0.3) { [weak self] in
        guard let self = self else { return }
        if self.mode == .gif {
            self.loadGIFs(reset: true)
        } else {
            self.linkSearch.search()
        }
    }

    private let glass: UIVisualEffectView = {
        let effect = UIGlassEffect(style: .regular)
        let view = UIVisualEffectView(effect: effect)
        view.cornerConfiguration = .capsule(maximumRadius: 28)
        view.clipsToBounds = true
        return view
    }()

    private lazy var modeControl = ComposerModeControl(items: modes.map { $0.title })
    private let modeToolbar = UIToolbar()
    private lazy var modeItem: UIBarButtonItem = {
        let item = UIBarButtonItem(customView: modeControl)
        // The modes are glass already; the item's own glass platter behind them would double it.
        item.hidesSharedBackground = true
        return item
    }()

    private let closeButton: UIButton = {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: "xmark")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        configuration.baseForegroundColor = .label
        configuration.cornerStyle = .capsule
        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = "Close"
        return button
    }()

    private let searchField = UISearchTextField()
    private lazy var searchRow = UIStackView(arrangedSubviews: [searchField, closeButton])
    private let headerContainer = UIView()
    private let footerContainer = UIView()
    private let topEdgeInteraction: UIScrollEdgeElementContainerInteraction = {
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.edge = .top
        return interaction
    }()

    private let bottomEdgeInteraction: UIScrollEdgeElementContainerInteraction = {
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.edge = .bottom
        return interaction
    }()

    private let suggestionsController = ComposerLinkSuggestionsViewController()
    private lazy var gifCollectionView = UICollectionView(frame: .zero, collectionViewLayout: makeGIFLayout())

    init(subject: ComposerSubject?, allowsGIF: Bool) {
        if case .media(let media) = subject {
            subjectTitle = ComposerLink.title(of: media)
        } else {
            subjectTitle = nil
        }
        let linkSearch = ComposerLinkSearch(subject: subject)
        self.linkSearch = linkSearch
        var modes: [Mode] = [.link(.people)]
        if linkSearch.hasCast {
            modes.append(.link(.characters))
        }
        modes.append(.link(.media))
        if allowsGIF {
            modes.append(.gif)
        }
        self.modes = modes
        mode = .link(.people)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        gifRequest?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true

        glass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glass)

        modeControl.selectedSegmentIndex = 0
        // The toolbar's larger titles don't fit equal widths, so each segment takes the room its title needs.
        modeControl.apportionsSegmentWidthsByContent = true
        modeControl.accessibilityLabel = "Insert"
        modeControl.addAction(UIAction { [weak self] _ in
            guard let self = self, self.modes.indices.contains(self.modeControl.selectedSegmentIndex) else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            self.select(self.modes[self.modeControl.selectedSegmentIndex])
        }, for: .valueChanged)

        closeButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.onClose?()
        }, for: .primaryActionTriggered)

        searchField.delegate = self
        searchField.returnKeyType = .done
        searchField.autocorrectionType = .no
        searchField.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.queryDidChange()
        }, for: .editingChanged)

        suggestionsController.onSelect = { [weak self] link in
            guard let self = self else { return }
            self.onSelectLink?(link, self.query)
        }
        suggestionsController.onRetry = { [weak self] in
            guard let self = self else { return }
            self.linkSearch.retry()
        }
        addChild(suggestionsController)
        suggestionsController.view.translatesAutoresizingMaskIntoConstraints = false

        gifCollectionView.backgroundColor = .clear
        gifCollectionView.dataSource = self
        gifCollectionView.delegate = self
        gifCollectionView.keyboardDismissMode = .none
        gifCollectionView.register(ComposerGIFCell.self, forCellWithReuseIdentifier: "gif")
        gifCollectionView.register(ComposerGIFHeaderView.self,
                                   forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                   withReuseIdentifier: "header")
        gifCollectionView.translatesAutoresizingMaskIntoConstraints = false

        searchRow.axis = .horizontal
        searchRow.alignment = .center
        searchRow.spacing = 10
        searchRow.translatesAutoresizingMaskIntoConstraints = false
        let toolbarAppearance = UIToolbarAppearance()
        toolbarAppearance.configureWithTransparentBackground()
        modeToolbar.standardAppearance = toolbarAppearance
        modeToolbar.scrollEdgeAppearance = toolbarAppearance
        modeToolbar.items = [modeItem]
        modeToolbar.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        headerContainer.addSubview(searchRow)
        footerContainer.translatesAutoresizingMaskIntoConstraints = false
        footerContainer.addSubview(modeToolbar)

        for scrollView in [suggestionsController.scrollView, gifCollectionView] {
            scrollView.topEdgeEffect.style = .soft
            scrollView.bottomEdgeEffect.style = .soft
            // Not a child view controller and floating over the navigation bar, so safe areas would be wrong here.
            scrollView.contentInsetAdjustmentBehavior = .never
        }
        headerContainer.addInteraction(topEdgeInteraction)
        footerContainer.addInteraction(bottomEdgeInteraction)

        let content = glass.contentView
        content.addSubview(suggestionsController.view)
        content.addSubview(gifCollectionView)
        content.addSubview(headerContainer)
        content.addSubview(footerContainer)

        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: view.topAnchor),
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glass.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            headerContainer.topAnchor.constraint(equalTo: content.topAnchor),
            headerContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            searchRow.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            searchRow.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 46),
            closeButton.heightAnchor.constraint(equalToConstant: 46),
            searchField.heightAnchor.constraint(equalTo: closeButton.heightAnchor),
            searchRow.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor),
            footerContainer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            modeToolbar.topAnchor.constraint(equalTo: footerContainer.topAnchor),
            modeToolbar.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 12),
            suggestionsController.view.topAnchor.constraint(equalTo: content.topAnchor),
            suggestionsController.view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            suggestionsController.view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            gifCollectionView.topAnchor.constraint(equalTo: content.topAnchor),
            gifCollectionView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            gifCollectionView.trailingAnchor.constraint(equalTo: content.trailingAnchor)
        ])
        // Lets the content overflow, clipped, while the bubble is the size of the "+" button, instead of growing it.
        let overflowing = [
            headerContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            searchRow.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -12),
            footerContainer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footerContainer.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            modeToolbar.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -12),
            modeToolbar.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -12),
            suggestionsController.view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            gifCollectionView.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ]
        for constraint in overflowing {
            constraint.priority = UILayoutPriority(999)
        }
        NSLayoutConstraint.activate(overflowing)
        suggestionsController.didMove(toParent: self)

        linkSearch.onUpdate = { [weak self] suggestions in
            guard let self = self else { return }
            self.suggestionsController.apply(suggestions, query: self.query)
        }
        linkSearch.activate()
        select(mode)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let headerHeight = headerContainer.frame.minY + searchRow.frame.maxY + 4
        let footerHeight = glass.contentView.bounds.height - footerContainer.frame.minY + 4
        guard headerHeight > 4, footerHeight > 4 else { return }
        for scrollView in [suggestionsController.scrollView, gifCollectionView] {
            let top = headerHeight + 4
            if scrollView.contentInset.top != top {
                let isAtTop = scrollView.contentOffset.y <= -scrollView.contentInset.top + 0.5
                scrollView.contentInset.top = top
                scrollView.verticalScrollIndicatorInsets.top = headerHeight
                if isAtTop {
                    scrollView.contentOffset.y = -top
                }
            }
            if scrollView.contentInset.bottom != footerHeight {
                scrollView.contentInset.bottom = footerHeight
                scrollView.verticalScrollIndicatorInsets.bottom = footerHeight
            }
        }
    }

    func setContentVisible(_ isVisible: Bool) {
        for subview in glass.contentView.subviews {
            subview.alpha = isVisible ? 1 : 0
        }
    }

    func focus() {
        searchField.becomeFirstResponder()
    }

    // MARK: - Modes

    private var query: String {
        searchField.text ?? ""
    }

    private func select(_ mode: Mode) {
        self.mode = mode
        searchField.placeholder = mode.placeholder
        suggestionsController.hint = mode.hint
        suggestionsController.castTitle = castTitle(for: mode)
        switch mode {
        case .link(.people): suggestionsController.resultsTitle = "People search results"
        case .link(.media): suggestionsController.resultsTitle = "Media search results"
        case .link(.characters), .gif: suggestionsController.resultsTitle = nil
        }
        let showsGIFs = mode == .gif
        topEdgeInteraction.scrollView = showsGIFs ? gifCollectionView : suggestionsController.scrollView
        bottomEdgeInteraction.scrollView = topEdgeInteraction.scrollView
        UIView.performWithoutAnimation {
            suggestionsController.view.isHidden = showsGIFs
            gifCollectionView.isHidden = showsGIFs == false
        }
        if case .link(let linkMode) = mode {
            linkSearch.mode = linkMode
        }
        queryDidChange()
    }

    private func queryDidChange() {
        if mode == .gif {
            guard query != gifQuery else { return }
            if gifQuery == nil {
                loadGIFs(reset: true)
            } else {
                searchDebouncer.call()
            }
            return
        }
        linkSearch.update(query: query)
        searchDebouncer.call()
    }

    private func castTitle(for mode: Mode) -> String {
        if mode == .link(.media) {
            return subjectTitle.map { "Related to \($0)" } ?? "Related"
        }
        let noun = mode == .link(.characters) ? "characters" : "cast"
        guard let subjectTitle = subjectTitle else { return noun.capitalized }
        let possessive = subjectTitle.hasSuffix("s") ? "\(subjectTitle)’" : "\(subjectTitle)’s"
        return "\(possessive) \(noun)"
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    // MARK: - Keyboard

    override var keyCommands: [UIKeyCommand]? {
        let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(closeFromKeyboard))
        escape.wantsPriorityOverSystemBehavior = true
        return [escape]
    }

    @objc private func closeFromKeyboard() {
        onClose?()
    }

    // MARK: - GIFs

    private func loadGIFs(reset: Bool) {
        let query = self.query
        if reset {
            gifRequest?.cancel()
            gifRequest = nil
            gifQuery = query
            gifPage = 0
            gifHasNext = false
            gifs = []
            gifCollectionView.reloadData()
            gifCollectionView.setContentOffset(CGPoint(x: 0, y: -gifCollectionView.adjustedContentInset.top), animated: false)
        }
        guard gifRequest == nil else { return }
        let page = gifPage + 1
        if gifs.isEmpty {
            gifHeader = ComposerSectionHeader.Status(text: "Searching Klipy…", isLoading: true)
        }
        gifRequest = KlipyAPIProvider.gifs(query: query, page: page) { [weak self] result in
            guard let self = self, query == self.gifQuery else { return }
            self.gifRequest = nil
            switch result {
            case .success(let result):
                let known = Set(self.gifs.compactMap { $0.shareSlug })
                let items = result.gifs
                    .filter { known.contains($0.slug) == false }
                    .map { ComposerGIFItem(previewURL: URL(string: $0.preview.url), gif: $0.commentGIF, shareSlug: $0.slug) }
                self.gifPage = page
                self.gifHasNext = result.hasNext
                let start = self.gifs.count
                self.gifs.append(contentsOf: items)
                if start == 0 {
                    self.gifCollectionView.reloadData()
                } else if items.isEmpty == false {
                    self.gifCollectionView.insertItems(at: (start..<self.gifs.count).map { IndexPath(item: $0, section: 0) })
                }
                if self.gifs.isEmpty {
                    self.gifHeader = ComposerSectionHeader.Status(text: query.isEmpty ? "No GIFs right now" : "No match for “\(query)”")
                } else {
                    self.gifHeader = ComposerInsertViewController.klipyAttribution
                }
            case .failure:
                if self.gifs.isEmpty {
                    let text = query.isEmpty ? "Error loading GIFs from Klipy" : "Error searching for “\(query)” on Klipy"
                    self.gifHeader = ComposerSectionHeader.Status(text: text, isRetryable: true)
                }
            }
        }
    }

    private static let klipyAttribution = ComposerSectionHeader.Status(text: "Powered by KLIPY")

    private func configure(_ header: ComposerGIFHeaderView) {
        header.content.status = gifHeader
        header.content.onTap = { [weak self] in
            guard let self = self else { return }
            self.loadGIFs(reset: true)
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard gifHasNext, indexPath.item >= gifs.count - 6 else { return }
        loadGIFs(reset: false)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gifs.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "gif", for: indexPath) as! ComposerGIFCell
        cell.configure(with: gifs[indexPath.item].previewURL)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "header", for: indexPath)
        if let header = header as? ComposerGIFHeaderView {
            configure(header)
        }
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard gifs.indices.contains(indexPath.item) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelectGIF?(gifs[indexPath.item])
    }

    private func makeGIFLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            let columns = environment.container.effectiveContentSize.width > 500 ? 4 : 3
            let fraction = 1.0 / CGFloat(columns)
            let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(fraction),
                                                                                 heightDimension: .fractionalWidth(fraction * 0.75)))
            item.contentInsets = NSDirectionalEdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                              heightDimension: .fractionalWidth(fraction * 0.75)),
                                                           repeatingSubitem: item,
                                                           count: columns)
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 9, bottom: 9, trailing: 9)
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),
                                                                                                        heightDimension: .absolute(ComposerSectionHeader.height)),
                                                                     elementKind: UICollectionView.elementKindSectionHeader,
                                                                     alignment: .top)
            section.boundarySupplementaryItems = [header]
            section.supplementaryContentInsetsReference = .none
            return section
        }
    }
}

/// Toolbars size custom views from their natural size, so that's where the height is reduced.
private final class ComposerModeControl: UISegmentedControl {
    private static let heightScale: CGFloat = 0.8

    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.height = (size.height * ComposerModeControl.heightScale).rounded()
        return size
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var fitting = super.sizeThatFits(size)
        fitting.height = (fitting.height * ComposerModeControl.heightScale).rounded()
        return fitting
    }
}
