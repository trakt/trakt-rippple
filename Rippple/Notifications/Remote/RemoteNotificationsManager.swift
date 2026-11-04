//
//  RemoteNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 07/06/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver

enum RemoteNotificationTopic: String, Codable {
    case trendingShows
    case trendingMovies
    case manualBlogPost
    case manualUpdate
    case test

    var topicARN: String? {
        switch self {
        case .trendingShows:
            return AWSConfiguration.trendingShowsTopicARN
        case .trendingMovies:
            return AWSConfiguration.trendingMoviesTopicARN
        case .manualBlogPost:
            return AWSConfiguration.manualBlogPostTopicARN
        case .manualUpdate:
            return AWSConfiguration.manualUpdateTopicARN
        case .test:
            return AWSConfiguration.testTopicARN
        }
    }
}

private struct RemoteNotificationTopicState {
    let topic: RemoteNotificationTopic
    let isSubscribed: Bool
}

/// Remote push reaches the device through two paths, each with its own "off" switch.
///
/// ACTIVITY (comment likes, replies, mentions, new followers)
///
///   App ── PUT /push/registrations ──▶ registration (PushInformationModel flags)
///                                            │
///   Trakt activity ──▶ server ── flag on? ───┴── yes ──▶ push to this endpoint ──▶ device
///
///   Off = the flag is false in the registration. The server checks it before each push.
///
/// BROADCAST (trending, blog post, app update)
///
///   App ── POST   /push/subscriptions ──┐ subscribe
///       └─ DELETE /push/subscriptions ──┤ unsubscribe
///                                       ▼
///   server ──▶ topic ──▶ every endpoint subscribed to the topic ──▶ device
///
///   Off = this endpoint is not subscribed to the topic. A topic has no per-user
///   filter, so a failed unsubscribe means the push keeps coming. That is why
///   syncTopics() never trusts a local cache and always sends the full desired state.
final class RemoteNotificationsManager {
    static let shared = RemoteNotificationsManager()

    /// Not lazy: subscriptions are synced from several concurrent tasks
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private let decoder = JSONDecoder()
    private let disposeBag = DisposeBag()
    private let session: URLSession
    private let userDefaults: UserDefaults
    private let cacheKeyPrefix = "RemoteNotificationsManager"

    private var baseURL: URL?
    private var topicSyncTask: Task<Void, Error>?
    private lazy var debouncedTopicSync = Debouncer(delay: 1.0) { [weak self] in
        guard let self = self else { return }
        self.syncTopicsInBackground()
    }

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

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            let ownedKeyPrefix = "\(self.cacheKeyPrefix)."
            for key in self.userDefaults.dictionaryRepresentation().keys where key.hasPrefix(ownedKeyPrefix) {
                self.userDefaults.removeObject(forKey: key)
            }
            self.userDefaults.synchronize()
        }.disposed(by: disposeBag)

        removeLegacySubscriptionCache()
        setupTopicSync()
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

    func pushInformation(endpointARN: String) async throws -> PushInformationModel {
        let data = try await get(path: "/push/registrations",
                                 queryItems: [URLQueryItem(name: "enpointARN", value: endpointARN)])
        return try decoder.decode(PushInformationModel.self, from: data)
    }

    func removePushInformation(endpointARN: String) async throws {
        let body = PushInformationReference(enpointARN: endpointARN)
        _ = try await delete(path: "/push/registrations", body: body)
        userDefaults.removeObject(forKey: pushInformationCacheKey(endpointARN: endpointARN))
        userDefaults.synchronize()
    }

    /// Must be called on the main thread. Topic syncs run one at a time, in call order,
    /// so the last call always reflects the latest switch values.
    @discardableResult
    func syncTopics() -> Task<Void, Error> {
        let endpointARN = userDefaults.string(forKey: "Rippple.endpointArnForSNS")
        let states = topicStates()
        let previousTask = topicSyncTask
        let task = Task { [weak self] in
            _ = await previousTask?.result
            guard let self = self, let endpointARN = endpointARN else { return }
            try await self.sync(states, endpointARN: endpointARN)
        }
        topicSyncTask = task
        return task
    }

    private func setupTopicSync() {
        debouncedTopicSync.call()

        onSettingsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTopicSync.call()
        }.disposed(by: disposeBag)

        remoteNotificationsEndpointUpdatedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedTopicSync.call()
        }.disposed(by: disposeBag)

        // Forced uploads call syncTopics() directly so they can report the result.
        onNotificationsSettingsChangedReceiver.listen { [weak self] update in
            guard let self = self, case .changed = update else { return }
            self.debouncedTopicSync.call()
        }.disposed(by: disposeBag)
    }

    private func syncTopicsInBackground() {
        let task = syncTopics()
        Task {
            do {
                try await task.value
            } catch {
                print("💀 Remote notifications topic sync Error: \(error)")
            }
        }
    }

    private func topicStates() -> [RemoteNotificationTopicState] {
        let canSubscribe = !SessionManager.shared.isLoggedOut
        var states = [
            RemoteNotificationTopicState(topic: .trendingShows, isSubscribed: canSubscribe && TrendingNotificationsManager.shared.trendingShows),
            RemoteNotificationTopicState(topic: .trendingMovies, isSubscribed: canSubscribe && TrendingNotificationsManager.shared.trendingMovies),
            RemoteNotificationTopicState(topic: .manualBlogPost, isSubscribed: canSubscribe && ManualRemoteNotificationsManager.shared.blogPost),
            RemoteNotificationTopicState(topic: .manualUpdate, isSubscribed: canSubscribe && ManualRemoteNotificationsManager.shared.appUpdate)
        ]

        if canSubscribe, UserManager.shared.currentUser?.slug == "kcador" {
            states.append(RemoteNotificationTopicState(topic: .test, isSubscribed: true))
        }

        return states
    }

    /// Syncs every topic even when one fails, then throws the first error.
    private func sync(_ states: [RemoteNotificationTopicState], endpointARN: String) async throws {
        var firstError: Error?

        for state in states {
            guard let topicARN = state.topic.topicARN else { continue }

            let body = TopicSubscriptionRequest(endpointARN: endpointARN, topicARN: topicARN)
            do {
                if state.isSubscribed {
                    _ = try await post(path: "/push/subscriptions", body: body)
                } else {
                    _ = try await delete(path: "/push/subscriptions", body: body)
                }
            } catch {
                print("💀 Remote notifications \(state.topic) sync Error: \(error)")
                firstError = firstError ?? error
            }
        }

        if let firstError = firstError {
            throw firstError
        }
    }

    /// Earlier versions skipped topic requests when this cache matched, which let it drift from the server.
    private func removeLegacySubscriptionCache() {
        let legacyKeyPrefix = "\(cacheKeyPrefix).subscription."
        for key in userDefaults.dictionaryRepresentation().keys where key.hasPrefix(legacyKeyPrefix) {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func post<T: Encodable>(path: String, body: T) async throws -> Data {
        let request = try request(method: "POST", path: path, body: encoder.encode(body))
        return try await data(for: request)
    }

    private func get(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        let request = try request(method: "GET", path: path, queryItems: queryItems)
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

    private func request(method: String,
                         path: String,
                         queryItems: [URLQueryItem] = [],
                         body: Data? = nil) throws -> URLRequest {
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
        components.queryItems = queryItems.isEmpty ? nil : queryItems
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

    private func pushInformationCacheKey(endpointARN: String) -> String {
        return "\(cacheKeyPrefix).pushInformation.\(endpointARN)"
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
