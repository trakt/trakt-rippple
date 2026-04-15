//
//  BadgeAppIconViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/05/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import SwiftUI
import UIKit
import UserNotifications
import Receiver

let (badgeModeTransmitter, badgeModeReceiver) = Receiver<Int>.make(with: .hot)

// SwiftUI view that mirrors the original table content and behavior
struct BadgeAppIconView: View {
    @State private var footerText: String = ""
    @State private var selectedMode: Int = UserDefaults.standard.integer(forKey: "Badge.mode")

    private let disposeBag = DisposeBag()

    private struct BadgeOption: Identifiable, Hashable {
        var id: Int { identifier }

        let identifier: Int
        let string: String
    }

    @State private var noOption: [BadgeOption] = [
        BadgeOption(identifier: 0, string: "No Badge")
    ]

    @State private var allOptions: [BadgeOption] = [
        BadgeOption(identifier: 1, string: "Movies To Watch"),
        BadgeOption(identifier: 2, string: "Shows To Watch"),
        BadgeOption(identifier: 3, string: "Episodes To Watch")
    ]

    @State private var pinnedOptions: [BadgeOption] = [
        BadgeOption(identifier: 4, string: "Movies To Watch"),
        BadgeOption(identifier: 5, string: "Shows To Watch"),
        BadgeOption(identifier: 6, string: "Episodes To Watch")
    ]

    var body: some View {
        SwiftUI.List {
            Section(footer: Text(footerText)) {
                ForEach($noOption) { option in
                    Button {
                        handleSelection(option.wrappedValue.identifier)
                    } label: {
                        HStack {
                            Text(option.wrappedValue.string)
                            Spacer()
                            if selectedMode == option.wrappedValue.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(UIColor(asset: .globalTint)))
                            }
                        }
                    }.foregroundColor(.primary)
                }
            }
            Section(header: Text("All Items Count")) {
                ForEach($allOptions) { option in
                    Button {
                        handleSelection(option.wrappedValue.identifier)
                    } label: {
                        HStack {
                            Text(option.wrappedValue.string)
                            Spacer()
                            if selectedMode == option.wrappedValue.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(UIColor(asset: .globalTint)))
                            }
                        }
                    }.foregroundColor(.primary)
                }
            }
            Section(header: Text("Pinned Items Count")) {
                ForEach($pinnedOptions) { option in
                    Button {
                        handleSelection(option.wrappedValue.identifier)
                    } label: {
                        HStack {
                            Text(option.wrappedValue.string)
                            Spacer()
                            if selectedMode == option.wrappedValue.identifier {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(UIColor(asset: .globalTint)))
                            }
                        }
                    }.foregroundColor(.primary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Badge Count")
        .onAppear {
            checkBadgeAccess()

            applicationLifecycleReceiver.listen { lifecycle in
                switch lifecycle {
                case .didFinishLaunching:
                    break
                case .didBecomeActive:
                    checkBadgeAccess()
                case .didEnterBackground:
                    break
                }
            }.disposed(by: disposeBag)
        }
    }

    private func handleSelection(_ index: Int) {
        selectedMode = index
        UserDefaults.standard.setValue(index, forKey: "Badge.mode")
        UserDefaults.standard.synchronize()
        badgeModeTransmitter.broadcast(index)
    }

    private func checkBadgeAccess() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            var text: String
            switch settings.badgeSetting {
            case .notSupported:
                text = "App Icon Badge isn't supported."
            case .disabled:
                text = "⚠️ You need to enable Badges in your device's Settings>Rippple>Notifications."
            case .enabled:
                text = ""
            @unknown default:
                text = ""
            }
            DispatchQueue.main.async {
                self.footerText = text
            }
        }
    }
}

// Hosting controller to preserve the original type name and integration points
final class BadgeAppIconViewController: UIHostingController<BadgeAppIconView> {
    init() {
        super.init(rootView: BadgeAppIconView())
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: BadgeAppIconView())
    }
}

#if DEBUG
#Preview("Badge App Icon") {
    BadgeAppIconView()
}
#endif
