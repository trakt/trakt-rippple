//
//  SmartListPromptViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

/// The first step of a new smart list: describe it in a few words, and the on-device model fills in the builder's
/// sentence, or skip to build it from scratch.
final class SmartListPromptViewController: UIViewController, UITextViewDelegate, UIScrollViewDelegate {
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let examplesStack = UIStackView()
    private let contentStack = UIStackView()
    private let scrollView = UIScrollView()
    private var conversationController: RipppleHostingController<SmartListConversationView>?
    /// Where the conversation's text goes on screen, where the request was typed.
    private var conversationInsets = UIEdgeInsets.zero
    private var promptTask: Task<Void, Never>?
    /// A request to change, typed before.
    private var initialPrompt = ""
    /// Where the request was on screen before this one, in window coordinates, to move it from there.
    private var promptOrigin: CGPoint?

    /// Opens with a request ready to change, as typed. With `origin`, the request moves from there to where it's typed.
    convenience init(prompt: String, movingFrom origin: CGPoint? = nil) {
        self.init(nibName: nil, bundle: nil)
        initialPrompt = prompt
        promptOrigin = origin
    }

    private var prompt: String {
        textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    deinit {
        promptTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ripppleViewBackground
        title = "New Smart List"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.promptTask?.cancel()
            self.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = nextItem

        let font = UIFont.preferredFont(forTextStyle: .title2)
        textView.font = font
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.autocapitalizationType = .sentences
        textView.returnKeyType = .next
        textView.delegate = self

        placeholderLabel.text = "Type what you’d want or choose one below"
        placeholderLabel.font = font
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)

        examplesStack.axis = .vertical
        examplesStack.alignment = .leading
        examplesStack.spacing = 2
        for example in SmartListPromptExamples.current() {
            examplesStack.addArrangedSubview(UIButton.smartListOption(example) { [weak self] in
                guard let self = self else { return }
                // The examples stay to slide away with the others as the request is sent.
                self.textView.text = example
                self.placeholderLabel.isHidden = true
                self.submit()
            })
        }
        let skipButton = UIButton.smartListOption("Skip and build it yourself", image: UIImage(systemName: "chevron.forward")) { [weak self] in
            guard let self = self else { return }
            self.skip()
        }

        contentStack.addArrangedSubview(textView)
        contentStack.addArrangedSubview(examplesStack)
        contentStack.addArrangedSubview(skipButton)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 24
        // Scrolls when the examples don't fit above the keyboard, instead of squeezing them.
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        scrollView.alwaysBounceVertical = true
        // Starts below the navigation bar and scrolls behind it.
        scrollView.contentInsetAdjustmentBehavior = .scrollableAxes
        scrollView.delegate = self
        scrollView.addSubview(contentStack)
        // The examples scroll down to the screen's edge, under the home indicator, rather than stopping above it.
        view.keyboardLayoutGuide.usesBottomSafeArea = false
        view.addSubview(scrollView)

        // Lined up with the builder's sentence, which starts 40 points in.
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        // Content as tall as the screen, growing only when the examples need more room.
        let fitsScreen = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        fitsScreen.priority = .defaultLow
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 120),
            // Room to scroll the last examples up, where they're no longer dimmed. A fixed height: tied to the scroll view's,
            // it would change as the keyboard hides while scrolling.
            content.bottomAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor, constant: 320),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            fitsScreen,
            // Inside the safe area, which leaves room for bar buttons shown beside the content.
            contentStack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -40),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualTo: placeholderLabel.heightAnchor)
        ])

        if initialPrompt.isEmpty == false {
            textView.text = initialPrompt
            textViewDidChange(textView)
        }

        SmartListAssistant.prewarm()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateExamplesOpacity()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateExamplesOpacity()
    }

    /// Examples low on the screen are dimmed and brighten as they scroll up, drawing the eye to the prompt first.
    private func updateExamplesOpacity() {
        let height = scrollView.bounds.height
        guard height > 0 else { return }
        for example in examplesStack.arrangedSubviews {
            let position = example.convert(CGPoint(x: 0, y: example.bounds.midY), to: scrollView).y - scrollView.contentOffset.y
            // Full strength in the top 40% of the visible area, down to 30% at its bottom.
            let fade = min(max((position / height - 0.4) / 0.6, 0), 1)
            example.alpha = 1 - 0.7 * fade
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        if let origin = promptOrigin {
            promptOrigin = nil
            movePrompt(from: origin)
        }
    }

    /// The request, as it was shown before, moves to where it's typed and becomes the text field: wherever it was, it
    /// ends exactly in place.
    private func movePrompt(from origin: CGPoint) {
        view.layoutIfNeeded()
        let moving = UILabel()
        moving.font = textView.font
        moving.numberOfLines = 0
        moving.lineBreakStrategy = []
        moving.textColor = .secondaryLabel
        moving.text = textView.text
        let size = moving.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude))
        moving.frame = CGRect(origin: view.convert(origin, from: nil), size: CGSize(width: textView.bounds.width, height: size.height))
        view.addSubview(moving)
        textView.alpha = 0
        let target = textView.convert(CGPoint.zero, to: view)
        let isReduced = UIAccessibility.isReduceMotionEnabled
        // It moves once the screens have crossed, when it's the only copy left: the one fading out stays put.
        let delay = isReduced ? 0 : 0.2
        let duration = isReduced ? 0.2 : 0.3
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseInOut, animations: {
            moving.frame.origin = target
        }, completion: { [weak self] _ in
            UIView.transition(with: moving, duration: 0.1, options: .transitionCrossDissolve, animations: {
                moving.textColor = .label
            }, completion: { [weak self] _ in
                guard let self = self else { return }
                self.textView.alpha = 1
                moving.removeFromSuperview()
            })
        })
    }

    private var nextItem: UIBarButtonItem {
        let item = UIBarButtonItem(image: UIImage(systemName: "chevron.right"), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.submit()
        })
        item.style = .prominent
        item.accessibilityLabel = "Next"
        return item
    }

    func textViewDidChange(_ textView: UITextView) {
        let isEmpty = textView.text.isEmpty
        placeholderLabel.isHidden = isEmpty == false
        // Examples are only suggestions for a blank prompt.
        guard examplesStack.isHidden != (isEmpty == false) else { return }
        UIView.animate(withDuration: 0.2) {
            self.examplesStack.isHidden = isEmpty == false
            self.examplesStack.alpha = isEmpty ? 1 : 0
        }
    }

    /// Return submits, like the Next button: the prompt still wraps over several lines.
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text == "\n" else { return true }
        submit()
        return false
    }

    /// Without a prompt, Next skips to building the list from scratch.
    private func submit() {
        let prompt = prompt
        guard promptTask == nil else { return }
        guard prompt.isEmpty == false else {
            skip()
            return
        }
        let conversation = SmartListConversation(prompt: prompt)
        beginConversation()

        promptTask = Task { @MainActor [weak self] in
            // The request is read while it's put in place, and thinking starts once it's there.
            // Steps told before the conversation is in place wait in it, and show once it is.
            async let read = SmartListAssistant.definition(from: prompt, onStep: { conversation.show($0) })
            guard let self = self else { return }
            await self.startConversation(conversation)
            let definition = await read
            guard Task.isCancelled == false else { return }
            guard let definition = definition else {
                // The conversation stays to say why, and the request can be tapped to change it.
                self.promptTask = nil
                await conversation.finish(with: nil)
                guard Task.isCancelled == false else { return }
                self.conversationController?.setRootView(self.conversationView(conversation) { [weak self] in
                    guard let self = self else { return }
                    self.endConversation()
                    self.textView.becomeFirstResponder()
                })
                self.view.isUserInteractionEnabled = true
                self.navigationController?.isModalInPresentation = false
                return
            }
            var draft = SmartListDraft()
            draft.source = definition.source
            draft.mediaType = definition.mediaType
            draft.filters = definition.filters
            await conversation.finish(with: definition)
            guard Task.isCancelled == false else { return }
            self.promptTask = nil
            self.showBuilder(with: draft, continuing: conversation)
        }
    }

    /// Building it by hand goes the same way as a request, with a short reply instead of a reading, so the builder always
    /// continues a conversation that can be tapped to ask after all.
    private func skip() {
        guard promptTask == nil else { return }
        let conversation = SmartListConversation(prompt: "Skip and build it myself", isSkipped: true)
        beginConversation()
        let replies = [
            "Okay, I get it, you don't need me. I'm not taking it personally.",
            "Fine, it's all yours. I'll just be over here, not reading anything.",
            "Building it yourself? Respect. I'll keep the seat warm.",
            "No problem. I wasn't that attached to it anyway."
        ]
        promptTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.startConversation(conversation)
            conversation.show(SmartListAssistant.Step(lines: [
                SmartListAssistant.Line(kind: .chose, text: replies.randomElement() ?? replies[0]),
                SmartListAssistant.Line(kind: .note, text: "Changed your mind? Tap your message to ask me after all.")
            ]))
            await conversation.finish(with: nil)
            guard Task.isCancelled == false else { return }
            self.promptTask = nil
            self.showBuilder(with: SmartListDraft(), continuing: conversation)
        }
    }

    private func beginConversation() {
        textView.resignFirstResponder()
        view.isUserInteractionEnabled = false
        navigationController?.isModalInPresentation = true
        navigationItem.rightBarButtonItem = nil
    }

    /// The request becomes the first message of a conversation. What's below it goes at once, and the request scrolls
    /// back to where it was typed, as a picked example may be far down: the only movement before thinking starts.
    /// Cancel remains available.
    private func startConversation(_ conversation: SmartListConversation) async {
        let isReduced = UIAccessibility.isReduceMotionEnabled
        for subview in contentStack.arrangedSubviews where subview !== textView {
            subview.alpha = 0
        }
        let top = -scrollView.adjustedContentInset.top
        if scrollView.contentOffset.y != top {
            await withCheckedContinuation { continuation in
                UIView.animate(withDuration: isReduced ? 0.2 : 0.45, delay: 0, options: .curveEaseInOut, animations: {
                    self.scrollView.contentOffset.y = top
                }, completion: { _ in
                    continuation.resume()
                })
            }
        }
        view.layoutIfNeeded()
        let typed = textView.convert(textView.bounds, to: view)
        conversationInsets = UIEdgeInsets(top: typed.minY, left: typed.minX, bottom: view.safeAreaInsets.bottom,
                                          right: view.bounds.width - typed.maxX)
        // The whole screen, so a long conversation scrolls under the bar and the home indicator rather than being cut
        // where it starts or ends.
        let controller = RipppleHostingController(rootView: conversationView(conversation))
        controller.safeAreaRegions = []
        addChild(controller)
        let conversationView: UIView = controller.view
        conversationView.backgroundColor = .clear
        conversationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(conversationView)
        NSLayoutConstraint.activate([
            conversationView.topAnchor.constraint(equalTo: view.topAnchor),
            conversationView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            conversationView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            conversationView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        controller.didMove(toParent: self)
        conversationController = controller
        conversationView.layoutIfNeeded()

        // The conversation shows the request as typed, in the same place. When it says something else, skipping, the two
        // cross.
        if conversation.prompt == prompt {
            textView.alpha = 0
        } else {
            conversationView.alpha = 0
            await withCheckedContinuation { continuation in
                UIView.animate(withDuration: 0.25, animations: {
                    self.textView.alpha = 0
                    conversationView.alpha = 1
                }, completion: { _ in
                    continuation.resume()
                })
            }
        }
        conversation.send()
    }

    private func conversationView(_ conversation: SmartListConversation, editPrompt: (() -> Void)? = nil) -> SmartListConversationView {
        SmartListConversationView(conversation: conversation, fillsHeight: true, insets: conversationInsets, editPrompt: editPrompt)
    }

    /// Back to the request, to change it.
    private func endConversation() {
        conversationController?.willMove(toParent: nil)
        conversationController?.view.removeFromSuperview()
        conversationController?.removeFromParent()
        conversationController = nil
        textView.alpha = 1
        for subview in contentStack.arrangedSubviews where subview !== textView {
            subview.alpha = 1
        }
        textViewDidChange(textView)
        view.isUserInteractionEnabled = true
        navigationController?.isModalInPresentation = false
        navigationItem.rightBarButtonItem = nextItem
    }

    /// Replaces this step, so going forward can't come back to it. After a conversation, the builder continues it in
    /// place: it starts with the conversation where it is here, then slides up, and only the bar changes.
    private func showBuilder(with draft: SmartListDraft, continuing conversation: SmartListConversation? = nil) {
        let conversationTop = conversationController == nil ? 0 : conversationInsets.top - (conversation?.scrolledBy ?? 0)
        guard let builder = SmartListBuilderViewController.make(list: nil, draft: draft, conversation: conversation, conversationTop: conversationTop)
        else { return }
        textView.resignFirstResponder()
        if conversation != nil {
            let transition = CATransition()
            transition.type = .fade
            transition.duration = 0.3
            navigationController?.navigationBar.layer.add(transition, forKey: nil)
        }
        navigationController?.setViewControllers([builder], animated: conversation == nil)
    }
}

// MARK: - Examples

/// Examples change with each visit: a few about now (the season, this year, the device language), then a rotating
/// selection of the others. Each one reads as the conditions it turns into.
private enum SmartListPromptExamples {
    private static let count = 16

    /// Only phrasings the assistant reads in full, so a suggestion never leaves words out.
    private static let others = [
        "Trending horror movies from the 80s",
        "Korean dramas on Netflix I haven’t watched",
        "Popular comedies under 90 minutes with a good rating",
        "Upcoming sci-fi shows",
        "Well rated thrillers on my watchlist",
        "Comedies from the eighties",
        "Recommended thrillers I haven’t watched",
        "Trending shows on Disney Plus",
        "French movies from the 60s",
        "Popular westerns from before 1980",
        "Horror movies under 90 minutes",
        "War movies with an IMDb rating of 8 or higher",
        "Spanish crime shows on Netflix",
        "Family movies on Disney Plus",
        "Upcoming fantasy movies",
        "Trending documentaries",
        "Popular action movies from the 2000s",
        "Highly rated dramas from Korea",
        "Movies directed by Christopher Nolan",
        "Tom Hanks movies from the 90s",
        "A24 horror movies I haven’t watched",
        "Movies about time travel",
        "Shows about zombies",
        "Movies with a Rotten Tomatoes score of 90% or higher",
        "Pixar movies from the 2010s",
        "Highly rated Korean movies in my library",
        "Movies with Tom Holland",
        "Comedies that aren’t on Netflix",
        "Anime from Japan",
        "Crime shows from the UK",
        "Movies in French from the 70s",
        "Movies about heists with a high rating"
    ]

    static func current(on date: Date = .now, locale: Locale = .current) -> [String] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        var timely = [String]()
        switch calendar.component(.month, from: date) {
        case 2: timely.append("Romance movies about Valentine’s Day")
        case 10: timely.append("Horror movies about Halloween")
        case 12: timely.append("Family movies about Christmas")
        default: break
        }
        timely.append("Trending action movies from this year")
        timely.append("Well rated comedies from the \((year / 10 - 1) * 10)s")
        // Named in English, like the rest of the prompt. "Movies in German" reads as a language, "German movies" as a country.
        if let code = locale.language.languageCode?.identifier, code != "en",
           let language = Locale(identifier: "en_US").localizedString(forLanguageCode: code) {
            timely.append("Popular movies in \(language)")
        }
        return timely + others.shuffled().prefix(max(count - timely.count, 0))
    }
}

// MARK: - Options

extension UIButton {
    /// Plain secondary text, as the prompt's examples and the suggested names read.
    static func smartListOption(_ title: String, image: UIImage? = nil, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.image = image?.withConfiguration(UIImage.SymbolConfiguration(textStyle: .footnote))
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.baseForegroundColor = .secondaryLabel
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0)
        configuration.titleAlignment = .leading
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .body)
            return attributes
        }
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.contentHorizontalAlignment = .leading
        return button
    }
}
