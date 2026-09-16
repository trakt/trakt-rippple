//
//  TraktLimitsView.swift
//  Rippple
//
//  Created by Kevin Cador on 15/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import SwiftUI

struct TraktLimitsView: View {
    let limitReached: Bool
    let close: () -> Void

    @State private var disposeBag = DisposeBag()
    @State private var limits: [TraktLimitCategory]?
    @State private var isVIP = UserManager.shared.isCurrentVIP
    @State private var isLoading = false
    @State private var hasError = false

    var body: some View {
        NavigationStack {
            RipppleList {
                Section {
                    Text(limitReached
                        ? "You’ve reached a Trakt account limit. Here are the limits for your account."
                        : "Here are the current limits for your Trakt account.")
                        .foregroundStyle(.secondary)
                }
                if isLoading {
                    ProgressView("Loading limits…")
                }
                if hasError {
                    Section {
                        Text("Your account limits couldn’t be loaded.")
                            .foregroundStyle(.secondary)
                        Button("Try Again") {
                            _Concurrency.Task { await load() }
                        }
                    }
                }
                if let limits = limits {
                    if limits.isEmpty {
                        Text("Trakt hasn’t provided any account limits.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(limits, id: \.name) { category in
                        Section(title(for: category.name)) {
                            ForEach(category.values.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                                LabeledContent(title(for: entry.key), value: entry.value.formatted())
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                if !isVIP {
                    Section {
                        Button("Explore Trakt VIP") {
                            UIApplication.shared.switchToPurchase()
                        }
                        .font(.headline)
                    } footer: {
                        Text("Discover the benefits included with Trakt VIP.")
                    }
                }
            }
            .navigationTitle("Account Limits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) { close() }
                }
            }
            .onAppear {
                onSettingsChangedReceiver.listen { settings in
                    DispatchQueue.main.async {
                        guard let settings = settings else {
                            close()
                            return
                        }
                        isVIP = settings.user.isTraktVIP
                    }
                }.disposed(by: disposeBag)
            }
            .onDisappear { disposeBag = DisposeBag() }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func title(for key: String) -> String {
        switch key {
        case "collection":
            return "Library"
        case "saved_filters":
            return "Smart List"
        default:
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    @MainActor
    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        hasError = false
        defer { isLoading = false }
        do {
            let response = try await TraktAPIProvider.fetchAccountLimits()
            guard !_Concurrency.Task<Never, Never>.isCancelled else { return }
            limits = response.limits
            isVIP = response.user.isTraktVIP
        } catch {
            hasError = true
        }
    }
}

private struct TraktLimitCategory {
    let name: String
    let values: [String: Int]
}

private struct TraktLimitsResponse {
    let limits: [TraktLimitCategory]
    let user: User

    private struct Payload: Decodable {
        let limits: [String: [String: Int]]
        let user: User
    }

    init(data: Data) throws {
        let payload = try TraktAPIProvider.decoder.decode(Payload.self, from: data)
        user = payload.user
        limits = try TraktLimitsResponse.categoryNames(in: data).compactMap { name in
            payload.limits[name].map { TraktLimitCategory(name: name, values: $0) }
        }
    }

    /// Dictionary decoding loses JSON object order. Read category keys from the
    /// validated response bytes, respecting nested objects and escaped strings.
    private static func categoryNames(in data: Data) throws -> [String] {
        let bytes = Array(data)
        var names = [String]()
        var depth = 0
        var rootKey = ""
        var inLimits = false
        var index = 0
        while index < bytes.count {
            switch bytes[index] {
            case 123, 91: // { or [
                depth += 1
                if depth == 2 { inLimits = rootKey == "limits" && bytes[index] == 123 }
            case 125, 93: // } or ]
                if depth == 2 { inLimits = false }
                depth -= 1
            case 34: // Quoted string
                let start = index
                index += 1
                while index < bytes.count {
                    if bytes[index] == 92 { // Escaped character
                        index += 2
                    } else if bytes[index] == 34 {
                        break
                    } else {
                        index += 1
                    }
                }
                let end = index
                var next = index + 1
                while next < bytes.count, [9, 10, 13, 32].contains(bytes[next]) {
                    next += 1
                }
                if next < bytes.count, bytes[next] == 58,
                   depth == 1 || (depth == 2 && inLimits) {
                    let key = try JSONDecoder().decode(String.self, from: Data(bytes[start...end]))
                    if depth == 1 {
                        rootKey = key
                    } else {
                        names.append(key)
                    }
                }
            default:
                break
            }
            index += 1
        }
        return names
    }
}

private extension TraktAPIProvider {
    static func fetchAccountLimits() async throws -> TraktLimitsResponse {
        try await withCheckedThrowingContinuation { continuation in
            noChacheProvider.request(.settings, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                do {
                    let response = try result.get().filterSuccessfulStatusCodes()
                    try continuation.resume(returning: TraktLimitsResponse(data: response.data))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
