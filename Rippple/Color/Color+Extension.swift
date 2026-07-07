//
//  Color+Extension.swift
//  Rippple
//
//  Created by Kevin Cador on 24/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
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

struct RipppleTintTrait: UITraitDefinition {
    static let defaultValue = RipppleTintColor.original
    static let affectsColorAppearance = true
    static let name = "RipppleTint"
    static let identifier = "com.rippple"
}

extension UITraitCollection {
    var ripppleTintColor: RipppleTintColor {
        self[RipppleTintTrait.self]
    }
}

extension UIMutableTraits {
    var ripppleTintColor: RipppleTintColor {
        get { self[RipppleTintTrait.self] }
        set { self[RipppleTintTrait.self] = newValue }
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

    var isLight: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white > 0.7
    }
}
