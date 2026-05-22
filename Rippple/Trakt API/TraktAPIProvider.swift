//
//  TraktAPIProvider.swift
//  Rippple
//
//  Created by Kevin Cador on 11/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

import Moya
import Alamofire

final class TraktAPIProvider {

    static let source = TokenSource()

    static let networkLogger = NetworkLoggerPlugin(configuration: NetworkLoggerPlugin.Configuration(logOptions: .verbose))

    static let debug_provider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy()),
                                                              plugins: [networkLogger, AuthPlugin { return source.token }])

    static let provider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy(),
                                                                         eventMonitors: [checkRatingMonitor]),
                                                        plugins: [AuthPlugin { return source.token }])

    static let noRatingProvider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy()),
                                                        plugins: [AuthPlugin { return source.token }])
    static let noChacheProvider = MoyaProvider<TraktAPIService>(requestClosure: requestClosure,
                                                                session: Session(interceptor: RipppleRetryPolicy(),
                                                                                 eventMonitors: [checkRatingMonitor]),
                                                                plugins: [AuthPlugin { return source.token }])
    static let noChacheDebugProvider = MoyaProvider<TraktAPIService>(requestClosure: requestClosure,
                                                                session: Session(interceptor: RipppleRetryPolicy(),
                                                                                 eventMonitors: [checkRatingMonitor]),
                                                                     plugins: [networkLogger, AuthPlugin { return source.token }])

    static let decoder = setupJSONDecoder()

    static let checkRatingMonitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
        monitor.requestDidCompleteTaskWithError = { (request, _, error) in
            // if it's a post call and the error is nil, check if we ask for a rating
            if request.request?.method == .post, error == nil {
                AppManager.shared.checkRating()
                TraktStatusCheckManager.shared.refresh()
            }
        }
        return monitor
    }()

    static let requestClosure = { (endpoint: Endpoint, done: MoyaProvider.RequestResultClosure) in
        do {
            var request: URLRequest = try endpoint.urlRequest()
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            done(.success(request))
        } catch {
            print("Error trying to create a request: \(error)")
        }
    }

    private static let dateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static let dateAndTimeFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static let dateAndTimeWithoutMillisecondsFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static func setupJSONDecoder() -> JSONDecoder {
        let decoder = TraktJSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            // yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ
            if let date = dateAndTimeFormatter().date(from: dateString) {
                return date
            }
            // yyyy-MM-dd'T'HH:mm:ssZZZZZ
            if let date = dateAndTimeWithoutMillisecondsFormatter().date(from: dateString) {
                return date
            }
            // yyyy-MM-dd
            if let date = dateFormatter().date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "Cannot decode date string \(dateString)")
        }
        return decoder
    }
}

private final class TraktJSONDecoder: JSONDecoder, @unchecked Sendable {
    override func decode<T>(_ type: T.Type, from data: Data) throws -> T where T: Decodable {
        if type == [Comment].self {
            return try super.decode(LossyCommentArray<Comment>.self, from: data).elements as! T
        }

        if type == [CommentItem].self {
            return try super.decode(LossyCommentArray<CommentItem>.self, from: data).elements as! T
        }

        return try super.decode(type, from: data)
    }
}

private struct LossyCommentArray<Element: Decodable>: Decodable {
    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements = [Element]()

        while container.isAtEnd == false {
            let decodedElement = try container.decode(LossyDecodableElement<Element>.self)
            if let element = decodedElement.value {
                elements.append(element)
            } else if let error = decodedElement.error, Self.shouldSkip(error) == false {
                throw error
            }
        }

        self.elements = elements
    }

    private static func shouldSkip(_ error: Error) -> Bool {
        switch error {
        case DecodingError.keyNotFound(let key, _):
            return key.stringValue == "comment"
        case DecodingError.valueNotFound(_, let context),
             DecodingError.typeMismatch(_, let context):
            return context.codingPath.last?.stringValue == "comment"
        default:
            return false
        }
    }
}

private struct LossyDecodableElement<Element: Decodable>: Decodable {
    let value: Element?
    let error: Error?

    init(from decoder: Decoder) {
        do {
            value = try Element(from: decoder)
            error = nil
        } catch {
            value = nil
            self.error = error
        }
    }
}

// MARK: - AuthPlugin

final class TokenSource {
    var token: String?
    init() { }
}

protocol AuthorizedTargetType: TargetType {
    var needsAuth: Bool { get }
}

private struct AuthPlugin: PluginType {
    let tokenClosure: () -> String?

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        if let token = tokenClosure(),
           let target = target as? AuthorizedTargetType,
           target.needsAuth {
            var request = request
            request.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
            return request
        } else if tokenClosure() == nil,
                  let target = target as? AuthorizedTargetType,
                  target.needsAuth,
                  target.method == .delete || target.method == .patch || target.method == .post || target.method == .put {
            onNeedsToShowLoginTransmitter.broadcast(true)
            return request
        } else {
            return request
        }
    }
}
