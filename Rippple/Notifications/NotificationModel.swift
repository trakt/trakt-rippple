//
//  NotificationModel.swift
//  Rippple
//
//  Created by Kevin Cador on 28/04/2023.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

struct RipppleNotification: Encodable, Decodable, Hashable, Equatable {
    let identifier: String
    let title: String
    let subtitle: String
    let body: String
    let date: Date
    let link: String?
    let versionToCheck: Int?

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    static func == (lhs: RipppleNotification, rhs: RipppleNotification) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
