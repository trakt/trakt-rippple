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

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        SwiftUI.List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Image(systemName: "bubbles.and.sparkles")) About Automations")
                        .font(.headline)
                    Text("Automations are little helpers that can automatically do an **Action** for you, based on a **Trigger**. They only work if you do the Trigger action from Rippple.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $watchlistAddBack) {
                        Text("Keep in Watchlist")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **watch** a single episode of a TV Show that is in your Watchlist...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **re-add** the TV Show back in your Watchlist.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "note")) Notes")
                            .foregroundStyle(Color(UIColor.systemYellow.darker(amount: 0.15)))
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Once you watch a single episode of a TV Show, Trakt automatically removes it from your Watchlist. This reverse Trakt's automatic behavior.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $removeShowToWatchFromList) {
                        Text("Remove Listed TV Shows")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **watch** an episode of a TV Show...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **remove** the TV Show from the Custom Lists used to build your 'To Watch'.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "note")) Notes")
                            .foregroundStyle(Color(UIColor.systemYellow.darker(amount: 0.15)))
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Use this if you want to keep track of TV Shows you have in Custom Lists and automatically remove them when you start watching them. This way, every List used in 'To Watch' become an auto-managed Watchlist.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $removeMovieToWatchFromList) {
                        Text("Remove Listed Movies")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **watch** a Movie...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **remove** the Movie from the Custom Lists used to build your 'To Watch'.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "note")) Notes")
                            .foregroundStyle(Color(UIColor.systemYellow.darker(amount: 0.15)))
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Use this if you want to keep track of Movies you have in Custom Lists and automatically remove them when you watch them. This way, every List used in 'To Watch' become an auto-managed Watchlist.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $removeEpisodeAutoWatchedSync) {
                        Text("Remove Listed Episode")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **watch** an episode of a TV Show...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **remove** that Episode from any Custom List you have.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "exclamationmark.triangle")) Warning")
                            .foregroundStyle(.red)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("This Automation takes time to go through all lists to remove episodes. Use it only if you manage playlists of single episodes yourself and if you don't have a lot of lists!")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $addToWatchlistAutoListSync) {
                        Text("List → Watchlist")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **add** a TV Show in any Custom List...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **add** the TV Show in your Watchlist as well.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "note")) Notes")
                            .foregroundStyle(Color(UIColor.systemYellow.darker(amount: 0.15)))
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("This can be used to fill your Watchlist while keeping another kind of organisation with Lists.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
            Section {
                VStack {
                    Toggle(isOn: $addToWatchlistAutoWatchedSync) {
                        Text("Watch → Watchlist")
                            .font(.headline)
                    }.tint(Color(UIColor(asset: .globalTint)))
                        .toggleStyle(.switch)
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "bolt")) Trigger")
                            .foregroundStyle(.green)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("When you **watch** an episode of a TV Show...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "sparkles")) Action")
                            .foregroundStyle(.blue)
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("Automatically **add** the TV Show in your Watchlist.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Image(systemName: "note")) Notes")
                            .foregroundStyle(Color(UIColor.systemYellow.darker(amount: 0.15)))
                            .font(.callout.lowercaseSmallCaps().bold())
                        Text("This is useful if you want your Watchlist to also be your Currently Watching list.")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.padding(10)
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }.padding(.horizontal, -5)
            }.padding(.vertical, 6)
        }.listSectionSpacing(.compact)
    }
}

#Preview {
    AutomationSettingsView()
}
