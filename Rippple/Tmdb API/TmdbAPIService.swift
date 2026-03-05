//
//  TmdbAPIService.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

import Moya

enum TmdbAPIService {
    case configuration

    case movieImages(Int64)
    case tvImages(Int64)

    case people(Int64)

    case episode(Int64, Int, Int)
    case season(Int64, Int)

    // Where to Watch via JustWatch
    case movieProviders(Int64)
    case showProviders(Int64)
    case seasonProviders(Int64, Int)

    case providersForMovieInRegion(String)
    case providersForTVInRegion(String)

    // for search
    case trending

    case search(String)

    case combinedCredit(Int64)

    case showKeywords(Int64)
    case movieKeywords(Int64)

    case tvChanges(Int64, Date, Date)
}

// MARK: - TargetType Protocol Implementation
extension TmdbAPIService: TargetType {
    var validationType: ValidationType {
        switch self {
        case .configuration:
            return .none
        case .movieImages:
            return .successCodes
        case .tvImages:
            return .successCodes
        case .people:
            return .successCodes
        case .episode:
            return .successCodes
        case .movieProviders:
            return .successCodes
        case .showProviders:
            return .successCodes
        case .trending:
            return .successCodes
        case .search:
            return .successCodes
        case .combinedCredit:
            return .successCodes
        case .movieKeywords:
            return .successCodes
        case .showKeywords:
            return .successCodes
        case .tvChanges:
            return .successCodes
        case .seasonProviders:
            return .successCodes
        case .providersForMovieInRegion:
            return .successCodes
        case .providersForTVInRegion:
            return .successCodes
        case .season:
            return .successCodes
        }
    }
    var baseURL: URL { return URL(string: TmdbAPIConfiguration.baseURL)! }
    var path: String {
        switch self {
        case .configuration:
            return "/configuration"
        case .movieImages(let tmdbId):
            return "/movie/\(tmdbId)/images"
        case .tvImages(let tmdbId):
            return "/tv/\(tmdbId)/images"
        case .people(let tmdbId):
            return "/person/\(tmdbId)/images"
        case .episode(let tmdbId, let season, let number):
            return "/tv/\(tmdbId)/season/\(season)/episode/\(number)/images"
        case .movieProviders(let tmdbId):
            return "/movie/\(tmdbId)/watch/providers"
        case .showProviders(let tmdbId):
            return "/tv/\(tmdbId)/watch/providers"
        case .trending:
            return "/trending/all/day"
        case .search:
            return "/search/multi"
        case .combinedCredit(let tmdbId):
            return "/person/\(tmdbId)/combined_credits"
        case .showKeywords(let tmdbId):
            return "/tv/\(tmdbId)/keywords"
        case .movieKeywords(let tmdbId):
            return "/movie/\(tmdbId)/keywords"
        case .tvChanges(let tmdbId, _, _):
            return "/tv/\(tmdbId)/changes"
        case .seasonProviders(let tmdbId, let seasonNumber):
            return "/tv/\(tmdbId)/season/\(seasonNumber)/watch/providers"
        case .providersForMovieInRegion:
            return "/watch/providers/movie"
        case .providersForTVInRegion:
            return "/watch/providers/tv"
        case .season(let tmdbId, let seasonNumber):
            return "/tv/\(tmdbId)/season/\(seasonNumber)/images"
        }
    }
    var method: Moya.Method {
        switch self {
        case .configuration, .movieImages, .tvImages, .people, .episode, .movieProviders, .showProviders, .trending, .search, .combinedCredit, .showKeywords, .movieKeywords, .tvChanges, .seasonProviders, .providersForMovieInRegion, .providersForTVInRegion, .season:
            return .get
        }
    }
    var task: Task {
        switch self {
        case .configuration:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .movieImages:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .tvImages:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .season:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .people:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .episode:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .movieProviders:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .showProviders:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .trending:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .search(let query):
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey,
                                                   "query": query],
                                      encoding: URLEncoding.default)
        case .combinedCredit:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .movieKeywords:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .showKeywords:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .tvChanges(_, let startDate, let endDate):
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey,
                                                   "end_date": dateFormatter.string(from: endDate),
                                                   "start_date": dateFormatter.string(from: startDate),
                                                   "page": 1],
                                      encoding: URLEncoding.default)
        case .seasonProviders:
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey],
                                      encoding: URLEncoding.default)
        case .providersForMovieInRegion(let region):
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey,
                                                   "watch_region": region],
                                      encoding: URLEncoding.default)
        case .providersForTVInRegion(let region):
            return .requestParameters(parameters: ["api_key": TmdbAPIConfiguration.apiKey,
                                                   "watch_region": region],
                                      encoding: URLEncoding.default)
        }
    }
    var headers: [String: String]? {
        switch self {
        default:
            return [:]
        }
    }
}
