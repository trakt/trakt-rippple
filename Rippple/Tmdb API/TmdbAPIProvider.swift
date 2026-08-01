//
//  TmdbAPIProvider.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2018.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

enum TmdbAPIProvider {
    static let source = TokenSource()

    static var networkLogger: NetworkLoggerPlugin {
        let networkLogger = NetworkLoggerPlugin()
        networkLogger.configuration.logOptions = .default
        return networkLogger
    }

    static var provider = MoyaProvider<TmdbAPIService>(session: Session(interceptor: RipppleRetryPolicy()),
                                                       plugins: [ /* networkLogger */ ])

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
}
