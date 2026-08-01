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

    private init() {}

    static let shared = ForYouManager()

    func filterForYou(comments: [CommentItem], filter: Filter) -> [CommentItem] {
        return comments.filter { item -> Bool in
            if (filter == .all || filter == .becauseYouFollowOnly) && FollowManager.shared.followed(user: item.comment.user) {
                return true
            }

            if filter == .all || filter == .becauseYouWatchedOnly {
                switch item.type {
                case .movie:
                    if item.movie?.isWatched == true { return true }
                case .show:
                    if item.show?.isWatchedAtLeastOnce == true { return true }
                case .season:
                    if item.season?.isWatchedAtLeastOnce == true { return true }
                case .episode:
                    if item.episode?.isWatched == true { return true }
                case .list, .officiallist, .unknown:
                    break
                }
            }

            return false
        }
    }
}
