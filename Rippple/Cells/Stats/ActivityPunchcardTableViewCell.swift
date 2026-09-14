//
//  ActivityPunchcardTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 10/07/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

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
