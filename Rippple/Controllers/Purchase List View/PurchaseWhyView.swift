//
//  PurchaseWhyView.swift
//  Rippple
//
//  Created by Kevin Cador on 10/01/2025.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI

/// What Trakt VIP unlocks in Rippple, declared from most to least valuable and sorted like https://app.trakt.tv/vip.
enum VIPBenefit: CaseIterable {
    case stats
    case limits
    case smartLists
    case info
    case toWatch
    case shelf
    case rewatching
    case relatedTitles
    case support

    /// The benefit that matches why the paywall opened comes first, then the rest by value.
    static func ordered(leading benefit: VIPBenefit?) -> [VIPBenefit] {
        guard let benefit = benefit else { return allCases }
        return [benefit] + allCases.filter { $0 != benefit }
    }

    var imageName: String {
        switch self {
        case .stats: return "chart.pie"
        case .smartLists: return "sparkles"
        case .info: return "lightbulb"
        case .toWatch: return "checklist"
        case .limits: return "square.stack.3d.up"
        case .shelf: return "sparkles.rectangle.stack"
        case .rewatching: return "backward.circle"
        case .relatedTitles: return "rectangle.on.rectangle.angled"
        case .support: return "heart"
        }
    }

    var title: String {
        switch self {
        case .stats: return "Advanced Stats"
        case .smartLists: return "More Smart Lists"
        case .info: return "More Info"
        case .toWatch: return "Your To Watch"
        case .limits: return "Higher Limits"
        case .shelf: return "Your Shelf"
        case .rewatching: return "Smarter Rewatching"
        case .relatedTitles: return "More Related Titles"
        case .support: return "Support Trakt & Rippple"
        }
    }

    var description: String {
        switch self {
        case .stats:
            return "Relive what you watched with Month in Review, Year in Review, and all-time stats."
        case .smartLists:
            return "Describe what you want to watch and keep more Smart Lists that update themselves."
        case .info:
            return "Learn more about the shows and movies you love, starting with trivia."
        case .toWatch:
            return "Pin, group, sort, and filter To Watch to plan what you'll watch next."
        case .limits:
            return "Keep more in your lists and track without worrying about limits."
        case .shelf:
            return "Arrange your Shelf and add your own rails to browse your way."
        case .rewatching:
            return "Start and stop rewatches so your progress and history stay accurate."
        case .relatedTitles:
            return "See more shows and movies like the ones you're exploring."
        case .support:
            return "Help keep independent media tracking going."
        }
    }

    /// Markdown header for a paywall opened by this benefit; the bold part takes the tint color.
    var headline: String {
        switch self {
        case .stats: return "Relive everything you watched with **Trakt VIP**."
        case .smartLists: return "Keep more Smart Lists with **Trakt VIP**."
        case .info: return "Know more about what you watch with **Trakt VIP**."
        case .toWatch: return "Make To Watch yours with **Trakt VIP**."
        case .limits: return "Track and save more with **Trakt VIP**."
        case .shelf: return "Build your own Shelf with **Trakt VIP**."
        case .rewatching: return "Track every rewatch with **Trakt VIP**."
        case .relatedTitles: return "Find more like this with **Trakt VIP**."
        case .support: return "Support Trakt and Rippple with **Trakt VIP**."
        }
    }
}

struct PurchaseWhyView: View {
    /// Why the paywall opened. `nil` when the person came to browse VIP rather than hitting a gate.
    let benefit: VIPBenefit?

    private var otherBenefits: [VIPBenefit] {
        VIPBenefit.ordered(leading: benefit).filter { $0 != benefit }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            if let benefit = benefit {
                FeaturedBenefitView(benefit: benefit)
                Text("Also with VIP")
                    .font(.title3)
                    .bold()
                    .padding(.bottom, -10)
            }

            VStack(spacing: 24) {
                ForEach(otherBenefits, id: \.self) { benefit in
                    FeatureItemView(imageName: benefit.imageName,
                                    title: benefit.title,
                                    description: benefit.description)
                }
            }

            ReviewsView()
        }.padding([.leading, .trailing], 30)
    }
}

private struct FeaturedBenefitView: View {
    let benefit: VIPBenefit

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: benefit.imageName)
                .font(.title)
                .foregroundStyle(Color(uiColor: .ripppleTintContrastingLabel))
                .frame(width: 52, height: 52)
                .background(Color(UIColor(asset: .globalTint)), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(benefit.title)
                    .font(.title3)
                    .bold()
                Text(benefit.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(uiColor: .ripppleCardBackground), in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(uiColor: .ripppleCardBorder), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ReviewsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loved by people who track")
                .font(.title3)
                .bold()
            ReviewItemView(title: "Best APP EVER!",
                           rating: 5,
                           name: "Ace873219",
                           review: "My wife and I have tried many apps to track our TV/Movies. By far this app is the best! Far superior in every way, shape, and form. It connects seamlessly with your Trakt account and is a one stop shop for all of your entertainment tracking needs.",
                           country: "United States")

            ReviewItemView(title: "Great app with bright future",
                           rating: 5,
                           name: "Not_Found_Xavi",
                           review: "✅ Features rich trakt app\n✅ Great Design\n✅ Talkative Developers\n✅ Fairly priced",
                           country: "Spain")

            ReviewItemView(title: "The best",
                           rating: 5,
                           name: "Devs.Nate",
                           review: "I’ve tried a LOT of apps and this is by far the best one",
                           country: "United States")

            ReviewItemView(title: "My favorite Trakt app.",
                           rating: 5,
                           name: "Tom Coolen",
                           review: "I love the look and feel of the app and the streamlined experience it provides.",
                           country: "Belgium")

            ReviewItemView(title: "Best app for Trakt",
                           rating: 5,
                           name: "_ATi_",
                           review: "its my favorite app so far for Trakt thanks for building such an amazing app",
                           country: "Türkiye")
        }
    }
}

private extension UIColor {
    /// Same border the app's cards use.
    static let ripppleCardBorder = UIColor { traits in
        let separator = UIColor(asset: .separator)
        if traits.ripppleTintedAppearance || traits.userInterfaceStyle == .dark {
            return separator.withAlphaComponent(0.5)
        }
        return separator.lighter(amount: 0.15)
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
                .accessibilityHidden(true)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }.accessibilityElement(children: .combine)
    }
}

struct ReviewItemView: View {
    var title: String
    var rating: Int
    var name: String
    var review: String
    var country: String

    var body: some View {
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
            }.accessibilityElement()
                .accessibilityLabel("\(rating) out of 5 stars")
            Text(review)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("by **\(name)** from **\(country)**")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .ripppleCardBackground))
        .cornerRadius(15)
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(uiColor: .ripppleCardBorder), lineWidth: 1)
        }
    }
}

#Preview("From a gate") {
    ScrollView {
        PurchaseWhyView(benefit: .info)
    }
}

#Preview("Browsing VIP") {
    ScrollView {
        PurchaseWhyView(benefit: nil)
    }
}
