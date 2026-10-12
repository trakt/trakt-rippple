//
//  EmojiReactionsSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI

struct EmojiReactionsSettingsView: View {
    @AppStorage("EmojiReactionsSettings.enabled") private var isEnabled = true
    @AppStorage("EmojiReactionsSettings.shower") private var isShowerEnabled = true
    /// The media lists metadata line, shared with General settings: 4 shows reactions, 1 is the default (ratings).
    @AppStorage("GeneralSettings.commentscount") private var listsDisplay = 1

    private var showsReactionsInLists: Binding<Bool> {
        Binding {
            listsDisplay == 4
        } set: { isOn in
            updateListsDisplay(isOn ? 4 : 1)
        }
    }

    var body: some View {
        RipppleForm {
            Section(footer: Text("Show the community's emoji reactions on Movies, TV Shows, Seasons and Episodes, and react to them yourself.")) {
                Toggle("Emoji Reactions", isOn: $isEnabled)
            }

            Section(footer: Text("Rains your own reactions down the screen when you open a Movie, TV Show, Season or Episode you reacted to.")) {
                Toggle("Reaction Shower", isOn: $isShowerEnabled)
            }
            .disabled(!isEnabled)

            Section(footer: Text("Shows the top reactions instead of ratings or comment count in the metadata line of media lists.")) {
                Toggle("Reactions in Lists", isOn: showsReactionsInLists)
            }
            .disabled(!isEnabled)
        }
        .navigationTitle("Emoji Reactions")
        .onChange(of: isEnabled) { _, isEnabled in
            if !isEnabled, listsDisplay == 4 {
                updateListsDisplay(1)
            }
            onEmojiReactionsDisplayTransmitter.broadcast(isEnabled)
        }
    }

    private func updateListsDisplay(_ display: Int) {
        listsDisplay = display
        onCommentsCountDisplayTransmitter.broadcast(display)
    }
}
