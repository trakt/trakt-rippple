//
//  TraktAPIService.swift
//  Rippple
//
//  Created by Kevin Cador on 04/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

import Moya

struct PageInfo: Equatable, Hashable {
    static func == (lhs: PageInfo, rhs: PageInfo) -> Bool {
        return lhs.page == rhs.page
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(page)
    }

    var page: Int
    var limit: Int
    var pageCount: Int
    var itemCount: Int

    var nextPage: PageInfo {
        return PageInfo(page: page + 1,
                        limit: limit,
                        pageCount: pageCount,
                        itemCount: itemCount)
    }

    static func firstPage(with limit: Int) -> PageInfo {
        return PageInfo(page: 1,
                        limit: limit,
                        pageCount: 1,
                        itemCount: limit)
    }

    init(page: Int, limit: Int, pageCount: Int, itemCount: Int) {
        self.page = page
        self.limit = limit
        self.pageCount = pageCount
        self.itemCount = itemCount
    }

    init?(headers: [AnyHashable: Any]) {
        if let page = headers["x-pagination-page"] as? String,
            let limit = headers["x-pagination-limit"] as? String,
            let pageCount = headers["x-pagination-page-count"] as? String,
            let itemCount = headers["x-pagination-item-count"] as? String {
            self.page = Int(page)!
            self.limit = Int(limit)!
            self.pageCount = Int(pageCount)!
            self.itemCount = Int(itemCount)!
        } else {
            return nil
        }
    }
}

enum TraktObjectType {
    case movie(movieId: Int64)
    case show(showId: Int64)
    case season(showId: Int64, season: Int)
    case episode(showId: Int64, season: Int, episode: Int)
    case user(slug: String)
    case comment(commentId: Int64)
    case all
    case trending
}

enum PostType: String {
    case movie
    case show
    case season
    case episode
}

enum NoteType: String {
    case movie
    case show
    case season
    case episode

    case movieRating
    case showRating
    case seasonRating
    case episodeRating

    case history

    case movieCollection
    case showCollection

    case person
}

enum NotePrivacy: String, Codable, UnknownDecodable {
    case all = "public"
    case me = "private"
    case friends
    case unknown
}

enum HistoryMediaType: String {
    case movies
    case episodes
    case shows
    case seasons
}

enum ListMediaType: String {
    case movies
    case episodes
    case shows
    case seasons
}

enum RatedMediaType: String {
    case all
    case movies
    case episodes
    case shows
    case seasons
}

enum LikeType: String {
    case comments
    case lists
}

enum WatchlistSort: String {
    case rank
    case added
    case released
    case title
}

enum CommentsSort: String {
    case newest
    case oldest
    case likes
    case replies
}

enum SearchType: String {
    case moviesAndShow = "movie,show"
    case movie
    case show
    case person
    case list
}

enum Extended: String {
    case full
    case noseasons
    case fullnoseasons = "noseasons,full"
    case guestStars = "guest_stars"
    case min
}

enum WatchedType: String {
    case movies
    case shows
}

enum HiddenType: String {
    case movie
    case show
    case season
    case user
}

enum ListType: String {
    case all
    case personal
    case official
    case watchlists
    case recommendations
}

enum HiddenSection: String {
    case progressWatched = "progress_watched"
    case calendar
    case comments
    case dropped
}

enum IncludeReplies: String {
    case include = "true"
    case exclude = "false"
    case only = "only"
}

enum TmdbType: String {
    case show
    case episode
    case movie
    case person
}

enum GetNoteType: String {
    case all
    case movies
    case shows
    case seasons
    case episodes
    case people
    case history
    case collection
    case ratings
}

enum CertificationType: String {
    case movies
    case shows
}

enum TraktAPIService {
    case token(code: String)
    case refresh(refreshToken: String)
    case revoke(token: String)
    case watching(slug: String = "me")
    case settings
    case comments(type: TraktObjectType, pageInfo: PageInfo, sortBy: CommentsSort?, replies: IncludeReplies?)
    case commentCount(type: TraktObjectType)

    case history(slug: String = "me", type: HistoryMediaType?, id: Int64?, pageInfo: PageInfo, endDate: Date?)
    case isWatched(type: HistoryMediaType, id: Int64)
    case addMovieToHistory(id: Int64, watchedAt: Date?)
    case addEpisodeToHistory(id: Int64, watchedAt: Date?)
    case addEpisodesToHistory(showId: Int64, watchedAt: Date?, seasonsEpisodes: [(Int, Int)], runtime: Int?)
    case addSeasonToHistory(id: Int64, watchedAt: Date?)
    case addShowToHistory(id: Int64, watchedAt: Date?)
    case removeFromHistory(id: Int64)
    case removeMovieFromHistory(id: Int64)
    case removeShowFromHistory(id: Int64)
    case removeEpisodeFromHistory(id: Int64)
    case removeSeasonFromHistory(id: Int64)
    case removeMultipleFromHistory(ids: [Int64])

    case likes(type: LikeType, pageInfo: PageInfo)

    case likeComment(id: Int64)
    case unlikeComment(id: Int64)
    case likeList(slug: String, id: Int64)
    case unlikeList(slug: String, id: Int64)

    case commentLikesCount(id: Int64)
    case commentLikes(id: Int64, pageInfo: PageInfo)

    case stats(type: TraktObjectType)

    case postComment(type: PostType, traktId: Int64, body: String, spoilers: Bool)
    case postReply(id: Int64, body: String, spoilers: Bool)

    case deleteComment(id: Int64)
    case updateComment(id: Int64, body: String, spoilers: Bool)

    case follow(slug: String)
    case unfollow(slug: String)

    case following(slug: String?)
    case pendingFollowing
    case followers(slug: String?)
    case friends(slug: String?)

    case show(id: String, extended: Extended?)
    case movie(id: String, extended: Extended?)
    case comment(id: Int64)
    case episode(id: String, season: Int, episode: Int)
    case user(id: String)

    case commentMediaItem(id: Int64)

    case showSentiments(id: String)
    case movieSentiments(id: String)
    case seasonSentiments(id: String, season: Int)
    case episodeSentiments(id: Int64)

    case search(type: SearchType, query: String)
    case lookup(tmdbID: String, type: TmdbType)

    case trendingLists(type: ListType?)
    case popularLists(type: ListType?)

    case seasons(id: Int64)
    case episodes(id: Int64, season: Int)

    case ratings(type: TraktObjectType)

    case rated(slug: String = "me", type: RatedMediaType?, extended: Extended?)

    case rateMovie(id: Int64, rating: Int)
    case rateShow(id: Int64, rating: Int)
    case rateSeason(id: Int64, rating: Int)
    case rateEpisode(id: Int64, rating: Int)

    case removeMovieRating(id: Int64)
    case removeShowRating(id: Int64)
    case removeSeasonRating(id: Int64)
    case removeEpisodeRating(id: Int64)

    case checkin(item: CheckinItem)
    case cancelCheckin

    case showProgress(id: Int64, includesSpecials: Bool)

    case watchlist(slug: String = "me", type: ListMediaType?, extended: Extended?, sort: WatchlistSort?, pageInfo: PageInfo)
    case recommended(slug: String = "me", type: ListMediaType?, extended: Extended?, sort: WatchlistSort?, pageInfo: PageInfo)
    case collection(slug: String = "me", type: ListMediaType?, extended: Extended?, sort: WatchlistSort?, pageInfo: PageInfo)

    case addToWatchlist(item: WatchlistedItem)
    case removeFromWatchlist(item: WatchlistedItem)

    case addToRecommendations(item: WatchlistedItem)
    case removeFromRecommendations(item: WatchlistedItem)

    case addToCollection(item: WatchlistedItem)
    case removeFromCollection(item: WatchlistedItem)

    case peopleMovie(id: Int64)
    case peopleShow(id: Int64, extended: Extended?)
    case peopleEpisode(id: Int64, season: Int, episode: Int, extended: Extended?)
    case peopleSeason(id: Int64, season: Int, extended: Extended?)

    case people(id: Int64)
    case peopleSlug(slug: String)

    case peopleMovies(id: Int64)
    case peopleShows(id: Int64)
    case knownFor(id: Int64)

    case customLists(slug: String = "me")
    case customList(userSlug: String, listSlug: String)
    case collaborations(slug: String = "me")
    case listItems(slug: String?, id: Int64, type: ListMediaType?, extended: Extended?, pageInfo: PageInfo, marker: String)
    case createList(name: String, description: String, privacy: ListPrivacy, displayNumbers: Bool, allowComments: Bool)
    case deleteList(id: Int64)
    case reorderLists(ids: [Int64])
    case updateList(id: Int64, name: String, description: String, privacy: ListPrivacy, displayNumbers: Bool, allowComments: Bool)

    case addToList(slug: String? = "me", id: Int64, item: WatchlistedItem)
    case removeFromList(slug: String? = "me", id: Int64, item: WatchlistedItem)

    case addToListWithNotes(slug: String? = "me", id: Int64, item: WatchlistedItemWithNotes)

    case watched(slug: String = "me", type: WatchedType, extended: Extended?)
    case syncWatched(type: WatchedType, extended: Extended?)

    case showsCalendar(startDate: Date, days: Int, filters: [String: String])
    case premiereCalendar(startDate: Date, days: Int)
    // calendars/all/shows/start_date/days
    case moviesCalendar(startDate: Date, days: Int, filters: [String: String])
    case dvdMoviesCalendar(startDate: Date, days: Int)

    case myShowsCalendar(startDate: Date, days: Int)
    case myMoviesCalendar(startDate: Date, days: Int)

    case hidden(section: HiddenSection, type: HiddenType?, extended: Extended?, pageInfo: PageInfo)

    case hideShow(section: HiddenSection, id: Int64, at: Date? = .now)
    case unhideShow(section: HiddenSection, id: Int64)

    case hideSeason(section: HiddenSection, id: Int64)
    case unhideSeason(section: HiddenSection, id: Int64)

    case hideMovie(section: HiddenSection, id: Int64)

    case hideUser(section: HiddenSection, slug: String)
    case unhideUser(section: HiddenSection, slug: String)

    case resetProgress(id: Int64)
    case undoResetProgress(id: Int64)

    case trendingMovies(filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case trendingShows(filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case anticipatedMovies(filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case anticipatedShows(filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case popularMovies(filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case popularShows(filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case recommendedMovies(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case recommendedShows(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case boxoffice(filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case playedMovies(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case playedShows(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case watchedMovies(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case watchedShows(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case collectedMovies(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)
    case collectedShows(period: String, filters: [String: String], extended: Extended, pageInfo: PageInfo)

    case movieGenres
    case tvGenres

    case movieLanguages
    case tvLanguages
    case movieCountries
    case tvCountries
    case movieCertifications
    case tvCertifications
    case networks

    case savedFilters
    case savedFilter(section: String, path: String, query: String, pageInfo: PageInfo)

    case movieLists(id: Int64, type: ListType)
    case showLists(id: Int64, type: ListType)

    case updateListItem(note: String, userId: String, listId: Int64, itemId: Int64)
    case updateWatchlistItem(note: String, itemId: Int64)
    case updateRecommendationItem(note: String, itemId: Int64)

    case notes(userId: String, noteType: GetNoteType, extended: Extended?, pageInfo: PageInfo)
    case addNotes(type: NoteType, traktId: Int64, notes: String, spoilers: Bool, privacy: NotePrivacy)
    case updateNotes(id: Int64, notes: String, spoilers: Bool?, privacy: NotePrivacy?)
    case deleteNotes(id: Int64)

    case certifications(type: CertificationType)

    case lastActivities

    case movieReleases(id: Int64)

    case lastEpisode(id: Int64)
    case nextEpisode(id: Int64)

    case videos(type: TraktObjectType)

    case mir(slug: String, year: Int, month: Int)
    case yir(slug: String, year: Int)

    case showTranslations(id: String)
    case movieTranslations(id: String)
    case seasonTranslations(id: String, season: Int)
    case episodeTranslations(id: String, season: Int, episode: Int)

    case showListed(id: Int64)
    case movieListed(id: Int64)
    case seasonListed(id: Int64, season: Int)
    case episodeListed(id: Int64, season: Int, episode: Int)

    case reactions
    case addCommentReaction(id: Int64, reaction: String)
    case removeCommentReaction(id: Int64, reaction: String)
    case commentReactions(id: Int64, pageInfo: PageInfo)
    case commentReactionsSummary(id: Int64)
    case userCommentsReactions

    case verifyIAP(transactionId: UInt64, userId: Int64)
    case verifySandboxIAP(transactionId: UInt64, userId: Int64)
}

// MARK: - TargetType Protocol Implementation
extension TraktAPIService: AuthorizedTargetType {
    var validationType: ValidationType {
//        return .successCodes

//        switch self {
//        case .checkin:
//            return .customCodes([201, 409])
//        case .deleteComment:
//            return .customCodes([204, 409])
//        case .user:
//            return .customCodes([200, 404, 401])
//        default:
//            return .successCodes
//        }

        return .customCodes([200, 201, 204, 401, 409])
    }
    var baseURL: URL {
        switch self {
        case .verifyIAP, .verifySandboxIAP:
            // Some things can go through the website, not the API
            return URL(string: TraktAPIConfiguration.authBaseURL)!
        default:
            return URL(string: TraktAPIConfiguration.baseURL)!
        }
    }
    var path: String {
        switch self {
        case .token:
            return "/oauth/token"
        case .refresh:
            return "/oauth/token"
        case .revoke:
            return "/oauth/revoke"
        case .watching(let slug):
            return "/users/\(slug)/watching"
        case .settings:
            return "/users/settings"
        case let .comments(type, _, sort, _):
            switch type {
            case .movie(let movieId):
                if let sort = sort {
                    return "/movies/\(movieId)/comments/\(sort)"
                }
                return "/movies/\(movieId)/comments/newest"
            case .show(let showId):
                if let sort = sort {
                    return "/shows/\(showId)/comments/\(sort)"
                }
                return "/shows/\(showId)/comments/newest"
            case .season(let showId, let season):
                if let sort = sort {
                    return "/shows/\(showId)/seasons/\(season)/comments/\(sort)"
                }
                return "/shows/\(showId)/seasons/\(season)/comments/newest"
            case .episode(let showId, let season, let episode):
                if let sort = sort {
                    return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/comments/\(sort)"
                }
                return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/comments/newest"
            case .user(let slug):
                return "/users/\(slug)/comments/all/all"
            case .comment(let commentId):
                return "/comments/\(commentId)/replies"
            case .all:
                return "/comments/recent/all/all"
            case .trending:
                return "/comments/trending"
            }
        case let .commentLikesCount(id):
            return "/comments/\(id)/likes"
        case let .commentCount(type):
            switch type {
            case .movie(let movieId):
                return "/movies/\(movieId)/comments"
            case .show(let showId):
                return "/shows/\(showId)/comments"
            case .season(let showId, let season):
                return "/shows/\(showId)/seasons/\(season)/comments/newest"
            case .episode(let showId, let season, let episode):
                return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/comments/newest"
            case .user(let slug):
                return "/users/\(slug)/comments/all/all"
            case .comment(let commentId):
                return "/comments/\(commentId)/replies"
            case .all:
                fatalError()
            case .trending:
                fatalError()
            }
        case let .history(slug, type, id, _, _):
            if let type = type, id == nil {
                return "/users/\(slug)/history/\(type)"
            } else if let type = type, let id = id {
                return "/users/\(slug)/history/\(type)/\(id)"
            } else {
                return "/users/\(slug)/history"
            }
        case let .isWatched(type, id):
            return "/users/me/history/\(type)/\(id)"
        case let .likeComment(id), let .unlikeComment(id):
            return "/comments/\(id)/like"
        case let .likeList(slug, id), let .unlikeList(slug, id):
            if slug == "trakt" {
                return "/lists/\(id)/like"
            } else {
                return "/users/\(slug)/lists/\(id)/like"
            }
        case .likes(let type, _):
            return "/users/likes/\(type)"
        case .commentLikes(let id, _):
            return "/comments/\(id)/likes"
        case let .stats(type):
            switch type {
            case .movie(let movieId):
                return "/movies/\(movieId)/stats"
            case .show(let showId):
                return "/shows/\(showId)/stats"
            case .season(let showId, let season):
                return "/shows/\(showId)/seasons/\(season)/stats"
            case .episode(let showId, let season, let episode):
                return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/stats"
            case .user(let slug):
                return "/users/\(slug)/stats"
            case .comment(let commentId):
                return "/comments/\(commentId)/stats" // not supported by trakt
            case .all:
                fatalError()
            case .trending:
                fatalError()
            }
        case .postComment:
            return "/comments"
        case .postReply(let id, _, _):
            return "/comments/\(id)/replies"
        case .deleteComment(let id):
            return "/comments/\(id)"
        case .updateComment(let id, _, _):
            return "/comments/\(id)"
        case .follow(let id), .unfollow(let id):
            return "/users/\(id)/follow"
        case .following(let slug):
            if let slug = slug {
                return "/users/\(slug)/following"
            }
            return "/users/me/following"
        case .pendingFollowing:
            return "/users/requests/following"
        case .followers(let slug):
            if let slug = slug {
                return "/users/\(slug)/followers"
            }
            return "/users/me/followers"
        case .friends(let slug):
            if let slug = slug {
                return "/users/\(slug)/friends"
            }
            return "/users/me/friends"
        case .show(let id, _):
            return "/shows/\(id)"
        case .showSentiments(let id):
            return "/shows/\(id)/sentiments"
        case .movieSentiments(let id):
            return "/movies/\(id)/sentiments"
        case .seasonSentiments(let id, let season):
            return "/shows/\(id)/seasons/\(season)/sentiments"
        case .episodeSentiments(let id):
            return "/episodes/\(id)/sentiments"
        case .movie(let id, _):
            return "/movies/\(id)"
        case .comment(let id):
            return "/comments/\(id)"
        case .episode(let id, let season, let episode):
            return "/shows/\(id)/seasons/\(season)/episodes/\(episode)"
        case .user(let id):
            return "/users/\(id)"
        case .commentMediaItem(let id):
            return "/comments/\(id)/item"
        case .search(let type, _):
            return "/search/\(type.rawValue)"
        case .lookup(let tmdb, _):
            return "/search/tmdb/\(tmdb)"
        case .trendingMovies:
            return "/movies/trending"
        case .trendingShows:
            return "/shows/trending/"
        case .trendingLists(let type):
            if let type = type {
                return "/lists/trending/\(type)"
            } else {
                return "/lists/trending"
            }
        case .popularMovies:
            return "/movies/popular"
        case .popularShows:
            return "/shows/popular"
        case .popularLists(let type):
            if let type = type {
                return "/lists/popular/\(type)"
            } else {
                return "/lists/popular"
            }
        case .anticipatedMovies:
            return "/movies/anticipated"
        case .anticipatedShows:
            return "/shows/anticipated"
        case .seasons(let id):
            return "/shows/\(id)/seasons"
        case .episodes(let id, let season):
            return "/shows/\(id)/seasons/\(season)"
        case .ratings(let type):
            switch type {
            case .movie(let movieId):
                return "/movies/\(movieId)/ratings"
            case .show(let showId):
                return "/shows/\(showId)/ratings"
            case .season(let showId, let season):
                return "/shows/\(showId)/seasons/\(season)/ratings"
            case .episode(let showId, let season, let episode):
                return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/ratings"
            default:
                fatalError("Other types not managed by ratings method")
            }
        case .rated(let slug, let type, _):
            return "/users/\(slug)/ratings/\(type ?? .all)"
        case .rateMovie:
            return "/sync/ratings"
        case .rateShow:
            return "/sync/ratings"
        case .rateEpisode:
            return "/sync/ratings"
        case .rateSeason:
            return "/sync/ratings"
        case .removeMovieRating:
            return "/sync/ratings/remove"
        case .removeShowRating:
            return "/sync/ratings/remove"
        case .removeSeasonRating:
            return "/sync/ratings/remove"
        case .removeEpisodeRating:
            return "/sync/ratings/remove"
        case .checkin:
            return "/checkin"
        case .cancelCheckin:
            return "/checkin"
        case .showProgress(let showId, _):
            return "shows/\(showId)/progress/watched"
        case .watchlist(let slug, let type, _, let sort, _):
            switch (type, sort) {
            case (.some(let type), .some(let sort)):
                return "/users/\(slug)/watchlist/\(type)/\(sort)"
            case (.some(let type), nil):
                return "/users/\(slug)/watchlist/\(type)"
            default:
                return "/users/\(slug)/watchlist"
            }
        case .recommended(let slug, let type, _, let sort, _):
            switch (type, sort) {
            case (.some(let type), .some(let sort)):
                return "/users/\(slug)/favorites/\(type)/\(sort)"
            case (.some(let type), nil):
                return "/users/\(slug)/favorites/\(type)"
            default:
                return "/users/\(slug)/favorites"
            }
        case .collection(let slug, let type, _, _, _):
            switch type {
            case .some(let type):
                return "/users/\(slug)/collection/\(type)"
            default:
                return "/users/\(slug)/collection"
            }
        case .addToWatchlist:
            return "/sync/watchlist"
        case .removeFromWatchlist:
            return "/sync/watchlist/remove"
        case .addToRecommendations:
            return "/sync/favorites"
        case .removeFromRecommendations:
            return "/sync/favorites/remove"
        case .addToCollection:
            return "/sync/collection"
        case .removeFromCollection:
            return "/sync/collection/remove"
        case .recommendedShows(let period, _, _, _):
            return "shows/favorited/\(period)"
        case .recommendedMovies(let period, _, _, _):
            return "movies/favorited/\(period)"
        case .boxoffice:
            return "/movies/boxoffice"
        case .peopleMovie(let movieId):
            return "/movies/\(movieId)/people"
        case .peopleShow(let showId, _):
            return "/shows/\(showId)/people"
        case .peopleEpisode(let showId, let season, let episode, _):
            return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/people"
        case .peopleSeason(let showId, let season, _):
            return "/shows/\(showId)/seasons/\(season)/people"
        case .people(let peopleId):
            return "/people/\(peopleId)"
        case .peopleSlug(let slug):
            return "/people/\(slug)"
        case .peopleMovies(let peopleId):
            return "/people/\(peopleId)/movies"
        case .peopleShows(let peopleId):
            return "/people/\(peopleId)/shows"
        case .customLists(let slug):
            return "/users/\(slug)/lists"
        case .customList(let userSlug, let listSlug):
            return "/users/\(userSlug)/lists/\(listSlug)"
        case .collaborations(let slug):
            return "/users/\(slug)/lists/collaborations"
        case .listItems(let slug, let listId, let type, _, _, _):
            if let slug = slug {
                switch type {
                case .some(let type):
                    return "/users/\(slug)/lists/\(listId)/items/\(type)"
                default:
                    return "/users/\(slug)/lists/\(listId)/items/movie,show,season,episode"
                }
            } else {
                switch type {
                case .some(let type):
                    return "/lists/\(listId)/items/\(type)"
                default:
                    return "/lists/\(listId)/items/movie,show,season,episode"
                }
            }
        case .createList:
            return "/users/me/lists"
        case .deleteList(let listId):
            return "/users/me/lists/\(listId)"
        case .reorderLists:
            return "/users/me/lists/reorder"
        case .updateList(let listId, _, _, _, _, _):
            return "/users/me/lists/\(listId)"
        case .updateListItem(_, let userId, let listId, let itemId):
            return "/users/\(userId)/lists/\(listId)/items/\(itemId)"
        case .updateWatchlistItem(_, let itemId):
            return "/sync/watchlist/\(itemId)"
        case .updateRecommendationItem(_, let itemId):
            return "/sync/favorites/\(itemId)"
        case .addToList(let slug, let listId, _), .addToListWithNotes(let slug, let listId, _):
            return "/users/\(slug!)/lists/\(listId)/items"
        case .removeFromList(let slug, let listId, _):
            return "/users/\(slug!)/lists/\(listId)/items/remove"
        case .watched(let slug, let type, _):
            return "/users/\(slug)/watched/\(type)"
        case .syncWatched(let type, _):
            return "/sync/watched/\(type)"
        case .addEpisodeToHistory, .addMovieToHistory, .addSeasonToHistory, .addShowToHistory, .addEpisodesToHistory:
            return "/sync/history"
        case .showsCalendar(let startDate, let days, _):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/all/shows/\(formattedDate)/\(days)"
        case .premiereCalendar(let startDate, let days):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/all/shows/premieres/\(formattedDate)/\(days)"
        case .moviesCalendar(let startDate, let days, _):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/all/movies/\(formattedDate)/\(days)"
        case .myShowsCalendar(let startDate, let days):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/my/shows/\(formattedDate)/\(days)"
        case .myMoviesCalendar(let startDate, let days):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/my/movies/\(formattedDate)/\(days)"
        case .dvdMoviesCalendar(let startDate, let days):
            let dateFormatter = DateFormatter.init()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let formattedDate = dateFormatter.string(from: startDate)
            return "calendars/all/dvd/\(formattedDate)/\(days)"
        case .removeFromHistory, .removeMultipleFromHistory, .removeShowFromHistory, .removeEpisodeFromHistory, .removeMovieFromHistory, .removeSeasonFromHistory:
            return "sync/history/remove"
        case .hidden(let section, _, _, _), .hideShow(let section, _, _), .hideMovie(let section, _), .hideSeason(let section, _), .hideUser(let section, _):
            return "users/hidden/\(section.rawValue)"
        case .unhideShow(let section, _), .unhideSeason(let section, _), .unhideUser(let section, _):
            return "users/hidden/\(section.rawValue)/remove"
        case .resetProgress(let showId), .undoResetProgress(let showId):
            return "/shows/\(showId)/progress/watched/reset"
        case .playedMovies(let period, _, _, _):
            return "movies/played/\(period)"
        case .playedShows(let period, _, _, _):
            return "shows/played/\(period)"
        case .watchedMovies(let period, _, _, _):
            return "movies/watched/\(period)"
        case .watchedShows(let period, _, _, _):
            return "shows/watched/\(period)"
        case .collectedMovies(let period, _, _, _):
            return "movies/collected/\(period)"
        case .collectedShows(let period, _, _, _):
            return "shows/collected/\(period)"
        case .tvGenres:
            return "/genres/shows"
        case .movieGenres:
            return "/genres/movies"
        case .movieLanguages:
            return "/languages/movies"
        case .tvLanguages:
            return "/languages/shows"
        case .movieCountries:
            return "/countries/movies"
        case .tvCountries:
            return "/countries/shows"
        case .movieCertifications:
            return "/certifications/movies"
        case .tvCertifications:
            return "/certifications/shows"
        case .networks:
            return "/networks"
        case .savedFilters:
            return "/users/saved_filters"
        case .savedFilter(_, let path, _, _):
            return path
        case .showLists(let id, let type):
            return "/shows/\(id)/lists/\(type)"
        case .movieLists(let id, let type):
            return "/movies/\(id)/lists/\(type)"
        case .notes(let userId, let noteType, _, _):
            return "/users/\(userId)/notes/\(noteType)"
        case .addNotes:
            return "/notes"
        case .updateNotes(let id, _, _, _):
            return "/notes/\(id)"
        case .deleteNotes(let id):
            return "/notes/\(id)"
        case .certifications(let type):
            return "/certifications/\(type)"
        case .lastActivities:
            return "/sync/last_activities"
        case .movieReleases(let id):
            return "/movies/\(id)/releases"
        case .lastEpisode(let id):
            return "/shows/\(id)/last_episode"
        case .nextEpisode(let id):
            return "/shows/\(id)/next_episode"
        case .videos(let type):
            switch type {
            case .movie(let id):
                return "/movies/\(id)/videos"
            case .show(let id):
                return "/shows/\(id)/videos"
            case .season(let showId, let season):
                return "/shows/\(showId)/seasons/\(season)/videos"
            case .episode(let showId, let season, let episode):
                return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/videos"
            default:
                fatalError("Unsupported type for /videos")
            }
        case .mir(let slug, let year, let month):
            return "/users/\(slug)/mir/\(year)/\(month)"
        case .yir(let slug, let year):
            return "/users/\(slug)/yir/\(year)"
        case .showTranslations(let showId):
            return "/shows/\(showId)/translations"
        case .movieTranslations(let movieId):
            return "/movies/\(movieId)/translations"
        case .seasonTranslations(let showId, let season):
            return "/shows/\(showId)/seasons/\(season)/translations"
        case .episodeTranslations(let showId, let season, let episode):
            return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/translations"
        case .knownFor(let id):
            return "/people/\(id)/known_for"
        case .showListed(let showId):
            return "/shows/\(showId)/listed"
        case .movieListed(let movieId):
            return "/movies/\(movieId)/listed"
        case .seasonListed(let showId, let season):
            return "/shows/\(showId)/seasons/\(season)/listed"
        case .episodeListed(let showId, let season, let episode):
            return "/shows/\(showId)/seasons/\(season)/episodes/\(episode)/listed"
        case .reactions:
            return "/reactions"
        case .addCommentReaction(let id, let reaction):
            return "/comments/\(id)/reactions/\(reaction)"
        case .removeCommentReaction(let id, let reaction):
            return "/comments/\(id)/reactions/\(reaction)"
        case .userCommentsReactions:
            return "/users/reactions/comments"
        case .commentReactions(let id, _):
            return "/comments/\(id)/reactions"
        case .commentReactionsSummary(let id):
            return "/comments/\(id)/reactions/summary"
        case .verifyIAP:
            return "/vip/apple/v2/verify"
        case .verifySandboxIAP:
            return "/vip/apple/sandbox/v2/verify"

        }
    }
    var method: Moya.Method {
        switch self {
        case .token, .revoke, .refresh:
            return .post
        case .watching, .settings, .comments, .history:
            return .get
        case .isWatched:
            return .head
        case .likeComment:
            return .post
        case .unlikeComment:
            return .delete
        case .likeList:
            return .post
        case .unlikeList:
            return .delete
        case .likes:
            return .get
        case .commentLikes:
            return .get
        case .stats:
            return .get
        case .commentCount:
            return .head
        case .postComment:
            return .post
        case .postReply:
            return .post
        case .deleteComment:
            return .delete
        case .updateComment:
            return .put
        case .follow:
            return .post
        case .unfollow:
            return .delete
        case .following, .followers, .friends, .pendingFollowing:
            return .get
        case .commentLikesCount:
            return .head
        case .show:
            return .get
        case .showSentiments, .movieSentiments, .seasonSentiments, .episodeSentiments:
            return .get
        case .movie:
            return .get
        case .comment:
            return .get
        case .episode:
            return .get
        case .user:
            return .get
        case .commentMediaItem:
            return .get
        case .search:
            return .get
        case .lookup:
            return .get
        case .trendingShows:
            return .get
        case .trendingMovies:
            return .get
        case .trendingLists:
            return .get
        case .popularLists:
            return .get
        case .popularShows:
                return .get
        case .popularMovies:
            return .get
        case .anticipatedShows:
            return .get
        case .anticipatedMovies:
            return .get
        case .seasons:
            return .get
        case .episodes:
            return .get
        case .ratings:
            return .get
        case .rated:
            return .get
        case .rateMovie:
            return .post
        case .rateShow:
            return .post
        case .rateSeason:
            return .post
        case .rateEpisode:
            return .post
        case .removeMovieRating:
            return .post
        case .removeShowRating:
            return .post
        case .removeSeasonRating:
            return .post
        case .removeEpisodeRating:
            return .post
        case .checkin:
            return .post
        case .cancelCheckin:
            return .delete
        case .showProgress:
            return .get
        case .watchlist:
            return .get
        case .addToWatchlist, .addToRecommendations, .removeFromWatchlist, .removeFromRecommendations, .addToCollection, .removeFromCollection:
            return .post
        case .recommendedMovies:
            return .get
        case .recommendedShows:
            return .get
        case .boxoffice:
            return .get
        case .peopleMovie, .peopleShow, .people, .peopleSlug, .peopleMovies, .peopleShows, .peopleEpisode:
            return .get
        case .customLists, .customList, .collaborations:
            return .get
        case .listItems:
            return .get
        case .createList:
            return .post
        case .deleteList:
            return .delete
        case .reorderLists:
            return .post
        case .updateList:
            return .put
        case .addToList, .removeFromList, .addToListWithNotes:
            return .post
        case .watched, .syncWatched:
            return .get
        case .addMovieToHistory, .addEpisodeToHistory, .addShowToHistory, .addSeasonToHistory, .addEpisodesToHistory:
            return .post
        case .showsCalendar, .moviesCalendar, .dvdMoviesCalendar, .myShowsCalendar, .myMoviesCalendar, .premiereCalendar:
            return .get
        case .removeFromHistory, .removeMultipleFromHistory, .removeShowFromHistory, .removeMovieFromHistory, .removeEpisodeFromHistory, .removeSeasonFromHistory:
            return .post
        case .hidden:
            return .get
        case .hideShow, .hideMovie, .hideSeason, .hideUser:
            return .post
        case .unhideShow, .unhideSeason, .unhideUser:
            return .post
        case .recommended:
            return .get
        case .collection:
            return .get
        case .resetProgress:
            return .post
        case .undoResetProgress:
            return .delete
        case .playedShows, .playedMovies, .watchedShows, .watchedMovies, .collectedShows, .collectedMovies:
            return .get
        case .tvGenres, .movieGenres, .movieLanguages, .tvLanguages, .movieCountries, .tvCountries, .movieCertifications, .tvCertifications, .networks:
            return .get
        case .savedFilters:
            return .get
        case .savedFilter:
            return .get
        case .showLists:
            return .get
        case .movieLists:
            return .get
        case .updateListItem, .updateWatchlistItem, .updateRecommendationItem:
            return .put
        case .notes:
            return .get
        case .addNotes:
            return .post
        case .updateNotes:
            return .put
        case .deleteNotes:
            return .delete
        case .certifications:
            return .get
        case .lastActivities:
            return .get
        case .movieReleases:
            return .get
        case .lastEpisode:
            return .get
        case .nextEpisode:
            return .get
        case .peopleSeason:
            return .get
        case .videos:
            return .get
        case .mir, .yir:
            return .get
        case .showTranslations, .movieTranslations, .seasonTranslations, .episodeTranslations:
            return .get
        case .knownFor:
            return .get
        case .showListed:
            return .get
        case .movieListed:
            return .get
        case .seasonListed:
            return .get
        case .episodeListed:
            return .get
        case .reactions:
            return .get
        case .addCommentReaction:
            return .post
        case .removeCommentReaction:
            return .delete
        case .commentReactions:
            return .get
        case .commentReactionsSummary:
            return .get
        case .userCommentsReactions:
            return .get
        case .verifyIAP, .verifySandboxIAP:
            return .post
        }
    }
    var task: Task {
        switch self {
        case let .token(code):
            return .requestParameters(parameters: ["code": code,
                                                   "client_id": TraktAPIConfiguration.clientId,
                                                   "client_secret": TraktAPIConfiguration.secretId,
                                                   "redirect_uri": TraktAPIConfiguration.callbackURL,
                                                   "grant_type": "authorization_code"],
                                      encoding: JSONEncoding.default)
        case let .refresh(refreshToken):
            return .requestParameters(parameters: ["refresh_token": refreshToken,
                                                   "client_id": TraktAPIConfiguration.clientId,
                                                   "client_secret": TraktAPIConfiguration.secretId,
                                                   "redirect_uri": TraktAPIConfiguration.callbackURL,
                                                   "grant_type": "refresh_token"],
                                      encoding: JSONEncoding.default)
        case let .revoke(accessToken):
            return .requestParameters(parameters: ["token": accessToken],
                                      encoding: URLEncoding.default)
        case .watching:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .settings:
            return .requestParameters(parameters: ["extended": "browsing"],
                                      encoding: URLEncoding.default)
        case let .comments(_, pageInfo, _, replies):
            if let replies = replies {
                return .requestParameters(parameters: ["extended": "full,reactions",
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)",
                                                       "include_replies": replies.rawValue],
                                          encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["extended": "full,reactions",
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            }
        case let .likes(_, pageInfo), let .commentLikes(_, pageInfo):
            return .requestParameters(parameters: ["extended": "full,reactions",
                                                   "page": "\(pageInfo.page)",
                                                   "limit": "\(pageInfo.limit)"],
                                      encoding: URLEncoding.default)
        case .history(_, _, _, let pageInfo, let date):
            if let date = date {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                if date.timeIntervalSince1970 == 0 {
                    return .requestParameters(parameters: ["extended": "full",
                                                           "page": "\(pageInfo.page)",
                                                           "limit": "\(pageInfo.limit)",
                                                           "start_at": "\(formatter.string(from: date))",
                                                           "end_at": "\(formatter.string(from: date))"],
                                              encoding: URLEncoding.default)
                } else {
                    return .requestParameters(parameters: ["extended": "full",
                                                           "page": "\(pageInfo.page)",
                                                           "limit": "\(pageInfo.limit)",
                                                           "end_at": "\(formatter.string(from: date))"],
                                              encoding: URLEncoding.default)
                }
            } else {
                return .requestParameters(parameters: ["extended": "full",
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            }
        case .isWatched:
            return .requestParameters(parameters: ["page": "1", "limit": "1"],
                                      encoding: URLEncoding.default)
        case .likeComment, .unlikeComment, .likeList, .unlikeList:
            return .requestPlain
        case .stats:
            return .requestPlain
        case .commentCount, .commentLikesCount:
            return .requestPlain
        case let .postComment(type, traktId, body, spoilers):
            return .requestParameters(parameters: [type.rawValue: ["ids": ["trakt": traktId]],
                                                   "comment": body,
                                                   "spoiler": spoilers],
                                      encoding: JSONEncoding.default)
        case let .postReply(_, body, spoilers):
            return .requestParameters(parameters: ["comment": body, "spoiler": spoilers],
                                      encoding: JSONEncoding.default)
        case .deleteComment:
            return .requestPlain
        case let .updateComment(_, body, spoilers):
            return .requestParameters(parameters: ["comment": body, "spoiler": spoilers],
                                      encoding: JSONEncoding.default)
        case .follow, .unfollow:
            return .requestPlain
        case .following:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .pendingFollowing:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .followers:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .friends:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .show(_, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .showSentiments, .movieSentiments, .seasonSentiments, .episodeSentiments:
            return .requestPlain
        case .movie(_, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .comment:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .episode:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .user:
            return .requestParameters(parameters: ["extended": "full,vip"],
                                      encoding: URLEncoding.default)
        case .commentMediaItem:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .search(let type, let query):
            if type == .person {
                return .requestParameters(parameters: ["query": query,
                             "extended": "full",
                             "page": "1",
                             "limit": "50",
                             "fields": "name"],
                encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["query": query,
                             "extended": "full",
                             "page": "1",
                             "limit": "50"],
                encoding: URLEncoding.default)
            }
        case .lookup(_, let type):
            return .requestParameters(parameters: ["extended": "full", "type": type],
                                      encoding: URLEncoding.default)
        case .trendingMovies(let parameters, let extended, let pageInfo),
                .trendingShows(let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .trendingLists:
            return .requestParameters(parameters: ["extended": "full",
                                                   "page": "1",
                                                   "limit": "50"],
                                      encoding: URLEncoding.default)
        case .popularMovies(let parameters, let extended, let pageInfo),
                .popularShows(let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .popularLists:
            return .requestParameters(parameters: ["extended": "full",
                                                   "page": "1",
                                                   "limit": "50"],
                                      encoding: URLEncoding.default)
        case .anticipatedMovies(let parameters, let extended, let pageInfo),
                .anticipatedShows(let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .seasons:
            return .requestParameters(parameters: ["extended": "episodes,full"],
                                      encoding: URLEncoding.default)
        case .episodes:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .ratings:
            return .requestParameters(parameters: ["extended": "all"],
                                      encoding: URLEncoding.default)
        case .rated(_, _, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .rateMovie(let id, let rating):
            return .requestJSONEncodable(MoviesRating(movies: [Rating(rating: rating,
                                                                     ids: Identifiers.init(trakt: id,
                                                                                           slug: nil,
                                                                                           imdb: nil,
                                                                                           tmdb: nil,
                                                                                           tvdb: nil,
                                                                                           tvrage: nil))]))
        case .rateShow(let id, let rating):
            return .requestJSONEncodable(ShowsRating(shows: [Rating(rating: rating,
                                                                    ids: Identifiers.init(trakt: id,
                                                                                          slug: nil,
                                                                                          imdb: nil,
                                                                                          tmdb: nil,
                                                                                          tvdb: nil,
                                                                                          tvrage: nil))]))
        case .rateSeason(let id, let rating):
            return .requestJSONEncodable(SeasonsRating(seasons: [Rating(rating: rating,
                                                                      ids: Identifiers.init(trakt: id,
                                                                                            slug: nil,
                                                                                            imdb: nil,
                                                                                            tmdb: nil,
                                                                                            tvdb: nil,
                                                                                            tvrage: nil))]))
        case .rateEpisode(let id, let rating):
            return .requestJSONEncodable(EpisodesRating(episodes: [Rating(rating: rating,
                                                                          ids: Identifiers.init(trakt: id,
                                                                                                slug: nil,
                                                                                                imdb: nil,
                                                                                                tmdb: nil,
                                                                                                tvdb: nil,
                                                                                                tvrage: nil))]))
        case .removeMovieRating(let id):
            return .requestJSONEncodable(MoviesRating(movies: [Rating(rating: 0,
                                                                      ids: Identifiers.init(trakt: id,
                                                                                            slug: nil,
                                                                                            imdb: nil,
                                                                                            tmdb: nil,
                                                                                            tvdb: nil,
                                                                                            tvrage: nil))]))
        case .removeShowRating(let id):
            return .requestJSONEncodable(ShowsRating(shows: [Rating(rating: 0,
                                                                      ids: Identifiers.init(trakt: id,
                                                                                            slug: nil,
                                                                                            imdb: nil,
                                                                                            tmdb: nil,
                                                                                            tvdb: nil,
                                                                                            tvrage: nil))]))
        case .removeSeasonRating(let id):
            return .requestJSONEncodable(SeasonsRating(seasons: [Rating(rating: 0,
                                                                      ids: Identifiers.init(trakt: id,
                                                                                            slug: nil,
                                                                                            imdb: nil,
                                                                                            tmdb: nil,
                                                                                            tvdb: nil,
                                                                                            tvrage: nil))]))
        case .removeEpisodeRating(let id):
            return .requestJSONEncodable(EpisodesRating(episodes: [Rating(rating: 0,
                                                                      ids: Identifiers.init(trakt: id,
                                                                                            slug: nil,
                                                                                            imdb: nil,
                                                                                            tmdb: nil,
                                                                                            tvdb: nil,
                                                                                            tvrage: nil))]))
        case .checkin(let item):
            return .requestJSONEncodable(item)
        case .cancelCheckin:
            return .requestPlain
        case .showProgress(_, let includesSpecials):
            if includesSpecials {
                return .requestParameters(parameters: ["extended": "full",
                                                       "specials": true,
                                                       "count_specials": false,
                                                       "last_activity": "watched"],
                                          encoding: URLEncoding.default)
            }
            return .requestParameters(parameters: ["extended": "full",
                                                   "last_activity": "watched"],
                                      encoding: URLEncoding.default)
        case .collection(_, _, let extended, _, let pageInfo):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended,
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            }
        case .recommended(_, _, let extended, _, let pageInfo), .watchlist(_, _, let extended, _, let pageInfo):
            var parameters = ["page": "\(pageInfo.page)",
                              "limit": "\(pageInfo.limit)"]
            if let extended = extended {
                parameters["extended"] = extended.rawValue
            }
            return .requestParameters(parameters: parameters,
                                      encoding: URLEncoding.default)
        case .addToWatchlist(let item), .removeFromWatchlist(let item):
            return .requestJSONEncodable(item)
        case .addToRecommendations(let item), .removeFromRecommendations(let item):
            return .requestJSONEncodable(item)
        case .addToCollection(let item), .removeFromCollection(let item):
            return .requestJSONEncodable(item)
        case .recommendedMovies(_, let parameters, let extended, let pageInfo),
                .recommendedShows(_, let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .boxoffice(let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .peopleMovie:
            return .requestPlain
        case .peopleShow(_, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended.rawValue],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .peopleEpisode(_, _, _, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended.rawValue],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .peopleSeason(_, _, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended.rawValue],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .people, .peopleSlug, .peopleShows, .peopleMovies:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .customLists:
            return .requestPlain
        case .customList:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .collaborations:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .listItems(_, _, _, let extended, let pageInfo, let marker):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended,
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)",
                                                       "marker": marker],
                                          encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)",
                                                       "marker": marker],
                                          encoding: URLEncoding.default)
            }
        case .createList(let name, let description, let privacy, let displayNumbers, let allowComments):
            return .requestParameters(parameters: ["name": name,
                                                   "description": description,
                                                   "privacy": privacy.rawValue,
                                                   "display_numbers": displayNumbers,
                                                   "allow_comments": allowComments],
                                      encoding: JSONEncoding.default)
        case .deleteList:
            return .requestPlain
        case .reorderLists(let ids):
            return .requestParameters(parameters: ["rank": ids],
            encoding: JSONEncoding.default)
        case .updateList(_, let name, let description, let privacy, let displayNumbers, let allowComments):
            return .requestParameters(parameters: ["name": name,
                                                   "description": description,
                                                   "privacy": privacy.rawValue,
                                                   "display_numbers": displayNumbers,
                                                   "allow_comments": allowComments],
                                      encoding: JSONEncoding.default)
        case .addToList(_, _, let item), .removeFromList(_, _, let item):
            return .requestJSONEncodable(item)
        case .addToListWithNotes(_, _, let item):
            return .requestJSONEncodable(item)
        case .watched(_, _, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .syncWatched( _, let extended):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended],
                                          encoding: URLEncoding.default)
            } else {
                return .requestPlain
            }
        case .addMovieToHistory(let traktId, let watchedAt):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            return .requestParameters(parameters: ["movies": [["ids": ["trakt": traktId], "watched_at": watchedAt != nil ? formatter.string(from: watchedAt!) : "released"] as [String: Any]]],
            encoding: JSONEncoding.default)
        case .addEpisodeToHistory(let traktId, let watchedAt):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            return .requestParameters(parameters: ["episodes": [["ids": ["trakt": traktId], "watched_at": watchedAt != nil ? formatter.string(from: watchedAt!) : "released"] as [String: Any]]],
            encoding: JSONEncoding.default)
        case .addEpisodesToHistory(let showId, let watchedAt, let seasonsEpisodes, let runtime):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            var watchedAtWithOffset = watchedAt

            var seasons = [AddHistorySeason]()
            for (season, episode) in seasonsEpisodes.sorted(by: { $0.0 == $1.0 ? $0.1 > $1.1 : $0.0 > $1.0 }) {
                if let watchedAt = watchedAt {
                    let watched = formatter.string(from: watchedAtWithOffset!)
                    watchedAtWithOffset = Calendar.current.date(byAdding: .second,
                                                                value: (runtime ?? 1) * -60,
                                                                to: watchedAtWithOffset!) ?? watchedAt
                    let episode = AddHistoryEpisode(number: episode, watched_at: watched)
                    let season = AddHistorySeason(number: season, episodes: [episode])
                    seasons.append(season)
                } else {
                    let episode = AddHistoryEpisode(number: episode, watched_at: "released")
                    let season = AddHistorySeason(number: season, episodes: [episode])
                    seasons.append(season)
                }
            }
            let show = AddHistoryShow(ids: AddHistoryId(trakt: showId), seasons: seasons)
            let historyStruct = AddHistoryStruct(shows: [show])

            return .requestJSONEncodable(historyStruct)
        case .addShowToHistory(let traktId, let watchedAt):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            return .requestParameters(parameters: ["shows": [["ids": ["trakt": traktId], "watched_at": watchedAt != nil ? formatter.string(from: watchedAt!) : "released"] as [String: Any]]],
            encoding: JSONEncoding.default)
        case .addSeasonToHistory(let traktId, let watchedAt):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            return .requestParameters(parameters: ["seasons": [["ids": ["trakt": traktId], "watched_at": watchedAt != nil ? formatter.string(from: watchedAt!) : "released"] as [String: Any]]],
            encoding: JSONEncoding.default)
        case .moviesCalendar(_, _, let parameters), .showsCalendar(_, _, let parameters):
            var params: [String: String] = ["extended": "full"]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .dvdMoviesCalendar, .myShowsCalendar, .myMoviesCalendar, .premiereCalendar:
            return .requestParameters(parameters: ["extended": "full"], encoding: URLEncoding.default)
        case .removeFromHistory(let id):
            return .requestParameters(parameters: ["ids": [id]], encoding: JSONEncoding.default)
        case .removeMovieFromHistory(let id):
            return .requestParameters(parameters: ["movies": [["ids": ["trakt": id]]]], encoding: JSONEncoding.default)
        case .removeShowFromHistory(let id):
            return .requestParameters(parameters: ["shows": [["ids": ["trakt": id]]]], encoding: JSONEncoding.default)
        case .removeEpisodeFromHistory(let id):
            return .requestParameters(parameters: ["episodes": [["ids": ["trakt": id]]]], encoding: JSONEncoding.default)
        case .removeSeasonFromHistory(let id):
            return .requestParameters(parameters: ["seasons": [["ids": ["trakt": id]]]], encoding: JSONEncoding.default)
        case .removeMultipleFromHistory(let ids):
            return .requestParameters(parameters: ["ids": ids], encoding: JSONEncoding.default)
        case .hidden(_, let type, let extended, let pageInfo):
            if let type = type, let extended = extended {
                return .requestParameters(parameters: ["type": "\(type)",
                                                       "extended": extended,
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            } else if let type = type {
                return .requestParameters(parameters: ["type": "\(type)",
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            } else if let extended = extended {
                return .requestParameters(parameters: ["extended": extended,
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            }
        case .hideShow(_, let showId, let atDate):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)

            return .requestParameters(parameters: ["shows": [["ids": ["trakt": showId], "hidden_at": formatter.string(from: atDate ?? .now)]]],
                                      encoding: JSONEncoding.default)
        case .unhideShow(_, let showId):
            return .requestParameters(parameters: ["shows": [["ids": ["trakt": showId]]]], encoding: JSONEncoding.default)
        case .hideSeason(_, let seasonId), .unhideSeason(_, let seasonId):
            return .requestParameters(parameters: ["seasons": [["ids": ["trakt": seasonId]]]], encoding: JSONEncoding.default)
        case .hideMovie(_, let movieId):
            return .requestParameters(parameters: ["movies": [["ids": ["trakt": movieId]]]], encoding: JSONEncoding.default)
        case .hideUser(_, let slug), .unhideUser(_, let slug):
            return .requestParameters(parameters: ["users": [["ids": ["slug": slug]]]], encoding: JSONEncoding.default)
        case .resetProgress:
            return .requestPlain
        case .undoResetProgress:
            return .requestPlain
        case .playedMovies(_, let parameters, let extended, let pageInfo),
                .playedShows(_, let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .watchedMovies(_, let parameters, let extended, let pageInfo),
                .watchedShows(_, let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .collectedMovies(_, let parameters, let extended, let pageInfo),
                .collectedShows(_, let parameters, let extended, let pageInfo):
            var params: [String: String] = ["extended": extended.rawValue,
                          "page": String(pageInfo.page),
                          "limit": String(pageInfo.limit)]
            params.merge(parameters) { s1, _ in
                return s1
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .tvGenres, .movieGenres, .movieLanguages, .tvLanguages, .movieCountries, .tvCountries, .movieCertifications, .tvCertifications, .networks:
            return .requestPlain
        case .savedFilters:
            return .requestPlain
        case .savedFilter(let section, _, let query, let pageInfo):
            var queryString = query.removingPercentEncoding!
            if section == "search", !queryString.localizedCaseInsensitiveContains("query=") {
                queryString += "&query="
            }
            if section == "calendars" {
                queryString += "&extended=full"
            } else {
                queryString += "&extended=full&page=\(pageInfo.page)&limit=\(pageInfo.limit)"
            }
            let params = queryString.components(separatedBy: "&").map({
                $0.components(separatedBy: "=")
            }).reduce(into: [String: String]()) { dict, pair in
                if pair.count == 2 {
                    dict[pair[0]] = pair[1]
                }
            }
            return .requestParameters(parameters: params,
                                      encoding: URLEncoding.default)
        case .showLists:
            return .requestPlain
        case .movieLists:
            return .requestPlain
        case .updateListItem(let note, _, _, _), .updateWatchlistItem(let note, _), .updateRecommendationItem(let note, _):
            return .requestParameters(parameters: ["notes": note],
                                      encoding: JSONEncoding.default)
        case .notes(_, _, let extended, let pageInfo):
            if let extended = extended {
                return .requestParameters(parameters: ["extended": extended,
                                                       "page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            } else {
                return .requestParameters(parameters: ["page": "\(pageInfo.page)",
                                                       "limit": "\(pageInfo.limit)"],
                                          encoding: URLEncoding.default)
            }
        case .addNotes(let type, let traktId, let notes, let spoilers, let privacy):
            if type == .history {
                return .requestParameters(parameters: ["attached_to": ["type": "history",
                                                                       "id": traktId],
                                                       "notes": notes,
                                                       "spoiler": spoilers,
                                                       "privacy": privacy.rawValue],
                                          encoding: JSONEncoding.default)
            } else if type == .person {
                return .requestParameters(parameters: ["person": ["ids": ["trakt": traktId]],
                                                       "notes": notes,
                                                       "spoiler": spoilers,
                                                       "privacy": privacy.rawValue],
                                          encoding: JSONEncoding.default)
            } else if type.rawValue.hasSuffix("Collection") {
                return .requestParameters(parameters: ["attached_to": ["type": "collection"],
                                                       type.rawValue.split(separator: "Collection").joined(): ["ids": ["trakt": traktId]],
                                                       "notes": notes,
                                                       "spoiler": spoilers,
                                                       "privacy": privacy.rawValue],
                                          encoding: JSONEncoding.default)
            } else if type.rawValue.hasSuffix("Rating") {
                return .requestParameters(parameters: ["attached_to": ["type": "rating"],
                                                       type.rawValue.split(separator: "Rating").joined(): ["ids": ["trakt": traktId]],
                                                       "notes": notes,
                                                       "spoiler": spoilers,
                                                       "privacy": privacy.rawValue],
                                          encoding: JSONEncoding.default)
            } else {
                return .requestParameters(parameters: [type.rawValue: ["ids": ["trakt": traktId]],
                                                       "notes": notes,
                                                       "spoiler": spoilers,
                                                       "privacy": privacy.rawValue],
                                          encoding: JSONEncoding.default)
            }
        case .updateNotes(_, let notes, let spoilers, let privacy):
            var params: [String: Any] = ["notes": notes]
            if let privacy = privacy {
                params.updateValue(privacy.rawValue, forKey: "privacy")
            }
            if let spoilers = spoilers {
                params.updateValue(spoilers, forKey: "spoiler")
            }
            return .requestParameters(parameters: params,
                                      encoding: JSONEncoding.default)
        case .deleteNotes:
            return .requestPlain
        case .certifications:
            return .requestPlain
        case .lastActivities:
            return .requestPlain
        case .movieReleases:
            return .requestPlain
        case .nextEpisode:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .lastEpisode:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .videos:
            return .requestPlain
        case .mir, .yir:
            return .requestPlain
        case .showTranslations, .movieTranslations, .seasonTranslations, .episodeTranslations:
            return .requestPlain
        case .knownFor:
            return .requestParameters(parameters: ["extended": "full"],
                                      encoding: URLEncoding.default)
        case .showListed:
            return .requestPlain
        case .movieListed:
            return .requestPlain
        case .seasonListed:
            return .requestPlain
        case .episodeListed:
            return .requestPlain
        case .reactions:
            return .requestPlain
        case .addCommentReaction:
            return .requestPlain
        case .removeCommentReaction:
            return .requestPlain
        case .commentReactions(_, let pageInfo):
            return .requestParameters(parameters: ["extended": "full",
                                                   "page": "\(pageInfo.page)",
                                                   "limit": "\(pageInfo.limit)"],
                                      encoding: URLEncoding.default)
        case .commentReactionsSummary:
            return .requestPlain
        case .userCommentsReactions:
            return .requestParameters(parameters: ["extended": "min", "limit": "all"],
                                      encoding: URLEncoding.default)
        case .verifyIAP(let transactionId, let userId), .verifySandboxIAP(let transactionId, let userId):
            return .requestParameters(parameters: ["transaction_id": transactionId,
                                                   "user_id": userId],
                                      encoding: JSONEncoding.default)
        }
    }
    var headers: [String: String]? {
        switch self {
        case .token, .refresh:
            return ["Content-type": "application/json"]
        case .revoke:
            return ["Content-type": "application/x-www-form-urlencoded",
                    "trakt-api-version": "2",
                    "trakt-api-key": TraktAPIConfiguration.clientId]
        default:
            return ["Content-type": "application/json",
                    "trakt-api-version": "2",
                    "trakt-api-key": TraktAPIConfiguration.clientId]
        }
    }
    var needsAuth: Bool {
        switch self {
        case .trendingMovies(let filters, _, _),
                .anticipatedMovies(let filters, _, _),
                .popularMovies(let filters, _, _),
                .boxoffice(let filters, _, _),
                .recommendedMovies(_, let filters, _, _),
                .watchedMovies(_, let filters, _, _),
                .playedMovies(_, let filters, _, _),
                .collectedMovies(_, let filters, _, _),
                .trendingShows(let filters, _, _),
                .anticipatedShows(let filters, _, _),
                .popularShows(let filters, _, _),
                .recommendedShows(_, let filters, _, _),
                .watchedShows(_, let filters, _, _),
                .playedShows(_, let filters, _, _),
                .collectedShows(_, let filters, _, _):
            if filters.keys.contains(SmartSearch.Filter.ignoreWatched.rawValue) == true {
                return true
            }
            return false
        case .token, .refresh, .revoke, .commentLikesCount, .show, .movie, .comment, .episode, .commentMediaItem, .search, .trendingLists, .popularLists, .seasons, .episodes, .ratings, .peopleMovie, .peopleShow, .peopleEpisode, .peopleSeason, .people, .peopleSlug, .peopleShows, .peopleMovies, .showsCalendar, .moviesCalendar, .dvdMoviesCalendar, .tvGenres, .movieGenres, .movieLanguages, .tvLanguages, .movieCountries, .tvCountries, .movieCertifications, .tvCertifications, .networks, .movieLists, .showLists, .premiereCalendar, .certifications, .movieReleases, .lastEpisode, .nextEpisode, .showSentiments, .movieSentiments, .seasonSentiments, .episodeSentiments, .videos, .showTranslations, .movieTranslations, .seasonTranslations, .episodeTranslations, .knownFor, .reactions, .commentReactionsSummary:
            return false
        case let .stats(type):
            switch type {
            case .user:
                return true
            default:
                return false
            }
        case let .comments(type: type, _, _, _):
            switch type {
            case .user:
                return true
            default:
                return false
            }
        case let .commentCount(type: type):
            switch type {
            case .user:
                return true
            default:
                return false
            }
        default:
            return true
        }
    }
}

extension SmartSearch {
    var service: TraktAPIService {
        switch contentType {
        case .movie:
            switch contentKind {
            case .trending:
                return .trendingMovies(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                       extended: .full,
                                       pageInfo: PageInfo.firstPage(with: count))
            case .anticipated:
                return .anticipatedMovies(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .popular:
                return .popularMovies(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .boxOffice:
                return .boxoffice(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                  extended: .full,
                                  pageInfo: PageInfo.firstPage(with: count))
            case .recommended:
                return .recommendedMovies(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .watched:
                return .watchedMovies(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .played:
                return .playedMovies(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .collected:
                return .collectedMovies(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            }
        case .show:
            switch contentKind {
            case .trending:
                return .trendingShows(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                       extended: .full,
                                       pageInfo: PageInfo.firstPage(with: count))
            case .anticipated:
                return .anticipatedShows(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .popular:
                return .popularShows(filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .boxOffice:
                fatalError("Box office not possible with shows")
            case .recommended:
                return .recommendedShows(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .watched:
                return .watchedShows(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .played:
                return .playedShows(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            case .collected:
                return .collectedShows(period: period?.rawValue ?? "all",
                                          filters: filters.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value },
                                          extended: .full,
                                          pageInfo: PageInfo.firstPage(with: count))
            }
        }
    }
}
