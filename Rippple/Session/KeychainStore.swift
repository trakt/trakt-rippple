//
//  KeychainStore.swift
//  Rippple
//
//  Created by Kevin Cador on 25/02/2026.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Security

struct Token: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String
    let scope: String
    let createdAt: Double

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
        case createdAt = "created_at"
    }
}

enum KeychainStore {
    private static let service = "tv.trakt.rippple.keychain"
    private static let tokenKey = "SessionManager.token"
    private static let accessGroup = "GZG6JGPM44.tv.trakt.rippple"

    static func token() -> Token? {
        // Wait until the Keychain is ready before trying to get the token
        // eg: when the device is restarted
        waitUntilKeychainAvailable()

        guard let tokenData = data(forKey: tokenKey) else { return nil }
        do {
            return try PropertyListDecoder().decode(Token.self, from: tokenData)
        } catch {
            print("KeychainStore - token decode failed: \(error)")
            return nil
        }
    }

    static func setToken(_ token: Token) {
        if let data = try? PropertyListEncoder().encode(token) {
            set(data, forKey: tokenKey)
        }
    }

    static func removeToken() {
        remove(forKey: tokenKey)
    }

    static func accessToken() -> String? {
        token()?.accessToken
    }

    #if targetEnvironment(macCatalyst)
    static func mcpAccessKey(rotate: Bool = false) throws -> String {
        let key = "MCPServer.accessKey"
        let previousValue = data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
        if !rotate, let value = previousValue,
           value.count == 5, value.unicodeScalars.allSatisfy({ $0.properties.isEmojiPresentation }) {
            return value
        }
        // Use Unicode's Emoticons block rather than maintaining a curated emoji list.
        let emojis = (0x1F600...0x1F64F).compactMap(UnicodeScalar.init).filter {
            $0.properties.isEmojiPresentation
        }
        let count = UInt32(emojis.count)
        let limit = UInt32.max - UInt32.max % count
        var value = ""
        repeat {
            value = ""
            for _ in 0..<5 {
                var random: UInt32 = 0
                repeat {
                    guard SecRandomCopyBytes(kSecRandomDefault, MemoryLayout<UInt32>.size, &random) == errSecSuccess else {
                        throw NSError(domain: "MCPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not generate a local access key."])
                    }
                } while random >= limit
                value.unicodeScalars.append(emojis[Int(random % count)])
            }
        } while value == previousValue
        set(Data(value.utf8), forKey: key)
        guard data(forKey: key) == Data(value.utf8) else {
            throw NSError(domain: "MCPServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not save the local access key in Keychain."])
        }
        return value
    }
    #endif

    // MARK: Private

    private static func isKeychainAvailable() -> Bool {
        var query = baseQuery(forKey: tokenKey)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return true
        default:
            return ![errSecNotAvailable,
                     errSecInteractionNotAllowed].contains(status)
        }
    }

    @discardableResult
    private static func waitUntilKeychainAvailable(maxWait: TimeInterval = 300, pollInterval: TimeInterval = 1) -> Bool {
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            if isKeychainAvailable() { return true }
            Thread.sleep(forTimeInterval: pollInterval)
        }
        return false
    }

    private static func baseQuery(forKey key: String) -> [String: Any] {
        var query = [String: Any]()
        query[kSecClass as String] = kSecClassGenericPassword
        query[kSecAttrService as String] = service
        query[kSecAttrAccount as String] = key
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse as Any
        query[kSecAttrAccessGroup as String] = accessGroup
        return query
    }

    private static func data(forKey key: String) -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func set(_ data: Data, forKey key: String) {
        let status = update(data, forKey: key)
        if status == errSecItemNotFound {
            _ = add(data, forKey: key)
            return
        }
        if status != errSecSuccess {
            // Best-effort fallback: delete and re-add to recover from corrupt entries.
            _ = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
            _ = add(data, forKey: key)
        }
    }

    private static func remove(forKey key: String) {
        _ = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
    }

    private static func update(_ data: Data, forKey key: String) -> OSStatus {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    private static func add(_ data: Data, forKey key: String) -> OSStatus {
        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(query as CFDictionary, nil)
    }
}
