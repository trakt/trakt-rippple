//
//  ActivityPunchcardView.swift
//  Rippple
//
//  Created by Kevin Cador on 07/08/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

enum ActivityPunchcardMetrics {
    static let punchSize: CGFloat = 12
    static let spacing: CGFloat = 5
    static let rowCount = 5

    static func dimensionCount(for length: CGFloat) -> Int {
        return max(Int((length + spacing) / (punchSize + spacing)), 1)
    }

    static func gridLength(for dimensionCount: Int) -> CGFloat {
        return (CGFloat(dimensionCount) * punchSize)
            + (CGFloat(max(dimensionCount - 1, 0)) * spacing)
    }
}

struct ActivityPunchcardView: View {
    let activityCounts: [Date: Int]

    var isLoading = false
    var referenceDate: Date = .now
    var calendar: Calendar = .current
    var tint = UIColor(asset: .globalTint)
    var punchSize = ActivityPunchcardMetrics.punchSize
    var spacing = ActivityPunchcardMetrics.spacing
    var dimensionCountReduction = 0
    var additionalColumnCountReduction = 0
    var expandsPunchesToFit = false
    var outerCornerRadiusFactor: CGFloat = 0.5

    var body: some View {
        GeometryReader { geometry in
            let columnCount = max(dimensionCount(for: geometry.size.width)
                - dimensionCountReduction
                - additionalColumnCountReduction, 1)
            let rowCount = max(dimensionCount(for: geometry.size.height) - dimensionCountReduction, 1)
            let resolvedPunchSize = resolvedPunchSize(for: geometry.size,
                                                      columnCount: columnCount,
                                                      rowCount: rowCount)
            let punches = punches(count: columnCount * rowCount)
            let maximumCount = punches.map(\.activityCount).max() ?? 0
            let isEmpty = maximumCount == 0
            let columns = Array(repeating: GridItem(.fixed(resolvedPunchSize),
                                                    spacing: spacing),
                                count: columnCount)

            LazyVGrid(columns: columns,
                      alignment: .center,
                      spacing: spacing) {
                ForEach(punches.indices, id: \.self) { index in
                    let punch = punches[index]
                    UnevenRoundedRectangle(cornerRadii: cornerRadii(for: index,
                                                                    columnCount: columnCount,
                                                                    rowCount: rowCount,
                                                                    punchSize: resolvedPunchSize),
                                           style: .continuous)
                        .fill(color(for: punch.activityCount,
                                    maximumCount: maximumCount))
                        .frame(width: resolvedPunchSize,
                               height: resolvedPunchSize)
                        .accessibilityLabel(punch.date.formatted(date: .complete,
                                                                 time: .omitted))
                        .accessibilityValue(punch.activityCount == 1
                            ? "1 activity"
                            : "\(punch.activityCount) activities")
                }
            }
            .frame(width: gridLength(for: columnCount, punchSize: resolvedPunchSize),
                   height: gridLength(for: rowCount, punchSize: resolvedPunchSize))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .opacity(isLoading ? 0.1 : isEmpty ? 0.2 : 1)
            .animation(isLoading ? .easeInOut(duration: 1).repeatForever() : .default,
                       value: isLoading)
            .overlay {
                if !isLoading, isEmpty {
                    Text("No recent activity")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dimensionCount(for length: CGFloat) -> Int {
        return max(Int((length + spacing) / (punchSize + spacing)), 1)
    }

    private func resolvedPunchSize(for size: CGSize,
                                   columnCount: Int,
                                   rowCount: Int) -> CGFloat {
        guard expandsPunchesToFit else { return punchSize }
        let horizontalSize = (size.width - (CGFloat(columnCount - 1) * spacing)) / CGFloat(columnCount)
        let verticalSize = (size.height - (CGFloat(rowCount - 1) * spacing)) / CGFloat(rowCount)
        return max(min(horizontalSize, verticalSize), punchSize)
    }

    private func gridLength(for dimensionCount: Int, punchSize: CGFloat) -> CGFloat {
        return (CGFloat(dimensionCount) * punchSize)
            + (CGFloat(max(dimensionCount - 1, 0)) * spacing)
    }

    private func punches(count: Int) -> [Punch] {
        let lastDate = calendar.startOfDay(for: referenceDate)
        return (0..<count).compactMap { index in
            let offset = index - count + 1
            guard let date = calendar.date(byAdding: .day,
                                           value: offset,
                                           to: lastDate) else { return nil }
            return Punch(date: date,
                         activityCount: activityCounts[date, default: 0])
        }
    }

    private func cornerRadii(for index: Int,
                             columnCount: Int,
                             rowCount: Int,
                             punchSize: CGFloat) -> RectangleCornerRadii {
        let regularRadius: CGFloat = 3
        let outsideRadius = punchSize * outerCornerRadiusFactor
        let bottomLeadingIndex = (rowCount - 1) * columnCount
        let bottomTrailingIndex = (rowCount * columnCount) - 1

        return RectangleCornerRadii(topLeading: index == 0 ? outsideRadius : regularRadius,
                                    bottomLeading: index == bottomLeadingIndex ? outsideRadius : regularRadius,
                                    bottomTrailing: index == bottomTrailingIndex ? outsideRadius : regularRadius,
                                    topTrailing: index == columnCount - 1 ? outsideRadius : regularRadius)
    }

    private func color(for activityCount: Int, maximumCount: Int) -> Color {
        guard activityCount > 0, maximumCount > 0 else {
            return Color(uiColor: .tertiarySystemFill)
        }

        let ratio = CGFloat(activityCount) / CGFloat(maximumCount)
        let color: UIColor

        switch ratio {
        case ...0.25:
            color = dynamicTintColor(lightModeAlpha: 0.25) { $0.lighter(amount: 0.2) }
        case ...0.5:
            color = dynamicTintColor(lightModeAlpha: 0.5) { $0 }
        case ...0.75:
            color = dynamicTintColor(lightModeAlpha: 0.75) { $0.darker(amount: 0.2) }
        default:
            color = dynamicTintColor { $0.darker(amount: 0.4) }
        }

        return Color(uiColor: color)
    }

    private func dynamicTintColor(lightModeAlpha: CGFloat? = nil,
                                  transform: @escaping (UIColor) -> UIColor) -> UIColor {
        return UIColor { traitCollection in
            let color = transform(tint.resolvedColor(with: traitCollection))
            guard traitCollection.userInterfaceStyle != .dark,
                  let lightModeAlpha else { return color }
            return color.withAlphaComponent(lightModeAlpha)
        }
    }
}

private extension ActivityPunchcardView {
    struct Punch: Identifiable {
        let date: Date
        let activityCount: Int

        var id: Date {
            return date
        }
    }
}
