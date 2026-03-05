//
//  ShortcutManager.swift
//  Rippple
//
//  Created by Kevin Cador on 14/06/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

final class ShortcutManager {

    let searchAndKeyboardShortcutItem = UIApplicationShortcutItem(type: "SearchAndKeyboard",
                                                                  localizedTitle: "Search",
                                                                  localizedSubtitle: nil,
                                                                  icon: UIApplicationShortcutIcon(type: .search),
                                                                  userInfo: nil)

    let appIconShortcutItem = UIApplicationShortcutItem(type: "AppIcon",
                                                        localizedTitle: "Edit App Icon",
                                                        localizedSubtitle: nil,
                                                        icon: UIApplicationShortcutIcon(systemImageName: "app"),
                                                        userInfo: nil)

    private init() { }

    static let shared = ShortcutManager()

    func shouldHandle(shortcut: UIApplicationShortcutItem) {
        if shortcut == searchAndKeyboardShortcutItem {
            DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://search")!)
        } else {
            DeeplinkManager.shared.registerDeeplink(url: URL(string: "ripl://settings/appicon")!)
        }
    }
}
