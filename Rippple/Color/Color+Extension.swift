//
//  Color+Extension.swift
//  Rippple
//
//  Created by Kevin Cador on 24/11/2017.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

extension UIColor {
    enum Asset: String {
        case globalTint = "Global Tint"
        case shadow = "Shadow"
        case separator = "Card Separator"
        case safeGlobalTint
    }

    convenience init(asset: Asset) {
        switch asset {
        case .shadow, .separator:
            self.init(named: asset.rawValue)!
        case .globalTint:
            self.init { traitCollection in
                traitCollection.ripppleTintColor.color
            }
        case .safeGlobalTint:
            self.init { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    traitCollection.ripppleTintColor.safeColor
                } else {
                    traitCollection.ripppleTintColor.color
                }
            }
        }
    }
}

private enum RipppleBackgroundLevel {
    case view
    case card
    case insideCard

    func tintFraction(for traitCollection: UITraitCollection) -> CGFloat {
        let isHighContrast = traitCollection.accessibilityContrast == .high

        switch (traitCollection.userInterfaceStyle, self, isHighContrast) {
        case (.dark, .view, false):
            return 0.14
        case (.dark, .card, false):
            return 0.20
        case (.dark, .insideCard, false):
            return 0.27
        case (.dark, .view, true):
            return 0.08
        case (.dark, .card, true):
            return 0.18
        case (.dark, .insideCard, true):
            return 0.28
        case (_, .view, false):
            return 0.11
        case (_, .card, false):
            return 0.04
        case (_, .insideCard, false):
            return 0.08
        case (_, .view, true):
            return 0.13
        case (_, .card, true):
            return 0.01
        case (_, .insideCard, true):
            return 0.07
        }
    }
}

extension UIColor {
    static let ripppleTintContrastingLabel = UIColor { traitCollection in
        let tint = traitCollection.ripppleTintColor.color
        return tint.isLight(resolvedWith: traitCollection) ? .black : .white
    }

    static let ripppleViewBackground = ripppleBackground(level: .view,
                                                         fallback: { _ in .systemBackground })
    static let ripppleGroupedViewBackground = ripppleBackground(level: .view,
                                                                fallback: { _ in .systemGroupedBackground })
    static let ripppleCardBackground = ripppleBackground(level: .card,
                                                         fallback: { traitCollection in
                                                             traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .systemBackground
                                                         })
    static let ripppleGroupedCardBackground = ripppleBackground(level: .card,
                                                                fallback: { _ in .secondarySystemGroupedBackground })
    static let ripppleSystemCardBackground = ripppleBackground(level: .card,
                                                               fallback: { _ in .systemBackground })
    static let ripppleSecondaryBackground = ripppleBackground(level: .card,
                                                              fallback: { _ in .secondarySystemBackground })
    static let ripppleInsideCardBackground = ripppleBackground(level: .insideCard,
                                                               fallback: { traitCollection in
                                                                   traitCollection.userInterfaceStyle == .dark ? .tertiarySystemBackground : .systemBackground
                                                               })
    static let ripppleInsideGroupedCardBackground = ripppleBackground(level: .insideCard,
                                                                      fallback: { _ in .tertiarySystemGroupedBackground })
    static let ripppleTertiaryBackground = ripppleBackground(level: .insideCard,
                                                             fallback: { _ in .tertiarySystemBackground })
    static let ripppleCalloutBackground = UIColor { traitCollection in
        guard traitCollection.ripppleTintedAppearance else {
            return UIColor.systemGray.withAlphaComponent(0.1)
        }

        return UIColor.ripppleInsideCardBackground.resolvedColor(with: traitCollection)
    }

    private static func ripppleBackground(level: RipppleBackgroundLevel,
                                          fallback: @escaping (UITraitCollection) -> UIColor) -> UIColor {
        return UIColor { traitCollection in
            guard traitCollection.ripppleTintedAppearance else {
                return fallback(traitCollection).resolvedColor(with: traitCollection)
            }

            let tint = traitCollection.ripppleTintColor.color.resolvedColor(with: traitCollection)
            let base = traitCollection.userInterfaceStyle == .dark ? UIColor.black : UIColor.white
            return base.blended(with: tint,
                                fraction: level.tintFraction(for: traitCollection),
                                traitCollection: traitCollection)
        }
    }

    private func blended(with color: UIColor,
                         fraction: CGFloat,
                         traitCollection: UITraitCollection) -> UIColor {
        let base = resolvedColor(with: traitCollection)
        let color = color.resolvedColor(with: traitCollection)

        var baseRed: CGFloat = 0
        var baseGreen: CGFloat = 0
        var baseBlue: CGFloat = 0
        var baseAlpha: CGFloat = 0
        var colorRed: CGFloat = 0
        var colorGreen: CGFloat = 0
        var colorBlue: CGFloat = 0
        var colorAlpha: CGFloat = 0

        guard base.getRed(&baseRed,
                          green: &baseGreen,
                          blue: &baseBlue,
                          alpha: &baseAlpha),
            color.getRed(&colorRed,
                         green: &colorGreen,
                         blue: &colorBlue,
                         alpha: &colorAlpha) else {
            return base
        }

        return UIColor(red: baseRed + ((colorRed - baseRed) * fraction),
                       green: baseGreen + ((colorGreen - baseGreen) * fraction),
                       blue: baseBlue + ((colorBlue - baseBlue) * fraction),
                       alpha: baseAlpha + ((colorAlpha - baseAlpha) * fraction))
    }
}

public enum RipppleTintColor: Int, CaseIterable {
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
    case pink
    case brown
    case monochrome

    var name: String {
        return String(describing: self)
    }

    var color: UIColor {
        switch self {
        case .original:
            UIColor(named: "Global Tint")!
        case .red:
            UIColor.systemRed
        case .blue:
            UIColor.systemBlue
        case .cyan:
            UIColor.systemCyan
        case .mint:
            UIColor.systemMint
        case .pink:
            UIColor.systemPink
        case .teal:
            UIColor.systemTeal
        case .brown:
            UIColor.systemBrown
        case .green:
            UIColor.systemGreen
        case .indigo:
            UIColor.systemIndigo
        case .orange:
            UIColor.systemOrange
        case .yellow:
            UIColor.systemYellow.darker(amount: 0.09)
        case .monochrome:
            UIColor.label
        }
    }

    var safeColor: UIColor {
        switch self {
        case .original:
            UIColor(named: "Global Tint")!
        case .red:
            UIColor.systemRed
        case .blue:
            UIColor.systemBlue
        case .cyan:
            UIColor.systemCyan
        case .mint:
            UIColor.systemMint
        case .pink:
            UIColor.systemPink
        case .teal:
            UIColor.systemTeal
        case .brown:
            UIColor.systemBrown
        case .green:
            UIColor.systemGreen
        case .indigo:
            UIColor.systemIndigo
        case .orange:
            UIColor.systemOrange
        case .yellow:
            UIColor.systemYellow.darker(amount: 0.09)
        case .monochrome:
            UIColor.systemGray
        }
    }
}

enum RipppleAppearanceDefaults {
    static let suiteName = "group.tv.trakt.rippple"
    static let tintKey = "AppManager.currentTint"
    static let tintedAppearanceKey = "AppManager.tintedAppearance"
}

/// Catalyst modal contexts can start a separate trait hierarchy, so defaults must remain live after UIKit caches them.
final class RipppleTintTraitValue: NSObject {
    private let explicitTint: RipppleTintColor?

    fileprivate var tint: RipppleTintColor {
        if let explicitTint = explicitTint {
            return explicitTint
        }
        let rawValue = UserDefaults(suiteName: RipppleAppearanceDefaults.suiteName)!.integer(forKey: RipppleAppearanceDefaults.tintKey)
        return RipppleTintColor(rawValue: rawValue) ?? .original
    }

    fileprivate init(tint: RipppleTintColor? = nil) {
        explicitTint = tint
    }
}

struct RipppleTintTrait: UITraitDefinition {
    static let defaultValue = RipppleTintTraitValue()
    static let affectsColorAppearance = true
    static let name = "RipppleTint"
    static let identifier = "com.rippple"
}

final class RipppleTintedAppearanceTraitValue: NSObject {
    private let explicitIsEnabled: Bool?

    fileprivate var isEnabled: Bool {
        return explicitIsEnabled ?? UserDefaults.standard.bool(forKey: RipppleAppearanceDefaults.tintedAppearanceKey)
    }

    fileprivate init(isEnabled: Bool? = nil) {
        explicitIsEnabled = isEnabled
    }
}

struct RipppleTintedAppearanceTrait: UITraitDefinition {
    static let defaultValue = RipppleTintedAppearanceTraitValue()
    static let affectsColorAppearance = true
    static let name = "RipppleTintedAppearance"
    static let identifier = "com.rippple.tinted-appearance"
}

extension UITraitCollection {
    var ripppleTintColor: RipppleTintColor {
        self[RipppleTintTrait.self].tint
    }

    var ripppleTintedAppearance: Bool {
        self[RipppleTintedAppearanceTrait.self].isEnabled
    }
}

extension UIMutableTraits {
    var ripppleTintColor: RipppleTintColor {
        get { self[RipppleTintTrait.self].tint }
        set { self[RipppleTintTrait.self] = RipppleTintTraitValue(tint: newValue) }
    }

    var ripppleTintedAppearance: Bool {
        get { self[RipppleTintedAppearanceTrait.self].isEnabled }
        set { self[RipppleTintedAppearanceTrait.self] = RipppleTintedAppearanceTraitValue(isEnabled: newValue) }
    }
}

public extension UIColor {
    convenience init?(hex: String) {
        let r, g, b, a: CGFloat

        if hex.hasPrefix("#") {
            let start = hex.index(hex.startIndex, offsetBy: 1)
            let hexColor = String(hex[start...])

            if hexColor.count == 8 {
                let scanner = Scanner(string: hexColor)
                var hexNumber: UInt64 = 0

                if scanner.scanHexInt64(&hexNumber) {
                    r = CGFloat((hexNumber & 0xFF000000) >> 24) / 255
                    g = CGFloat((hexNumber & 0x00FF0000) >> 16) / 255
                    b = CGFloat((hexNumber & 0x0000FF00) >> 8) / 255
                    a = CGFloat(hexNumber & 0x000000FF) / 255

                    self.init(red: r, green: g, blue: b, alpha: a)
                    return
                }
            }
        }

        return nil
    }
}

extension UIColor {
    func lighter(amount: CGFloat = 0.25) -> UIColor {
        return hueColorWithBrightnessAmount(amount: 1 + amount)
    }

    func darker(amount: CGFloat = 0.25) -> UIColor {
        return hueColorWithBrightnessAmount(amount: 1 - amount)
    }

    private func hueColorWithBrightnessAmount(amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        if getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: hue,
                           saturation: saturation,
                           brightness: brightness * amount,
                           alpha: alpha)
        } else {
            return self
        }
    }

    private func isLight(resolvedWith traitCollection: UITraitCollection) -> Bool {
        let color = resolvedColor(with: traitCollection)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0

        guard color.getRed(&red, green: &green, blue: &blue, alpha: nil) else {
            return false
        }

        let perceivedBrightness = sqrt((0.299 * red * red)
            + (0.587 * green * green)
            + (0.114 * blue * blue))
        let lightColorThreshold: CGFloat = 0.6
        return perceivedBrightness > lightColorThreshold
    }
}
