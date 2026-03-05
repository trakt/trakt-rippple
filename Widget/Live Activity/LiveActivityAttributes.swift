//
//  LiveActivityAttributes.swift
//  Rippple
//
//  Created by Kevin Cador on 16/09/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Foundation
#if !targetEnvironment(macCatalyst)
import ActivityKit

struct RipppleLiveActivityAttributes: ActivityAttributes {
    public typealias LiveActivityStatus = ContentState

    public struct ContentState: Codable, Hashable {
        var entry: WidgetModel
    }
}
#endif
