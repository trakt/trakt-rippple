//
//  AutomationSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 13/03/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import SwiftUI

struct AutomationSettingsView: View {
    @AppStorage("GeneralSettings.watchlistaddback") private var watchlistAddBack = false
    @AppStorage("GeneralSettings.addtowatchlistautolistsync") private var addToWatchlistAutoListSync = false
    @AppStorage("GeneralSettings.addtowatchlistautowatchedsync") private var addToWatchlistAutoWatchedSync = false
    @AppStorage("GeneralSettings.removeepisodeautowatchedsync") private var removeEpisodeAutoWatchedSync = false
    @AppStorage("GeneralSettings.removeshowtowatchfromlist") private var removeShowToWatchFromList = false
    @AppStorage("GeneralSettings.removemovietowatchfromlist") private var removeMovieToWatchFromList = false

    private var hasTraktVIP: Bool {
        PurchaseManager.shared.purchased
    }

    private var hasEpisodeToWatchCustomLists: Bool {
        EpisodeToWatchSettings.shared.lists.isEmpty == false
    }

    private var hasMovieToWatchCustomLists: Bool {
        MovieToWatchSettings.shared.lists.isEmpty == false
    }

    var body: some View {
        SwiftUI.List {
            aboutSection

            automationSection(title: "Keep in Watchlist", isOn: $watchlistAddBack) {
                automationRow(.trigger, "When you **watch** an episode of a show that is in your Watchlist...")
                automationRow(.action, "Automatically **add** the show back to your Watchlist.")
                automationRow(.note, "Trakt removes a show from your Watchlist as soon as you start watching it. This brings it back automatically.")
            }

            automationSection(title: "Remove Listed TV Shows", isOn: $removeShowToWatchFromList) {
                if hasTraktVIP == false {
                    automationRow(.warning, "Customizing To Watch requires Trakt VIP. Without it, this automation may not have any lists to update.")
                }
                if hasEpisodeToWatchCustomLists == false {
                    automationRow(.warning, "Enable at least one personal Custom List in Episodes To Watch settings so this automation knows which lists to update.")
                }
                automationRow(.trigger, "When you **watch** an episode of a show...")
                automationRow(.action, "Automatically **remove** the show from the Custom Lists used to build your To Watch.")
                automationRow(.note, "Use this to turn your To Watch Custom Lists into self-cleaning watchlists. Only your personal Custom Lists are updated; Watchlist, Collection, Recommendations, Liked Lists, Collaborations and Smart Searches are left unchanged.")
            }

            automationSection(title: "Remove Listed Movies", isOn: $removeMovieToWatchFromList) {
                if hasTraktVIP == false {
                    automationRow(.warning, "Customizing To Watch requires Trakt VIP. Without it, this automation may not have any lists to update.")
                }
                if hasMovieToWatchCustomLists == false {
                    automationRow(.warning, "Enable at least one personal Custom List in Movies To Watch settings so this automation knows which lists to update.")
                }
                automationRow(.trigger, "When you **watch** a movie...")
                automationRow(.action, "Automatically **remove** the movie from the Custom Lists used to build your To Watch.")
                automationRow(.note, "Use this to turn your To Watch Custom Lists into self-cleaning watchlists. Only your personal Custom Lists are updated; Watchlist, Collection, Recommendations, Liked Lists, Collaborations and Smart Searches are left unchanged.")
            }

            automationSection(title: "Remove Listed Episode", isOn: $removeEpisodeAutoWatchedSync) {
                automationRow(.trigger, "When you **watch** an episode of a show...")
                automationRow(.action, "Automatically **remove** that episode from any of your Custom Lists.")
                automationRow(.warning, "This automation checks every list to find matching episodes, so it can take a while. Use it only if you manage episode-based lists yourself.")
            }

            automationSection(title: "List → Watchlist", isOn: $addToWatchlistAutoListSync) {
                automationRow(.trigger, "When you **add** a show to any Custom List...")
                automationRow(.action, "Automatically **add** the show to your Watchlist too.")
                automationRow(.note, "Use this to keep your Watchlist filled while still organizing shows with Custom Lists.")
            }

            automationSection(title: "Watch → Watchlist", isOn: $addToWatchlistAutoWatchedSync) {
                automationRow(.trigger, "When you **watch** an episode of a show...")
                automationRow(.action, "Automatically **add** the show to your Watchlist.")
                automationRow(.note, "Use this if you want your Watchlist to also act as your Currently Watching list.")
            }
        }.listSectionSpacing(.compact)
    }

    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(Image(systemName: "bubbles.and.sparkles")) About Automations")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Automations run an **Action** for you after a **Trigger** happens. They only run when you perform the trigger action from Rippple.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }.padding(.vertical, 2)
        }.listRowInsets(rowInsets)
    }

    private func automationSection<Content: View>(title: String,
                                                  isOn: Binding<Bool>,
                                                  @ViewBuilder content: () -> Content) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: isOn) {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                }.tint(Color(UIColor(asset: .globalTint)))
                    .toggleStyle(.switch)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 8)

                content()
            }.padding(.vertical, 8)
        }.listRowInsets(rowInsets)
    }

    private func automationRow(_ kind: AutomationRowKind, _ message: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(Image(systemName: kind.systemImage)) \(kind.title)")
                .foregroundStyle(kind.color)
                .font(.callout.lowercaseSmallCaps().bold())
            Text(message)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(10)
            .background(.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    }
}

private enum AutomationRowKind {
    case trigger
    case action
    case note
    case warning

    var title: String {
        switch self {
        case .trigger:
            return "Trigger"
        case .action:
            return "Action"
        case .note:
            return "Notes"
        case .warning:
            return "Warning"
        }
    }

    var systemImage: String {
        switch self {
        case .trigger:
            return "bolt"
        case .action:
            return "sparkles"
        case .note:
            return "note"
        case .warning:
            return "exclamationmark.triangle"
        }
    }

    var color: Color {
        switch self {
        case .trigger:
            return .green
        case .action:
            return .blue
        case .note:
            return Color(UIColor.systemYellow.darker(amount: 0.15))
        case .warning:
            return .red
        }
    }
}

#Preview {
    AutomationSettingsView()
}
