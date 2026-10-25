//
//  SmartListConversation.swift
//  Rippple
//
//  Created by Kevin Cador on 22/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import SwiftUI
import UIKit

/// How a request is read, told like a conversation: the request, a small thinking indicator, then what was understood,
/// looked into, found and chosen, each told as soon as it's done. Told live on the prompt screen, then kept above the builder's sentence,
/// where it can be scrolled back to.
@MainActor
final class SmartListConversation: ObservableObject {
    struct Line: Identifiable {
        enum Kind {
            /// A gap before a new speaker's message.
            case step
            case kept
            case fixed
            case leftOut
            case chose
            case note
        }

        let id: Int
        let kind: Kind
        let text: String
    }

    let prompt: String
    /// Skipped to build the list by hand: the request is the person saying so, and changing it starts from a blank one.
    let isSkipped: Bool
    @Published private(set) var isPromptSent = false
    @Published private(set) var isThinking = true
    @Published private(set) var seconds = 0
    @Published private(set) var lines = [Line]()
    @Published private(set) var revealed = 0
    /// The smart list the reading made, as the API has it, or nil when it made none.
    private var smartList: SmartListAssistant.Definition?
    /// When thinking started, for the time shown while it lasts and after.
    let startDate = Date()
    /// How far the conversation was scrolled while told, so the builder continues it where it is.
    var scrolledBy: CGFloat = 0
    /// Lines are revealed in order, as steps come in.
    private var reveal: Task<Void, Never>?

    init(prompt: String, isSkipped: Bool = false) {
        self.prompt = prompt
        self.isSkipped = isSkipped
    }

    /// The request to change when it's tapped.
    var editablePrompt: String {
        isSkipped ? "" : prompt
    }

    /// The request turns into the person's message, quieter than what follows.
    func send() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isPromptSent = true
        }
    }

    /// Tells a step of the reading as soon as it's done, a line at a time after the lines already told.
    func show(_ step: SmartListAssistant.Step) {
        let told = [(Line.Kind.step, "")] + step.lines.map { (SmartListConversation.kind(of: $0.kind), $0.text) }
        let first = lines.count
        lines += told.enumerated().map { Line(id: first + $0.offset, kind: $0.element.0, text: $0.element.1) }
        let count = lines.count
        let previous = reveal
        reveal = Task { [weak self] in
            await previous?.value
            guard let self = self else { return }
            let isReduced = UIAccessibility.isReduceMotionEnabled
            while self.revealed < count {
                // A line at a time, at a reading pace, as if it were being written.
                try? await Task.sleep(for: .milliseconds(isReduced ? 0 : 450))
                withAnimation(.easeOut(duration: 0.3)) {
                    self.revealed += 1
                }
            }
        }
    }

    /// Ends thinking once every step is told, with the smart list it made, then leaves a moment to read the last line.
    func finish(with definition: SmartListAssistant.Definition?) async {
        smartList = definition
        await reveal?.value
        withAnimation(.easeInOut(duration: 0.3)) {
            seconds = max(1, Int(Date().timeIntervalSince(startDate)))
            isThinking = false
        }
        // Every message ends its own sentence; the gaps between them aren't read.
        UIAccessibility.post(notification: .announcement, argument: lines.filter { $0.kind != .step }.map(\.text).joined(separator: " "))
        try? await Task.sleep(for: .milliseconds(UIAccessibility.isReduceMotionEnabled ? 300 : 900))
    }

    /// The request, every line told, then the smart list it made: to send as feedback, or to test the reader with.
    var transcript: String {
        let told = lines.filter { $0.kind != .step }.map(\.text)
        return (["Prompt: \(prompt)", ""] + told + ["", "Smart list: \(smartListJSON ?? "none")"]).joined(separator: "\n")
    }

    private var smartListJSON: String? {
        guard let smartList = smartList else { return nil }
        struct Made: Encodable {
            let source: SmartListSource
            let mediaType: SmartListMediaType
            let filters: SmartListFilters

            enum CodingKeys: String, CodingKey {
                case source
                case mediaType = "media_type"
                case filters
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let made = Made(source: smartList.source, mediaType: smartList.mediaType, filters: smartList.filters)
        return (try? encoder.encode(made)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private static func kind(of kind: SmartListAssistant.Line.Kind) -> Line.Kind {
        switch kind {
        case .kept: return .kept
        case .fixed: return .fixed
        case .leftOut: return .leftOut
        case .chose: return .chose
        case .note: return .note
        }
    }
}

struct SmartListConversationView: View {
    @ObservedObject var conversation: SmartListConversation
    /// Pinned to the top of a taller space while it's told, so lines appearing don't move what's above them.
    var fillsHeight = false
    /// Where the text goes while it fills the screen: lines scroll into the room above when the conversation outgrows it.
    var insets = UIEdgeInsets.zero
    /// Once told, the request can be tapped to change it.
    var editPrompt: (() -> Void)?

    private var header: String {
        conversation.seconds == 1 ? "Thought for 1 second" : "Thought for \(conversation.seconds) seconds"
    }

    /// "Thinking… 12s", then "Thinking… 1m 15s".
    private func thinking(at date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSince(conversation.startDate)))
        return seconds < 60 ? "Thinking… \(seconds)s" : "Thinking… \(seconds / 60)m \(seconds % 60)s"
    }

    var body: some View {
        if fillsHeight {
            // Taller than the space once every reading is told: it scrolls, following the newest line, instead of
            // overflowing above the space's top.
            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .padding(EdgeInsets(top: insets.top, leading: insets.left, bottom: 0, trailing: insets.right))
                }
                .scrollIndicators(.hidden)
                // Room above the home indicator that following the newest line keeps clear, while lines still scroll under it.
                .safeAreaPadding(.bottom, insets.bottom)
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, offset in
                    conversation.scrolledBy = offset
                }
                .onChange(of: conversation.revealed) { _, revealed in
                    withAnimation(.easeOut(duration: 0.35)) {
                        proxy.scrollTo(revealed - 1, anchor: .bottom)
                    }
                }
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            SmartListPromptText(text: conversation.prompt, color: conversation.isPromptSent ? .secondaryLabel : .label)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard conversation.isThinking == false else { return }
                    editPrompt?()
                }
                .accessibilityAddTraits(editPrompt == nil ? [] : .isButton)
                .accessibilityHint(editPrompt == nil ? "" : "Edits the request.")
                .accessibilityAction {
                    guard conversation.isThinking == false else { return }
                    editPrompt?()
                }
            HStack(spacing: 8) {
                if conversation.isThinking {
                    SmartListThinkingIndicator()
                        .frame(width: 16, height: 16)
                }
                Group {
                    if conversation.isThinking {
                        TimelineView(.periodic(from: conversation.startDate, by: 1)) { context in
                            Text(thinking(at: context.date))
                                .monospacedDigit()
                        }
                    } else {
                        Text(header)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            .padding(.top, 40)
            .opacity(conversation.isPromptSent ? 1 : 0)
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(conversation.lines) { line in
                    SmartListConversationLine(line: line)
                        .opacity(line.id < conversation.revealed ? 1 : 0)
                        .offset(y: line.id < conversation.revealed ? 0 : 8)
                }
                if conversation.isSkipped == false, conversation.isThinking == false,
                   conversation.revealed >= conversation.lines.count {
                    SmartListCopyLine(conversation: conversation)
                        .padding(.top, 4)
                        .transition(.opacity)
                }
            }
            .padding(.top, conversation.lines.isEmpty ? 0 : 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The request, the header and each line are read one by one, so the request can be activated on its own.
        .accessibilityElement(children: .contain)
    }
}

private struct SmartListConversationLine: View {
    let line: SmartListConversation.Line

    var body: some View {
        if line.kind == .step {
            Color.clear
                .frame(height: line.id == 0 ? 0 : 4)
                .accessibilityHidden(true)
        } else {
            // Wraps rather than truncates where the conversation is measured to fit, above the builder's sentence. What
            // was left out, or only noted, reads quieter than what was kept.
            Text(line.text)
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: [.leftOut, .note].contains(line.kind) ? .secondaryLabel : .label))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Copies the whole conversation, as one more quiet line at its end rather than a button: to send it as feedback, or to test
/// the reader with.
private struct SmartListCopyLine: View {
    let conversation: SmartListConversation
    @State private var isCopied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = conversation.transcript
            isCopied = true
            UIAccessibility.post(notification: .announcement, argument: "Copied")
        } label: {
            Text(isCopied ? "Copied" : "Copy conversation")
                .font(.subheadline)
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Copies the request, the conversation and the smart list.")
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation {
                isCopied = false
            }
        }
    }
}

/// The request, wrapped word by word like the prompt's text view: SwiftUI's `Text` moves words down to avoid a last line of
/// one word, so the request would rewrap when it's sent.
private struct SmartListPromptText: UIViewRepresentable {
    let text: String
    let color: UIColor

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .title2)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.lineBreakStrategy = []
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        label.textColor = color
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? label.intrinsicContentSize.width
        return CGSize(width: width, height: label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
    }
}

/// The app's loader, small enough to sit beside a line of text.
private struct SmartListThinkingIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> NVActivityIndicatorView {
        let indicator = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 16, height: 16), type: .ballScaleMultiple,
                                                color: UIColor(asset: .globalTint))
        indicator.startAnimating()
        return indicator
    }

    func updateUIView(_ indicator: NVActivityIndicatorView, context: Context) {}
}
