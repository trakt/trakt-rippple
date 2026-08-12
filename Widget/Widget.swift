//
//  Widget.swift
//  SingleWidget
//
//  Created by Kevin Cador on 10/07/2022.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import WidgetKit

typealias MediaWidgetIntent = MediaTypeIntent

@main
struct RipppleWidgets {
    static func main() {
        WidgetsWithActivities.main()
    }
}

#if targetEnvironment(macCatalyst)
struct WidgetsWithActivities: WidgetBundle {
    var body: some Widget {
        RipppleOpenControlWidget()
        RipppleOpenSearchControlWidget()
        SingleWidget()
        if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
            ToWatchWidget()
        }
        UpcomingWidget()
        QuickAccessWidget()
        ActivityPunchcardWidget()
    }
}
#else
struct WidgetsWithActivities: WidgetBundle {
    var body: some Widget {
        RipppleOpenControlWidget()
        RipppleOpenSearchControlWidget()
        RipppleLiveActivityWidget()
        SingleWidget()
        if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
            ToWatchWidget()
        }
        UpcomingWidget()
        QuickAccessWidget()
        if #available(iOS 27.0, macOS 27.0, macCatalyst 27.0, visionOS 27.0, *) {
            WatchingControlWidget()
        }
        RipppleLock()
        LastWatchedLockWidget()
        ShowToWatchLockWidget()
        MovieToWatchLockWidget()
        UpcomingShowLockWidget()
        UpcomingMovieLockWidget()
        ActivityPunchcardWidget()
    }
}
#endif

struct RipppleOpenControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rippple.control.open") {
            ControlWidgetButton(action: OpenRipppleIntent()) {
                Label("Open Rippple", systemImage: "target")
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .displayName("Open Rippple")
        .description("Open Rippple from system controls.")
    }
}

struct RipppleOpenSearchControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.rippple.control.search") {
            ControlWidgetButton(action: OpenRipppleSearchIntent()) {
                Label("Search with Rippple", image: .customTargetBadgeMagnifyingglass)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .displayName("Search with Rippple")
        .description("Open Search in Rippple from system controls.")
    }
}
