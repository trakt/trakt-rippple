//
//  AppIconChooserView.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI
import UIKit

struct AppIconChooserView: View {
    private let glass = [AppIcon(name: "Liquid", identifier: .original)]
    private let original = [AppIcon(name: "Original", identifier: .classic),
                            AppIcon(name: "Original", identifier: .dark),
                            AppIcon(name: "Original", identifier: .color),
                            AppIcon(name: "Original", identifier: .pride),
                            AppIcon(name: "Original", identifier: .lightMonochrome),
                            AppIcon(name: "Original", identifier: .darkMonochrome),
                            AppIcon(name: "Original", identifier: .desktop)]
    private let palette = [AppIcon(name: "Edition", identifier: .border_dark_ai_edition),
                           AppIcon(name: "Edition", identifier: .border_light_ai_edition),
                           AppIcon(name: "Edition", identifier: .seven_dark_ai_edition),
                           AppIcon(name: "Edition", identifier: .seven_light_ai_edition),
                           AppIcon(name: "Edition", identifier: .seven_neon_ai_edition)]
    private let pride = [AppIcon(name: "Pride", identifier: .pride),
                         AppIcon(name: "Pride", identifier: .pride2),
                         AppIcon(name: "Pride", identifier: .pride3),
                         AppIcon(name: "Pride", identifier: .seven_pride_dark),
                         AppIcon(name: "Pride", identifier: .seven_pride_light),
                         AppIcon(name: "Pride", identifier: .seven_neon_pride)]
    private let monochrome = [AppIcon(name: "Monochrome", identifier: .lightMonochrome),
                              AppIcon(name: "Monochrome", identifier: .darkMonochrome),
                              AppIcon(name: "Monochrome", identifier: .lightMonochrome2),
                              AppIcon(name: "Monochrome", identifier: .darkMonochrome2),
                              AppIcon(name: "Monochrome", identifier: .seven_monochrome_light),
                              AppIcon(name: "Monochrome", identifier: .seven_monochrome_dark),
                              AppIcon(name: "Monochrome", identifier: .seven_neon_monochrome)]
    private let neon = [AppIcon(name: "Neon", identifier: .seven_neon_ai_edition),
                        AppIcon(name: "Neon", identifier: .seven_neon_pride),
                        AppIcon(name: "Neon", identifier: .seven_neon_monochrome),
                        AppIcon(name: "Neon", identifier: .seven_neon_purple),
                        AppIcon(name: "Neon", identifier: .seven_neon_red),
                        AppIcon(name: "Neon", identifier: .seven_neon_orange),
                        AppIcon(name: "Neon", identifier: .seven_neon_yellow),
                        AppIcon(name: "Neon", identifier: .seven_neon_green),
                        AppIcon(name: "Neon", identifier: .seven_neon_mint),
                        AppIcon(name: "Neon", identifier: .seven_neon_teal),
                        AppIcon(name: "Neon", identifier: .seven_neon_cyan),
                        AppIcon(name: "Neon", identifier: .seven_neon_blue),
                        AppIcon(name: "Neon", identifier: .seven_neon_indigo),
                        AppIcon(name: "Neon", identifier: .seven_neon_pink),
                        AppIcon(name: "Neon", identifier: .seven_neon_brown)]
    private let light1 = [AppIcon(name: "Light", identifier: .light_purple),
                          AppIcon(name: "Light", identifier: .light_red),
                          AppIcon(name: "Light", identifier: .light_orange),
                          AppIcon(name: "Light", identifier: .light_yellow),
                          AppIcon(name: "Light", identifier: .light_green),
                          AppIcon(name: "Light", identifier: .light_mint),
                          AppIcon(name: "Light", identifier: .light_teal),
                          AppIcon(name: "Light", identifier: .light_cyan),
                          AppIcon(name: "Light", identifier: .light_blue),
                          AppIcon(name: "Light", identifier: .light_indigo),
                          AppIcon(name: "Light", identifier: .light_pink),
                          AppIcon(name: "Light", identifier: .light_brown)]
    private let light2 = [AppIcon(name: "Light", identifier: .light_purple_border),
                          AppIcon(name: "Light", identifier: .light_red_border),
                          AppIcon(name: "Light", identifier: .light_orange_border),
                          AppIcon(name: "Light", identifier: .light_yellow_border),
                          AppIcon(name: "Light", identifier: .light_green_border),
                          AppIcon(name: "Light", identifier: .light_mint_border),
                          AppIcon(name: "Light", identifier: .light_teal_border),
                          AppIcon(name: "Light", identifier: .light_cyan_border),
                          AppIcon(name: "Light", identifier: .light_blue_border),
                          AppIcon(name: "Light", identifier: .light_indigo_border),
                          AppIcon(name: "Light", identifier: .light_pink_border),
                          AppIcon(name: "Light", identifier: .light_brown_border)]
    private let light3 = [AppIcon(name: "Light", identifier: .seven_light_purple),
                          AppIcon(name: "Light", identifier: .seven_light_red),
                          AppIcon(name: "Light", identifier: .seven_light_orange),
                          AppIcon(name: "Light", identifier: .seven_light_yellow),
                          AppIcon(name: "Light", identifier: .seven_light_green),
                          AppIcon(name: "Light", identifier: .seven_light_mint),
                          AppIcon(name: "Light", identifier: .seven_light_teal),
                          AppIcon(name: "Light", identifier: .seven_light_cyan),
                          AppIcon(name: "Light", identifier: .seven_light_blue),
                          AppIcon(name: "Light", identifier: .seven_light_indigo),
                          AppIcon(name: "Light", identifier: .seven_light_pink),
                          AppIcon(name: "Light", identifier: .seven_light_brown)]

    private let dark1 = [AppIcon(name: "Dark", identifier: .dark_purple),
                         AppIcon(name: "Dark", identifier: .dark_red),
                         AppIcon(name: "Dark", identifier: .dark_orange),
                         AppIcon(name: "Dark", identifier: .dark_yellow),
                         AppIcon(name: "Dark", identifier: .dark_green),
                         AppIcon(name: "Dark", identifier: .dark_mint),
                         AppIcon(name: "Dark", identifier: .dark_teal),
                         AppIcon(name: "Dark", identifier: .dark_cyan),
                         AppIcon(name: "Dark", identifier: .dark_blue),
                         AppIcon(name: "Dark", identifier: .dark_indigo),
                         AppIcon(name: "Dark", identifier: .dark_pink),
                         AppIcon(name: "Dark", identifier: .dark_brown)]
    private let dark2 = [AppIcon(name: "Dark", identifier: .dark_purple_border),
                         AppIcon(name: "Dark", identifier: .dark_red_border),
                         AppIcon(name: "Dark", identifier: .dark_orange_border),
                         AppIcon(name: "Dark", identifier: .dark_yellow_border),
                         AppIcon(name: "Dark", identifier: .dark_green_border),
                         AppIcon(name: "Dark", identifier: .dark_mint_border),
                         AppIcon(name: "Dark", identifier: .dark_teal_border),
                         AppIcon(name: "Dark", identifier: .dark_cyan_border),
                         AppIcon(name: "Dark", identifier: .dark_blue_border),
                         AppIcon(name: "Dark", identifier: .dark_indigo_border),
                         AppIcon(name: "Dark", identifier: .dark_pink_border),
                         AppIcon(name: "Dark", identifier: .dark_brown_border)]
    private let dark3 = [AppIcon(name: "Dark", identifier: .seven_dark_purple),
                         AppIcon(name: "Dark", identifier: .seven_dark_red),
                         AppIcon(name: "Dark", identifier: .seven_dark_orange),
                         AppIcon(name: "Dark", identifier: .seven_dark_yellow),
                         AppIcon(name: "Dark", identifier: .seven_dark_green),
                         AppIcon(name: "Dark", identifier: .seven_dark_mint),
                         AppIcon(name: "Dark", identifier: .seven_dark_teal),
                         AppIcon(name: "Dark", identifier: .seven_dark_cyan),
                         AppIcon(name: "Dark", identifier: .seven_dark_blue),
                         AppIcon(name: "Dark", identifier: .seven_dark_indigo),
                         AppIcon(name: "Dark", identifier: .seven_dark_pink),
                         AppIcon(name: "Dark", identifier: .seven_dark_brown)]

    private let color1 = [AppIcon(name: "Color", identifier: .color_purple),
                          AppIcon(name: "Color", identifier: .color_red),
                          AppIcon(name: "Color", identifier: .color_orange),
                          AppIcon(name: "Color", identifier: .color_yellow),
                          AppIcon(name: "Color", identifier: .color_green),
                          AppIcon(name: "Color", identifier: .color_mint),
                          AppIcon(name: "Color", identifier: .color_teal),
                          AppIcon(name: "Color", identifier: .color_cyan),
                          AppIcon(name: "Color", identifier: .color_blue),
                          AppIcon(name: "Color", identifier: .color_indigo),
                          AppIcon(name: "Color", identifier: .color_pink),
                          AppIcon(name: "Color", identifier: .color_brown)]
    private let color2 = [AppIcon(name: "Color", identifier: .color_purple_border),
                          AppIcon(name: "Color", identifier: .color_red_border),
                          AppIcon(name: "Color", identifier: .color_orange_border),
                          AppIcon(name: "Color", identifier: .color_yellow_border),
                          AppIcon(name: "Color", identifier: .color_green_border),
                          AppIcon(name: "Color", identifier: .color_mint_border),
                          AppIcon(name: "Color", identifier: .color_teal_border),
                          AppIcon(name: "Color", identifier: .color_cyan_border),
                          AppIcon(name: "Color", identifier: .color_blue_border),
                          AppIcon(name: "Color", identifier: .color_indigo_border),
                          AppIcon(name: "Color", identifier: .color_pink_border),
                          AppIcon(name: "Color", identifier: .color_brown_border)]
    private let color3 = [AppIcon(name: "Color", identifier: .seven_color_purple),
                          AppIcon(name: "Color", identifier: .seven_color_red),
                          AppIcon(name: "Color", identifier: .seven_color_orange),
                          AppIcon(name: "Color", identifier: .seven_color_yellow),
                          AppIcon(name: "Color", identifier: .seven_color_green),
                          AppIcon(name: "Color", identifier: .seven_color_mint),
                          AppIcon(name: "Color", identifier: .seven_color_teal),
                          AppIcon(name: "Color", identifier: .seven_color_cyan),
                          AppIcon(name: "Color", identifier: .seven_color_blue),
                          AppIcon(name: "Color", identifier: .seven_color_indigo),
                          AppIcon(name: "Color", identifier: .seven_color_pink),
                          AppIcon(name: "Color", identifier: .seven_color_brown)]
    #if !targetEnvironment(macCatalyst)
    @State private var alternateIconName = UIApplication.shared.alternateIconName
    #else
    @State private var alternateIconName = UserDefaults(suiteName: "group.tv.trakt.rippple")!.string(forKey: "WidgetManager.appIcon")
    #endif

    struct AppIconSection: Identifiable {
        var id: String {
            return name
        }

        let name: String
        let rows: [AppIconRow]
    }

    struct AppIconRow: Identifiable {
        var id: String {
            return row.first!.identifier.rawValue
        }

        let row: [AppIcon]
    }

    private var sections: [AppIconSection] {
        return [AppIconSection(name: "Latest", rows: [AppIconRow(row: glass)]),
                AppIconSection(name: "Original", rows: [AppIconRow(row: original)]),
                AppIconSection(name: "Palette", rows: [AppIconRow(row: palette)]),
                AppIconSection(name: "Pride", rows: [AppIconRow(row: pride)]),
                AppIconSection(name: "Monochrome", rows: [AppIconRow(row: monochrome)]),
                AppIconSection(name: "Neon", rows: [AppIconRow(row: neon)]),
                AppIconSection(name: "Light Background", rows: [AppIconRow(row: light1), AppIconRow(row: light2), AppIconRow(row: light3)]),
                AppIconSection(name: "Dark Background", rows: [AppIconRow(row: dark1), AppIconRow(row: dark2), AppIconRow(row: dark3)]),
                AppIconSection(name: "Color Background", rows: [AppIconRow(row: color1), AppIconRow(row: color2), AppIconRow(row: color3)])]
    }

    @State private var margin = 0.0

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading) {
                    ForEach(sections) { section in
                        Text(section.name)
                            .font(.headline)
                            .padding(.top)
                        ScrollView(.horizontal) {
                            ForEach(section.rows) { row in
                                LazyHStack {
                                    ForEach(row.row) { item in
                                        AppIconGeneratorView(appIconIdentifier: item.identifier)
                                            .frame(width: 100, height: 100)
                                            .clipShape(.rect(cornerRadius: 25, style: .continuous))
                                            .overlay {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                        .stroke(.gray.opacity(0.5),
                                                                lineWidth: 0.5)
                                                    if alternateIconName == item.alternateIconName {
                                                        RoundedRectangle(cornerRadius: 27, style: .continuous)
                                                            .stroke(Color(uiColor: UIColor(asset: .globalTint)),
                                                                    lineWidth: 2)
                                                            .padding(-2)
                                                    }
                                                }
                                            }
                                            .contentShape(.contextMenuPreview, .rect(cornerRadius: 25, style: .continuous))
                                            .onTapGesture {
                                                tap(appIcon: item)
                                            }.contextMenu {
                                                Button("Set Icon") {
                                                    tap(appIcon: item)
                                                }
                                            } preview: {
                                                AppIconChooserPreview(appIcon: item)
                                            }
                                    }
                                }
                            }
                        }.scrollClipDisabled()
                            .scrollIndicators(.hidden)
                    }
                }.padding()
            }.contentMargins(.bottom, margin)
            #if !targetEnvironment(macCatalyst)
            if #available(iOS 18.0, *) {
                AppIconChooserPreview(appIcon: AppIcon(name: "Preview",
                                                       identifier: AppIconIdentifier(rawValue: alternateIconName ?? "original") ?? .original))
                    .background(.regularMaterial)
                    .clipShape(.rect(cornerRadius: 35, style: .continuous))
                    .id(alternateIconName)
                    .onAppear {
                        margin = 170
                    }
                    .padding(.bottom)
            }
            #endif
        }
    }

    private func tap(appIcon: AppIcon) {
        WidgetManager.shared.storeAppIconForWidget(appIcon: appIcon)

        #if targetEnvironment(macCatalyst)

        let alertController = UIAlertController(title: "Not Supported (yet)",
                                                message: "Unfortunately, setting a custom icon on the Mac is not supported yet. As soon as it will be possible, Rippple will support the same icons on iPhone, iPad and on the Mac. In the meantime, you can add the \"Splash\" Widget on your Mac and use this menu to configure it.",
                                                preferredStyle: .alert)

        let cancel = UIAlertAction(title: "Okay", style: .cancel)
        alertController.addAction(cancel)

        AppManager.shared.present(viewController: alertController, animated: true)

        alternateIconName = appIcon.alternateIconName

        #else

        for tint in RipppleTintColor.allCases {
            if let alternateIconName = appIcon.alternateIconName, alternateIconName.localizedCaseInsensitiveContains(tint.name) {
                if UIApplication.shared.currentTint == tint {
                    setAppIcon(alternateIconName: appIcon.alternateIconName)
                } else {
                    let alert = UIAlertController(title: "App Tint Color",
                                                  message: "Do you want to set the icon only? Or set the icon and apply the same tint color for the app?",
                                                  preferredStyle: .alert)

                    let iconAction = UIAlertAction(title: "Set Icon Only", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                    }
                    alert.addAction(iconAction)

                    let iconAndTintAction = UIAlertAction(title: "Set Icon and Tint", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                        UIApplication.shared.setTintColor(tint: tint)
                    }
                    alert.addAction(iconAndTintAction)

                    AppManager.shared.present(viewController: alert, animated: true)
                }

                return
            } else if appIcon.identifier == .original || appIcon.identifier == .color || appIcon.identifier == .dark || appIcon.identifier == .desktop || appIcon.identifier == .dark_purple || appIcon.identifier == .color_purple || appIcon.identifier == .light_purple || appIcon.identifier == .seven_dark_purple || appIcon.identifier == .seven_neon_purple || appIcon.identifier == .dark_purple_border || appIcon.identifier == .seven_color_purple || appIcon.identifier == .seven_light_purple || appIcon.identifier == .color_purple_border || appIcon.identifier == .light_purple_border {
                if UIApplication.shared.currentTint == .original {
                    setAppIcon(alternateIconName: appIcon.alternateIconName)
                } else {
                    let alert = UIAlertController(title: "App Tint Color",
                                                  message: "Do you want to set the icon only? Or set the icon and apply the same tint color for the app?",
                                                  preferredStyle: .alert)

                    let iconAction = UIAlertAction(title: "Set Icon Only", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                    }
                    alert.addAction(iconAction)

                    let iconAndTintAction = UIAlertAction(title: "Set Icon and Tint", style: .default) { _ in
                        self.setAppIcon(alternateIconName: appIcon.alternateIconName)
                        UIApplication.shared.setTintColor(tint: .original)
                    }
                    alert.addAction(iconAndTintAction)

                    AppManager.shared.present(viewController: alert, animated: true)
                }

                return
            }
        }

        setAppIcon(alternateIconName: appIcon.alternateIconName)

        #endif
    }

    private func setAppIcon(alternateIconName: String?) {
        UIApplication.shared.setAlternateIconName(alternateIconName) { error in
            if let error = error {
                let alert = UIAlertController(title: "Error setting the Icon",
                                              message: "\(error.localizedDescription)\n\nHint: restarting your device can sometimes help.",
                                              preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Okay", style: .cancel)
                alert.addAction(cancel)
                AppManager.shared.present(viewController: alert, animated: true)
            } else {
                self.alternateIconName = alternateIconName
            }
        }
    }
}

struct AppIconChooserPreview: View {
    @State var appIcon: AppIcon
    @State private var startAnimation: Bool = false

    @State private var tintColor = [Color.red, .green, .blue, .purple, .pink, .orange, .yellow, .brown, .indigo, .cyan, .mint, .teal].randomElement() ?? .purple

    var body: some View {
        VStack {
            Text("Preview")
                .font(.headline)
            HStack {
                VStack {
                    AppIconGeneratorView(iconMode: .any, appIconIdentifier: appIcon.identifier)
                        .frame(width: 80, height: 80)
                        .clipShape(.rect(cornerRadius: 25, style: .continuous))
                        .overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(.gray.opacity(0.5),
                                            lineWidth: 0.5)
                            }
                        }
                    Text("Light")
                        .font(.caption)
                }.padding([.leading, .trailing])
                VStack {
                    AppIconGeneratorView(iconMode: .dark, appIconIdentifier: appIcon.identifier)
                        .frame(width: 80, height: 80)
                        .background(LinearGradient(colors: [Color(uiColor: .darkGray.darker(amount: 0.4)),
                                                            Color(uiColor: .darkGray.darker(amount: 0.6))],
                                                   startPoint: .top,
                                                   endPoint: .bottom))
                        .clipShape(.rect(cornerRadius: 25, style: .continuous))
                        .overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(.gray.opacity(0.5),
                                            lineWidth: 0.5)
                            }
                        }
                    Text("Dark")
                        .font(.caption)
                }.padding([.leading, .trailing])
                VStack {
                    AppIconGeneratorView(iconMode: .tinted, appIconIdentifier: appIcon.identifier)
                        .frame(width: 80, height: 80)
                        .colorMultiply(tintColor)
                        .background(LinearGradient(colors: [Color(uiColor: .darkGray.darker(amount: 0.4)),
                                                            Color(uiColor: .darkGray.darker(amount: 0.6))],
                                                   startPoint: .top,
                                                   endPoint: .bottom))
                        .clipShape(.rect(cornerRadius: 25, style: .continuous))
                        .overlay {
                            ZStack {
                                RoundedRectangle(cornerRadius: 25, style: .continuous)
                                    .stroke(.gray.opacity(0.5),
                                            lineWidth: 0.5)
                            }
                        }
                    Text("Tinted")
                        .font(.caption)
                }.padding([.leading, .trailing])
            }
        }.padding()
            .onAppear {
                withAnimation(.linear(duration: 2.0).repeatForever()) {
                    tintColor = [Color.red, .green, .blue, .purple, .pink, .orange, .yellow, .brown, .indigo, .cyan, .mint, .teal].randomElement() ?? .purple
                }
            }
    }
}

#Preview {
    AppIconChooserView()
}
