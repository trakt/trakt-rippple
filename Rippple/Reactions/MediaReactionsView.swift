//
//  MediaReactionsView.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import SwiftUI

struct MediaReactionsView: View {
    @StateObject private var viewModel: MediaReactionsViewModel
    @Environment(\.dismiss) private var dismiss

    private let title: String

    init(media: MediaModel) {
        _viewModel = StateObject(wrappedValue: MediaReactionsViewModel(media: media))
        title = media.mediaTitle
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 6)], spacing: 6) {
                    ForEach(viewModel.possibleReactions) { reaction in
                        reactionButton(for: reaction)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .ripppleViewBackground))
            .navigationTitle(title)
            .navigationSubtitle(viewModel.prompt)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .tint(Color(uiColor: .label))
                }
            }
        }
        .animation(.snappy, value: viewModel.held)
        .onAppear {
            viewModel.load()
        }
    }

    private func reactionButton(for reaction: ReactionType) -> some View {
        let isSent = viewModel.isHeld(reaction)
        let isAvailable = isSent || !viewModel.hasReachedLimit
        return Button {
            viewModel.toggle(reaction)
        } label: {
            Text(reaction.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(isSent ? Color(uiColor: UIColor(asset: .globalTint)) : Color(uiColor: .secondarySystemFill), in: Circle())
        }
        .buttonStyle(.plain)
        .opacity(isAvailable ? 1 : 0.35)
        .disabled(!isAvailable)
        .accessibilityLabel("\(reaction.displayName) reaction")
        .accessibilityAddTraits(isSent ? .isSelected : [])
    }
}

// MARK: - View model

/// Main thread confined: the manager completes on main and the change broadcast is hopped to main.
private final class MediaReactionsViewModel: ObservableObject {
    /// Reactions the user sent, in picker order.
    @Published private(set) var held = [ReactionType]()
    /// Nil until the community summary is known; only used to invite the first reaction.
    @Published private(set) var hasCommunityReactions: Bool?

    let possibleReactions = MediaReactionsManager.shared.possibleReactions

    private let target: MediaReactionsTarget?
    private let disposeBag = DisposeBag()
    private var summaryRequest: Cancellable?
    private var heldRequest: Cancellable?
    private var isMutating = false

    init(media: MediaModel) {
        target = MediaReactionsTarget(media: media)
        applyCachedState()

        onMediaReactionsChangedReceiver.listen { [weak self] changedTarget in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.target == changedTarget, !self.isMutating else { return }
                self.applyCachedState()
            }
        }.disposed(by: disposeBag)
    }

    deinit {
        summaryRequest?.cancel()
        heldRequest?.cancel()
    }

    /// Subtitle of the sheet, following what the user already sent.
    var prompt: String {
        if hasReachedLimit {
            return "Tap one to remove it."
        }
        if !held.isEmpty {
            return "Another one? Up to 3."
        }
        return hasCommunityReactions == false ? "Be the first to react! Up to 3." : "What's your reaction? Up to 3."
    }

    var hasReachedLimit: Bool {
        return held.count >= MediaReactionsManager.maximumReactionsPerMedia
    }

    func isHeld(_ reaction: ReactionType) -> Bool {
        return held.contains { $0.type == reaction.type }
    }

    func load() {
        guard let target = target else { return }

        summaryRequest?.cancel()
        summaryRequest = MediaReactionsManager.shared.fetchSummary(for: target) { [weak self] summary in
            guard let self = self, let summary = summary else { return }
            self.hasCommunityReactions = summary.reactionCount > 0
        }

        heldRequest?.cancel()
        heldRequest = MediaReactionsManager.shared.fetchHeldReactions(for: target) { [weak self] held in
            guard let self = self, !self.isMutating else { return }
            guard let held = held else {
                SwiftMessages.show(message: "😓 Couldn't load your reactions")
                return
            }
            self.held = self.ordered(held.map { $0.reaction })
        }
    }

    /// Applies the change right away so the grid doesn't wait on the network, then settles on the server state.
    func toggle(_ reaction: ReactionType) {
        guard let target = target, !isMutating else { return }
        let isRemoving = isHeld(reaction)

        isMutating = true
        let previous = held
        held = isRemoving ? held.filter { $0.type != reaction.type } : ordered(held + [reaction])
        SwiftMessages.show(message: isRemoving ? "Removing reaction..." : "Adding reaction...", style: .loading)

        let completion: (Bool) -> Void = { [weak self] succeeded in
            guard let self = self else { return }
            self.isMutating = false
            if !succeeded {
                self.held = previous
            }
            self.applyCachedState()
        }
        if isRemoving {
            MediaReactionsManager.shared.removeReaction(reaction, from: target, completion: completion)
        } else {
            MediaReactionsManager.shared.react(to: target, with: reaction, completion: completion)
        }
    }

    private func applyCachedState() {
        guard let target = target else { return }
        if let summary = MediaReactionsManager.shared.summary(for: target) {
            hasCommunityReactions = summary.reactionCount > 0
        }
        if let held = MediaReactionsManager.shared.heldReactions(for: target) {
            self.held = ordered(held.map { $0.reaction })
        }
    }

    private func ordered(_ reactions: [ReactionType]) -> [ReactionType] {
        let types = Set(reactions.map { $0.type })
        return possibleReactions.filter { types.contains($0.type) }
    }
}
