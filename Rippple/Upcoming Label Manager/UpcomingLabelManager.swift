//
//  UpcomingLabelManager.swift
//  Rippple
//
//  Created by Kevin Cador on 01/29/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

enum UpcomingLabelStyle: Int, CaseIterable {
    case hotAndUpcoming = 0
    case upcoming = 1

    var label: String {
        switch self {
        case .hotAndUpcoming:
            return "\u{1F525} & Upcoming"
        case .upcoming:
            return "Upcoming"
        }
    }

    var toggled: UpcomingLabelStyle {
        switch self {
        case .hotAndUpcoming:
            return .upcoming
        case .upcoming:
            return .hotAndUpcoming
        }
    }
}

let (upcomingLabelUpdatedTransmitter, upcomingLabelUpdatedReceiver) = Receiver<UpcomingLabelStyle>.make(with: .hot)

final class UpcomingLabelManager {
    static let shared = UpcomingLabelManager()

    private init() {}

    private var currentStyle: UpcomingLabelStyle {
        UpcomingLabelStyle(rawValue: UserDefaults.standard.integer(forKey: "UpcomingLabelManager.labelStyle")) ?? .hotAndUpcoming
    }

    var label: String {
        currentStyle.label
    }

    private func setStyle(_ style: UpcomingLabelStyle) {
        guard style != currentStyle else { return }
        UserDefaults.standard.set(style.rawValue, forKey: "UpcomingLabelManager.labelStyle")
        UserDefaults.standard.synchronize()
        upcomingLabelUpdatedTransmitter.broadcast(style)
    }

    @discardableResult
    func toggleLabel() -> String {
        let newStyle = currentStyle.toggled
        setStyle(newStyle)
        return newStyle.label
    }

    func isToggleableLabel(_ text: String?) -> Bool {
        guard let text else { return false }
        return UpcomingLabelStyle.allCases.contains { $0.label == text }
    }
}
