//
//  ForYouManager.swift
//  Rippple
//
//  Created by Kevin Cador on 23/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

final class ForYouManager {

    public enum Filter: Int {
        case all
        case becauseYouWatchedOnly
        case becauseYouFollowOnly
    }
    public var currentFilter = Filter.all

    private init() { }

    static let shared = ForYouManager()

    private var activities = [HistoryItem]()

    public func filterForYou(comments: [CommentItem]) -> [CommentItem] {
        return comments.filter { item -> Bool in
            if (currentFilter == .all || currentFilter == .becauseYouFollowOnly) && FollowManager.shared.followed(user: item.comment.user) {
                return true
            }

            if currentFilter == .all || currentFilter == .becauseYouWatchedOnly {
                for activity in activities {
                    if let movie = activity.movie, movie == item.movie { return true }
                    if let episode = activity.episode, episode == item.episode { return true }
                }
            }

            return false
        }
    }

    public func refreshActivities(with completion: @escaping (_ error: Error?) -> Void) {
        if SessionManager.shared.isLoggedOut {
            return
        }
        TraktAPIProvider.provider.request(TraktAPIService.history(type: nil, id: nil, pageInfo: PageInfo.firstPage(with: 50), endDate: nil),
                                          callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                                            switch result {
                                            case let .success(moyaResponse):
                                                do {
                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                    let fetchedActivities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                                                    DispatchQueue.main.async {
                                                        self.activities = fetchedActivities
                                                        completion(nil)
                                                    }
                                                } catch {
                                                    DispatchQueue.main.async {
                                                        print("For you comments (/activities) request JSON mapping failed! \(error)")
                                                        completion(error)
                                                    }
                                                }
                                            case let .failure(error):
                                                DispatchQueue.main.async {
                                                    print("For you comments (/activities) request failure \(error)")
                                                    completion(error)
                                                }
                                            }
        }
    }
}
