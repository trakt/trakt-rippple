//
//  TraktAPIProvider.swift
//  Rippple
//
//  Created by Kevin Cador on 11/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import Alamofire
import Foundation
import Moya
import Receiver

enum TraktAPIProvider {
    static let source = TokenSource()

    private static let commentsCacheBuster = CommentsCacheBuster()
    private static let listsCacheBuster = ListsCacheBuster()

    static let networkLogger = NetworkLoggerPlugin(configuration: NetworkLoggerPlugin.Configuration(logOptions: .verbose))

    static let debug_provider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy()),
                                                              plugins: [networkLogger,
                                                                        AuthPlugin { source.token },
                                                                        commentsCacheBuster,
                                                                        listsCacheBuster])

    static let provider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy(),
                                                                         eventMonitors: [checkRatingMonitor]),
                                                        plugins: [AuthPlugin { source.token },
                                                                  commentsCacheBuster,
                                                                  listsCacheBuster])

    static let noRatingProvider = MoyaProvider<TraktAPIService>(session: Session(interceptor: RipppleRetryPolicy()),
                                                                plugins: [AuthPlugin { source.token },
                                                                          commentsCacheBuster,
                                                                          listsCacheBuster])

    static let noChacheProvider = MoyaProvider<TraktAPIService>(requestClosure: requestClosure,
                                                                session: Session(interceptor: RipppleRetryPolicy(),
                                                                                 eventMonitors: [checkRatingMonitor]),
                                                                plugins: [AuthPlugin { source.token },
                                                                          commentsCacheBuster,
                                                                          listsCacheBuster])
    static let noChacheDebugProvider = MoyaProvider<TraktAPIService>(requestClosure: requestClosure,
                                                                     session: Session(interceptor: RipppleRetryPolicy(),
                                                                                      eventMonitors: [checkRatingMonitor]),
                                                                     plugins: [networkLogger,
                                                                               AuthPlugin { source.token },
                                                                               commentsCacheBuster,
                                                                               listsCacheBuster])

    #if targetEnvironment(macCatalyst)
    /// MCP reports upstream failures directly; mutations must never be retried automatically.
    static let mcpProvider = MoyaProvider<MCPAPIService>(endpointClosure: { target in
        Endpoint(url: target.baseURL.absoluteString,
                 sampleResponseClosure: { .networkResponse(200, Data()) },
                 method: target.method,
                 task: target.task,
                 httpHeaderFields: target.headers)
    }, session: Session(configuration: {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        return configuration
    }(), redirectHandler: Redirector(behavior: .doNotFollow)), plugins: [AuthPlugin { source.token }])
    #endif

    static let decoder = setupJSONDecoder()

    static let checkRatingMonitor: ClosureEventMonitor = {
        let monitor = ClosureEventMonitor()
        monitor.requestDidCompleteTaskWithError = { request, _, error in
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
    override func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
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
            } else if let error = decodedElement.error, shouldSkip(error) == false {
                throw error
            }
        }

        self.elements = elements
    }
}

private func shouldSkip(_ error: Error) -> Bool {
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

// MARK: - CommentsCacheBuster

private final class CommentsCacheBuster: PluginType {
    private let lock = NSLock()
    private var marker: String?

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard target.method == .get || target.method == .head,
              target.path.split(separator: "/").contains("comments") else { return request }

        lock.lock()
        let marker = marker
        lock.unlock()

        guard let marker = marker else { return request }
        return request.addingCacheMarker(marker)
    }

    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        guard target.method == .post || target.method == .put || target.method == .patch || target.method == .delete,
              target.path.split(separator: "/").contains("comments"),
              case .success(let response) = result,
              (200..<300).contains(response.statusCode) else { return }

        // Moya calls this before completion handlers trigger follow-up reads.
        lock.lock()
        marker = UUID().uuidString
        lock.unlock()
    }
}

// MARK: - ListsCacheBuster

private final class ListsCacheBuster: PluginType {
    private let disposeBag = DisposeBag()
    private let lock = NSLock()
    private var markers = [Int64: String]()

    init() {
        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.lock.lock()
            self.markers.removeAll()
            self.lock.unlock()
        }.disposed(by: disposeBag)
    }

    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        guard let target = target as? TraktAPIService,
              case .listItems(_, let listId, _, _, _) = target else { return request }

        lock.lock()
        let marker = markers[listId] ?? UUID().uuidString
        markers[listId] = marker
        lock.unlock()

        return request.addingCacheMarker(marker)
    }

    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        guard let target = target as? TraktAPIService,
              case .success(let response) = result,
              (200..<300).contains(response.statusCode) else { return }

        let listId: Int64
        switch target {
        case .addToList(_, let id, _), .removeFromList(_, let id, _), .addToListWithNotes(_, let id, _),
             .reorderListItems(_, let id, _), .updateListItem(_, _, let id, _),
             .updateList(let id, _, _, _, _, _), .deleteList(let id):
            listId = id
        default:
            return
        }

        lock.lock()
        markers[listId] = UUID().uuidString
        lock.unlock()
    }
}

private extension URLRequest {
    func addingCacheMarker(_ marker: String) -> URLRequest {
        guard let url = url,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return self }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "marker" }
        queryItems.append(URLQueryItem(name: "marker", value: marker))
        components.queryItems = queryItems

        guard let url = components.url else { return self }

        var request = self
        request.url = url
        return request
    }
}

// MARK: - AuthPlugin

final class TokenSource {
    var token: String?
    init() {}
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
