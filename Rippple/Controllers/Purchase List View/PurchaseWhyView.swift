//
//  PurchaseWhyView.swift
//  Rippple
//
//  Created by Kevin Cador on 10/01/2025.
//  Copyright © 2025 Trakt. All rights reserved.
//

import SwiftUI

struct PurchaseWhyView: View {

    let callback: () -> Void

    @State private var selectedSegment = 0

    var body: some View {
        VStack {
            ZStack(alignment: .center) {
                Picker("Options", selection: $selectedSegment) {
                    Text(verbatim: "   User Reviews   \u{200c}")
                        .tag(0)
                        .bold()
                    Text("Features")
                        .tag(1)
                        .bold()
                }.pickerStyle(.segmented)
                    .onChange(of: selectedSegment) {
                        callback()
                    }
                    .fixedSize()
            }

            Spacer(minLength: 30)

            if selectedSegment == 0 {
                VStack(spacing: 10) {
                    ReviewItemView(title: "the best",
                                   rating: 5,
                                   name: "xavierbarex",
                                   review: "incredibly underrated",
                                   country: "Canada")

                    ReviewItemView(title: "Best app for Trakt",
                                   rating: 5,
                                   name: "_ATi_",
                                   review: "its my favorite app so far for Trakt thanks for building such an amazing app",
                                   country: "Türkiye")

                    ReviewItemView(title: "Best APP EVER!",
                                   rating: 5,
                                   name: "Ace873219",
                                   review: "My wife and I have tried many apps to track our TV/Movies. By far this app is the best! Far superior in every way, shape, and form. It connects seamlessly with your Trakt account and is a one stop shop for all of your entertainment tracking needs. Seriously thank you to the developer for an amazing app and for the dedication they put in with the amount of consistent updates we get. Every week there are new additions/improvements. Seriously, this is the best!",
                                   country: "United States")

                    ReviewItemView(title: "Best Trakt app out there",
                                   rating: 5,
                                   name: "Nimesh.netco",
                                   review: "Rippple is the best trakt app out there. Better than the official trakt app. Recommended for anyone using trakt.",
                                   country: "Sri Lanka")

                    ReviewItemView(title: "Better than the official app",
                                   rating: 5,
                                   name: "hroyer",
                                   review: "Beautiful UI and more features than the recently updated official Trakt app.",
                                   country: "Canada")

                    ReviewItemView(title: "No complaints",
                                   rating: 5,
                                   name: "zalizes",
                                   review: "This is probably the most feature rich & customizable tracking app available, it has everything you could ever want. The only thing I wish it had was a lifetime subscription as i’d prefer to just pay more upfront and have it forever instead of having a subscription.",
                                   country: "United States")

                    ReviewItemView(title: "Good",
                                   rating: 5,
                                   name: "NgocThaj",
                                   review: "This app is incredible",
                                   country: "Japan")

                    ReviewItemView(title: "Great app with bright future",
                                   rating: 5,
                                   name: "Not_Found_Xavi",
                                   review: "✅ Features rich trakt app\n✅ Great Design\n✅ Talkative Developers\n✅ Fairly priced",
                                   country: "Spain")

                    ReviewItemView(title: "Superb",
                                   rating: 5,
                                   name: "Thanasut",
                                   review: "Great updates today 👍",
                                   country: "Thailand")

                    ReviewItemView(title: "The best",
                                   rating: 5,
                                   name: "Devs.Nate",
                                   review: "I’ve tried a LOT of apps and this is by far the best one",
                                   country: "United States")

                    ReviewItemView(title: "Ripple simply rocks",
                                   rating: 5,
                                   name: "Mel Van Rippple",
                                   review: "It takes Trakt and turns into what it should be. Just one suggestion… Rippple on Apple TV!!! Rippple on macOS!!! More Rippple!!! Rippple EVERYWHERE!!!",
                                   country: "Australia")

                    ReviewItemView(title: "My favorite Trakt app.",
                                   rating: 5,
                                   name: "Tom Coolen",
                                   review: "I love the look and feel of the app and the streamlined experience it provides. Great work, and this from a one man team. 👌🏻",
                                   country: "Belgium")
                }
            } else {
                VStack(spacing: 30) {
                    FeatureItemView(imageName: "text.justify.left",
                                    title: "Expanded Limits",
                                    description: "Create more lists, write more notes, expand your watchlist, and rate without hitting caps.")

                    FeatureItemView(imageName: "chart.pie",
                                    title: "Advanced Stats",
                                    description: "Explore Month in Review, Year in Review, and all-time stats with deeper insights.")

                    FeatureItemView(imageName: "checklist",
                                    title: "Your To Watch",
                                    description: "Pin items, control sorting, and customize filters to plan what you'll watch next.")

                    FeatureItemView(imageName: "sparkles.rectangle.stack",
                                    title: "Your Shelf",
                                    description: "Build a dynamic Shelf tailored to your taste and how you browse.")

                    FeatureItemView(imageName: "sparkle.magnifyingglass",
                                    title: "Smarter Searches",
                                    description: "Create and save Smart Searches beyond the defaults.")

                    FeatureItemView(imageName: "backward.circle",
                                    title: "Smarter Rewatching",
                                    description: "Track rewatches accurately and keep your viewing history meaningful.")

                    FeatureItemView(imageName: "target",
                                    title: "Support Trakt & Rippple",
                                    description: "Unlock the complete experience and support independent media tracking.")
                }
            }
        }.padding([.leading, .trailing], 30)
    }
}

struct FeatureItemView: View {

    var imageName: String
    var title: String
    var description: String

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: imageName)
                .foregroundStyle(Color(UIColor(asset: .globalTint)))
                .font(.title3)
                .frame(width: 30)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ReviewItemView: View {

    @Environment(\.colorScheme) var colorScheme

    var title: String
    var rating: Int
    var name: String
    var review: String
    var country: String

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(.headline)
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < rating ? "star.fill" : "star")
                            .resizable()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.orange)
                    }
                }
                HStack {
                    Text(review)
                        .font(.body)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text("by **\(name)** from **\(country)**")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }.padding()
        }.background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
            .cornerRadius(15)
            .shadow(color: .black.opacity(0.3), radius: 8)
    }
}

#Preview {
    ScrollView {
        PurchaseWhyView {

        }
    }
}
