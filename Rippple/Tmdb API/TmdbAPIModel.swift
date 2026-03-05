//
//  TmdbAPIModel.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Foundation

// MARK: - Configuration

struct Configuration: Codable {

    let images: ImagesConfiguration

}

struct ImagesConfiguration: Codable {

    let baseURL: String
    let posterSizes: [String]
    let backdropSizes: [String]
    let profileSizes: [String]

    enum CodingKeys: String, CodingKey {
        case baseURL = "secure_base_url"
        case posterSizes = "poster_sizes"
        case backdropSizes = "backdrop_sizes"
        case profileSizes = "profile_sizes"
    }
}

// MARK: - Images

struct PostersImages: Codable {
    let id: Int64
    let posters: [TMDbImage]
    let backdrops: [TMDbImage]
    let logos: [TMDbImage]
}

struct PostersOnlyImages: Codable {
    let id: Int64
    let posters: [TMDbImage]
}

struct StillsImages: Codable {
    let id: Int64
    let stills: [TMDbImage]
}

struct TMDbImage: Codable {
    let filePath: String
    let language: String?
    let voteAverage: Double?
    let voteCount: Int?
    let aspectRatio: Float?

    enum CodingKeys: String, CodingKey {
        case filePath = "file_path"
        case language = "iso_639_1"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case aspectRatio = "aspect_ratio"
    }
}

struct ProfilesImages: Codable {
    let id: Int64
    let profiles: [TMDbImage]
}

// MARK: - Providers (Where to Watch via  Just Watch)

struct ProvidersResult: Codable {
    let results: ProvidersCountry?
}

struct ProvidersCountry: Codable {
    let AD: Providers?
    let AE: Providers?
    let AG: Providers?
    let AL: Providers?
    let AO: Providers?
    let AR: Providers?
    let AT: Providers?
    let AU: Providers?
    let AZ: Providers?
    let BA: Providers?
    let BB: Providers?
    let BE: Providers?
    let BF: Providers?
    let BG: Providers?
    let BH: Providers?
    let BM: Providers?
    let BO: Providers?
    let BR: Providers?
    let BS: Providers?
    let BY: Providers?
    let BZ: Providers?
    let CA: Providers?
    let CD: Providers?
    let CH: Providers?
    let CI: Providers?
    let CL: Providers?
    let CM: Providers?
    let CO: Providers?
    let CR: Providers?
    let CU: Providers?
    let CV: Providers?
    let CY: Providers?
    let CZ: Providers?
    let DE: Providers?
    let DK: Providers?
    let DO: Providers?
    let DZ: Providers?
    let EC: Providers?
    let EE: Providers?
    let EG: Providers?
    let ES: Providers?
    let FI: Providers?
    let FJ: Providers?
    let FR: Providers?
    let GB: Providers?
    let GF: Providers?
    let GH: Providers?
    let GI: Providers?
    let GP: Providers?
    let GQ: Providers?
    let GR: Providers?
    let GT: Providers?
    let GY: Providers?
    let HK: Providers?
    let HN: Providers?
    let HR: Providers?
    let HU: Providers?
    let ID: Providers?
    let IE: Providers?
    let IL: Providers?
    let IN: Providers?
    let IQ: Providers?
    let IS: Providers?
    let IT: Providers?
    let JM: Providers?
    let JO: Providers?
    let JP: Providers?
    let KE: Providers?
    let KR: Providers?
    let KW: Providers?
    let LB: Providers?
    let LC: Providers?
    let LI: Providers?
    let LT: Providers?
    let LU: Providers?
    let LV: Providers?
    let LY: Providers?
    let MA: Providers?
    let MC: Providers?
    let MD: Providers?
    let ME: Providers?
    let MG: Providers?
    let MK: Providers?
    let ML: Providers?
    let MT: Providers?
    let MU: Providers?
    let MW: Providers?
    let MX: Providers?
    let MY: Providers?
    let MZ: Providers?
    let NE: Providers?
    let NG: Providers?
    let NI: Providers?
    let NL: Providers?
    let NO: Providers?
    let NZ: Providers?
    let OM: Providers?
    let PA: Providers?
    let PE: Providers?
    let PF: Providers?
    let PG: Providers?
    let PH: Providers?
    let PK: Providers?
    let PL: Providers?
    let PS: Providers?
    let PT: Providers?
    let PY: Providers?
    let QA: Providers?
    let RO: Providers?
    let RS: Providers?
    let RU: Providers?
    let SA: Providers?
    let SC: Providers?
    let SE: Providers?
    let SG: Providers?
    let SI: Providers?
    let SK: Providers?
    let SM: Providers?
    let SN: Providers?
    let SV: Providers?
    let TC: Providers?
    let TD: Providers?
    let TH: Providers?
    let TN: Providers?
    let TR: Providers?
    let TT: Providers?
    let TW: Providers?
    let TZ: Providers?
    let UA: Providers?
    let UG: Providers?
    let US: Providers?
    let UY: Providers?
    let VA: Providers?
    let VE: Providers?
    let XK: Providers?
    let YE: Providers?
    let ZA: Providers?
    let ZM: Providers?
    let ZW: Providers?
}

struct Providers: Codable {
    let link: String?
    let flatrate: [Provider]?
    let rent: [Provider]?
    let buy: [Provider]?
    let free: [Provider]?
    let ads: [Provider]?
    let none: [Provider]?
}

struct ProvidersInCountryResult: Codable {
    let results: [Provider]?
}

struct Provider: Codable {
    let priority: Int?
    let logo: String?
    let identifier: Int?
    let name: String?

    enum CodingKeys: String, CodingKey {
        case priority = "display_priority"
        case logo = "logo_path"
        case identifier = "provider_id"
        case name = "provider_name"
    }
}

// MARK: - Providers (Where to Watch via  Just Watch)

struct TMDbResults: Codable {
    let results: [TMDbResult]
}

struct TMDbResult: Codable, Hashable {
    let mediaType: String // movie, tv or person

    let title: String? // movie
    let name: String? // tv or person

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case title
        case name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(mediaType)
        hasher.combine(title)
        hasher.combine(name)
    }
}

// MARK: - Credits

struct Credits: Codable {
    let cast: [TMDBCast]
}

struct TMDBCast: Codable {
    let id: Int64
    let mediaType: String // movie, tv or person
    let popularity: Double

    enum CodingKeys: String, CodingKey {
        case mediaType = "media_type"
        case id
        case popularity
    }
}

// MARK: - Keywords

struct Keywords: Codable {
    let keywords: [Keyword]
}

struct Keyword: Codable {
    let id: Int64
    let name: String
}

// MARK: - Changes
/*
 {
   "changes": [
     {
       "key": "status",
       "items": [
         {
           "id": "65a96d03fc5f06012ebaf10b",
           "action": "updated",
           "time": "2024-01-18 18:25:07 UTC",
           "iso_639_1": "",
           "iso_3166_1": "",
           "value": "Canceled",
           "original_value": "Returning Series"
         }
       ]
     }
   ]
 }
 */

struct Changes: Codable {
    let changes: [Change]
}

struct Change: Codable {
    let key: String // looking for status only
    let items: [ChangeItem]
}

struct ChangeItem: Codable {
    let action: String? // looking for updated only
    let value: String?
    let originalValue: String?

    enum CodingKeys: String, CodingKey {
        case originalValue = "original_value"
        case value
        case action
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        action = try values.decode(String?.self, forKey: .action)
        var decodedValue: String?
        var decodedOriginalValue: String?
        do {
            decodedValue = try values.decode(String.self, forKey: .value)
            decodedOriginalValue = try values.decode(String.self, forKey: .originalValue)
        } catch {

        }
        value = decodedValue
        originalValue = decodedOriginalValue
    }
}
