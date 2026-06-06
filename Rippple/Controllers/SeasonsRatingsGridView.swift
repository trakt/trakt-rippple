//
//  SeasonsRatingsGridView.swift
//  Rippple
//
//  Created by Kevin Cador on 24/05/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import UIKit

protocol SeasonsRatingsGridViewDelegate: AnyObject {
    func seasonsRatingsGridView(_ gridView: SeasonsRatingsGridView,
                                didSelect episode: Episode)
    func seasonsRatingsGridView(_ gridView: SeasonsRatingsGridView,
                                contextMenuConfigurationFor episode: Episode,
                                indexPath: IndexPath) -> UIContextMenuConfiguration?
}

final class SeasonsRatingsGridView: UIView {
    weak var delegate: SeasonsRatingsGridViewDelegate?

    var adapter: SeasonsRatingsGridAdapter? {
        didSet {
            reloadData()
        }
    }

    var primaryScrollView: UIScrollView {
        return bodyCollectionView
    }

    private enum Metrics {
        static let cellSize = CGSize(width: 60, height: 40)
        static let spacing: CGFloat = 4
        static let leadingInset: CGFloat = 12
        static let bottomInset: CGFloat = 24
    }

    private let cornerView = UIView()
    private let topHeaderCollectionView: UICollectionView
    private let leftHeaderCollectionView: UICollectionView
    private let bodyLayout: SeasonsRatingsFixedGridLayout
    private let bodyCollectionView: UICollectionView

    private var isSynchronizingScrollOffset = false

    override init(frame: CGRect) {
        let topHeaderLayout = UICollectionViewFlowLayout()
        topHeaderLayout.scrollDirection = .horizontal
        topHeaderLayout.itemSize = Metrics.cellSize
        topHeaderLayout.minimumLineSpacing = Metrics.spacing
        topHeaderLayout.minimumInteritemSpacing = Metrics.spacing
        topHeaderLayout.sectionInset = .zero
        topHeaderLayout.estimatedItemSize = .zero

        topHeaderCollectionView = UICollectionView(frame: .zero, collectionViewLayout: topHeaderLayout)

        let leftHeaderLayout = UICollectionViewFlowLayout()
        leftHeaderLayout.scrollDirection = .vertical
        leftHeaderLayout.itemSize = Metrics.cellSize
        leftHeaderLayout.minimumLineSpacing = Metrics.spacing
        leftHeaderLayout.minimumInteritemSpacing = Metrics.spacing
        leftHeaderLayout.sectionInset = .zero
        leftHeaderLayout.estimatedItemSize = .zero

        leftHeaderCollectionView = UICollectionView(frame: .zero, collectionViewLayout: leftHeaderLayout)

        let bodyLayout = SeasonsRatingsFixedGridLayout()
        self.bodyLayout = bodyLayout
        bodyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: bodyLayout)

        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        let topHeaderLayout = UICollectionViewFlowLayout()
        topHeaderLayout.scrollDirection = .horizontal
        topHeaderLayout.itemSize = Metrics.cellSize
        topHeaderLayout.minimumLineSpacing = Metrics.spacing
        topHeaderLayout.minimumInteritemSpacing = Metrics.spacing
        topHeaderLayout.sectionInset = .zero
        topHeaderLayout.estimatedItemSize = .zero

        topHeaderCollectionView = UICollectionView(frame: .zero, collectionViewLayout: topHeaderLayout)

        let leftHeaderLayout = UICollectionViewFlowLayout()
        leftHeaderLayout.scrollDirection = .vertical
        leftHeaderLayout.itemSize = Metrics.cellSize
        leftHeaderLayout.minimumLineSpacing = Metrics.spacing
        leftHeaderLayout.minimumInteritemSpacing = Metrics.spacing
        leftHeaderLayout.sectionInset = .zero
        leftHeaderLayout.estimatedItemSize = .zero

        leftHeaderCollectionView = UICollectionView(frame: .zero, collectionViewLayout: leftHeaderLayout)

        let bodyLayout = SeasonsRatingsFixedGridLayout()
        self.bodyLayout = bodyLayout
        bodyCollectionView = UICollectionView(frame: .zero, collectionViewLayout: bodyLayout)

        super.init(coder: coder)

        configure()
    }

    func reloadData() {
        let seasonCount = adapter?.seasonCount ?? 0
        let episodeRowCount = adapter?.episodeRowCount ?? 0
        let hasSeasons = seasonCount > 0
        let hasEpisodeRows = hasSeasons && episodeRowCount > 0

        cornerView.isHidden = !hasSeasons
        topHeaderCollectionView.isHidden = !hasSeasons
        leftHeaderCollectionView.isHidden = !hasEpisodeRows
        bodyCollectionView.isHidden = !hasEpisodeRows

        bodyLayout.columnCount = seasonCount
        bodyLayout.rowCount = episodeRowCount

        topHeaderCollectionView.reloadData()
        leftHeaderCollectionView.reloadData()
        bodyCollectionView.reloadData()
    }

    func scrollToSeason(number: Int,
                        episodeNumber: Int?,
                        animated: Bool) {
        guard let adapter = adapter,
              let coordinate = adapter.coordinate(forSeasonNumber: number,
                                                  episodeNumber: episodeNumber) else { return }

        layoutIfNeeded()
        topHeaderCollectionView.layoutIfNeeded()
        leftHeaderCollectionView.layoutIfNeeded()
        bodyCollectionView.layoutIfNeeded()

        let targetX = CGFloat(coordinate.column) * (Metrics.cellSize.width + Metrics.spacing)
        let targetY = CGFloat(coordinate.row) * (Metrics.cellSize.height + Metrics.spacing)

        let centeredX = targetX - (bodyCollectionView.bounds.width - Metrics.cellSize.width) / 2
        let centeredY = targetY - (bodyCollectionView.bounds.height - Metrics.cellSize.height) / 2
        let offset = CGPoint(x: clampedXOffset(centeredX),
                             y: clampedYOffset(centeredY))

        bodyCollectionView.setContentOffset(offset, animated: animated)
        topHeaderCollectionView.setContentOffset(CGPoint(x: offset.x,
                                                         y: topHeaderCollectionView.contentOffset.y),
                                                 animated: animated)
        leftHeaderCollectionView.setContentOffset(CGPoint(x: leftHeaderCollectionView.contentOffset.x,
                                                          y: offset.y),
                                                  animated: animated)
    }

    private func configure() {
        backgroundColor = .systemBackground

        configureCornerView()
        configureCollectionView(topHeaderCollectionView)
        configureCollectionView(leftHeaderCollectionView)
        configureCollectionView(bodyCollectionView)

        topHeaderCollectionView.alwaysBounceHorizontal = true
        topHeaderCollectionView.alwaysBounceVertical = false
        topHeaderCollectionView.scrollsToTop = false

        leftHeaderCollectionView.alwaysBounceHorizontal = false
        leftHeaderCollectionView.alwaysBounceVertical = true
        leftHeaderCollectionView.scrollsToTop = false

        bodyCollectionView.alwaysBounceHorizontal = true
        bodyCollectionView.alwaysBounceVertical = true
        bodyCollectionView.scrollsToTop = true

        leftHeaderCollectionView.contentInset.bottom = Metrics.bottomInset
        leftHeaderCollectionView.verticalScrollIndicatorInsets.bottom = Metrics.bottomInset
        bodyCollectionView.contentInset.bottom = Metrics.bottomInset
        bodyCollectionView.verticalScrollIndicatorInsets.bottom = Metrics.bottomInset

        for item in [cornerView, topHeaderCollectionView, leftHeaderCollectionView, bodyCollectionView] {
            item.translatesAutoresizingMaskIntoConstraints = false
            addSubview(item)
        }

        NSLayoutConstraint.activate([
            cornerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leadingInset),
            cornerView.topAnchor.constraint(equalTo: topAnchor),
            cornerView.widthAnchor.constraint(equalToConstant: Metrics.cellSize.width),
            cornerView.heightAnchor.constraint(equalToConstant: Metrics.cellSize.height),

            topHeaderCollectionView.leadingAnchor.constraint(equalTo: cornerView.trailingAnchor, constant: Metrics.spacing),
            topHeaderCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            topHeaderCollectionView.topAnchor.constraint(equalTo: topAnchor),
            topHeaderCollectionView.heightAnchor.constraint(equalToConstant: Metrics.cellSize.height),

            leftHeaderCollectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Metrics.leadingInset),
            leftHeaderCollectionView.topAnchor.constraint(equalTo: cornerView.bottomAnchor, constant: Metrics.spacing),
            leftHeaderCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            leftHeaderCollectionView.widthAnchor.constraint(equalToConstant: Metrics.cellSize.width),

            bodyCollectionView.leadingAnchor.constraint(equalTo: leftHeaderCollectionView.trailingAnchor, constant: Metrics.spacing),
            bodyCollectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bodyCollectionView.topAnchor.constraint(equalTo: topHeaderCollectionView.bottomAnchor, constant: Metrics.spacing),
            bodyCollectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        reloadData()
    }

    private func configureCornerView() {
        cornerView.backgroundColor = .systemBackground
        cornerView.isAccessibilityElement = false
    }

    private func configureCollectionView(_ collectionView: UICollectionView) {
        collectionView.backgroundColor = .systemBackground
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(SeasonsRatingsHeaderCollectionViewCell.self,
                                forCellWithReuseIdentifier: SeasonsRatingsHeaderCollectionViewCell.reuseIdentifier)
        collectionView.register(SeasonsRatingsContentCollectionViewCell.self,
                                forCellWithReuseIdentifier: SeasonsRatingsContentCollectionViewCell.reuseIdentifier)
        collectionView.register(SeasonsRatingsEmptyCollectionViewCell.self,
                                forCellWithReuseIdentifier: SeasonsRatingsEmptyCollectionViewCell.reuseIdentifier)
    }

    private func synchronizeHeaderOffsets(from scrollView: UIScrollView) {
        guard !isSynchronizingScrollOffset else { return }

        isSynchronizingScrollOffset = true
        defer { isSynchronizingScrollOffset = false }

        if scrollView === bodyCollectionView {
            setContentOffset(for: topHeaderCollectionView,
                             x: bodyCollectionView.contentOffset.x,
                             y: topHeaderCollectionView.contentOffset.y)
            setContentOffset(for: leftHeaderCollectionView,
                             x: leftHeaderCollectionView.contentOffset.x,
                             y: bodyCollectionView.contentOffset.y)
        } else if scrollView === topHeaderCollectionView {
            setContentOffset(for: bodyCollectionView,
                             x: topHeaderCollectionView.contentOffset.x,
                             y: bodyCollectionView.contentOffset.y)
        } else if scrollView === leftHeaderCollectionView {
            setContentOffset(for: bodyCollectionView,
                             x: bodyCollectionView.contentOffset.x,
                             y: leftHeaderCollectionView.contentOffset.y)
        }
    }

    private func setContentOffset(for scrollView: UIScrollView,
                                  x: CGFloat,
                                  y: CGFloat) {
        let nextOffset = CGPoint(x: x, y: y)
        guard scrollView.contentOffset != nextOffset else { return }
        scrollView.contentOffset = nextOffset
    }

    private func clampedXOffset(_ xOffset: CGFloat) -> CGFloat {
        let contentWidth = max(bodyCollectionView.contentSize.width, topHeaderCollectionView.contentSize.width)
        let maxOffset = max(contentWidth - bodyCollectionView.bounds.width, 0)
        return min(max(xOffset, 0), maxOffset)
    }

    private func clampedYOffset(_ yOffset: CGFloat) -> CGFloat {
        let contentHeight = max(bodyCollectionView.contentSize.height, leftHeaderCollectionView.contentSize.height)
        let maxOffset = max(contentHeight + bodyCollectionView.contentInset.bottom - bodyCollectionView.bounds.height, 0)
        return min(max(yOffset, 0), maxOffset)
    }
}

extension SeasonsRatingsGridView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        guard let adapter = adapter else { return 0 }

        if collectionView === topHeaderCollectionView {
            return adapter.seasonCount
        } else if collectionView === leftHeaderCollectionView {
            return adapter.episodeRowCount
        } else if collectionView === bodyCollectionView {
            return adapter.bodyItemCount
        }

        return 0
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView === topHeaderCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeasonsRatingsHeaderCollectionViewCell.reuseIdentifier,
                                                          for: indexPath) as! SeasonsRatingsHeaderCollectionViewCell
            cell.configure(text: adapter?.seasonTitle(atColumn: indexPath.item))
            return cell
        } else if collectionView === leftHeaderCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeasonsRatingsHeaderCollectionViewCell.reuseIdentifier,
                                                          for: indexPath) as! SeasonsRatingsHeaderCollectionViewCell
            cell.configure(text: adapter?.episodeTitle(atRow: indexPath.item))
            return cell
        } else if collectionView === bodyCollectionView,
                  let adapter = adapter,
                  let coordinate = adapter.coordinate(forBodyItem: indexPath.item) {
            let viewModel = adapter.cellViewModel(at: coordinate)
            guard !viewModel.isEmpty else {
                return collectionView.dequeueReusableCell(withReuseIdentifier: SeasonsRatingsEmptyCollectionViewCell.reuseIdentifier,
                                                          for: indexPath)
            }

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SeasonsRatingsContentCollectionViewCell.reuseIdentifier,
                                                          for: indexPath) as! SeasonsRatingsContentCollectionViewCell
            cell.configure(with: viewModel)
            return cell
        }

        return collectionView.dequeueReusableCell(withReuseIdentifier: SeasonsRatingsEmptyCollectionViewCell.reuseIdentifier,
                                                  for: indexPath)
    }
}

extension SeasonsRatingsGridView: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        synchronizeHeaderOffsets(from: scrollView)
    }

    func collectionView(_ collectionView: UICollectionView,
                        shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard collectionView === bodyCollectionView,
              let adapter = adapter,
              let coordinate = adapter.coordinate(forBodyItem: indexPath.item) else { return false }

        return adapter.episode(at: coordinate) != nil
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        guard collectionView === bodyCollectionView,
              let adapter = adapter,
              let coordinate = adapter.coordinate(forBodyItem: indexPath.item),
              let episode = adapter.episode(at: coordinate) else { return }

        delegate?.seasonsRatingsGridView(self, didSelect: episode)
    }

    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard collectionView === bodyCollectionView,
              let adapter = adapter,
              let coordinate = adapter.coordinate(forBodyItem: indexPath.item),
              let episode = adapter.episode(at: coordinate),
              !adapter.cellViewModel(at: coordinate).isEmpty else { return nil }

        return delegate?.seasonsRatingsGridView(self,
                                                contextMenuConfigurationFor: episode,
                                                indexPath: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard collectionView === bodyCollectionView,
              let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? SeasonsRatingsContentCollectionViewCell else { return nil }

        cell.layer.zPosition = 100
        return UITargetedPreview(view: cell.label, parameters: UIPreviewParameters())
    }

    func collectionView(_ collectionView: UICollectionView,
                        previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard collectionView === bodyCollectionView,
              let indexPath = configuration.identifier as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) as? SeasonsRatingsContentCollectionViewCell else { return nil }

        cell.layer.zPosition = 0
        return UITargetedPreview(view: cell.label, parameters: UIPreviewParameters())
    }
}
