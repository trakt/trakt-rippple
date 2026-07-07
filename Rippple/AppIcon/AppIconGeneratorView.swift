//
//  AppIconGeneratorView.swift
//  Rippple
//
//  Created by Kevin Cador on 07/07/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import SwiftUI

enum AppIconIdentifier: String, Hashable, CaseIterable {
    case original

    case classic

    case dark
    case color
    case pride
    case lightMonochrome
    case darkMonochrome
    case desktop

    case color_purple
    case color_red
    case color_orange
    case color_yellow
    case color_green
    case color_mint
    case color_teal
    case color_cyan
    case color_blue
    case color_indigo
    case color_pink
    case color_brown

    case dark_purple
    case dark_red
    case dark_orange
    case dark_yellow
    case dark_green
    case dark_mint
    case dark_teal
    case dark_cyan
    case dark_blue
    case dark_indigo
    case dark_pink
    case dark_brown

    case light_purple
    case light_red
    case light_orange
    case light_yellow
    case light_green
    case light_mint
    case light_teal
    case light_cyan
    case light_blue
    case light_indigo
    case light_pink
    case light_brown

    case pride2
    case pride3

    case color_purple_border
    case color_red_border
    case color_orange_border
    case color_yellow_border
    case color_green_border
    case color_mint_border
    case color_teal_border
    case color_cyan_border
    case color_blue_border
    case color_indigo_border
    case color_pink_border
    case color_brown_border

    case dark_purple_border
    case dark_red_border
    case dark_orange_border
    case dark_yellow_border
    case dark_green_border
    case dark_mint_border
    case dark_teal_border
    case dark_cyan_border
    case dark_blue_border
    case dark_indigo_border
    case dark_pink_border
    case dark_brown_border

    case light_purple_border
    case light_red_border
    case light_orange_border
    case light_yellow_border
    case light_green_border
    case light_mint_border
    case light_teal_border
    case light_cyan_border
    case light_blue_border
    case light_indigo_border
    case light_pink_border
    case light_brown_border

    case lightMonochrome2
    case darkMonochrome2

    case seven_color_purple
    case seven_color_red
    case seven_color_orange
    case seven_color_yellow
    case seven_color_green
    case seven_color_mint
    case seven_color_teal
    case seven_color_cyan
    case seven_color_blue
    case seven_color_indigo
    case seven_color_pink
    case seven_color_brown

    case seven_dark_purple
    case seven_dark_red
    case seven_dark_orange
    case seven_dark_yellow
    case seven_dark_green
    case seven_dark_mint
    case seven_dark_teal
    case seven_dark_cyan
    case seven_dark_blue
    case seven_dark_indigo
    case seven_dark_pink
    case seven_dark_brown

    case seven_light_purple
    case seven_light_red
    case seven_light_orange
    case seven_light_yellow
    case seven_light_green
    case seven_light_mint
    case seven_light_teal
    case seven_light_cyan
    case seven_light_blue
    case seven_light_indigo
    case seven_light_pink
    case seven_light_brown

    case seven_monochrome_light
    case seven_monochrome_dark

    case seven_pride_light
    case seven_pride_dark

    case seven_neon_purple
    case seven_neon_red
    case seven_neon_orange
    case seven_neon_yellow
    case seven_neon_green
    case seven_neon_mint
    case seven_neon_teal
    case seven_neon_cyan
    case seven_neon_blue
    case seven_neon_indigo
    case seven_neon_pink
    case seven_neon_brown

    case seven_neon_ai_edition
    case seven_dark_ai_edition
    case seven_light_ai_edition
    case border_dark_ai_edition
    case border_light_ai_edition

    case seven_neon_monochrome
    case seven_neon_pride
}

enum TIconIdentifier: String, Hashable, CaseIterable {
    case white
    case purple
    case black
    case rainbow
    case rings_white
    case rings_black
    case rings_purple
}

struct AppIcon: Hashable, Identifiable {
    var id: String {
        return (name ?? "") + identifier.rawValue
    }

    let name: String?
    let identifier: AppIconIdentifier
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AppIconGeneratorView: View {
    enum AppIconMode {
        case any
        case dark
        case tinted
    }

    @State var iconMode = AppIconMode.any
    @State var appIconIdentifier: AppIconIdentifier

    var body: some View {
        switch iconMode {
        case .tinted:
            switch appIconIdentifier {
            case .original:
                RipppleGlassDarkIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [.white])
            case .classic:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.4,
                                     outslideRipppleOpacity: 0.2)
            case .dark:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.7,
                                     outslideRipppleOpacity: 0.5)
            case .color:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .pride:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.7,
                                     outslideRipppleOpacity: 0.5,
                                     insideRipppleShadowRadius: 0.05,
                                     secondRipppleShadowRadius: 0.05,
                                     outslideRipppleShadowRadius: 0.05)
            case .lightMonochrome:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.4,
                                     outslideRipppleOpacity: 0.2,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .darkMonochrome:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.4,
                                     outslideRipppleOpacity: 0.2)
            case .desktop:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.4,
                                     outslideRipppleOpacity: 0.2)
            case .color_purple:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_red:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_orange:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_yellow:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_green:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_mint:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_teal:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_cyan:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_blue:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_indigo:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_pink:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .color_brown:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white])
            case .dark_purple:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_red:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_orange:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_yellow:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_green:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_mint:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_teal:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_cyan:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_blue:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_indigo:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_pink:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_brown:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .light_purple:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_red:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_orange:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_yellow:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_green:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_mint:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_teal:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_cyan:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_blue:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_indigo:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_pink:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_brown:
                RipppleIconEntryView(backgroundGradient: [.clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .pride2:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .pride3:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .light_purple_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .color_purple_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_red_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_orange_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_yellow_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_green_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_mint_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_teal_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_cyan_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_blue_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_indigo_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_pink_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .color_brown_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_purple_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_red_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_orange_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_yellow_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_green_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_mint_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_teal_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_cyan_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_blue_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_indigo_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_pink_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .dark_brown_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_red_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_orange_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_yellow_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_green_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_mint_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_teal_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_cyan_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_blue_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_indigo_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_pink_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .light_brown_border:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .lightMonochrome2:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .darkMonochrome2:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .seven_color_purple:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_red:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_orange:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_green:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_mint:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_teal:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_blue:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_pink:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_color_brown:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_purple:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_red:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_orange:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_green:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_mint:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_teal:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_blue:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_pink:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_dark_brown:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_purple:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_red:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_orange:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_green:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_mint:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_teal:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_blue:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_pink:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_brown:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_monochrome_light:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_monochrome_dark:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_pride_light:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_pride_dark:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_neon_purple:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_red:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_orange:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_green:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_mint:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_teal:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_blue:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_pink:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_brown:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_monochrome:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_pride:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [.clear], colors: [Color(uiColor: .darkGray.resolvedColor(with: UITraitCollection()))])
            case .seven_dark_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_light_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .border_dark_ai_edition:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            case .border_light_ai_edition:
                Rippple2IconEntryView(backgroundGradient: [.clear],
                                      foregroundGradient: [.white])
            }
        case .dark, .any:
            switch appIconIdentifier {
            case .original:
                if iconMode == .dark {
                    RipppleGlassDarkIconEntryView()
                } else {
                    RipppleGlassIconEntryView()
                }
            case .classic:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(hex: "b05df2"), Color(hex: "7f60f2")],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.3,
                                     insideRipppleShadowRadius: 0.001,
                                     secondRipppleShadowRadius: 0.001,
                                     outslideRipppleShadowRadius: 0.001)
            case .dark:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(hex: "b05df2"), Color(hex: "7f60f2")],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.7,
                                     outslideRipppleOpacity: 0.5)
            case .color:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(hex: "b05df2"), Color(hex: "7f60f2")],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(hex: "b05df2"), Color(hex: "7f60f2")])
                }
            case .pride:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white],
                                         insideRipppleOpacity: 1.0,
                                         secondRipppleOpacity: 0.7,
                                         outslideRipppleOpacity: 0.5,
                                         insideRipppleShadowRadius: 0.05,
                                         secondRipppleShadowRadius: 0.05,
                                         outslideRipppleShadowRadius: 0.05)
                } else {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                              Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white],
                                         overlayOpacity: 0.6,
                                         insideRipppleOpacity: 1.0,
                                         secondRipppleOpacity: 0.7,
                                         outslideRipppleOpacity: 0.5,
                                         insideRipppleShadowRadius: 0.05,
                                         secondRipppleShadowRadius: 0.05,
                                         outslideRipppleShadowRadius: 0.05)
                }
            case .lightMonochrome:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [.white],
                                         foregroundGradient: [.black],
                                         insideRipppleOpacity: 0.6,
                                         secondRipppleOpacity: 0.4,
                                         outslideRipppleOpacity: 0.2,
                                         insideRipppleShadowRadius: 0,
                                         secondRipppleShadowRadius: 0,
                                         outslideRipppleShadowRadius: 0)
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .darkGray)],
                                         insideRipppleOpacity: 0.6,
                                         secondRipppleOpacity: 0.4,
                                         outslideRipppleOpacity: 0.2,
                                         insideRipppleShadowRadius: 0,
                                         secondRipppleShadowRadius: 0,
                                         outslideRipppleShadowRadius: 0)
                }
            case .darkMonochrome:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [.white],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.4,
                                     outslideRipppleOpacity: 0.2)
            case .desktop:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [.white],
                                     insideRipppleGradient: [Color(hex: "e4d0f9"), Color(hex: "d7d0f9")],
                                     secondRipppleGradient: [Color(hex: "e4d0f9"), Color(hex: "d7d0f9")],
                                     outsideRipppleGradient: [Color(hex: "a561ea"), Color(hex: "7a61ea")],
                                     insideRipppleOpacity: 0.6,
                                     secondRipppleOpacity: 0.3,
                                     outslideRipppleOpacity: 0.9,
                                     insideRipppleShadowRadius: 0.001,
                                     secondRipppleShadowRadius: 0.001,
                                     outslideRipppleShadowRadius: 0.001)
            case .color_purple:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_red:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_orange:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_yellow:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_green:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_mint:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_teal:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_cyan:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_blue:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_indigo:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_pink:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .color_brown:
                if iconMode == .any {
                    RipppleIconEntryView(backgroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                         foregroundGradient: [.white])
                } else {
                    RipppleIconEntryView(backgroundGradient: [.clear],
                                         foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                         insideRipppleOpacity: 1,
                                         secondRipppleOpacity: 0.6,
                                         outslideRipppleOpacity: 0.5)
                }
            case .dark_purple:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_red:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_orange:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_yellow:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_green:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_mint:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_teal:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_cyan:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_blue:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_indigo:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_pink:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .dark_brown:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                     foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1,
                                     secondRipppleOpacity: 0.6,
                                     outslideRipppleOpacity: 0.5)
            case .light_purple:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_red:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_orange:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_yellow:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_green:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_mint:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_teal:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_cyan:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_blue:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_indigo:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_pink:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .light_brown:
                RipppleIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                     foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                     insideRipppleOpacity: 1.0,
                                     secondRipppleOpacity: 0.5,
                                     outslideRipppleOpacity: 0.35,
                                     insideRipppleShadowRadius: 0,
                                     secondRipppleShadowRadius: 0,
                                     outslideRipppleShadowRadius: 0)
            case .pride2:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .pride3:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .light_purple_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .color_purple_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))])
                }
            case .color_red_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))])
                }
            case .color_orange_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))])
                }
            case .color_yellow_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))])
                }
            case .color_green_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))])
                }
            case .color_mint_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))])
                }
            case .color_teal_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))])
                }
            case .color_cyan_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))])
                }
            case .color_blue_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))])
                }
            case .color_indigo_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))])
                }
            case .color_pink_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))])
                }
            case .color_brown_border:
                if iconMode == .any {
                    Rippple2IconEntryView(backgroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                          foregroundGradient: [.white])
                } else {
                    Rippple2IconEntryView(backgroundGradient: [.clear],
                                          foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))])
                }
            case .dark_purple_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))])
            case .dark_red_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))])
            case .dark_orange_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))])
            case .dark_yellow_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))])
            case .dark_green_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))])
            case .dark_mint_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))])
            case .dark_teal_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))])
            case .dark_cyan_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))])
            case .dark_blue_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))])
            case .dark_indigo_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))])
            case .dark_pink_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))])
            case .dark_brown_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))])
            case .light_red_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))])
            case .light_orange_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))])
            case .light_yellow_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))])
            case .light_green_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))])
            case .light_mint_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))])
            case .light_teal_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))])
            case .light_cyan_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))])
            case .light_blue_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))])
            case .light_indigo_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))])
            case .light_pink_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))])
            case .light_brown_border:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))])
            case .lightMonochrome2:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [iconMode == .any ? .black : Color(uiColor: .darkGray)])
            case .darkMonochrome2:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [.white])
            case .seven_color_purple:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_red:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_orange:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_yellow:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_green:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_mint:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_teal:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_cyan:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_blue:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_indigo:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_pink:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_color_brown:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                              foregroundGradient: [.white],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                              colors: [])
                }
            case .seven_dark_purple:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_red:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_orange:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_green:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_mint:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_teal:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_blue:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_pink:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_dark_brown:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_purple:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_red:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_orange:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_green:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_mint:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_teal:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_blue:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_pink:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_light_brown:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_monochrome_light:
                if iconMode == .any {
                    RipppleSevenIconEntryView(backgroundGradient: [.white],
                                              foregroundGradient: [.black],
                                              colors: [])
                } else {
                    RipppleSevenIconEntryView(backgroundGradient: [.clear],
                                              foregroundGradient: [Color(uiColor: .darkGray)],
                                              colors: [])
                }
            case .seven_monochrome_dark:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [.white],
                                          colors: [])
            case .seven_pride_light:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                          foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_pride_dark:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                          foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                               Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                          colors: [])
            case .seven_neon_purple:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_red:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_orange:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_yellow:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_green:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_mint:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemMint.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_teal:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemTeal.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_cyan:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemCyan.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_blue:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_indigo:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemIndigo.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_pink:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_brown:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemBrown.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_monochrome:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemGray.resolvedColor(with: UITraitCollection()))])
            case .seven_neon_pride:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear])
            case .seven_neon_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .init(white: 0.009) : .clear], colors: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                                                                                          Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                                                                                          Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                                                                                          Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                                                                                          Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                                                                                          Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))])
            case .seven_dark_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear], foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))], colors: [])
            case .seven_light_ai_edition:
                RipppleSevenIconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear], foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                                                                                         Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))], colors: [])
            case .border_dark_ai_edition:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .black : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            case .border_light_ai_edition:
                Rippple2IconEntryView(backgroundGradient: [iconMode == .any ? .white : .clear],
                                      foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                           Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                      insideRipppleShadowRadius: 0,
                                      secondRipppleShadowRadius: 0,
                                      outslideRipppleShadowRadius: 0)
            }
        }
    }
}

struct TIconGeneratorView: View {
    @State var tIconIdentifier: TIconIdentifier

    var body: some View {
        switch tIconIdentifier {
        case .purple:
            RipppleIconEntryView(backgroundGradient: [.clear],
                                 foregroundGradient: [Color(hex: "b05df2"), Color(hex: "7f60f2")],
                                 insideRipppleShadowRadius: 0,
                                 secondRipppleShadowRadius: 0,
                                 outslideRipppleShadowRadius: 0)
        case .white:
            RipppleIconEntryView(backgroundGradient: [.clear],
                                 foregroundGradient: [.white],
                                 insideRipppleShadowRadius: 0,
                                 secondRipppleShadowRadius: 0,
                                 outslideRipppleShadowRadius: 0)
        case .black:
            RipppleIconEntryView(backgroundGradient: [.clear],
                                 foregroundGradient: [.black],
                                 insideRipppleShadowRadius: 0,
                                 secondRipppleShadowRadius: 0,
                                 outslideRipppleShadowRadius: 0)
        case .rainbow:
            Rippple2IconEntryView(backgroundGradient: [.clear],
                                  foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                       Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))])
        case .rings_white:
            Rippple2IconEntryView(backgroundGradient: [.clear],
                                  foregroundGradient: [Color(uiColor: .white.resolvedColor(with: UITraitCollection()))])
        case .rings_black:
            Rippple2IconEntryView(backgroundGradient: [.clear],
                                  foregroundGradient: [Color(uiColor: .black.resolvedColor(with: UITraitCollection()))])
        case .rings_purple:
            Rippple2IconEntryView(backgroundGradient: [.clear],
                                  foregroundGradient: [Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection()))])
        }
    }
}

struct RipppleIconEntryView: View {
    var backgroundGradient: [Color] = [Color.white]
    var foregroundGradient: [Color] = [Color(hex: "b05df2"), Color(hex: "7f60f2")]

    var overlayOpacity: CGFloat = 0.0

    var insideRipppleGradient: [Color]?
    var secondRipppleGradient: [Color]?
    var outsideRipppleGradient: [Color]?

    var insideRipppleScale: CGFloat = 0.3
    var secondRipppleScale: CGFloat = 0.58
    var outslideRipppleScale: CGFloat = 0.85

    var insideRipppleOpacity: CGFloat = 1
    var secondRipppleOpacity: CGFloat = 0.5
    var outslideRipppleOpacity: CGFloat = 0.3

    var insideRipppleShadowRadius: CGFloat = 0.2
    var secondRipppleShadowRadius: CGFloat = 0.2
    var outslideRipppleShadowRadius: CGFloat = 0.2

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundGradient),
                               startPoint: backgroundGradient.count == 2 ? .topLeading : .top,
                               endPoint: backgroundGradient.count == 2 ? .bottomTrailing : .bottom).blur(radius: geometry.size.width * 0.05, opaque: true)
                    .overlay {
                        if overlayOpacity != 0.0 {
                            Rectangle()
                                .fill(.black.opacity(overlayOpacity))
                        }
                    }

                RoundedRectangle(cornerRadius: (geometry.size.width * outslideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: (outsideRipppleGradient != nil) ? .init(colors: outsideRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: foregroundGradient.count == 2 ? .topLeading : .top,
                        endPoint: foregroundGradient.count == 2 ? .bottomTrailing : .bottom
                    ))
                    .frame(maxWidth: geometry.size.width * outslideRipppleScale, maxHeight: geometry.size.height * outslideRipppleScale)
                    .shadow(color: outslideRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * outslideRipppleShadowRadius)
                    .opacity(outslideRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * secondRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: (secondRipppleGradient != nil) ? .init(colors: secondRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: foregroundGradient.count == 2 ? .topLeading : .top,
                        endPoint: foregroundGradient.count == 2 ? .bottomTrailing : .bottom
                    ))
                    .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                    .shadow(color: secondRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * secondRipppleShadowRadius)
                    .opacity(secondRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * insideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: (insideRipppleGradient != nil) ? .init(colors: insideRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: foregroundGradient.count == 2 ? .topLeading : .top,
                        endPoint: foregroundGradient.count == 2 ? .bottomTrailing : .bottom
                    ))
                    .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                    .shadow(color: insideRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * insideRipppleShadowRadius)
            }
        }
    }
}

struct RipppleGlassIconEntryView: View {
    var backgroundGradient: [Color] = [Color.purple, Color.red]
    var foregroundGradient: [Color] = [Color.white]

    var insideRipppleScale: CGFloat = 0.3
    var secondRipppleScale: CGFloat = 0.58
    var outslideRipppleScale: CGFloat = 0.85

    var insideRipppleOpacity: CGFloat = 1
    var secondRipppleOpacity: CGFloat = 0.5
    var outslideRipppleOpacity: CGFloat = 0.3

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundGradient),
                               startPoint: .topTrailing,
                               endPoint: .bottomLeading).blur(radius: geometry.size.width * 0.05, opaque: true)
                RoundedRectangle(cornerRadius: (geometry.size.width * outslideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * outslideRipppleScale, height: geometry.size.height * outslideRipppleScale)
                    .opacity(outslideRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * secondRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                    .opacity(secondRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * insideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                    .opacity(insideRipppleOpacity)
            }
        }
    }
}

struct RipppleGlassDarkIconEntryView: View {
    var backgroundGradient: [Color] = [Color(uiColor: .darkGray.darker())]
    var foregroundGradient: [Color] = [Color.purple, Color.red]

    var insideRipppleScale: CGFloat = 0.3
    var secondRipppleScale: CGFloat = 0.58
    var outslideRipppleScale: CGFloat = 0.85

    var insideRipppleOpacity: CGFloat = 1
    var secondRipppleOpacity: CGFloat = 0.5
    var outslideRipppleOpacity: CGFloat = 0.3

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundGradient),
                               startPoint: .topTrailing,
                               endPoint: .bottomLeading).blur(radius: geometry.size.width * 0.05, opaque: true)
                RoundedRectangle(cornerRadius: (geometry.size.width * outslideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * outslideRipppleScale, height: geometry.size.height * outslideRipppleScale)
                    .opacity(outslideRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * secondRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                    .opacity(secondRipppleOpacity)

                RoundedRectangle(cornerRadius: (geometry.size.width * insideRipppleScale) / 2)
                    .fill(LinearGradient(
                        gradient: .init(colors: foregroundGradient),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                    .opacity(insideRipppleOpacity)
            }
        }
    }
}

struct Rippple2IconEntryView: View {
    var backgroundGradient: [Color] = [Color.white]
    var foregroundGradient: [Color] = [Color(hex: "b05df2"), Color(hex: "7f60f2")]

    var insideRipppleGradient: [Color]?
    var secondRipppleGradient: [Color]?
    var outsideRipppleGradient: [Color]?

    var insideRipppleScale: CGFloat = 0.3
    var secondRipppleScale: CGFloat = 0.525
    var outslideRipppleScale: CGFloat = 0.75

    var insideRipppleOpacity: CGFloat = 1
    var secondRipppleOpacity: CGFloat = 1
    var outslideRipppleOpacity: CGFloat = 1

    var insideRipppleShadowRadius: CGFloat = 0.0
    var secondRipppleShadowRadius: CGFloat = 0.0
    var outslideRipppleShadowRadius: CGFloat = 0.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(gradient: Gradient(colors: backgroundGradient),
                               startPoint: backgroundGradient.count == 2 ? .topLeading : .top,
                               endPoint: backgroundGradient.count == 2 ? .bottomTrailing : .bottom).blur(radius: geometry.size.width * 0.05, opaque: true)

                Circle()
                    .stroke(LinearGradient(
                        gradient: (outsideRipppleGradient != nil) ? .init(colors: outsideRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: geometry.size.width * 5 / 100)
                    .frame(maxWidth: geometry.size.width * outslideRipppleScale, maxHeight: geometry.size.height * outslideRipppleScale)
                    .shadow(color: outslideRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * outslideRipppleShadowRadius)
                    .opacity(outslideRipppleOpacity)

                Circle()
                    .stroke(LinearGradient(
                        gradient: (secondRipppleGradient != nil) ? .init(colors: secondRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: geometry.size.width * 5 / 100)
                    .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                    .shadow(color: outslideRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * secondRipppleShadowRadius)
                    .opacity(secondRipppleOpacity)

                Circle()
                    .stroke(LinearGradient(
                        gradient: (insideRipppleGradient != nil) ? .init(colors: insideRipppleGradient!) : .init(colors: foregroundGradient),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ), lineWidth: geometry.size.width * 5 / 100)
                    .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                    .shadow(color: outslideRipppleShadowRadius != 0.0 ? Color(.sRGBLinear, white: 0, opacity: 0.33) : .clear,
                            radius: geometry.size.width * insideRipppleShadowRadius)
                    .opacity(insideRipppleOpacity)
            }
        }
    }
}

/*
 struct RipppleNeonIconEntryView: View {
     var backgroundGradient: [Color] = [Color.black]
     var foregroundGradient: [Color] = [Color.white]

     var insideRipppleScale: CGFloat = 0.3
     var secondRipppleScale: CGFloat = 0.525
     var outslideRipppleScale: CGFloat = 0.75

     var colors: [Color] = [.red, .yellow, .green, .blue, .purple, .red]

     var body: some View {
         GeometryReader { geometry in
             ZStack {
                 /* LinearGradient(gradient: Gradient(colors: backgroundGradient),
                                startPoint: .top,
                                endPoint: .bottom)
 */
                 Rectangle()
                     .fill(AngularGradient(gradient: Gradient(colors: [.red, .yellow, .green, .blue, .purple, .red]), center: .center))

                 Color.black.opacity(0.98)

                 Circle()
                     .stroke(LinearGradient(
                         gradient: .init(colors: foregroundGradient),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     ), lineWidth: geometry.size.width * 5/100)
                     .frame(maxWidth: geometry.size.width * outslideRipppleScale, maxHeight: geometry.size.height * outslideRipppleScale)
                     .multicolorGlow(colors: colors)

                 Circle()
                     .stroke(LinearGradient(
                         gradient: .init(colors: foregroundGradient),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     ), lineWidth: geometry.size.width * 5/100)
                     .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                     .multicolorGlow(colors: colors)

                 Circle()
                     .stroke(LinearGradient(
                         gradient: .init(colors: foregroundGradient),
                         startPoint: .topLeading,
                         endPoint: .bottomTrailing
                     ), lineWidth: geometry.size.width * 5/100)
                     .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                     .multicolorGlow(colors: colors)
             }
         }
     }
 }
 */

struct RipppleSevenIconEntryView: View {
    var backgroundGradient: [Color] = [.init(white: 0.009)]
    var foregroundGradient: [Color] = [.white]

    var insideRipppleScale: CGFloat = 0.3
    var secondRipppleScale: CGFloat = 0.575
    var outslideRipppleScale: CGFloat = 0.8

    var colors: [Color] = [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                           Color(uiColor: .systemYellow.resolvedColor(with: UITraitCollection())),
                           Color(uiColor: .systemGreen.resolvedColor(with: UITraitCollection())),
                           Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                           Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                           Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))]

    var body: some View {
        GeometryReader { geometry in
            if colors.isEmpty {
                ZStack {
                    backgroundGradient.first!

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ),
                        lineWidth: geometry.size.width * 2 / 100)
                        .frame(maxWidth: geometry.size.width * outslideRipppleScale, maxHeight: geometry.size.height * outslideRipppleScale)

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ), lineWidth: geometry.size.width * 4 / 100)
                        .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ), lineWidth: geometry.size.width * 8 / 100)
                        .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                }
            } else {
                ZStack {
                    backgroundGradient.first!

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ), lineWidth: geometry.size.width * 2 / 100)
                        .frame(maxWidth: geometry.size.width * outslideRipppleScale, maxHeight: geometry.size.height * outslideRipppleScale)
                        .multicolorGlow(colors: colors)

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ), lineWidth: geometry.size.width * 4 / 100)
                        .frame(width: geometry.size.width * secondRipppleScale, height: geometry.size.height * secondRipppleScale)
                        .multicolorGlow(colors: colors)

                    Circle()
                        .stroke(AngularGradient(
                            gradient: .init(colors: foregroundGradient),
                            center: .center
                        ), lineWidth: geometry.size.width * 8 / 100)
                        .frame(width: geometry.size.width * insideRipppleScale, height: geometry.size.height * insideRipppleScale)
                        .multicolorGlow(colors: colors)
                }
            }
        }
    }
}

private extension View {
    func multicolorGlow(colors: [Color]) -> some View {
        ZStack {
            ForEach(0..<3) { i in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(AngularGradient(gradient: Gradient(colors: colors), center: .center))
                        .mask(self.blur(radius: maskBlur(for: geometry.size.width)))
                        .overlay(self.blur(radius: overlayBlur(for: geometry.size.width, and: i)))
                }
            }
        }
    }

    private func maskBlur(for width: CGFloat) -> CGFloat {
        return CGFloat((width / 400) * 18)
    }

    private func overlayBlur(for width: CGFloat, and i: Int) -> CGFloat {
        let x = (width / 400) * 8
        return CGFloat(x - (CGFloat(i) * x))
    }
}

#Preview("red") {
    let adaptiveColumn = [
        GridItem(.adaptive(minimum: 100))
    ]
    let radius = 25.0
    let size = 100.0
    let shadow = 5.0

    return ScrollView {
        LazyVGrid(columns: adaptiveColumn, spacing: 10) {
            /*
                        Rippple2IconEntryView(backgroundGradient: [.white],
                                                    foregroundGradient: [Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection())),
                                                                         Color(uiColor: .systemOrange.resolvedColor(with: UITraitCollection())),
                                                                         Color(uiColor: .systemPink.resolvedColor(with: UITraitCollection())),
                                                                         Color(uiColor: .systemBlue.resolvedColor(with: UITraitCollection())),
                                                                         Color(uiColor: .systemPurple.resolvedColor(with: UITraitCollection())),
                                                                         Color(uiColor: .systemRed.resolvedColor(with: UITraitCollection()))],
                                                    insideRipppleShadowRadius: 0,
                                                    secondRipppleShadowRadius: 0,
                                                    outslideRipppleShadowRadius: 0)
                        .frame(width: size, height: size)
                        .cornerRadius(radius)
                        .shadow(radius: shadow)
             */
            /*
             ForEach(AppIconIdentifier.allCases, id: \.self) { item in
                 AppIconGeneratorView(appIconIdentifier: item)
                     .frame(width: size, height: size)
                     .cornerRadius(radius)
                     .shadow(radius: shadow)
             }
              */
            AppIconGeneratorView(iconMode: .any,
                                 appIconIdentifier: .original)
                .frame(width: size, height: size)
                .cornerRadius(radius)
                .shadow(radius: shadow)
        }.padding()
    }
}
