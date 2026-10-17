//
//  KlipyAPI.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Moya

enum KlipyAPIService {
    case gifs(key: String, query: String, page: Int, customerId: String)
    case share(key: String, slug: String, customerId: String)
}

extension KlipyAPIService: TargetType {
    var baseURL: URL {
        URL(string: "https://api.klipy.com/api/v1")!
    }

    var path: String {
        switch self {
        case .gifs(let key, let query, _, _):
            return "/\(key)/gifs/\(query.isEmpty ? "trending" : "search")"
        case .share(let key, let slug, _):
            return "/\(key)/gifs/share/\(slug)"
        }
    }

    var method: Moya.Method {
        switch self {
        case .gifs: return .get
        case .share: return .post
        }
    }

    var task: Moya.Task {
        switch self {
        case .gifs(_, let query, let page, let customerId):
            var parameters: [String: Any] = ["customer_id": customerId, "page": page, "per_page": 24]
            if query.isEmpty == false {
                parameters["q"] = query
            }
            return .requestParameters(parameters: parameters, encoding: URLEncoding.default)
        case .share(_, _, let customerId):
            return .requestParameters(parameters: ["customer_id": customerId], encoding: JSONEncoding.default)
        }
    }

    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
}

// MARK: - Models

struct KlipyGIF: Decodable {
    struct Source: Decodable {
        let url: String
        let width: Double
        let height: Double
    }

    struct Formats: Decodable {
        let gif: Source
        let webp: Source?
    }

    struct Files: Decodable {
        let md: Formats
        let sm: Formats
    }

    let slug: String
    let file: Files

    var preview: Source {
        file.sm.webp ?? file.sm.gif
    }

    var commentGIF: CommentGIF {
        let full = file.md.webp ?? file.md.gif
        return CommentGIF(url: full.url, width: full.width, height: full.height)
    }
}

struct KlipyGIFPage {
    let gifs: [KlipyGIF]
    let hasNext: Bool
}

/// Sponsored items ride along in the same array, so items decode one by one and only real GIFs are kept.
private struct KlipyPageResponse: Decodable {
    struct Page: Decodable {
        let data: [Item]
        let hasNext: Bool

        enum CodingKeys: String, CodingKey {
            case data
            case hasNext = "has_next"
        }
    }

    struct Item: Decodable {
        let gif: KlipyGIF?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try? container.decode(String.self, forKey: .type)
            gif = type == "gif" ? try? KlipyGIF(from: decoder) : nil
        }

        enum CodingKeys: String, CodingKey {
            case type
        }
    }

    let data: Page
}

// MARK: - Provider

enum KlipyAPIProvider {
    static let provider = MoyaProvider<KlipyAPIService>(session: Session(interceptor: RipppleRetryPolicy()))

    private static let customerIdKey = "KlipyAPIProvider.customerId"

    static var isAvailable: Bool {
        apiKey != nil
    }

    private static var apiKey: String? {
        guard let key = KlipyAPIConfiguration.apiKey, key.isEmpty == false else { return nil }
        return key
    }

    private static var customerId: String {
        if let id = UserDefaults.standard.string(forKey: customerIdKey) {
            return id
        }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: customerIdKey)
        return id
    }

    static func gifs(query: String,
                     page: Int,
                     completion: @escaping (Result<KlipyGIFPage, Error>) -> Void) -> Cancellable? {
        guard let key = apiKey else { return nil }
        let target = KlipyAPIService.gifs(key: key, query: query, page: page, customerId: customerId)
        return provider.request(target, callbackQueue: .global(qos: .userInitiated)) { result in
            let decoded: Result<KlipyGIFPage, Error> = Result {
                let response = try result.get().filterSuccessfulStatusCodes()
                let page = try JSONDecoder().decode(KlipyPageResponse.self, from: response.data).data
                return KlipyGIFPage(gifs: page.data.compactMap { $0.gif }, hasNext: page.hasNext)
            }
            DispatchQueue.main.async {
                completion(decoded)
            }
        }
    }

    static func share(slug: String) {
        guard let key = apiKey else { return }
        provider.request(.share(key: key, slug: slug, customerId: customerId)) { _ in }
    }
}
