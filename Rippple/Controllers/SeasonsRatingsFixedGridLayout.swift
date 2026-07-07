//
//  SeasonsRatingsFixedGridLayout.swift
//  Rippple
//
//  Created by Kevin Cador on 24/05/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import UIKit

final class SeasonsRatingsFixedGridLayout: UICollectionViewLayout {
    var columnCount = 0 {
        didSet {
            if columnCount != oldValue {
                invalidateLayout()
            }
        }
    }

    var rowCount = 0 {
        didSet {
            if rowCount != oldValue {
                invalidateLayout()
            }
        }
    }

    let itemSize = CGSize(width: 60, height: 40)
    let itemSpacing: CGFloat = 4

    override var collectionViewContentSize: CGSize {
        guard columnCount > 0, rowCount > 0 else { return .zero }

        let width = CGFloat(columnCount) * itemSize.width + CGFloat(columnCount - 1) * itemSpacing
        let height = CGFloat(rowCount) * itemSize.height + CGFloat(rowCount - 1) * itemSpacing
        return CGSize(width: width, height: height)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard columnCount > 0, rowCount > 0 else { return [] }

        let columnStride = itemSize.width + itemSpacing
        let rowStride = itemSize.height + itemSpacing

        let firstColumn = max(Int(floor(rect.minX / columnStride)), 0)
        let lastColumn = min(Int(floor(rect.maxX / columnStride)), columnCount - 1)
        let firstRow = max(Int(floor(rect.minY / rowStride)), 0)
        let lastRow = min(Int(floor(rect.maxY / rowStride)), rowCount - 1)

        guard firstColumn <= lastColumn, firstRow <= lastRow else { return [] }

        var attributes = [UICollectionViewLayoutAttributes]()
        for row in firstRow...lastRow {
            for column in firstColumn...lastColumn {
                let item = row * columnCount + column
                let indexPath = IndexPath(item: item, section: 0)
                if let itemAttributes = layoutAttributesForItem(at: indexPath),
                   itemAttributes.frame.intersects(rect) {
                    attributes.append(itemAttributes)
                }
            }
        }

        return attributes
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard columnCount > 0, rowCount > 0 else { return nil }
        guard indexPath.item >= 0, indexPath.item < columnCount * rowCount else { return nil }

        let row = indexPath.item / columnCount
        let column = indexPath.item % columnCount

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: CGFloat(column) * (itemSize.width + itemSpacing),
                                  y: CGFloat(row) * (itemSize.height + itemSpacing),
                                  width: itemSize.width,
                                  height: itemSize.height)
        return attributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
}
