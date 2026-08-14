//
//  AppIconChooserView.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2024.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

struct AppIconChooserView: View {
    private let colorIcons: [AppIconIdentifier] = [
        .red,
        .orange,
        .yellow,
        .green,
        .mint,
        .teal,
        .cyan,
        .blue,
        .indigo,
        .purple,
        .pink,
        .brown,
        .monochrome
    ]

    private let specialIcons: [AppIconIdentifier] = [
        .peace,
        .pride,
        .unity
    ]

    private let stealthIcons: [AppIconIdentifier] = [
        .shadow,
        .ghost
    ]

    @State private var selectedIdentifier: AppIconIdentifier
    @State private var previewAppearance = AppIconPreviewAppearance.default
    @State private var errorMessage: String?
    @State private var showsCatalystMessage = false

    init() {
        #if targetEnvironment(macCatalyst)
        _selectedIdentifier = State(initialValue: .original)
        #else
        let storedName = UIApplication.shared.alternateIconName
        _selectedIdentifier = State(initialValue: AppIconIdentifier(rawValue: storedName ?? "") ?? .original)
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                iconSection(title: nil, identifiers: [.original])
                iconSection(title: "Color Editions", identifiers: colorIcons)
                iconSection(title: "Community Editions", identifiers: specialIcons)
                iconSection(title: "Stealth Editions", identifiers: stealthIcons)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            appearancePreviewPane
                .padding(.horizontal)
                .padding(.vertical, 8)
        }
        .alert("Unable to Change Icon",
               isPresented: Binding(get: { errorMessage != nil },
                                    set: { isPresented in
                                        if isPresented == false {
                                            errorMessage = nil
                                        }
                                    })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("App Icons on Mac",
               isPresented: $showsCatalystMessage) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Changing the app icon isn’t supported on Mac Catalyst yet.")
        }
    }

    private var appearancePreviewPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: 20) {
                ForEach(AppIconPreviewAppearance.allCases) { appearance in
                    Button {
                        withAnimation(.snappy) {
                            previewAppearance = appearance
                        }
                    } label: {
                        VStack(spacing: 6) {
                            AppIconPreviewView(appIconIdentifier: selectedIdentifier,
                                               appearance: appearance)
                                .frame(maxWidth: 72)
                                .aspectRatio(1, contentMode: .fit)

                            Text(previewAppearance == appearance ? "✔ \(appearance.name)" : appearance.name)
                                .font(.caption)
                                .fontWeight(previewAppearance == appearance ? .semibold : .medium)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    if previewAppearance == appearance {
                                        Capsule()
                                            .fill(Color(uiColor: .systemGray5))
                                    }
                                }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Preview icons in \(appearance.name) appearance")
                    .accessibilityAddTraits(previewAppearance == appearance ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: 420)
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
    }

    private func iconSection(title: String?, identifiers: [AppIconIdentifier]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.headline)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 16)],
                      spacing: 20) {
                ForEach(identifiers, id: \.self) { identifier in
                    Button {
                        select(identifier)
                    } label: {
                        VStack(spacing: 8) {
                            AppIconPreviewView(appIconIdentifier: identifier,
                                               appearance: previewAppearance)
                                .aspectRatio(1, contentMode: .fit)

                            Text(selectedIdentifier == identifier ? "✔ \(identifier.name)" : identifier.name)
                                .font(.caption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background {
                                    if selectedIdentifier == identifier {
                                        Capsule()
                                            .fill(Color(uiColor: .systemGray5))
                                    }
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(identifier.name) app icon")
                    .accessibilityAddTraits(selectedIdentifier == identifier ? .isSelected : [])
                }
            }
        }
    }

    private func select(_ identifier: AppIconIdentifier) {
        #if targetEnvironment(macCatalyst)
        showsCatalystMessage = true
        #else
        setIcon(identifier)
        #endif
    }

    private func setIcon(_ identifier: AppIconIdentifier) {
        UIApplication.shared.setAlternateIconName(identifier.alternateIconName) { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "\(error.localizedDescription)\n\nRestarting the device can sometimes resolve this."
                    return
                }

                selectedIdentifier = identifier
            }
        }
    }
}

#Preview {
    AppIconChooserView()
}
