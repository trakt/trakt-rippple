//
//  AppIconPreviewView.swift
//  Rippple
//
//  Created by Kevin Cador on 07/07/2023.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI

enum AppIconIdentifier: String, Hashable, CaseIterable {
    case original
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case cyan
    case blue
    case indigo
    case purple
    case pink
    case brown
    case pride
    case monochrome
    case shadow
    case ghost
    case unity
    case peace

    var name: String {
        switch self {
        case .original:
            return "Rippple"
        case .red:
            return "Red"
        case .orange:
            return "Orange"
        case .yellow:
            return "Yellow"
        case .green:
            return "Green"
        case .mint:
            return "Mint"
        case .teal:
            return "Teal"
        case .cyan:
            return "Cyan"
        case .blue:
            return "Blue"
        case .indigo:
            return "Indigo"
        case .purple:
            return "Purple"
        case .pink:
            return "Pink"
        case .brown:
            return "Brown"
        case .pride:
            return "Pride"
        case .monochrome:
            return "Monochrome"
        case .shadow:
            return "Shadow"
        case .ghost:
            return "Ghost"
        case .unity:
            return "Unity"
        case .peace:
            return "Peace"
        }
    }

    var alternateIconName: String? {
        return self == .original ? nil : rawValue
    }

    fileprivate func previewAssetName(for appearance: AppIconPreviewAppearance) -> String {
        return "app_icon_preview_\(rawValue)_\(appearance.rawValue)"
    }
}

enum AppIconPreviewAppearance: String, CaseIterable, Identifiable {
    case `default`
    case dark
    case clear

    var id: AppIconPreviewAppearance {
        return self
    }

    var name: String {
        switch self {
        case .default:
            return "Default"
        case .dark:
            return "Dark"
        case .clear:
            return "Clear"
        }
    }
}

struct AppIconPreviewView: View {
    let appIconIdentifier: AppIconIdentifier
    let appearance: AppIconPreviewAppearance

    var body: some View {
        Image(appIconIdentifier.previewAssetName(for: appearance))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        ForEach(AppIconPreviewAppearance.allCases) { appearance in
            AppIconPreviewView(appIconIdentifier: .unity,
                               appearance: appearance)
                .frame(width: 100, height: 100)
        }
    }
    .padding()
}
