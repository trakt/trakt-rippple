//
//  SpoilersViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 10/03/2023.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import SwiftUI
import UIKit

let (episodeDetailTitlesTransmitter, episodeDetailTitlesReceiver) = Receiver<Bool>.make(with: .hot)
let (episodeListTitlesTransmitter, episodeListTitlesReceiver) = Receiver<Bool>.make(with: .hot)
let (toWatchTitlesTransmitter, toWatchTitlesReceiver) = Receiver<Bool>.make(with: .hot)
let (episodeImagesTransmitter, episodeImagesReceiver) = Receiver<Bool>.make(with: .hot)
let (actorEpisodeCountsTransmitter, actorEpisodeCountsReceiver) = Receiver<Bool>.make(with: .hot)

private struct SpoilerSampleLabel: UIViewRepresentable {
    private let text = String(localized: "Wow! What an ending! Who would have thought that Darth Vader is Luke Skywalker's father?")

    func makeUIView(context: Context) -> RedactableLabel {
        let label = RedactableLabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        configure(label)
        return label
    }

    func updateUIView(_ label: RedactableLabel, context: Context) {
        guard label.text != text else { return }
        label.setText(text, redacting: redactedRange)
    }

    func sizeThatFits(_ proposal: ProposedViewSize,
                      uiView: RedactableLabel,
                      context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        uiView.preferredMaxLayoutWidth = width
        let size = uiView.sizeThatFits(CGSize(width: width,
                                              height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    private func configure(_ label: RedactableLabel) {
        label.isRedactedByDefault = true
        label.setText(text, redacting: redactedRange)
    }

    private var redactedRange: NSRange {
        return NSRange(location: 0, length: (text as NSString).length)
    }
}

struct SpoilersView: View {
    @AppStorage("GeneralSettings.detailepisodetitle") private var alwaysShowsEpisodeTitlesInDetails = false
    @AppStorage("GeneralSettings.listsepisodetitle") private var alwaysShowsEpisodeTitlesInLists = false
    @AppStorage("GeneralSettings.towatchepisodetitle") private var alwaysShowsToWatchEpisodeTitles = false
    @AppStorage("GeneralSettings.episodeImageSpoilers") private var redactsEpisodeImages = true
    @AppStorage("GeneralSettings.actorEpisodeCountSpoilers") private var redactsActorEpisodeCounts = true

    var body: some View {
        Form {
            Section("Try It") {
                VStack(alignment: .leading, spacing: 8) {
                    SpoilerSampleLabel()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Tap the hidden plot twist to reveal it. Tap it again to hide it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("⚠️ This quote comes from [*The Simpsons* S03E12](ripl://tmdb/shows/456/seasons/3/episodes/12), where Homer loudly spoils [***The Empire Strikes Back***](ripl://tmdb/movies/1891) for everyone waiting in line as he exits the theater.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.vertical, 3)
            }

            Section("Episode Titles") {
                spoilerToggle(title: "Episode details",
                              description: "Episode titles stay protected until an episode is watched.",
                              isOn: protectsEpisodeTitlesInDetails)

                spoilerToggle(title: "Lists",
                              description: "Episode titles stay protected in season and episode lists until they are watched.",
                              isOn: protectsEpisodeTitlesInLists)

                spoilerToggle(title: "To Watch and Up Next",
                              description: "Episode titles stay protected in To Watch and Up Next until they are watched.",
                              isOn: protectsToWatchEpisodeTitles)
            }

            Section("Episode Images") {
                spoilerToggle(title: "Episode images",
                              description: "Show artwork replaces episode images until an episode is watched.",
                              isOn: protectsEpisodeImages)
            }

            Section("Cast & Crew") {
                spoilerToggle(title: "Actor episode counts",
                              description: "Actor episode counts stay protected.",
                              isOn: protectsActorEpisodeCounts)
            }
        }
        .navigationTitle("Spoilers")
        .listSectionSpacing(.compact)
    }

    private var protectsEpisodeTitlesInDetails: Binding<Bool> {
        return Binding(
            get: {
                alwaysShowsEpisodeTitlesInDetails == false
            },
            set: { isProtected in
                let alwaysShowsSpoilers = isProtected == false
                alwaysShowsEpisodeTitlesInDetails = alwaysShowsSpoilers
                episodeDetailTitlesTransmitter.broadcast(alwaysShowsSpoilers)
            }
        )
    }

    private var protectsEpisodeTitlesInLists: Binding<Bool> {
        return Binding(
            get: {
                alwaysShowsEpisodeTitlesInLists == false
            },
            set: { isProtected in
                let alwaysShowsSpoilers = isProtected == false
                alwaysShowsEpisodeTitlesInLists = alwaysShowsSpoilers
                episodeListTitlesTransmitter.broadcast(alwaysShowsSpoilers)
            }
        )
    }

    private var protectsToWatchEpisodeTitles: Binding<Bool> {
        return Binding(
            get: {
                alwaysShowsToWatchEpisodeTitles == false
            },
            set: { isProtected in
                let alwaysShowsSpoilers = isProtected == false
                alwaysShowsToWatchEpisodeTitles = alwaysShowsSpoilers
                toWatchTitlesTransmitter.broadcast(alwaysShowsSpoilers)
            }
        )
    }

    private var protectsEpisodeImages: Binding<Bool> {
        return Binding(
            get: {
                redactsEpisodeImages
            },
            set: { isProtected in
                redactsEpisodeImages = isProtected
                episodeImagesTransmitter.broadcast(isProtected)
            }
        )
    }

    private var protectsActorEpisodeCounts: Binding<Bool> {
        return Binding(
            get: {
                redactsActorEpisodeCounts
            },
            set: { isProtected in
                redactsActorEpisodeCounts = isProtected
                actorEpisodeCountsTransmitter.broadcast(isProtected)
            }
        )
    }

    private func spoilerToggle(title: LocalizedStringKey,
                               description: LocalizedStringKey,
                               isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 3)
        }
    }
}

final class SpoilersViewController: RipppleHostingController<SpoilersView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: SpoilersView())
    }
}
