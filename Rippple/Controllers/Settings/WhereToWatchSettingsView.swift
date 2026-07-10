//
//  WhereToWatchSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 25/04/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI

struct WhereToWatchSettingsView: View {
    @State private var selectedMode = "Display All"
    @State private var country = CountryManager.userCountry
    @State private var favorites = CountryManager.shared.favoriteProviders
    @State private var displayInLists = CountryManager.shared.displayInLists

    @State private var providers = [ProviderType]()

    @State private var loading = false

    var body: some View {
        Form {
            Section {
                Picker("Display Mode", selection: $selectedMode) {
                    Text("All Providers").tag("Display All")
                    Text("Favorites Only").tag("Only Favorites")
                    Text("Never Display").tag("Disabled")
                }.pickerStyle(.menu)
                if selectedMode != "Disabled" {
                    Toggle("Display in Lists", isOn: $displayInLists)
                    Picker("Country", selection: $country) {
                        ForEach(Country.allCases) { country in
                            Text(country.localizedCountry).tag(country)
                        }
                    }.pickerStyle(.menu)
                }
            } footer: {
                switch selectedMode {
                case "Display All":
                    if displayInLists {
                        Text("All Providers for the selected country will be displayed in Lists and Details, sorted by display priority with your favorites on top.")
                    } else {
                        Text("All Providers for the selected country will be displayed in Details, sorted by display priority with your favorites on top.")
                    }
                case "Only Favorites":
                    if favorites.isEmpty {
                        if displayInLists {
                            Text("⚠️ Choose your favorites for the selected country, otherwise, providers won't be displayed in Lists and Details.")
                        } else {
                            Text("⚠️ Choose your favorites for the selected country, otherwise, providers won't be displayed in Details.")
                        }
                    } else {
                        if displayInLists {
                            Text("Only your Favorite Providers for the selected country will be displayed in Lists and Details, sorted by your preference.")
                        } else {
                            Text("Only your Favorite Providers for the selected country will be displayed in Details, sorted by your preference.")
                        }
                    }
                case "Disabled":
                    Text("Providers won't be displayed in Lists and Details.")
                default:
                    EmptyView()
                }
            }
            if selectedMode != "Disabled" {
                if !favorites.isEmpty {
                    Section("Your Favorites in \(country.localizedCountry)") {
                        ForEach(favorites) { provider in
                            HStack(spacing: 10) {
                                if let providerLogoURL = provider.logo,
                                   let url = ImagesManager.shared.imageURL(for: providerLogoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        EmptyView()
                                    }
                                    .cornerRadius(10)
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                Text(provider.name ?? "Unknown")
                            }
                        }.onDelete { offset in
                            CountryManager.shared.favoriteProviders.remove(atOffsets: offset)
                            favorites = CountryManager.shared.favoriteProviders
                        }.onMove { from, to in
                            CountryManager.shared.favoriteProviders.move(fromOffsets: from, toOffset: to)
                            favorites = CountryManager.shared.favoriteProviders
                        }
                    }
                }
                if !providers.isEmpty {
                    Section {
                        ForEach(providers) { provider in
                            HStack(spacing: 10) {
                                if let providerLogoURL = provider.logo,
                                   let url = ImagesManager.shared.imageURL(for: providerLogoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        EmptyView()
                                    }
                                    .cornerRadius(10)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                Text(provider.name ?? "Unknown")
                                Spacer()
                                Button {
                                    if favorites.contains(where: { $0 == provider }) {
                                        CountryManager.shared.favoriteProviders.removeAll(where: { $0 == provider })
                                        favorites = CountryManager.shared.favoriteProviders
                                    } else {
                                        CountryManager.shared.favoriteProviders.append(provider)
                                        favorites = CountryManager.shared.favoriteProviders
                                    }
                                } label: {
                                    if favorites.contains(where: { $0 == provider }) {
                                        Image(systemName: "star.fill")
                                    } else {
                                        Image(systemName: "star")
                                    }
                                }.tint(.yellow)
                            }
                        }
                    } header: {
                        Text("All Providers in \(country.localizedCountry)")
                    } footer: {
                        Text("TV and Movie Providers are provided by JustWatch via TMDb.")
                    }
                }
            }
        }.onAppear {
            if CountryManager.shared.disabled {
                selectedMode = "Disabled"
            } else {
                if CountryManager.shared.favoritesOnly {
                    selectedMode = "Only Favorites"
                } else {
                    selectedMode = "Display All"
                }
            }
        }.onChange(of: displayInLists) { _, newValue in
            CountryManager.shared.displayInLists = newValue
        }.onChange(of: selectedMode) { _, newValue in
            switch newValue {
            case "Display All":
                CountryManager.shared.disabled = false
                CountryManager.shared.favoritesOnly = false
            case "Only Favorites":
                CountryManager.shared.disabled = false
                CountryManager.shared.favoritesOnly = true
            case "Disabled":
                CountryManager.shared.disabled = true
            default:
                break
            }
        }.onChange(of: country, initial: true) { _, newValue in
            CountryManager.shared.storeCountryChoosenByUser(country: newValue.rawValue)
            favorites = CountryManager.shared.favoriteProviders
            displayInLists = CountryManager.shared.displayInLists
            providers = [ProviderType]()
            loading = true
            Task {
                let tvProviders = (try? await fetchTVProviders(in: newValue.rawValue)) ?? [ProviderType]()
                let movieProviders = (try? await fetchMovieProviders(in: newValue.rawValue)) ?? [ProviderType]()
                var providers: [ProviderType] = tvProviders
                for movieProvider in movieProviders {
                    if let tvProvider = providers.first(where: { $0 == movieProvider }) {
                        if movieProvider.priority ?? 0 < tvProvider.priority ?? 0 {
                            providers.removeAll(where: { $0 == movieProvider })
                            providers.append(movieProvider)
                        }
                    } else {
                        providers.append(movieProvider)
                    }
                }
                self.providers = providers.sorted(by: { $0.priority ?? 0 < $1.priority ?? 0 })
                self.loading = false
            }
        }.environment(\.editMode, .constant(EditMode.active))
            .toolbar {
                if loading {
                    ProgressView()
                }
            }
    }

    private func fetchTVProviders(in region: String) async throws -> [ProviderType] {
        return try await withCheckedThrowingContinuation { continuation in
            TmdbAPIProvider.provider.request(.providersForTVInRegion(region),
                                             callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let providersInCountryResult = try response.map(ProvidersInCountryResult.self, using: TmdbAPIProvider.decoder)
                        var providers = [ProviderType]()
                        for providerInCountry in providersInCountryResult.results ?? [Provider]() {
                            let providerType = ProviderType(priority: providerInCountry.priority,
                                                            logo: providerInCountry.logo,
                                                            identifier: providerInCountry.identifier,
                                                            name: providerInCountry.name,
                                                            type: ["tv"])
                            providers.append(providerType)
                        }
                        continuation.resume(returning: providers)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchMovieProviders(in region: String) async throws -> [ProviderType] {
        return try await withCheckedThrowingContinuation { continuation in
            TmdbAPIProvider.provider.request(.providersForMovieInRegion(region),
                                             callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let providersInCountryResult = try response.map(ProvidersInCountryResult.self, using: TmdbAPIProvider.decoder)
                        var providers = [ProviderType]()
                        for providerInCountry in providersInCountryResult.results ?? [Provider]() {
                            let providerType = ProviderType(priority: providerInCountry.priority,
                                                            logo: providerInCountry.logo,
                                                            identifier: providerInCountry.identifier,
                                                            name: providerInCountry.name,
                                                            type: ["movie"])
                            providers.append(providerType)
                        }
                        continuation.resume(returning: providers)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
