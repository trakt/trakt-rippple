//
//  ForYouManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/01/2018.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

final class ForYouManager {
    enum Filter: Int {
        case all
        case becauseYouWatchedOnly
        case becauseYouFollowOnly
    }

    var currentFilter = Filter.all

    private init() {}

    static let shared = ForYouManager()

    func filterForYou(comments: [CommentItem]) -> [CommentItem] {
        return comments.filter { item -> Bool in
            if (currentFilter == .all || currentFilter == .becauseYouFollowOnly) && FollowManager.shared.followed(user: item.comment.user) {
                return true
            }

            if currentFilter == .all || currentFilter == .becauseYouWatchedOnly {
                if item.movie?.isWatched == true { return true }
                if item.episode?.isWatched == true { return true }
            }

            return false
        }
    }
}
