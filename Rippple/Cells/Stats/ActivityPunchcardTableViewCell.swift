//
//  ActivityPunchcardTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

private enum ActivityPunchcardMetrics {
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

    var body: some View {
        GeometryReader { geometry in
            let columnCount = ActivityPunchcardMetrics.dimensionCount(for: geometry.size.width)
            let rowCount = ActivityPunchcardMetrics.dimensionCount(for: geometry.size.height)
            let punches = punches(count: columnCount * rowCount)
            let maximumCount = punches.map(\.activityCount).max() ?? 0
            let isEmpty = maximumCount == 0
            let columns = Array(repeating: GridItem(.fixed(ActivityPunchcardMetrics.punchSize),
                                                    spacing: ActivityPunchcardMetrics.spacing),
                                count: columnCount)

            LazyVGrid(columns: columns,
                      alignment: .center,
                      spacing: ActivityPunchcardMetrics.spacing) {
                ForEach(punches.indices, id: \.self) { index in
                    let punch = punches[index]
                    UnevenRoundedRectangle(cornerRadii: cornerRadii(for: index,
                                                                    columnCount: columnCount,
                                                                    rowCount: rowCount),
                                           style: .continuous)
                        .fill(color(for: punch.activityCount,
                                    maximumCount: maximumCount))
                        .frame(width: ActivityPunchcardMetrics.punchSize,
                               height: ActivityPunchcardMetrics.punchSize)
                        .accessibilityLabel(punch.date.formatted(date: .complete,
                                                                 time: .omitted))
                        .accessibilityValue(punch.activityCount == 1
                            ? "1 activity"
                            : "\(punch.activityCount) activities")
                }
            }
            .frame(width: ActivityPunchcardMetrics.gridLength(for: columnCount),
                   height: ActivityPunchcardMetrics.gridLength(for: rowCount))
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
                             rowCount: Int) -> RectangleCornerRadii {
        let regularRadius: CGFloat = 3
        let outsideRadius = ActivityPunchcardMetrics.punchSize / 2
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

final class ActivityPunchcardTableViewCell: TintedCanvasTableViewCell {
    static let reuseIdentifier = "activity punchcard"
    private static let punchcardHorizontalInset: CGFloat = 40

    static func visibleDayCount(for containerWidth: CGFloat) -> Int {
        let width = max(containerWidth - punchcardHorizontalInset, 0)
        return ActivityPunchcardMetrics.dimensionCount(for: width)
            * ActivityPunchcardMetrics.rowCount
    }

    @IBOutlet private var cardView: CardView!
    @IBOutlet private var punchcardPlaceholderView: UIView!
    @IBOutlet private var punchcardPlaceholderHeightConstraint: NSLayoutConstraint!

    private var activityCounts = [Date: Int]()
    private var isLoading = false
    private var referenceDate: Date = .now
    private var configuredWidth: CGFloat = 0
    private var hostingController: RipppleHostingController<ActivityPunchcardView>!

    override func awakeFromNib() {
        super.awakeFromNib()
        installPunchcardView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePunchcardHeight(for: punchcardPlaceholderView.bounds.width)
    }

    func setup(activityCounts: [Date: Int],
               isLoading: Bool = false,
               referenceDate: Date = .now,
               containerWidth: CGFloat) {
        self.activityCounts = activityCounts
        self.isLoading = isLoading
        self.referenceDate = referenceDate
        hostingController.setRootView(makePunchcardView())

        if abs(contentView.bounds.width - containerWidth) > 0.5 {
            contentView.bounds.size.width = containerWidth
        }
        contentView.layoutIfNeeded()
        updatePunchcardHeight(for: punchcardPlaceholderView.bounds.width)
    }

    private func installPunchcardView() {
        hostingController = RipppleHostingController(rootView: makePunchcardView())
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        punchcardPlaceholderView.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: punchcardPlaceholderView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: punchcardPlaceholderView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: punchcardPlaceholderView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: punchcardPlaceholderView.bottomAnchor)
        ])
    }

    private func makePunchcardView() -> ActivityPunchcardView {
        return ActivityPunchcardView(activityCounts: activityCounts,
                                     isLoading: isLoading,
                                     referenceDate: referenceDate,
                                     tint: UIColor(asset: .globalTint))
    }

    private func updatePunchcardHeight(for width: CGFloat) {
        guard width > 0, abs(width - configuredWidth) > 0.5 else { return }
        configuredWidth = width

        let columnCount = ActivityPunchcardMetrics.dimensionCount(for: width)
        let horizontalRemainder = width
            - ActivityPunchcardMetrics.gridLength(for: columnCount)
        let gridHeight = ActivityPunchcardMetrics.gridLength(for: ActivityPunchcardMetrics.rowCount)
        punchcardPlaceholderHeightConstraint.constant = gridHeight + horizontalRemainder
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
