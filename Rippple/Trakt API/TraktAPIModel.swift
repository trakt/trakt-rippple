//
//  TraktAPIModel.swift
//  Rippple
//
//  Created by Kevin Cador on 11/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Emoji
import Foundation

// MARK: - Unknown value Enum

protocol UnknownDecodable: Decodable, RawRepresentable {
    static var unknown: Self { get }
}

extension UnknownDecodable where RawValue: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(RawValue.self)
        self = Self(rawValue: raw) ?? .unknown
    }
}

// MARK: - Standard Media Objects

enum EpisodeType: String, Codable, UnknownDecodable {
    case standard
    case seriesPremiere = "series_premiere"
    case seasonPremiere = "season_premiere"
    case midSeasonFinale = "mid_season_finale"
    case midSeasonPremiere = "mid_season_premiere"
    case seasonFinale = "season_finale"
    case seriesFinale = "series_finale"
    case unknown
}

struct Episode: Codable, Equatable, Hashable {
    private static let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 2
        return numberFormatter
    }()

    static func == (lhs: Episode, rhs: Episode) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    let title: String?
    let season: Int
    let number: Int
    let identifiers: Identifiers

    let commentCount: Int?

    let firstAired: Date?

    let rating: Double?
    let votes: Int?

    let runtime: Int?
    let overview: String?

    let episodeType: EpisodeType?

    enum CodingKeys: String, CodingKey {
        case title
        case season
        case number
        case identifiers = "ids"
        case commentCount = "comment_count"
        case firstAired = "first_aired"
        case runtime
        case overview
        case rating
        case votes
        case episodeType = "episode_type"
    }

    var localizedEpisodeNumber: String {
        return "S\(Episode.numberFormatter.string(from: NSNumber(value: season))!)E\(Episode.numberFormatter.string(from: NSNumber(value: number))!)"
    }

    var localizedSeasonNumber: String {
        return "S\(Episode.numberFormatter.string(from: NSNumber(value: season))!)"
    }
}

struct Show: Codable, Equatable, Hashable {
    static func == (lhs: Show, rhs: Show) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    let officialTitle: String
    let originalTitle: String?
    var title: String {
        if let originalTitle = originalTitle, originalTitle != officialTitle {
            if let language = language, Locale.preferredLanguages.contains(where: { $0.hasPrefix(language) }) {
                return originalTitle
            } else {
                return officialTitle
            }
        } else {
            return officialTitle
        }
    }

    var sortableTitle: String {
        title.sortableString
    }

    let releaseYear: Int?
    let identifiers: Identifiers

    let commentCount: Int?
    let airedEpisodes: Int?

    let tagline: String?
    let overview: String?

    let runtime: Int?
    let certification: String?
    let genres: [String]?

    let firstAired: Date?
    let country: String?

    let network: String?
    let status: String?

    let airs: ShowAirInfo?

    let rating: Double?
    let votes: Int?

    let homepage: String?
    let trailer: String?

    let language: String?

    enum CodingKeys: String, CodingKey {
        case officialTitle = "title"
        case releaseYear = "year"
        case identifiers = "ids"
        case commentCount = "comment_count"
        case airedEpisodes = "aired_episodes"
        case tagline
        case overview
        case runtime
        case genres
        case firstAired = "first_aired"
        case country
        case network
        case status
        case airs
        case certification
        case rating
        case votes
        case homepage
        case trailer
        case originalTitle = "original_title"
        case language
    }
}

struct ShowAirInfo: Codable, Equatable {
    let day: String?
    let time: String?
    let timezone: String?
}

struct Identifiers: Codable, Equatable, Hashable {
    static func == (lhs: Identifiers, rhs: Identifiers) -> Bool {
        if let traktIdLhs = lhs.trakt, let traktIdRhs = rhs.trakt {
            return traktIdLhs == traktIdRhs
        }

        if let slugIdLhs = lhs.slug, let slugIdRhs = rhs.slug {
            return slugIdLhs == slugIdRhs
        }

        if let tmdbIdLhs = lhs.tmdb, let tmdbIdRhs = rhs.tmdb {
            return tmdbIdLhs == tmdbIdRhs
        }

        return false
    }

    func hash(into hasher: inout Hasher) {
        if let trakt = trakt {
            hasher.combine(trakt)
            return
        }

        if let slug = slug {
            hasher.combine(slug)
            return
        }

        if let tmdb = tmdb {
            hasher.combine(tmdb)
            return
        }
    }

    let trakt: Int64?
    let slug: String?
    let imdb: String?
    let tmdb: Int64?
    let tvdb: Int64?
    let tvrage: Int64?

    var traktIdOrSlug: String {
        if let trakt = trakt {
            return String(trakt)
        }
        return slug!
    }

    var slugOrTraktId: String {
        if let slug = slug {
            return slug
        }
        return String(trakt!)
    }
}

struct Movie: Codable, Equatable, Hashable {
    static func == (lhs: Movie, rhs: Movie) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    let officialTitle: String
    let originalTitle: String?
    var title: String {
        if let originalTitle = originalTitle, originalTitle != officialTitle {
            if let language = language, Locale.preferredLanguages.contains(where: { $0.hasPrefix(language) }) {
                return originalTitle
            } else {
                return officialTitle
            }
        } else {
            return officialTitle
        }
    }

    let releaseYear: Int?
    let identifiers: Identifiers

    let status: String?

    let commentCount: Int?

    let tagline: String?
    let overview: String?

    let runtime: Int?
    let certification: String?
    let genres: [String]?

    let released: String?
    let country: String?

    let rating: Double?
    let votes: Int?

    let homepage: String?
    let trailer: String?

    let language: String?

    enum CodingKeys: String, CodingKey {
        case officialTitle = "title"
        case releaseYear = "year"
        case identifiers = "ids"
        case commentCount = "comment_count"
        case tagline
        case overview
        case runtime
        case certification
        case genres
        case released
        case country
        case rating
        case votes
        case status
        case homepage
        case trailer
        case originalTitle = "original_title"
        case language
    }
}

struct Season: Codable, Equatable, Hashable {
    private static let numberFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumIntegerDigits = 2
        return numberFormatter
    }()

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    static func == (lhs: Season, rhs: Season) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    let title: String?
    let overview: String?

    let number: Int
    let identifiers: Identifiers

    let commentCount: Int?

    let rating: Double?
    let votes: Int?

    let episodeCount: Int?
    let airedEpisodes: Int?

    let episodes: [Episode]?

    let firstAired: Date?

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case title
        case overview
        case number
        case identifiers = "ids"
        case commentCount = "comment_count"
        case episodeCount = "episode_count"
        case airedEpisodes = "aired_episodes"
        case episodes
        case rating
        case votes
    }

    var localizedSeasonNumber: String {
        return "S\(Season.numberFormatter.string(from: NSNumber(value: number))!)"
    }
}

enum ListPrivacy: String, Codable, UnknownDecodable {
    case all = "public"
    case me = "private"
    case friends
    case link
    case unknown
}

struct ListItem: Codable {
    let list: List?
}

struct List: Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    static func == (lhs: List, rhs: List) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    private let _name: String
    let description: String?
    let commentsAllowed: Bool
    let displayRank: Bool
    let itemCount: Int?
    let likes: Int
    let identifiers: Identifiers

    let type: String?

    let privacy: ListPrivacy

    let commentCount: Int?

    let shareLink: String?

    let user: User

    enum CodingKeys: String, CodingKey {
        case _name = "name"
        case description
        case commentsAllowed = "allow_comments"
        case itemCount = "item_count"
        case likes
        case identifiers = "ids"
        case commentCount = "comment_count"
        case privacy
        case displayRank = "display_numbers"
        case user
        case type
        case shareLink = "share_link"
    }

    var name: String {
        return _name.emojiUnescapedString
    }
}

// MARK: - Watching

enum WatchingType: String, Codable, UnknownDecodable {
    case episode
    case movie
    case unknown
}

enum WatchingAction: String, Codable, UnknownDecodable {
    case scrobble
    case checkin
    case unknown
}

struct WatchingItem: Codable, Equatable {
    let expireDate: Date
    let startDate: Date
    let action: WatchingAction
    let type: WatchingType

    let movie: Movie?
    let show: Show?
    let episode: Episode?

    init(media: MediaModel) {
        startDate = Date()
        expireDate = startDate.addingTimeInterval(7200)
        action = .checkin
        switch media {
        case .movie(let movie):
            type = .movie
            self.movie = movie
            show = nil
            episode = nil
        case .episode(let episode, let show):
            type = .episode
            self.show = show
            self.episode = episode
            movie = nil
        default:
            fatalError()
        }
    }

    enum CodingKeys: String, CodingKey {
        case expireDate = "expires_at"
        case startDate = "started_at"
        case action
        case type

        case movie
        case show
        case episode
    }

    static func == (lhs: WatchingItem, rhs: WatchingItem) -> Bool {
        return lhs.action == rhs.action &&
            lhs.startDate == rhs.startDate &&
            lhs.expireDate == rhs.expireDate
    }
}

// MARK: - Images

struct ImageSet: Codable {
    let full: URL
}

struct Images: Codable {
    let avatar: ImageSet
}

// MARK: - Settings

struct Account: Codable {
    let coverImageURL: URL?
    let slurm: String?

    enum CodingKeys: String, CodingKey {
        case coverImageURL = "cover_image"
        case slurm = "token"
    }
}

struct User: Codable, Equatable, Hashable {
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.identifiers == rhs.identifiers
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifiers)
    }

    fileprivate let _username: String
    let isPrivate: Bool
    fileprivate let _name: String?
    let isVip: Bool?
    let isVipEp: Bool?
    let isVipOg: Bool?
    let vipYears: Int?
    let vipCoverImage: URL?
    let identifiers: Identifiers
    let joinDate: Date?
    let location: String?
    let about: String?
    let gender: String?
    let age: Int?
    let images: Images?
    let isDirector: Bool?

    enum CodingKeys: String, CodingKey {
        case _username = "username"
        case isPrivate = "private"
        case _name = "name"
        case isVip = "vip"
        case isVipEp = "vip_ep"
        case isVipOg = "vip_og"
        case vipYears = "vip_years"
        case identifiers = "ids"
        case joinDate = "joined_at"
        case location
        case about
        case gender
        case age
        case images
        case vipCoverImage = "vip_cover_image"
        case isDirector = "director"
    }

    var username: String {
        return "@\(_username.slugify())"
    }

    var name: String {
        if let name = _name, name.isEmpty == false {
            return name
        }
        return _username
    }

    var isTraktVIP: Bool {
        return isVip ?? false || isVipOg ?? false || isVipEp ?? false
    }
}

extension User {
    var slug: String {
        return identifiers.slug ?? _username.slugify()
    }
}

struct ListLimits: Codable {
    let count: Int
}

struct NotesLimits: Codable {
    let itemCount: Int

    enum CodingKeys: String, CodingKey {
        case itemCount = "item_count"
    }
}

struct Limits: Codable {
    let list: ListLimits
    let notes: NotesLimits
}

struct Permissions: Codable {
    let commenting: Bool
    let liking: Bool
    let following: Bool
}

struct Browsing: Codable {
    let watchOnlyOnce: Bool

    enum CodingKeys: String, CodingKey {
        case watchOnlyOnce = "watch_only_once"
    }
}

struct Settings: Codable, Hashable {
    let user: User
    let account: Account
    let limits: Limits
    let permissions: Permissions
    let browsing: Browsing

    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
    }

    static func == (lhs: Settings, rhs: Settings) -> Bool {
        return lhs.user == rhs.user
    }
}

// MARK: - Likes (light)

struct CommentLikeId: Codable {
    let id: Int64
}

struct CommentLike: Codable {
    let comment: CommentLikeId?
}

// MARK: - List Likes

struct ListLike: Codable {
    let likedAt: Date
    let list: List

    enum CodingKeys: String, CodingKey {
        case likedAt = "liked_at"
        case list
    }
}

// MARK: - Comments

enum CommentType: String, Codable, UnknownDecodable {
    case movie
    case show
    case season
    case episode
    case list
    case officiallist
    case unknown
}

struct CommentItem: Codable, Hashable {
    static func == (lhs: CommentItem, rhs: CommentItem) -> Bool {
        return lhs.comment == rhs.comment && lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(comment)
        hasher.combine(type)
    }

    let type: CommentType

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    let comment: Comment
}

struct Comment: Codable, Equatable, Hashable {
    static func == (lhs: Comment, rhs: Comment) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    let identifier: Int64
    let body: String
    let containsSpoiler: Bool
    let isReview: Bool
    let parentIdentifier: Int64
    let createDate: Date
    let updateDate: Date
    let replies: Int
    let likes: Int
    let userRating: Int?
    let user: User
    let reactions: ReactionSummary?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case body = "comment"
        case containsSpoiler = "spoiler"
        case isReview = "review"
        case parentIdentifier = "parent_id"
        case createDate = "created_at"
        case updateDate = "updated_at"
        case replies
        case likes
        case userRating = "user_rating"
        case user
        case reactions
    }
}

extension Comment {
    var isReply: Bool {
        return parentIdentifier != 0
    }
}

// MARK: - History

enum HistoryAction: String, Codable, UnknownDecodable {
    case scrobble
    case checkin
    case watch
    case unknown
}

enum HistoryType: String, Codable, UnknownDecodable {
    case movie
    case episode
    case unknown
}

struct HistoryItem: Codable, Equatable, Hashable {
    let identifier: Int64
    let watchDate: Date
    let action: HistoryAction
    let type: HistoryType

    let movie: Movie?
    let episode: Episode?
    let show: Show?

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case watchDate = "watched_at"
        case action
        case type
        case movie
        case episode
        case show
    }

    static func == (lhs: HistoryItem, rhs: HistoryItem) -> Bool {
        return lhs.identifier == rhs.identifier &&
            lhs.watchDate == rhs.watchDate &&
            lhs.action == rhs.action &&
            lhs.type == rhs.type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
        hasher.combine(watchDate)
        hasher.combine(action)
        hasher.combine(type)
    }
}

// MARK: - Stats

struct Stats: Codable {
    let comments: Int?
    let watchers: Int?
    let plays: Int?
    let collectors: Int?
    let lists: Int?
    let votes: Int?
    let recommended: Int?
    let collectedEpisodes: Int?

    enum CodingKeys: String, CodingKey {
        case comments
        case watchers
        case plays
        case collectors
        case lists
        case votes
        case recommended
        case collectedEpisodes = "collected_episodes"
    }
}

// MARK: - (M)IR Statis

struct IRUserStats: Codable {
    let stats: IRStats
}

struct IRStats: Codable {
    let all: IRAllStats
}

struct IRAllStats: Codable {
    let minutes: IRMonthlyStats
    let playCounts: IRMonthlyStats
    let ratingsCounts: IRMonthlyStats
    let commentsCounts: IRMonthlyStats

    enum CodingKeys: String, CodingKey {
        case minutes
        case playCounts = "play_counts"
        case ratingsCounts = "ratings_counts"
        case commentsCounts = "comments_counts"
    }
}

struct IRMonthlyStats: Codable {
    let total: Int
}

// MARK: - User Stats

struct UserStats: Codable {
    let movies: UserMovieStats
    let shows: UserShowStats
    let seasons: UserSeasonStats
    let episodes: UserEpisodeStats
    let network: UserNetworkStats
}

struct UserNetworkStats: Codable {
    let following: Int
    let followers: Int
    let friends: Int
}

struct UserMovieStats: Codable {
    let comments: Int
    let watched: Int
    let plays: Int
    let ratings: Int
    let minutes: Int
}

struct UserEpisodeStats: Codable {
    let comments: Int
    let watched: Int
    let plays: Int
    let ratings: Int
    let minutes: Int
}

struct UserShowStats: Codable {
    let comments: Int
    let ratings: Int
    let watched: Int
}

struct UserSeasonStats: Codable {
    let comments: Int
    let ratings: Int
}

// MARK: - Blocked User

struct BlockedUser: Codable {
    let hiddenAt: Date?
    let user: User

    enum CodingKeys: String, CodingKey {
        case hiddenAt = "hidden_at"
        case user
    }
}

// MARK: - Hidden Shows

struct HiddenShow: Codable, Equatable {
    let hiddenAt: Date
    let show: Show

    enum CodingKeys: String, CodingKey {
        case hiddenAt = "hidden_at"
        case show
    }
}

// MARK: - Follow

struct Follow: Codable {
    let followedAt: Date?
    let user: User

    enum CodingKeys: String, CodingKey {
        case followedAt = "followed_at"
        case user
    }
}

// MARK: - Social

struct SocialEntry: Codable, Equatable, Hashable {
    let followedAt: Date
    let user: User
    let watched: SocialWatched?
    let watchlisted: SocialWatchlisted?

    enum CodingKeys: String, CodingKey {
        case followedAt = "followed_at"
        case user
        case watched
        case watchlisted
    }
}

struct SocialWatched: Codable, Equatable, Hashable {
    let plays: Int
    let lastWatchedAt: Date?
    let lastUpdatedAt: Date?
    let rating: SocialRating?
    let comment: SocialComment?

    enum CodingKeys: String, CodingKey {
        case plays
        case lastWatchedAt = "last_watched_at"
        case lastUpdatedAt = "last_updated_at"
        case rating
        case comment
    }
}

struct SocialRating: Codable, Equatable, Hashable {
    let rating: Int
    let ratedAt: Date?

    enum CodingKeys: String, CodingKey {
        case rating
        case ratedAt = "rated_at"
    }
}

struct SocialComment: Codable, Equatable, Hashable {
    let identifiers: Identifiers
    let body: String?
    let containsSpoiler: Bool
    let isReview: Bool
    let createDate: Date?
    let updateDate: Date?

    enum CodingKeys: String, CodingKey {
        case identifiers = "ids"
        case body = "comment"
        case containsSpoiler = "spoiler"
        case isReview = "review"
        case createDate = "created_at"
        case updateDate = "updated_at"
    }
}

struct SocialWatchlisted: Codable, Equatable, Hashable {
    let listedAt: Date

    enum CodingKeys: String, CodingKey {
        case listedAt = "listed_at"
    }
}

// MARK: - Media Item

struct MediaItem: Codable, Equatable {
    var type: CommentType {
        if movie != nil { return .movie }

        // Order here is important
        if episode != nil { return .episode }
        if season != nil { return .season }
        if show != nil { return .show }

        if list != nil { return .list }

        return .unknown
    }

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    let watchers: Int?
    let listedAt: Date?
    let collectedAt: Date?
    let lastCollectedAt: Date?
    let hiddenAt: Date?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case movie
        case show
        case episode
        case season
        case list
        case watchers
        case listedAt = "listed_at"
        case collectedAt = "collected_at"
        case lastCollectedAt = "last_collected_at"
        case hiddenAt = "hidden_at"
        case notes
    }

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        return lhs.type == rhs.type &&
            lhs.movie == rhs.movie &&
            lhs.show == rhs.show &&
            lhs.episode == rhs.episode &&
            lhs.season == rhs.season &&
            lhs.list == rhs.list
    }
}

// MARK: - Watchlist Item

struct WatchlistItem: Codable, Equatable, Hashable {
    var type: CommentType {
        if movie != nil { return .movie }

        // Order here is important
        if episode != nil { return .episode }
        if season != nil { return .season }
        if show != nil { return .show }

        if list != nil { return .list }

        return .unknown
    }

    let listedAt: Date
    let rank: Int

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    let id: Int64
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case listedAt = "listed_at"
        case rank
        case movie
        case show
        case episode
        case season
        case list
        case notes
        case id
    }

    static func == (lhs: WatchlistItem, rhs: WatchlistItem) -> Bool {
        return lhs.type == rhs.type &&
            lhs.movie == rhs.movie &&
            lhs.show == rhs.show &&
            lhs.episode == rhs.episode &&
            lhs.season == rhs.season &&
            lhs.list == rhs.list &&
            lhs.listedAt == rhs.listedAt &&
            lhs.rank == rhs.rank &&
            lhs.notes == rhs.notes &&
            lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(movie)
        hasher.combine(show)
        hasher.combine(episode)
        hasher.combine(season)
        hasher.combine(list)
        hasher.combine(listedAt)
        hasher.combine(rank)
        hasher.combine(notes)
        hasher.combine(id)
    }
}

// MARK: - Collection Item

struct CollectionItem: Codable, Equatable, Hashable {
    var type: CommentType {
        if movie != nil { return .movie }

        // Order here is important
        if episode != nil { return .episode }
        if season != nil { return .season }
        if show != nil { return .show }

        if list != nil { return .list }

        return .unknown
    }

    var listedAt: Date {
        if let collectedAt = collectedAt { return collectedAt }
        if let lastCollectedAt = lastCollectedAt { return lastCollectedAt }
        return Date() // should never happen but we never know
    }

    let collectedAt: Date?
    let lastCollectedAt: Date?

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    let notes: String?

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case lastCollectedAt = "last_collected_at"
        case movie
        case show
        case episode
        case season
        case list
        case notes
    }

    static func == (lhs: CollectionItem, rhs: CollectionItem) -> Bool {
        return lhs.type == rhs.type &&
            lhs.movie == rhs.movie &&
            lhs.show == rhs.show &&
            lhs.episode == rhs.episode &&
            lhs.season == rhs.season &&
            lhs.list == rhs.list &&
            lhs.collectedAt == rhs.collectedAt &&
            lhs.lastCollectedAt == rhs.lastCollectedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(movie)
        hasher.combine(show)
        hasher.combine(episode)
        hasher.combine(season)
        hasher.combine(list)
        hasher.combine(collectedAt)
        hasher.combine(lastCollectedAt)
    }
}

// MARK: - Comments likes

struct Like: Codable, Equatable, Hashable {
    let likedAt: Date?
    let user: User

    enum CodingKeys: String, CodingKey {
        case likedAt = "liked_at"
        case user
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
        hasher.combine(likedAt)
    }
}

// MARK: - Ratings

struct Ratings: Codable {
    let trakt: TraktRatings
    let rottenTomatoes: RottenTomatoesRatings
    let imdb: IMDbRatings
    let metascore: MetascoreRatings
    let tmdb: TMDbRatings

    enum CodingKeys: String, CodingKey {
        case trakt
        case rottenTomatoes = "rotten_tomatoes"
        case imdb
        case metascore
        case tmdb
    }
}

struct MetascoreRatings: Codable {
    let rating: Int?
    let link: URL?
}

struct RottenTomatoesRatings: Codable {
    let rating: Int?
    let userRating: Int?
    let link: URL?

    let state: String? // certified, fresh or rotten
    let userState: String? // certified, upright or spilled

    enum CodingKeys: String, CodingKey {
        case rating
        case userRating = "user_rating"
        case link
        case state
        case userState = "user_state"
    }
}

struct IMDbRatings: Codable {
    let rating: Float?
    let votes: Int?
    let link: URL?
}

struct TMDbRatings: Codable {
    let rating: Float?
    let votes: Int?
    let link: URL?
}

struct TraktRatings: Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(rating)
        hasher.combine(votes)
        hasher.combine(distribution)
    }

    let rating: Float
    let votes: Int
    let distribution: RatingDistribution
}

struct RatingDistribution: Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(one)
        hasher.combine(two)
        hasher.combine(three)
        hasher.combine(four)
        hasher.combine(five)
        hasher.combine(six)
        hasher.combine(seven)
        hasher.combine(eight)
        hasher.combine(nine)
        hasher.combine(ten)
    }

    let one: Int
    let two: Int
    let three: Int
    let four: Int
    let five: Int
    let six: Int
    let seven: Int
    let eight: Int
    let nine: Int
    let ten: Int

    enum CodingKeys: String, CodingKey {
        case one = "1"
        case two = "2"
        case three = "3"
        case four = "4"
        case five = "5"
        case six = "6"
        case seven = "7"
        case eight = "8"
        case nine = "9"
        case ten = "10"
    }
}

enum RatedItemType: String, Codable, UnknownDecodable {
    case movie
    case episode
    case show
    case season
    case unknown
}

struct RatedItem: Codable, Equatable, Hashable {
    let rateDate: Date
    let rating: Int
    let type: RatedItemType

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?

    enum CodingKeys: String, CodingKey {
        case rateDate = "rated_at"
        case rating
        case type

        case movie
        case show
        case episode
        case season
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(rating)
        hasher.combine(rateDate)
        hasher.combine(movie)
        hasher.combine(season)
        hasher.combine(show)
        hasher.combine(episode)
    }
}

struct MoviesRating: Codable {
    let movies: [Rating]
}

struct ShowsRating: Codable {
    let shows: [Rating]
}

struct EpisodesRating: Codable {
    let episodes: [Rating]
}

struct SeasonsRating: Codable {
    let seasons: [Rating]
}

struct Rating: Codable {
    let rating: Int
    let ids: Identifiers
}

struct CheckinItem: Codable {
    let movie: Movie?
    let episode: Episode?

    let appVersion: String?

    init(episode: Episode) {
        movie = nil
        self.episode = episode
        appVersion = "\(Bundle.main.releaseVersionNumber!)"
    }

    init(movie: Movie) {
        self.movie = movie
        episode = nil
        appVersion = "\(Bundle.main.releaseVersionNumber!)"
    }
}

struct ShowProgress: Codable, Hashable {
    let id = UUID()
    let aired: Int
    let completed: Int
    let lastWatchedAt: Date?
    let nextEpisodeToWatch: Episode?
    let resetAt: Date?
    let seasons: [SeasonProgress]
    let lastEpisode: Episode?

    enum CodingKeys: String, CodingKey {
        case lastWatchedAt = "last_watched_at"
        case nextEpisodeToWatch = "next_episode"
        case resetAt = "reset_at"
        case aired
        case seasons
        case completed
        case lastEpisode = "last_episode"
    }

    var toRewatchCount: Int {
        guard let resetDate = resetAt else { return 0 }
        var index = 0
        for season in seasons {
            for episode in season.episodes {
                if let lastWatchedDate = episode.lastWatchedAt {
                    if lastWatchedDate < resetDate {
                        index += 1
                    }
                }
            }
        }
        return index
    }

    var nextToRewatch: (SeasonProgress, EpisodeProgress)? {
        guard let resetDate = resetAt else { return nil }
        for season in seasons {
            for episode in season.episodes {
                if let lastWatchedDate = episode.lastWatchedAt {
                    if lastWatchedDate < resetDate {
                        return (season, episode)
                    }
                }
            }
        }
        return nil
    }

    var behind: Int {
        let toRewatchCount = toRewatchCount
        if toRewatchCount > 0 { return toRewatchCount }

        var behind = 0
        for season in seasons where season.number != 0 {
            for episode in season.episodes {
                if !episode.completed {
                    behind += 1
                }
                if let nextEpisodeToWatch = nextEpisodeToWatch, episode.number == nextEpisodeToWatch.number, season.number == nextEpisodeToWatch.season {
                    // this is the next episode to watch (we restart counting from 1)
                    behind = 1
                }
            }
        }
        return behind
    }
}

struct SeasonProgress: Codable, Hashable {
    let number: Int
    let title: String?
    let aired: Int
    let completed: Int
    let episodes: [EpisodeProgress]
}

struct EpisodeProgress: Codable, Hashable {
    let number: Int
    let completed: Bool
    let lastWatchedAt: Date?

    enum CodingKeys: String, CodingKey {
        case lastWatchedAt = "last_watched_at"
        case number
        case completed
    }
}

// Used to send stuff to trakt

struct WatchlistedItem: Codable {
    let movies: [Movie]?
    let shows: [Show]?
    let seasons: [Season]?
    let episodes: [Episode]?

    init(episode: Episode) {
        movies = nil
        shows = nil
        seasons = nil
        episodes = [episode]
    }

    init(movie: Movie) {
        movies = [movie]
        shows = nil
        seasons = nil
        episodes = nil
    }

    init(season: Season) {
        movies = nil
        shows = nil
        seasons = [season]
        episodes = nil
    }

    init(show: Show) {
        movies = nil
        shows = [show]
        seasons = nil
        episodes = nil
    }

    init(models: [MediaModel]) {
        var movies = [Movie]()
        var shows = [Show]()
        var seasons = [Season]()
        var episodes = [Episode]()
        for model in models {
            switch model {
            case .movie(let movie):
                movies.append(movie)
            case .show(let show):
                shows.append(show)
            case .episode(let episode, _):
                episodes.append(episode)
            case .season(let season, _):
                seasons.append(season)
            case .showProgress(let show, _):
                shows.append(show)
            default:
                fatalError()
            }
        }
        self.movies = movies
        self.shows = shows
        self.seasons = seasons
        self.episodes = episodes
    }

    init(watchlistItems: [WatchlistItem]) {
        var movies = [Movie]()
        var shows = [Show]()
        var seasons = [Season]()
        var episodes = [Episode]()
        for watchlistItem in watchlistItems {
            switch watchlistItem.type {
            case .movie:
                movies.append(watchlistItem.movie!)
            case .episode:
                episodes.append(watchlistItem.episode!)
            case .show:
                shows.append(watchlistItem.show!)
            case .season:
                seasons.append(watchlistItem.season!)
            default:
                fatalError()
            }
        }
        self.movies = movies
        self.shows = shows
        self.seasons = seasons
        self.episodes = episodes
    }
}

struct ItemWithNote: Codable {
    let identifiers: Identifiers
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case identifiers = "ids"
        case notes
    }
}

struct WatchlistedItemWithNotes: Codable {
    let movies: [ItemWithNote]?
    let shows: [ItemWithNote]?
}

struct People: Codable {
    let cast: [Cast]
    let crew: Crew?
    let guestStars: [Cast]?

    enum CodingKeys: String, CodingKey {
        case cast
        case crew
        case guestStars = "guest_stars"
    }

    var allMovies: [Movie] {
        var result: [Movie] = []

        // From cast credits
        for c in cast {
            if let m = c.movie, !result.contains(m) { result.append(m) }
        }

        // From guest star appearances
        if let guest = guestStars {
            for g in guest {
                if let m = g.movie, !result.contains(m) { result.append(m) }
            }
        }

        // From crew jobs
        if let crew = crew {
            for job in crew.jobs {
                if let m = job.movie, !result.contains(m) { result.append(m) }
            }
        }

        return result
    }

    var allShows: [Show] {
        var result: [Show] = []

        // From cast credits
        for c in cast {
            if let s = c.show, !result.contains(s) { result.append(s) }
        }

        // From guest star appearances
        if let guest = guestStars {
            for g in guest {
                if let s = g.show, !result.contains(s) { result.append(s) }
            }
        }

        // From crew jobs
        if let crew = crew {
            for job in crew.jobs {
                if let s = job.show, !result.contains(s) { result.append(s) }
            }
        }

        return result
    }
}

struct Cast: Codable, Equatable, Hashable {
    let characters: [String]
    let person: Person?
    let episodeCount: Int?

    let movie: Movie?
    let show: Show?

    enum CodingKeys: String, CodingKey {
        case characters
        case person
        case episodeCount = "episode_count"

        case movie
        case show
    }
}

struct PersonItem: Codable, Equatable, Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(person)
    }

    let person: Person
}

struct Person: Codable, Equatable, Hashable {
    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.ids == rhs.ids
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ids)
    }

    let name: String
    let ids: Identifiers

    let biography: String?
    let birthday: Date?
    let death: Date?
    let birthplace: String?
    let height: Float?

    let homepage: String?

    let socialIds: SocialIdentifiers?

    let knownForDepartment: String?

    enum CodingKeys: String, CodingKey {
        case name
        case ids
        case biography
        case birthday
        case birthplace
        case height
        case death
        case homepage
        case socialIds = "social_ids"
        case knownForDepartment = "known_for_department"
    }
}

struct Genre: Codable {
    let name: String
    let slug: String
}

struct CertificationsCounties: Codable {
    let us: [Certification]
}

struct Network: Codable, Hashable {
    let name: String
}

struct Language: Codable {
    let code: String
}

struct Certification: Codable, Equatable, Hashable {
    let name: String
    let slug: String
    let description: String

    var metadata: String {
        switch name {
        case "TV-Y":
            return "All Children"
        case "TV-Y7":
            return "Directed to Older Children"
        case "TV-Y7-FV":
            return "Directed to Older Children - Fantasy Violence"
        case "TV-G":
            return "General Audience"
        case "TV-PG":
            return "Parental Guidance Suggested"
        case "TV-14":
            return "Parents Strongly Cautioned"
        case "TV-MA":
            return "Mature Audience Only"
        case "G":
            return "General Audiences"
        case "PG":
            return "Parental Guidance Suggested"
        case "PG-13":
            return "Parents Strongly Cautioned"
        case "R":
            return "Restricted"
        case "NC-17":
            return "No One 17 and Under Admitted"
        default:
            return description
        }
    }

    var longDescription: String {
        switch name {
        case "TV-Y":
            return "Content is suitable for all children. Usually aimed at preschool-aged children, it contains little or no violence, no strong language, and minimal suggestive content."
        case "TV-Y7":
            return "Content is suitable for children age 7 and older. May contain mild fantasy violence, comedic violence, or infrequent mild language."
        case "TV-Y7-FV":
            return "Content is suitable for older children with more intense fantasy violence."
        case "TV-G":
            return "Content is suitable for all ages, although it may not necessarily be of interest to children. It typically contains little to no violence, no strong language, and no sexually suggestive content."
        case "TV-PG":
            return "Content may not be suitable for younger children. It may contain some material that parents might find unsuitable for younger children, such as moderate violence, some sexual situations, or infrequent coarse language."
        case "TV-14":
            return "Content may not be suitable for children under 14. It may contain intense violence, strong language, sexual content, or suggestive dialogue."
        case "TV-MA":
            return "Content is specifically designed to be viewed by adults and is not suitable for children under 17. It may contain graphic violence, explicit language, sexual content, or adult themes."
        case "G":
            return "All ages admitted. The content is considered suitable for general audiences and contains no strong language, violence, or mature themes."
        case "PG":
            return "Some material may not be suitable for children. Parents are encouraged to provide guidance to their kids about the content."
        case "PG-13":
            return "Some material may be inappropriate for children under 13. Parents are urged to be cautious and may find some content unsuitable for younger teens."
        case "R":
            return "Under 17 requires accompanying parent or adult guardian. The movie may contain adult themes, strong language, violence, nudity, or other content unsuitable for minors."
        case "NC-17":
            return "Content is only suitable for adults. No one under 17 is permitted to watch the movie."
        default:
            return ""
        }
    }
}

struct SocialIdentifiers: Codable {
    let twitter: String?
    let facebook: String?
    let instagram: String?
    let wikipedia: String?
}

struct Crew: Codable {
    let production: [Job]?
    let art: [Job]?
    let crew: [Job]?
    let costumeAndMakeUp: [Job]?
    let directing: [Job]?
    let writing: [Job]?
    let sound: [Job]?
    let camera: [Job]?
    let visualEffects: [Job]?
    let lighting: [Job]?
    let editing: [Job]?
    let createdBy: [Job]?

    enum CodingKeys: String, CodingKey {
        case production
        case art
        case crew
        case costumeAndMakeUp = "costume & make-up"
        case directing
        case writing
        case sound
        case camera
        case visualEffects = "visual effects"
        case lighting
        case editing
        case createdBy = "created by"
    }

    var jobs: [Job] {
        // Aggregate all crew departments
        let allDepartments: [[Job]] = [
            production ?? [],
            art ?? [],
            crew ?? [],
            costumeAndMakeUp ?? [],
            directing ?? [],
            writing ?? [],
            sound ?? [],
            camera ?? [],
            visualEffects ?? [],
            lighting ?? [],
            editing ?? [],
            createdBy ?? []
        ]
        return allDepartments
            .flatMap { $0 }
    }

    func jobs(for movie: Movie) -> [Job] {
        // Aggregate all crew departments and filter jobs linked to the provided movie
        let allDepartments: [[Job]] = [
            production ?? [],
            art ?? [],
            crew ?? [],
            costumeAndMakeUp ?? [],
            directing ?? [],
            writing ?? [],
            sound ?? [],
            camera ?? [],
            visualEffects ?? [],
            lighting ?? [],
            editing ?? [],
            createdBy ?? []
        ]
        return allDepartments
            .flatMap { $0 }
            .filter { $0.movie == movie }
    }

    func jobs(for show: Show) -> [Job] {
        // Aggregate all crew departments and filter jobs linked to the provided show
        let allDepartments: [[Job]] = [
            production ?? [],
            art ?? [],
            crew ?? [],
            costumeAndMakeUp ?? [],
            directing ?? [],
            writing ?? [],
            sound ?? [],
            camera ?? [],
            visualEffects ?? [],
            lighting ?? [],
            editing ?? [],
            createdBy ?? []
        ]
        return allDepartments
            .flatMap { $0 }
            .filter { $0.show == show }
    }
}

struct Job: Codable, Equatable, Hashable {
    let jobs: [String]
    let person: Person?

    let movie: Movie?
    let show: Show?
}

// MARK: - Watched Item

struct WatchedItem: Codable, Equatable, Hashable {
    var type: CommentType {
        if movie != nil { return .movie }

        // Order here is important
        if episode != nil { return .episode }
        if season != nil { return .season }
        if show != nil { return .show }

        if list != nil { return .list }

        return .unknown
    }

    let plays: Int
    let lastWatchedAt: Date
    let lastUpdatedAt: Date
    let resetAt: Date?

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let list: List?

    enum CodingKeys: String, CodingKey {
        case plays
        case lastWatchedAt = "last_watched_at"
        case lastUpdatedAt = "last_updated_at"
        case resetAt = "reset_at"
        case movie
        case show
        case episode
        case season
        case list
    }

    static func == (lhs: WatchedItem, rhs: WatchedItem) -> Bool {
        return lhs.type == rhs.type &&
            lhs.movie == rhs.movie &&
            lhs.show == rhs.show &&
            lhs.episode == rhs.episode &&
            lhs.season == rhs.season &&
            lhs.list == rhs.list &&
            lhs.lastWatchedAt == rhs.lastWatchedAt &&
            lhs.resetAt == rhs.resetAt &&
            lhs.lastUpdatedAt == rhs.lastUpdatedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(movie)
        hasher.combine(show)
        hasher.combine(episode)
        hasher.combine(season)
        hasher.combine(list)
        hasher.combine(lastWatchedAt)
    }
}

// MARK: - Calendar

struct ShowEpisodeCalendarItem: Codable, Hashable {
    let firstAired: Date

    let show: Show
    let episode: Episode

    enum CodingKeys: String, CodingKey {
        case firstAired = "first_aired"
        case show
        case episode
    }
}

struct MovieCalendarItem: Codable, Hashable {
    let released: Date

    let movie: Movie
}

// MARK: - Add Multi in history

struct AddHistoryStruct: Codable {
    let shows: [AddHistoryShow]
}

struct AddHistoryShow: Codable {
    let ids: AddHistoryId
    let seasons: [AddHistorySeason]
}

struct AddHistoryId: Codable {
    let trakt: Int64
}

struct AddHistorySeason: Codable {
    let number: Int
    let episodes: [AddHistoryEpisode]
}

struct AddHistoryEpisode: Codable {
    let number: Int
    let watched_at: String
}

// Saved Filters

struct SavedFilter: Codable, Equatable, Hashable {
    let section: String
    private let _name: String
    let path: String
    let query: String
    let limit: Int?

    init(section: String, name: String, path: String, query: String, limit: Int?) {
        self.section = section
        _name = name
        self.path = path
        self.query = query
        self.limit = limit
    }

    static func == (lhs: SavedFilter, rhs: SavedFilter) -> Bool {
        return lhs.section == rhs.section &&
            lhs.name == rhs.name &&
            lhs.path == rhs.path &&
            lhs.query == rhs.query &&
            lhs.limit == rhs.limit
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(section)
        hasher.combine(name)
        hasher.combine(path)
        hasher.combine(query)
        hasher.combine(limit)
    }

    enum CodingKeys: String, CodingKey {
        case section
        case _name = "name"
        case path
        case query
        case limit
    }

    var name: String {
        return _name.emojiUnescapedString
    }

    var normalized: SavedFilter {
        if path != "/all/trending" { return self }
        return SavedFilter(section: section,
                           name: name,
                           path: "/media/trending",
                           query: query,
                           limit: limit)
    }

    private var isCombinedTrending: Bool {
        ["/media/trending", "/all/trending"].contains(path)
    }

    var canFilterWatched: Bool {
        if isCombinedTrending {
            return true
        }

        if ["movies", "shows", "search"].contains(section) {
            return true
        }
        return false
    }

    var canSort: Bool {
        if ["episodes_to_watch",
            "movies_to_watch",
            "pinned_to_watch",
            "unpinned_to_watch",
            "CompletedShows",
            "DroppedShows",
            "PinnedShows",
            "PinnedMovies"].contains(section) {
            return false
        }

        if ["/users/me/watched/movies",
            "/users/me/watched/shows"].contains(path) ||
            isCombinedTrending {
            return false
        }

        if path.contains("users") || path.contains("sync") {
            return true
        }
        return false
    }
}

enum NoteItemType: String, Codable, UnknownDecodable {
    case movie
    case show
    case episode
    case season
    case unknown
}

enum NoteAttachementType: String, Codable, UnknownDecodable {
    case movie
    case show
    case season
    case episode
    case person
    case history
    case collection
    case rating
    case unknown
}

struct NoteItem: Codable, Equatable, Hashable {
    let noteAttachement: NoteAttachement

    let type: NoteItemType

    let movie: Movie?
    let show: Show?
    let episode: Episode?
    let season: Season?
    let person: Person?

    let note: Note

    enum CodingKeys: String, CodingKey {
        case noteAttachement = "attached_to"
        case type
        case movie
        case show
        case episode
        case season
        case note
        case person
    }
}

struct NoteAttachement: Codable, Equatable, Hashable {
    let type: NoteAttachementType
    let identifier: Int64? // can be the id of the history item

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case type
    }
}

struct Note: Codable, Equatable, Hashable {
    let identifier: Int64
    let notes: String
    let privacy: NotePrivacy
    let spoiler: Bool
    let createdAt: Date
    let updatedAt: Date
    let user: User

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
        case notes
        case privacy
        case spoiler
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case user
    }
}

/*
 {
   "all": "2014-11-20T07:01:32.000Z",
   "movies": {
     "watched_at": "2014-11-19T21:42:41.000Z",
     "collected_at": "2014-11-20T06:51:30.000Z",
     "rated_at": "2014-11-19T18:32:29.000Z",
     "watchlisted_at": "2014-11-19T21:42:41.000Z",
     "favorited_at": "2014-11-19T21:42:41.000Z",
     "commented_at": "2014-11-20T06:51:30.000Z",
     "paused_at": "2014-11-20T06:51:30.000Z",
     "hidden_at": "2016-08-20T06:51:30.000Z"
   },
   "episodes": {
     "watched_at": "2014-11-20T06:51:30.000Z",
     "collected_at": "2014-11-19T22:02:41.000Z",
     "rated_at": "2014-11-20T06:51:30.000Z",
     "watchlisted_at": "2014-11-20T06:51:30.000Z",
     "commented_at": "2014-11-20T06:51:30.000Z",
     "paused_at": "2014-11-20T06:51:30.000Z"
   },
   "shows": {
     "rated_at": "2014-11-19T19:50:58.000Z",
     "watchlisted_at": "2014-11-20T06:51:30.000Z",
     "favorited_at": "2014-11-20T06:51:30.000Z",
     "commented_at": "2014-11-20T06:51:30.000Z",
     "hidden_at": "2016-08-20T06:51:30.000Z"
   },
   "seasons": {
     "rated_at": "2014-11-19T19:54:24.000Z",
     "watchlisted_at": "2014-11-20T06:51:30.000Z",
     "commented_at": "2014-11-20T06:51:30.000Z",
     "hidden_at": "2016-08-20T06:51:30.000Z"
   },
   "comments": {
     "liked_at": "2014-11-20T03:38:09.000Z",
     "blocked_at": "2022-02-22T03:38:09.000Z"
   },
   "lists": {
     "liked_at": "2014-11-20T00:36:48.000Z",
     "updated_at": "2014-11-20T06:52:18.000Z",
     "commented_at": "2014-11-20T06:51:30.000Z"
   },
   "watchlist": {
     "updated_at": "2014-11-20T06:52:18.000Z"
   },
   "favorites": {
     "updated_at": "2014-11-20T06:52:18.000Z"
   },
   "account": {
     "settings_at": "2020-03-04T03:38:09.000Z",
     "followed_at": "2020-03-04T03:38:09.000Z",
     "following_at": "2020-03-04T03:38:09.000Z",
     "pending_at": "2020-03-04T03:38:09.000Z",
     "requested_at": "2022-04-27T03:38:09.000Z"
   },
   "saved_filters": {
     "updated_at": "2022-06-14T06:52:18.000Z"
   },
   "notes": {
     "updated_at": "2023-08-31T17:18:19.000Z"
   }
 }
 */

struct LastActivities: Codable, Equatable, Hashable {
    let all: Date
    let movies: LastMoviesActivities
    let episodes: LastEpisodesActivities
    let shows: LastShowsActivities
    let comments: LastCommentsActivities
}

struct LastEpisodesActivities: Codable, Equatable, Hashable {
    let watchedAt: Date

    enum CodingKeys: String, CodingKey {
        case watchedAt = "watched_at"
    }
}

struct LastMoviesActivities: Codable, Equatable, Hashable {
    let watchedAt: Date

    enum CodingKeys: String, CodingKey {
        case watchedAt = "watched_at"
    }
}

struct LastShowsActivities: Codable, Equatable, Hashable {
    let hiddenAt: Date
    let droppedAt: Date

    enum CodingKeys: String, CodingKey {
        case hiddenAt = "hidden_at"
        case droppedAt = "dropped_at"
    }
}

struct LastCommentsActivities: Codable, Equatable, Hashable {
    let blockedAt: Date

    enum CodingKeys: String, CodingKey {
        case blockedAt = "blocked_at"
    }
}

/**
   {
     "country": "us",
     "certification": "PG",
     "release_date": "2010-12-16",
     "release_type": "theatrical",
     "note": null
   }
 */
struct MovieReleaseActivity: Codable, Equatable, Hashable {
    let country: String
    let certification: String?
    let releaseDate: Date
    let releaseType: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case country
        case certification
        case releaseDate = "release_date"
        case releaseType = "release_type"
        case note
    }
}

/*
 {
   "deleted": {
     "movies": 1,
     "shows": 1,
     "seasons": 1,
     "episodes": 2,
     "people": 1
   },
   "not_found": {
     "movies": [
       {
         "ids": {
           "imdb": "tt0000111"
         }
       }
     ],
     "shows": [],
     "seasons": [],
     "episodes": [],
     "people": []
   },
   "list": {
     "updated_at": "2022-04-27T21:40:41.000Z",
     "item_count": 0
   }
 }
 */

struct RemoveListItemsResponse: Codable {
    let deleted: RemoveListItemsDeletedResponse
}

struct RemoveListItemsDeletedResponse: Codable {
    let episodes: Int
    let shows: Int
    let movies: Int
}

/*
 {
    "bad":[
       {
          "sentiment":"Boring and slow-paced with no engaging plot",
          "comment_ids":[
             391934,
             515218,
             525951,
             580002
          ]
       },
       {
          "sentiment":"Characters are unbearably unlikeable",
          "comment_ids":[
             428019,
             510637,
             518200,
             524654
          ]
       },
       {
          "sentiment":"Season 2 is significantly weaker than Season 1",
          "comment_ids":[
             537070,
             542279,
             542851,
             761444
          ]
       }
    ],
    "good":[
       {
          "sentiment":"Uniquely captivating and addictive despite uncomfortable situations",
          "comment_ids":[
             391799,
             407881,
             524155,
             524376,
             774928,
             634015
          ]
       },
       {
          "sentiment":"Excellent production quality with outstanding music and cinematography",
          "comment_ids":[
             396696,
             403438,
             433447,
             529941
          ]
       },
       {
          "sentiment":"Well-developed characters with deep storylines",
          "comment_ids":[
             393798,
             397958,
             450778,
             514565
          ]
       },
       {
          "sentiment":"Brilliant dark comedy with effective social satire",
          "comment_ids":[
             403438,
             529102,
             529941
          ]
       }
    ],
    "analyzed_at":"2025-03-03T14:43:15Z",
    "comment_count":67
 }
 */

struct CommentsSentiments: Codable, Equatable, Hashable {
    let bad: [Sentiment]
    let good: [Sentiment]
    let analyzedAt: Date
    let commentCount: Int

    enum CodingKeys: String, CodingKey {
        case bad
        case good
        case analyzedAt = "analyzed_at"
        case commentCount = "comment_count"
    }

    static func == (lhs: CommentsSentiments, rhs: CommentsSentiments) -> Bool {
        return lhs.analyzedAt == rhs.analyzedAt
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(analyzedAt)
    }

    var formattedSentiment: String {
        var sentiment = ""
        for goodSentiment in good {
            sentiment += "▲ \(goodSentiment.sentiment)\n"
        }
        sentiment += "\u{200B}\n"
        for badSentiment in bad {
            sentiment += "▼ \(badSentiment.sentiment)\n"
        }
        return sentiment.trimmingCharacters(in: .newlines)
    }
}

struct Sentiment: Codable {
    let sentiment: String
    let commentIds: [Int64]

    enum CodingKeys: String, CodingKey {
        case sentiment
        case commentIds = "comment_ids"
    }
}

/*
 {
     "title": "Game Of Thrones - Season 1 Recap - Official HBO UK",
     "url": "https://youtube.com/watch?v=e0Y8KpQpW8c",
     "site": "youtube",
     "type": "recap",
     "size": 1080,
     "official": true,
     "published_at": "2015-05-19T16:31:23.000Z",
     "country": "us",
     "language": "en"
   }
 */

struct Video: Codable, Identifiable, Hashable {
    var id = UUID()

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let title: String
    let url: URL
    let site: String?
    let type: String?
    let size: Int?
    let official: Bool?
    let publishedDate: Date?
    let country: String?
    let language: String?

    enum CodingKeys: String, CodingKey {
        case language
        case country
        case title
        case url
        case site
        case size
        case type
        case official
        case publishedDate = "published_at"
    }
}

// MARK: - Translations

/*
 "title": "Winter Is Coming",
     "overview": "Jon Arryn, the Hand of the King, is dead. King Robert Baratheon plans to ask his oldest friend, Eddard Stark, to take Jon's place. Across the sea, Viserys Targaryen plans to wed his sister to a nomadic warlord in exchange for an army.",
     "language": "en",
     "country": "us"
 */

struct Translation: Codable {
    let title: String?
    let overview: String?
    let tagline: String?
    let language: String?
    let country: String?
}

// MARK: - Reactions

struct UserReaction: Codable {
    let reactedAt: Date
    let reaction: ReactionType
    let type: String // only comment is supported for now
    let comment: UserReactionCommentId?

    enum CodingKeys: String, CodingKey {
        case reactedAt = "reacted_at"
        case reaction
        case type
        case comment
    }
}

struct UserReactionCommentId: Codable {
    let identifier: Int64

    enum CodingKeys: String, CodingKey {
        case identifier = "id"
    }
}

struct ReactionSummary: Codable {
    let reactionCount: Int
    let userCount: Int
    let distribution: ReactionDistribution

    enum CodingKeys: String, CodingKey {
        case reactionCount = "reaction_count"
        case userCount = "user_count"
        case distribution
    }
}

struct ReactionDistribution: Codable {
    let like: Int
    let dislike: Int
    let love: Int
    let laugh: Int
    let shocked: Int
    let bravo: Int
    let spoiler: Int

    var score: Int {
        // dislike is negative = -1
        // spoiler and shocked are neutral = 0
        return like + love + laugh + bravo - dislike
    }

    /// Returns up to three emojis representing the most common reactions.
    /// Order ties are broken using the fixed priority: 👍👎❤️😂😱👏🫣
    var top3Emojis: String {
        struct ReactionEntry {
            let emoji: String
            let count: Int
            let tieOrder: Int
        }

        // Map each reaction to its emoji and count
        let reactions: [ReactionEntry] = [
            ReactionEntry(emoji: "👍", count: like, tieOrder: 0),
            ReactionEntry(emoji: "👎", count: dislike, tieOrder: 1),
            ReactionEntry(emoji: "❤️", count: love, tieOrder: 2),
            ReactionEntry(emoji: "😂", count: laugh, tieOrder: 3),
            ReactionEntry(emoji: "😱", count: shocked, tieOrder: 4),
            ReactionEntry(emoji: "👏", count: bravo, tieOrder: 5),
            ReactionEntry(emoji: "🫣", count: spoiler, tieOrder: 6)
        ]

        // Sort by count descending, then by fixed tie order
        let sorted = reactions
            .filter { $0.count > 0 }
            .sorted {
                if $0.count != $1.count {
                    return $0.count > $1.count
                } else {
                    return $0.tieOrder < $1.tieOrder
                }
            }

        // Take up to 3 and concatenate emojis
        return sorted.prefix(3).map { $0.emoji }.joined()
    }
}

struct CommentReaction: Codable, Equatable, Hashable {
    let reactedAt: Date
    let reaction: ReactionType
    let user: User

    enum CodingKeys: String, CodingKey {
        case reactedAt = "reacted_at"
        case reaction
        case user
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(user)
        hasher.combine(reaction)
        hasher.combine(reactedAt)
    }
}

struct ReactionType: Codable, Equatable, Hashable, Identifiable {
    var id: String {
        type
    }

    let type: String
    let emoji: String

    enum CodingKeys: String, CodingKey {
        case emoji
        case type
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(emoji)
    }
}

// MARK: - IAP Verification

struct RemoteIAPInfo: Encodable {
    let id: String?
    let date: Date?
    let productID: String?
    let userID: Int64?
    let currencyCode: String?
    let countryCode: String?
    let price: Decimal?
    let appStoreReceiptData: String?

    enum CodingKeys: String, CodingKey {
        case id = "transaction_id"
        case date = "transaction_date"
        case productID = "product_id"
        case userID = "user_id"
        case currencyCode = "currency"
        case countryCode = "country"
        case price
        case appStoreReceiptData = "app_store_receipt_data"
    }
}
