//
//  ManualRemoteNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 22/04/2024.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

final class ManualRemoteNotificationsManager {
    static let shared = ManualRemoteNotificationsManager()

    /// Settings
    var appUpdate: Bool {
        didSet {
            UserDefaults.standard.set(appUpdate, forKey: "ManualRemoteNotificationsManager.appUpdate")
            UserDefaults.standard.synchronize()
        }
    }

    var blogPost: Bool {
        didSet {
            UserDefaults.standard.set(blogPost, forKey: "ManualRemoteNotificationsManager.blogPost")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        appUpdate = UserDefaults.standard.bool(forKey: "ManualRemoteNotificationsManager.appUpdate")
        blogPost = UserDefaults.standard.bool(forKey: "ManualRemoteNotificationsManager.blogPost")
    }
}
