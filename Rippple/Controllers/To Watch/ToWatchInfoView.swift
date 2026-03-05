//
//  ToWatchInfoView.swift
//  Rippple
//
//  Created by Kevin Cador on 01/17/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import SwiftUI

private struct ToWatchInfoView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let whatItDoes: String
    let howItWorks: String
    let waitMore: String

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                Section {
                    Text(whatItDoes)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("What it does")
                }

                Section {
                    Text(howItWorks)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("How it works")
                }

                Section {
                    Text(waitMore)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Text("Wait, there's more")
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .navigationTitle(title)
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MovieToWatchInfoView: View {
    var body: some View {
        ToWatchInfoView(title: "Movies To Watch",
                        whatItDoes: "Builds a personalized list of Movies to watch by combining movies from your Watchlist, Favorites, Collection or Custom Lists. Filters out movies you've already watched and sorts them by your preferences.",
                        howItWorks: "Choose which sources to include, pick a sorting method (release date, rating, random, etc.), and optionally group by source or merge into one big list. The list updates automatically as you watch movies or change your Trakt lists.",
                        waitMore: "Pin a movie to keep it at the top of your To Watch list. The \"\(UpcomingLabelManager.shared.label)\" section gives you an optional quick peek at your Calendar, so you can see what’s coming soon.")
    }
}

struct EpisodeToWatchInfoView: View {
    var body: some View {
        ToWatchInfoView(title: "Episodes To Watch",
                        whatItDoes: "Shows the next unwatched Episodes for each Show you're following. It pulls shows from your Watched list, Watchlist, Favorites, Collection or Custom Lists, then finds the next episode to watch for each.",
                        howItWorks: "Select which sources to include, choose how to sort (automatic prioritizes recently aired and shows you're binging, or pick by last watched, episode count, etc.), and optionally group by source or merge into one list. The list updates as you watch episodes and automatically tracks upcoming releases.",
                        waitMore: "Pin a show to keep it at the top of your To Watch list. The \"\(UpcomingLabelManager.shared.label)\" section gives you an optional quick peek at your Calendar, so you can see what’s coming soon.")
    }
}

#Preview {
    MovieToWatchInfoView()
}
