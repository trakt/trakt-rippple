import Foundation

// Copy this file to Secrets.swift and fill in your values.
// This file needs to be included in all targets that need those values.
// Keep Secrets.swift out of source control!

// Rippple uses the Trakt API to fetch a lot of its metadata and user information.
struct TraktAPIConfiguration {
    static let authBaseURL = "https://trakt.tv"
    static let baseURL = "https://api.trakt.tv"
    static let clientId = "<#TRAKT_CLIENT_ID#>"
    static let secretId = "<#TRAKT_CLIENT_SECRET#>"
    static let callbackURL = "ripl://trakt/oauth2/callback"
}

// Rippple uses the TMDb API to fetch images and where to watch information.
struct TmdbAPIConfiguration {
    static let baseURL = "https://api.themoviedb.org/3"
    static let apiKey = "<#TMDB_API_KEY#>"
}

// Rippple uses AWS to manage notifications.
// Remote Push Notifications will be disabled if no identityPoolId is provided.
struct AWSConfiguration {
    static let identityPoolId: String? = nil
    static let platformApplicationARN: String? = nil
    static let trendingShowsTopicARN: String? = nil
    static let trendingMoviesTopicARN: String? = nil
    static let recommendedShowsTopicARN: String? = nil
    static let recommendedMoviesTopicARN: String? = nil
    static let manualBlogPostTopicARN: String? = nil
    static let manualUpdateTopicARN: String? = nil
    static let testTopicARN: String? = nil
}
