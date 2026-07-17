//
//  ActivityNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/06/2020.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

final class ActivityNotificationsManager {
    static let shared = ActivityNotificationsManager()

    /// Settings
    var commentNewLikes: Bool {
        didSet {
            UserDefaults.standard.set(commentNewLikes, forKey: "ActivityNotificationsManager.commentNewLikes")
            UserDefaults.standard.synchronize()
        }
    }

    var commentNewReply: Bool {
        didSet {
            UserDefaults.standard.set(commentNewReply, forKey: "ActivityNotificationsManager.commentNewReply")
            UserDefaults.standard.synchronize()
        }
    }

    var commentNewMention: Bool {
        didSet {
            UserDefaults.standard.set(commentNewMention, forKey: "ActivityNotificationsManager.commentNewMention")
            UserDefaults.standard.synchronize()
        }
    }

    var activityNewFollower: Bool {
        didSet {
            UserDefaults.standard.set(activityNewFollower, forKey: "ActivityNotificationsManager.activityNewFollower")
            UserDefaults.standard.synchronize()
        }
    }

    // ----

    private init() {
        commentNewLikes = UserDefaults.standard.bool(forKey: "ActivityNotificationsManager.commentNewLikes")
        commentNewReply = UserDefaults.standard.bool(forKey: "ActivityNotificationsManager.commentNewReply")
        commentNewMention = UserDefaults.standard.bool(forKey: "ActivityNotificationsManager.commentNewMention")
        activityNewFollower = UserDefaults.standard.bool(forKey: "ActivityNotificationsManager.activityNewFollower")
    }
}
