//
//  SocialActivityUserSummary.swift
//  Rippple
//
//  Created by Kevin Cador on 13/06/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation

enum SocialActivityType: Int, Hashable {
    case watched
    case watchlisted
    case rated
    case commented
}

struct SocialActivityUserSummary: Hashable {
    let user: User
    let activityTypes: [SocialActivityType]
    let activityDetails: [SocialActivityDetail]
    let rating: Int?
    let comment: SocialActivityCommentSummary?
    let latestActivityDate: Date?

    private let firstIndex: Int

    static func summaries(from entries: [SocialEntry], media: MediaModel? = nil) -> [SocialActivityUserSummary] {
        var summariesByUser = [User: SocialActivityUserSummaryBuilder]()

        for (index, entry) in entries.enumerated() {
            let activityTypes = activityTypes(for: entry)
            guard activityTypes.isEmpty == false else { continue }

            let latestActivityDate = latestActivityDate(for: entry)

            guard var builder = summariesByUser[entry.user] else {
                summariesByUser[entry.user] = SocialActivityUserSummaryBuilder(user: entry.user,
                                                                               activityTypes: activityTypes,
                                                                               activityTypeCounts: activityTypeCounts(for: activityTypes),
                                                                               watchedAt: watchedDate(for: entry),
                                                                               watchedPlays: entry.watched?.plays ?? 0,
                                                                               watchlistedAt: entry.watchlisted?.listedAt,
                                                                               rating: entry.watched?.rating?.rating,
                                                                               ratedAt: entry.watched?.rating?.ratedAt,
                                                                               comment: commentSummary(for: entry, media: media),
                                                                               latestActivityDate: latestActivityDate,
                                                                               firstIndex: index)
                continue
            }

            builder.activityTypes.formUnion(activityTypes)
            activityTypes.forEach { builder.activityTypeCounts[$0, default: 0] += 1 }

            if shouldReplace(existingActivityDate: builder.watchedAt, with: watchedDate(for: entry)) {
                builder.watchedAt = watchedDate(for: entry)
            }

            if let plays = entry.watched?.plays {
                builder.watchedPlays = max(builder.watchedPlays, plays)
            }

            if shouldReplace(existingActivityDate: builder.watchlistedAt, with: entry.watchlisted?.listedAt) {
                builder.watchlistedAt = entry.watchlisted?.listedAt
            }

            if builder.rating == nil || shouldReplace(existingActivityDate: builder.ratedAt, with: entry.watched?.rating?.ratedAt) {
                builder.rating = entry.watched?.rating?.rating
                builder.ratedAt = entry.watched?.rating?.ratedAt
            }

            if let comment = commentSummary(for: entry, media: media),
               builder.comment == nil || shouldReplace(existingActivityDate: builder.comment?.date, with: comment.date) {
                builder.comment = comment
            }

            if shouldReplace(existingActivityDate: builder.latestActivityDate, with: latestActivityDate) {
                builder.latestActivityDate = latestActivityDate
            }

            summariesByUser[entry.user] = builder
        }

        return summariesByUser.values
            .map { builder in
                SocialActivityUserSummary(user: builder.user,
                                          activityTypes: sortedActivityTypes(for: builder),
                                          activityDetails: activityDetails(for: builder),
                                          rating: builder.rating,
                                          comment: builder.comment,
                                          latestActivityDate: builder.latestActivityDate,
                                          firstIndex: builder.firstIndex)
            }
            .sorted {
                switch ($0.latestActivityDate, $1.latestActivityDate) {
                case (let leftDate?, let rightDate?) where leftDate != rightDate:
                    return leftDate > rightDate
                case (.some, nil):
                    return true
                case (nil, .some):
                    return false
                default:
                    return $0.firstIndex < $1.firstIndex
                }
            }
    }

    static func activityTypes(for entry: SocialEntry) -> Set<SocialActivityType> {
        var activityTypes = Set<SocialActivityType>()

        if entry.watched != nil {
            activityTypes.insert(.watched)
        }

        if entry.watchlisted != nil {
            activityTypes.insert(.watchlisted)
        }

        if entry.watched?.rating != nil {
            activityTypes.insert(.rated)
        }

        if entry.watched?.comment != nil {
            activityTypes.insert(.commented)
        }

        return activityTypes
    }

    private static func activityDetails(for builder: SocialActivityUserSummaryBuilder) -> [SocialActivityDetail] {
        return sortedActivityTypes(for: builder).compactMap { activityType in
            switch activityType {
            case .watched:
                return SocialActivityDetail(type: .watched,
                                            date: builder.watchedAt,
                                            plays: builder.watchedPlays)
            case .watchlisted:
                return SocialActivityDetail(type: .watchlisted,
                                            date: builder.watchlistedAt,
                                            plays: nil)
            case .rated:
                return nil
            case .commented:
                return nil
            }
        }
    }

    private static func sortedActivityTypes(for builder: SocialActivityUserSummaryBuilder) -> [SocialActivityType] {
        return builder.activityTypes.sorted {
            let leftCount = builder.activityTypeCounts[$0, default: 0]
            let rightCount = builder.activityTypeCounts[$1, default: 0]

            if leftCount == rightCount {
                return $0.rawValue < $1.rawValue
            }

            return leftCount > rightCount
        }
    }

    private static func activityTypeCounts(for activityTypes: Set<SocialActivityType>) -> [SocialActivityType: Int] {
        return activityTypes.reduce(into: [:]) { counts, activityType in
            counts[activityType] = 1
        }
    }

    private static func watchedDate(for entry: SocialEntry) -> Date? {
        return entry.watched?.lastWatchedAt
    }

    private static func commentSummary(for entry: SocialEntry, media: MediaModel?) -> SocialActivityCommentSummary? {
        guard let media else { return nil }
        guard let socialComment = entry.watched?.comment else { return nil }
        guard let identifier = socialComment.identifiers.trakt else { return nil }

        let createDate = socialComment.createDate ?? socialComment.updateDate ?? Date()
        let updateDate = socialComment.updateDate ?? createDate
        let date = [socialComment.createDate, socialComment.updateDate].compactMap { $0 }.max()

        let comment = Comment(identifier: identifier,
                              body: socialComment.body ?? "",
                              containsSpoiler: socialComment.containsSpoiler,
                              isReview: socialComment.isReview,
                              language: socialComment.language,
                              parentIdentifier: 0,
                              createDate: createDate,
                              updateDate: updateDate,
                              replies: 0,
                              likes: 0,
                              userRating: nil,
                              user: entry.user,
                              reactions: nil)

        return SocialActivityCommentSummary(date: date,
                                            commentModel: CommentModel(media: media,
                                                                       comment: comment,
                                                                       spoilerStrategy: .showAllSpoilers))
    }

    private static func shouldReplace(existingActivityDate: Date?, with latestActivityDate: Date?) -> Bool {
        guard let latestActivityDate else { return false }
        guard let existingActivityDate else { return true }
        return latestActivityDate > existingActivityDate
    }

    private static func latestActivityDate(for entry: SocialEntry) -> Date? {
        return [
            entry.watched?.lastWatchedAt,
            entry.watched?.lastUpdatedAt,
            entry.watched?.rating?.ratedAt,
            entry.watched?.comment?.createDate,
            entry.watched?.comment?.updateDate,
            entry.watchlisted?.listedAt
        ].compactMap { $0 }.max()
    }
}

struct SocialActivitiesHeaderSummary: Hashable {
    let activityCount: Int
    let averageRatingPercentage: Int?

    init(summaries: [SocialActivityUserSummary]) {
        activityCount = summaries.reduce(0) { count, summary in
            count + summary.activityTypes.count
        }

        let ratings = summaries.compactMap(\.rating)
        guard ratings.isEmpty == false else {
            averageRatingPercentage = nil
            return
        }

        let averageRating = Double(ratings.reduce(0, +)) / Double(ratings.count)
        averageRatingPercentage = Int((averageRating * 10.0).rounded())
    }

    var titleText: String {
        return "\(activityCount) \(activityCount == 1 ? "activity" : "activities")"
    }

    var averageRatingText: String? {
        guard let averageRatingPercentage else { return nil }
        return "\(averageRatingPercentage)%"
    }
}

private struct SocialActivityUserSummaryBuilder {
    let user: User
    var activityTypes: Set<SocialActivityType>
    var activityTypeCounts: [SocialActivityType: Int]
    var watchedAt: Date?
    var watchedPlays: Int
    var watchlistedAt: Date?
    var rating: Int?
    var ratedAt: Date?
    var comment: SocialActivityCommentSummary?
    var latestActivityDate: Date?
    let firstIndex: Int
}

struct SocialActivityDetail: Hashable {
    let type: SocialActivityType
    let date: Date?
    let plays: Int?

    func text(using formatter: RelativeDateTimeFormatter, relativeTo date: Date = Date()) -> String {
        switch type {
        case .watched:
            let playCount = plays ?? 0

            if let activityDate = self.date {
                if activityDate.timeIntervalSince1970 == 0 {
                    return "\(playCount) play\(playCount > 1 ? "s" : "")"
                }

                let relativeDate = formatter.localizedString(for: activityDate, relativeTo: date)

                if playCount > 1 {
                    return "\(playCount) plays, last watched \(relativeDate)"
                }

                return "Watched \(relativeDate)"
            }

            if playCount > 1 {
                return "\(playCount) plays"
            }

            return "Watched"
        case .watchlisted:
            guard let activityDate = self.date else { return "Watchlisted" }
            return "Watchlisted \(formatter.localizedString(for: activityDate, relativeTo: date))"
        case .rated:
            return "Rated"
        case .commented:
            guard let activityDate = self.date else { return "Commented" }
            return "Commented \(formatter.localizedString(for: activityDate, relativeTo: date))"
        }
    }
}

struct SocialActivityCommentSummary: Hashable {
    let date: Date?
    let commentModel: CommentModel

    func text() -> String {
        return "Read \(userPossessiveName) \(commentModel.commentTypeText)"
    }

    private var userPossessiveName: String {
        let name = commentModel.comment.user.name

        if name.hasSuffix("s") || name.hasSuffix("S") {
            return "\(name)'"
        }

        return "\(name)'s"
    }
}
