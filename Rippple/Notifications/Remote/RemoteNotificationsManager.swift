//
//  RemoteNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/06/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Foundation

enum RemoteNotificationTopic: String, Codable {
    case trendingShows
    case trendingMovies
    case recommendedShows
    case recommendedMovies
    case manualBlogPost
    case manualUpdate
    case test

    var topicARN: String? {
        switch self {
        case .trendingShows:
            return AWSConfiguration.trendingShowsTopicARN
        case .trendingMovies:
            return AWSConfiguration.trendingMoviesTopicARN
        case .recommendedShows:
            return AWSConfiguration.recommendedShowsTopicARN
        case .recommendedMovies:
            return AWSConfiguration.recommendedMoviesTopicARN
        case .manualBlogPost:
            return AWSConfiguration.manualBlogPostTopicARN
        case .manualUpdate:
            return AWSConfiguration.manualUpdateTopicARN
        case .test:
            return AWSConfiguration.testTopicARN
        }
    }
}

enum RemoteNotificationTopicSyncResult {
    case skipped
    case subscribed
    case unsubscribed
}

struct RemoteNotificationsCacheStatus {
    let pushInformationCached: Bool?
    let subscriptions: [RemoteNotificationsSubscriptionCacheStatus]
}

struct RemoteNotificationsSubscriptionCacheStatus {
    let topic: RemoteNotificationTopic
    let topicARNConfigured: Bool
    let isSubscribed: Bool?
}

final class RemoteNotificationsManager {
    static let shared = RemoteNotificationsManager()

    private lazy var encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private let decoder = JSONDecoder()
    private let session: URLSession
    private let userDefaults: UserDefaults
    private let cacheKeyPrefix = "RemoteNotificationsManager"

    private var baseURL: URL?

    private(set) var isConfigured = false

    private init(session: URLSession = .shared, userDefaults: UserDefaults = .standard) {
        self.session = session
        self.userDefaults = userDefaults
    }

    func configure() {
        guard !isConfigured else { return }

        guard let remoteNotificationsBaseURL = RemoteNotificationsConfiguration.remoteNotificationsBaseURL else {
            print("Remote push notifications disabled: missing remote notifications REST base URL")
            return
        }
        guard let normalizedBaseURL = normalizedBaseURL(from: remoteNotificationsBaseURL) else {
            print("Remote push notifications disabled: invalid remote notifications REST base URL")
            return
        }
        guard AWSConfiguration.platformApplicationARN != nil else {
            print("Remote push notifications disabled: missing SNS platform application ARN")
            return
        }

        baseURL = normalizedBaseURL
        isConfigured = true
        print("Initialized remote notifications REST API")
    }

    func createEndpoint(token: String, customUserData: String) async throws -> String {
        guard let platformApplicationARN = AWSConfiguration.platformApplicationARN else {
            throw RemoteNotificationsManagerError.missingPlatformApplicationARN
        }

        let body = CreateEndpointRequest(platformApplicationARN: platformApplicationARN,
                                         token: token,
                                         customUserData: customUserData)
        let data = try await post(path: "/push/endpoints", body: body)
        let response = try decoder.decode(CreateEndpointResponse.self, from: data)
        return response.endpointARN
    }

    func updateEndpoint(endpointARN: String, customUserData: String) async throws {
        let body = UpdateEndpointRequest(endpointARN: endpointARN,
                                         customUserData: customUserData,
                                         enabled: true)
        _ = try await put(path: "/push/endpoints", body: body)
    }

    @discardableResult
    func savePushInformation(_ pushInformation: PushInformationModel, force: Bool = false) async throws -> Bool {
        let requestBody = try encoder.encode(pushInformation)
        let cacheKey = pushInformationCacheKey(endpointARN: pushInformation.enpointARN)
        guard force || userDefaults.data(forKey: cacheKey) != requestBody else { return false }

        _ = try await put(path: "/push/registrations", body: requestBody)
        userDefaults.set(requestBody, forKey: cacheKey)
        userDefaults.synchronize()
        return true
    }

    func removePushInformation(endpointARN: String) async throws {
        let body = PushInformationReference(enpointARN: endpointARN)
        _ = try await delete(path: "/push/registrations", body: body)
        userDefaults.removeObject(forKey: pushInformationCacheKey(endpointARN: endpointARN))
        userDefaults.synchronize()
    }

    func subscribe(endpointARN: String, to topic: RemoteNotificationTopic) async throws {
        guard let topicARN = topic.topicARN else {
            return
        }

        let body = TopicSubscriptionRequest(endpointARN: endpointARN, topicARN: topicARN)
        _ = try await post(path: "/push/subscriptions", body: body)
        saveSyncedSubscription(endpointARN: endpointARN, topicARN: topicARN, isSubscribed: true)
    }

    func unsubscribe(endpointARN: String, from topic: RemoteNotificationTopic) async throws {
        guard let topicARN = topic.topicARN else {
            return
        }

        let body = TopicSubscriptionRequest(endpointARN: endpointARN, topicARN: topicARN)
        _ = try await delete(path: "/push/subscriptions", body: body)
        saveSyncedSubscription(endpointARN: endpointARN, topicARN: topicARN, isSubscribed: false)
    }

    @discardableResult
    func syncSubscription(endpointARN: String, to topic: RemoteNotificationTopic, isSubscribed: Bool, force: Bool = false) async throws -> RemoteNotificationTopicSyncResult {
        guard let topicARN = topic.topicARN else { return .skipped }
        guard force || syncedSubscription(endpointARN: endpointARN, topicARN: topicARN) != isSubscribed else { return .skipped }

        if isSubscribed {
            try await subscribe(endpointARN: endpointARN, to: topic)
            return .subscribed
        } else {
            try await unsubscribe(endpointARN: endpointARN, from: topic)
            return .unsubscribed
        }
    }

    func cacheStatus(endpointARN: String?, topics: [RemoteNotificationTopic]) -> RemoteNotificationsCacheStatus {
        let pushInformationCached: Bool?
        if let endpointARN = endpointARN {
            pushInformationCached = userDefaults.data(forKey: pushInformationCacheKey(endpointARN: endpointARN)) != nil
        } else {
            pushInformationCached = nil
        }

        let subscriptions = topics.map { topic -> RemoteNotificationsSubscriptionCacheStatus in
            guard let topicARN = topic.topicARN else {
                return RemoteNotificationsSubscriptionCacheStatus(topic: topic,
                                                                  topicARNConfigured: false,
                                                                  isSubscribed: nil)
            }

            let isSubscribed: Bool?
            if let endpointARN = endpointARN {
                isSubscribed = syncedSubscription(endpointARN: endpointARN, topicARN: topicARN)
            } else {
                isSubscribed = nil
            }

            return RemoteNotificationsSubscriptionCacheStatus(topic: topic,
                                                              topicARNConfigured: true,
                                                              isSubscribed: isSubscribed)
        }

        return RemoteNotificationsCacheStatus(pushInformationCached: pushInformationCached,
                                              subscriptions: subscriptions)
    }

    private func post<T: Encodable>(path: String, body: T) async throws -> Data {
        let request = try request(method: "POST", path: path, body: encoder.encode(body))
        return try await data(for: request)
    }

    private func put<T: Encodable>(path: String, body: T) async throws -> Data {
        let request = try request(method: "PUT", path: path, body: encoder.encode(body))
        return try await data(for: request)
    }

    private func put(path: String, body: Data) async throws -> Data {
        let request = try request(method: "PUT", path: path, body: body)
        return try await data(for: request)
    }

    private func delete<T: Encodable>(path: String, body: T) async throws -> Data {
        let request = try request(method: "DELETE", path: path, body: encoder.encode(body))
        return try await data(for: request)
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteNotificationsManagerError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw RemoteNotificationsManagerError.httpError(
                statusCode: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }

        return data
    }

    private func request(method: String, path: String, body: Data) throws -> URLRequest {
        guard let baseURL = baseURL else {
            throw RemoteNotificationsManagerError.notConfigured
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else {
            throw RemoteNotificationsManagerError.invalidBaseURL
        }

        let normalizedBasePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullPath = [normalizedBasePath, normalizedPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")
        components.path = "/\(fullPath)"
        components.query = nil
        components.fragment = nil
        guard let url = components.url else {
            throw RemoteNotificationsManagerError.invalidBaseURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = RemoteNotificationsConfiguration.remoteNotificationsAPIKey {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.httpBody = body
        return request
    }

    private func normalizedBaseURL(from url: URL) -> URL? {
        if isValidRemoteNotificationsBaseURL(url) {
            return url
        }

        let rawValue = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawValue.isEmpty else { return nil }

        let urlString = rawValue.hasPrefix("//") ? "https:\(rawValue)" : "https://\(rawValue)"
        guard let url = URL(string: urlString),
              isValidRemoteNotificationsBaseURL(url) else {
            return nil
        }

        return url
    }

    private func isValidRemoteNotificationsBaseURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return false
        }

        return true
    }

    private func syncedSubscription(endpointARN: String, topicARN: String) -> Bool? {
        return userDefaults.object(forKey: subscriptionCacheKey(endpointARN: endpointARN, topicARN: topicARN)) as? Bool
    }

    private func saveSyncedSubscription(endpointARN: String, topicARN: String, isSubscribed: Bool) {
        userDefaults.set(isSubscribed, forKey: subscriptionCacheKey(endpointARN: endpointARN, topicARN: topicARN))
        userDefaults.synchronize()
    }

    private func pushInformationCacheKey(endpointARN: String) -> String {
        return "\(cacheKeyPrefix).pushInformation.\(endpointARN)"
    }

    private func subscriptionCacheKey(endpointARN: String, topicARN: String) -> String {
        return "\(cacheKeyPrefix).subscription.\(endpointARN).\(topicARN)"
    }
}

private enum RemoteNotificationsManagerError: LocalizedError {
    case notConfigured
    case invalidBaseURL
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case missingPlatformApplicationARN

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Remote notifications REST API is not configured."
        case .invalidBaseURL:
            return "Remote notifications REST API base URL is invalid."
        case .invalidResponse:
            return "Remote notifications REST API returned an invalid response."
        case .httpError(let statusCode, let body):
            return "Remote notifications REST API returned HTTP \(statusCode): \(body ?? "empty response")"
        case .missingPlatformApplicationARN:
            return "Remote notifications SNS platform application ARN is missing."
        }
    }
}

private struct CreateEndpointRequest: Encodable {
    let platformApplicationARN: String
    let token: String
    let customUserData: String
}

private struct CreateEndpointResponse: Decodable {
    let endpointARN: String

    private enum CodingKeys: String, CodingKey {
        case endpointARN
        case endpointArn
        case EndpointArn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let endpointARN = try container.decodeIfPresent(String.self, forKey: .endpointARN) {
            self.endpointARN = endpointARN
        } else if let endpointARN = try container.decodeIfPresent(String.self, forKey: .endpointArn) {
            self.endpointARN = endpointARN
        } else if let endpointARN = try container.decodeIfPresent(String.self, forKey: .EndpointArn) {
            self.endpointARN = endpointARN
        } else {
            throw DecodingError.keyNotFound(CodingKeys.endpointARN,
                                            DecodingError.Context(codingPath: decoder.codingPath,
                                                                  debugDescription: "Missing endpoint ARN in create endpoint response."))
        }
    }
}

private struct UpdateEndpointRequest: Encodable {
    let endpointARN: String
    let customUserData: String
    let enabled: Bool
}

private struct PushInformationReference: Encodable {
    let enpointARN: String
}

private struct TopicSubscriptionRequest: Encodable {
    let endpointARN: String
    let topicARN: String
}
