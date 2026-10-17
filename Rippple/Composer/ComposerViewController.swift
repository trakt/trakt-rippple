//
//  ComposerViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 17/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class ComposerViewController: UIViewController {
    private static let insertBubbleInset: CGFloat = 24

    private let session: ComposerSession
    private var configuration: ComposerConfiguration
    private(set) var draft: ComposerDraft

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerView = ComposerSubjectHeaderView()
    private let textView = ComposerTextView()
    private let previewTextView = UITextView()
    private let attachmentView = ComposerAttachmentView()
    private let privacyButton = ComposerOptionButton()
    private let spoilerButton = ComposerOptionButton()
    private let previewButton = ComposerOptionButton()
    private let accessoryBar = ComposerAccessoryBar()
    private struct InsertBubble {
        let controller: ComposerInsertViewController
        let dimmingView: UIView
        let collapsed: [NSLayoutConstraint]
        let expanded: [NSLayoutConstraint]
    }

    private var insertBubble: InsertBubble?
    private var pickedGIF: ComposerGIFItem?
    private var insertionRange = NSRange(location: 0, length: 0)
    private var pendingAlerts = [UIAlertController]()
    private var isPreviewing = false
    private var isSubmitting = false
    private var didAppearOnce = false
    private let disposeBag = DisposeBag()

    private lazy var markdownParser: SpoilerMarkdownParser = {
        let parser = SpoilerMarkdownParser(font: UIFont.preferredFont(forTextStyle: .body,
                                                                      compatibleWith: UITraitCollection(preferredContentSizeCategory: min(UIApplication.shared.preferredContentSizeCategory, .extraExtraExtraLarge))),
                                           automaticLinkDetectionEnabled: true)
        parser.color = .label
        parser.strike.strikeColor = .label
        parser.strike.color = .label
        parser.highlight.color = .label
        parser.spoiler.color = .label
        parser.allSpoiler.color = .label
        parser.displaySpoiler.color = .label
        parser.mention.color = .label
        parser.spoilerStrategy = .showAllSpoilers
        return parser
    }()

    private var wordCountCache: (text: String, count: Int)?

    private lazy var cancelItem: UIBarButtonItem = {
        let action = UIAction { [weak self] _ in
            guard let self = self else { return }
            self.cancel()
        }
        if let dismissTitle = configuration.dismissTitle {
            return UIBarButtonItem(title: dismissTitle, primaryAction: action)
        }
        return UIBarButtonItem(systemItem: .cancel, primaryAction: action)
    }()

    private lazy var submitItem: UIBarButtonItem = {
        let item = UIBarButtonItem(image: UIImage(systemName: session.submitSymbol(for: draft)), primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.submit()
        })
        item.style = .prominent
        item.tintColor = UIColor(asset: .globalTint)
        return item
    }()

    private func updateRightBarItems(submit: UIBarButtonItem) {
        navigationItem.rightBarButtonItems = configuration.isReadOnly ? nil : [submit]
    }

    private var hasUnsavedChanges: Bool {
        draft != session.initialDraft
    }

    init(session: ComposerSession) {
        self.session = session
        configuration = session.configuration
        draft = session.initialDraft
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func makeNavigationController(session: ComposerSession) -> StyledNavigationController {
        let composer = ComposerViewController(session: session)
        let navigationController = StyledNavigationController(rootViewController: composer)
        navigationController.presentationController?.delegate = composer
        return navigationController
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .ripppleViewBackground

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        textView.delegate = self

        previewTextView.isEditable = false
        previewTextView.isScrollEnabled = false
        previewTextView.backgroundColor = .clear
        previewTextView.textContainerInset = .zero
        previewTextView.textContainer.lineFragmentPadding = 0
        previewTextView.linkTextAttributes = [.foregroundColor: UIColor(asset: .globalTint)]
        previewTextView.delegate = self
        previewTextView.isHidden = true

        privacyButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.cyclePrivacy()
        }

        attachmentView.onRemove = { [weak self] in
            guard let self = self else { return }
            self.draft.gif = nil
            self.pickedGIF = nil
            self.draftDidChange()
        }

        spoilerButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.draft.containsSpoiler.toggle()
            self.draftDidChange()
        }
        previewButton.onTap = { [weak self] in
            guard let self = self else { return }
            self.setPreviewing(self.isPreviewing == false)
        }
        let editorStack = UIStackView(arrangedSubviews: [textView, previewTextView, makeOptionsRow()])
        editorStack.axis = .vertical
        editorStack.spacing = 8
        editorStack.setCustomSpacing(18, after: textView)
        editorStack.setCustomSpacing(18, after: previewTextView)
        editorStack.isLayoutMarginsRelativeArrangement = true
        editorStack.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)
        contentStack.addArrangedSubview(headerView)
        contentStack.addArrangedSubview(editorStack)
        contentStack.addArrangedSubview(attachmentView)

        accessoryBar.translatesAutoresizingMaskIntoConstraints = false
        accessoryBar.onAction = { [weak self] action in
            guard let self = self else { return }
            self.perform(action)
        }
        let edgeInteraction = UIScrollEdgeElementContainerInteraction()
        edgeInteraction.scrollView = scrollView
        edgeInteraction.edge = .bottom
        accessoryBar.addInteraction(edgeInteraction)
        view.addSubview(accessoryBar)

        let content = scrollView.contentLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            // Extra room on the trailing side keeps the scroll indicator off the cards.
            contentStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            accessoryBar.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            accessoryBar.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            accessoryBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -8)
        ])

        navigationItem.leftBarButtonItem = cancelItem
        applyConfiguration()
        textView.text = draft.text
        updateUI()
        setContentScrollView(scrollView, for: .top)

        onUserLoggedOutReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.view.window?.isUserInteractionEnabled = true
                self.dismiss(animated: true)
            }
        }.disposed(by: disposeBag)

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, RipppleTintTrait.self],
                                action: #selector(renderPreviewIfNeeded))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let barHeight = accessoryBar.isHidden ? 0 : accessoryBar.bounds.height + 16
        if scrollView.contentInset.bottom != barHeight {
            scrollView.contentInset.bottom = barHeight
            scrollView.verticalScrollIndicatorInsets.bottom = barHeight
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didAppearOnce == false else { return }
        didAppearOnce = true
        session.composerDidAppear(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.isBeingDismissed ?? isBeingDismissed {
            session.composerWillDisappear(draft)
        }
    }

    // MARK: - Session API

    func reloadConfiguration() {
        configuration = session.configuration
        applyConfiguration()
        updateUI()
    }

    func replace(with draft: ComposerDraft) {
        if draft.gif != self.draft.gif {
            pickedGIF = nil
        }
        textView.text = draft.text
        self.draft = draft
        draftDidChange()
    }

    func focusTextView() {
        guard configuration.isReadOnly == false, isPreviewing == false else { return }
        textView.becomeFirstResponder()
    }

    func presentAlert(title: String?, message: String?, actions: [ComposerAlertAction]) {
        enqueue(makeAlert(title: title, message: message, style: .alert, actions: actions))
    }

    func presentSheet(title: String?, message: String?, actions: [ComposerAlertAction], anchor: UIBarButtonItem) {
        let sheet = makeAlert(title: title, message: message, style: .actionSheet, actions: actions)
        sheet.popoverPresentationController?.barButtonItem = anchor
        enqueue(sheet)
    }

    // MARK: - Configuration and state

    private func applyConfiguration() {
        title = configuration.title
        navigationItem.subtitle = configuration.subtitle
        textView.placeholder = configuration.placeholder
        headerView.configure(subject: configuration.subject, detail: configuration.subjectDetail)
        accessoryBar.configure(tools: configuration.tools)

        textView.isEditable = configuration.isReadOnly == false
        updateRightBarItems(submit: submitItem)
        if configuration.isReadOnly {
            accessoryBar.isHidden = true
            textView.resignFirstResponder()
            isPreviewing = true
        }
        showPreview(isPreviewing)
    }

    private func updateUI() {
        submitItem.image = UIImage(systemName: session.submitSymbol(for: draft))
        submitItem.accessibilityLabel = session.submitTitle(for: draft)
        // Never disabled: it turns prominent once sending is possible, and `submit()` ignores taps until then.
        let style: UIBarButtonItem.Style = canSubmit ? .prominent : .plain
        if submitItem.style != style {
            submitItem.style = style
        }
        submitItem.accessibilityHint = canSubmit ? nil : "Not ready to send yet."

        previewButton.option = previewOption

        isModalInPresentation = insertBubble != nil || (configuration.isReadOnly == false && hasUnsavedChanges)

        privacyButton.option = privacyOption
        spoilerButton.option = spoilerOption
        accessoryBar.update(isPreviewing: isPreviewing)
        // Edits keep a comment's GIF as it is (Trakt's update has no GIF), so only a GIF the picker can replace is removable.
        attachmentView.configure(gif: draft.gif,
                                 isRemovable: configuration.isReadOnly == false && isPreviewing == false && configuration.tools.contains(.gif))
    }

    private func draftDidChange() {
        updateUI()
        renderPreviewIfNeeded()
        session.draftDidChange(draft)
    }

    // MARK: - Tool bar

    private func perform(_ action: ComposerAccessoryBar.Action) {
        guard let markdown = action.markdown else {
            showInsertBubble()
            return
        }
        textView.wrapSelection(prefix: markdown.prefix, suffix: markdown.suffix)
    }

    // MARK: - Options and count

    private func makeOptionsRow() -> UIView {
        let stack = UIStackView(arrangedSubviews: [privacyButton, spoilerButton, previewButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollView.frameLayoutGuide.heightAnchor.constraint(equalTo: scrollView.contentLayoutGuide.heightAnchor)
        ])
        return scrollView
    }

    private var privacyOption: ComposerOptionButton.Option? {
        guard configuration.tools.contains(.privacy) else { return nil }
        let isLocked = configuration.isPrivacyLocked
        let privacy = isLocked ? NotePrivacy.me : draft.privacy
        return ComposerOptionButton.Option(title: privacy.composerTitle,
                                           symbol: privacy.composerSymbol,
                                           isTappable: isLocked == false,
                                           accessibilityLabel: "Visible to: \(privacy.composerTitle)",
                                           accessibilityHint: isLocked ? "Notes on this item are always private." : "Double-tap to change who can see your note.")
    }

    private var spoilerOption: ComposerOptionButton.Option? {
        guard configuration.tools.contains(.spoilerFlag) else { return nil }
        return ComposerOptionButton.Option(title: draft.containsSpoiler ? "Spoiler Alert" : "No Spoilers",
                                           symbol: draft.containsSpoiler ? "exclamationmark.bubble.fill" : "text.bubble",
                                           accessibilityLabel: draft.containsSpoiler ? "Spoiler alert on" : "No spoilers",
                                           accessibilityHint: "Double-tap to switch the spoiler alert.")
    }

    private func cyclePrivacy() {
        switch draft.privacy {
        case .me, .unknown: draft.privacy = .friends
        case .friends: draft.privacy = .all
        case .all: draft.privacy = .me
        }
        draftDidChange()
    }

    private var count: (text: String, spoken: String, isOverLimit: Bool)? {
        if let limit = configuration.characterLimit {
            let remaining = limit - draft.text.count
            return ("\(remaining)",
                    remaining < 0 ? "\(-remaining) characters over the limit" : "\(remaining) characters left",
                    remaining < 0)
        }
        guard configuration.minimumWordCount > 0 else { return nil }
        let words = renderedWordCount
        let text = words == 1 ? "1 word" : "\(words) words"
        return (text, text, false)
    }

    private var previewOption: ComposerOptionButton.Option? {
        guard configuration.tools.contains(.preview), configuration.isReadOnly == false else { return nil }
        let count = count
        let action = isPreviewing ? "Edit" : "Preview"
        return ComposerOptionButton.Option(title: count?.text ?? action,
                                           symbol: isPreviewing ? "pencil" : "eyes",
                                           isWarning: count?.isOverLimit == true,
                                           accessibilityLabel: [action, count?.spoken].compactMap { $0 }.joined(separator: ", "),
                                           accessibilityHint: isPreviewing ? "Returns to editing your text." : "Shows your text as it will look.")
    }

    // MARK: - Insert bubble

    private func showInsertBubble(replacing range: NSRange? = nil) {
        guard insertBubble == nil, isPreviewing == false else { return }
        insertionRange = range ?? textView.selectedRange
        let controller = ComposerInsertViewController(subject: configuration.subject,
                                                      allowsGIF: configuration.tools.contains(.gif) && draft.gif == nil)
        controller.onSelectLink = { [weak self] link, query in
            guard let self = self else { return }
            self.textView.insert(link.markdown, at: self.insertionRange)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if link.searchId != nil {
                TraktAPIProvider.recordSearchSelection(query: query,
                                                       type: link.person != nil ? .person : .moviesAndShow,
                                                       id: link.searchId)
            }
            UIAccessibility.post(notification: .announcement, argument: "Link to \(link.title) inserted")
            self.hideInsertBubble()
        }
        controller.onSelectGIF = { [weak self] item in
            guard let self = self else { return }
            self.draft.gif = item.gif
            self.pickedGIF = item
            self.draftDidChange()
            UIAccessibility.post(notification: .announcement, argument: "GIF attached")
            self.hideInsertBubble()
        }
        controller.onClose = { [weak self] in
            guard let self = self else { return }
            self.hideInsertBubble()
        }
        presentInsertBubble(controller)
    }

    private func presentInsertBubble(_ controller: ComposerInsertViewController) {
        let dimmingView = UIControl()
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        dimmingView.alpha = 0
        dimmingView.isAccessibilityElement = false
        dimmingView.translatesAutoresizingMaskIntoConstraints = false
        dimmingView.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.hideInsertBubble()
        }, for: .touchUpInside)
        let host = insertBubbleHost
        host.addSubview(dimmingView)

        // Not a child view controller: UIKit requires a child's view inside its parent's, and this one covers the navigation bar.
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(controller.view)

        let anchor = accessoryBar.insertAnchorView
        let collapsed = [
            controller.view.leadingAnchor.constraint(equalTo: anchor.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: anchor.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: anchor.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: anchor.bottomAnchor)
        ]
        let inset = ComposerViewController.insertBubbleInset
        let expanded = [
            controller.view.topAnchor.constraint(equalTo: host.topAnchor, constant: inset),
            controller.view.leadingAnchor.constraint(equalTo: host.safeAreaLayoutGuide.leadingAnchor, constant: inset),
            controller.view.trailingAnchor.constraint(equalTo: host.safeAreaLayoutGuide.trailingAnchor, constant: -inset),
            controller.view.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -inset)
        ]
        NSLayoutConstraint.activate([
            dimmingView.topAnchor.constraint(equalTo: host.topAnchor),
            dimmingView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            dimmingView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            dimmingView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ] + collapsed)
        controller.setContentVisible(false)
        host.layoutIfNeeded()

        insertBubble = InsertBubble(controller: controller, dimmingView: dimmingView, collapsed: collapsed, expanded: expanded)
        setInsertChromeHidden(true)
        updateUI()
        controller.focus()

        animateInsertBubble(isOpening: true) {
            NSLayoutConstraint.deactivate(collapsed)
            NSLayoutConstraint.activate(expanded)
            host.layoutIfNeeded()
            dimmingView.alpha = 1
        } completion: {
            UIAccessibility.post(notification: .screenChanged, argument: controller.view)
        }
        fadeInsertBubbleContent(of: controller, visible: true, delay: 0.1)
    }

    private var insertBubbleHost: UIView {
        navigationController?.view ?? view
    }

    private func setInsertChromeHidden(_ isHidden: Bool) {
        UIView.performWithoutAnimation {
            if isHidden {
                navigationItem.setLeftBarButton(nil, animated: false)
                navigationItem.setRightBarButtonItems(nil, animated: false)
            } else {
                navigationItem.setLeftBarButton(cancelItem, animated: false)
                updateRightBarItems(submit: submitItem)
            }
            accessoryBar.setInsertBubbleShown(isHidden)
            navigationController?.navigationBar.layoutIfNeeded()
        }
    }

    private func hideInsertBubble() {
        guard let bubble = insertBubble else { return }
        insertBubble = nil
        updateUI()
        textView.becomeFirstResponder()

        fadeInsertBubbleContent(of: bubble.controller, visible: false, delay: 0)
        animateInsertBubble(isOpening: false) {
            NSLayoutConstraint.deactivate(bubble.expanded)
            NSLayoutConstraint.activate(bubble.collapsed)
            self.insertBubbleHost.layoutIfNeeded()
            bubble.dimmingView.alpha = 0
        } completion: { [weak self] in
            bubble.controller.view.removeFromSuperview()
            bubble.dimmingView.removeFromSuperview()
            guard let self = self else { return }
            self.setInsertChromeHidden(false)
            UIAccessibility.post(notification: .screenChanged, argument: self.textView)
        }
    }

    private func fadeInsertBubbleContent(of controller: ComposerInsertViewController, visible: Bool, delay: TimeInterval) {
        guard UIAccessibility.isReduceMotionEnabled == false else {
            controller.setContentVisible(visible)
            return
        }
        UIView.animate(withDuration: visible ? 0.15 : 0.05, delay: delay, options: [.beginFromCurrentState, .allowUserInteraction]) {
            controller.setContentVisible(visible)
        }
    }

    private func animateInsertBubble(isOpening: Bool, _ animations: @escaping () -> Void, completion: @escaping () -> Void) {
        guard UIAccessibility.isReduceMotionEnabled == false else {
            animations()
            completion()
            return
        }
        let duration: TimeInterval = isOpening ? 0.32 : 0.28
        let delay: TimeInterval = isOpening ? 0 : 0.04
        UIView.animate(springDuration: duration,
                       bounce: isOpening ? 0.3 : 0.25,
                       initialSpringVelocity: 0,
                       delay: delay,
                       options: [.beginFromCurrentState, .allowUserInteraction],
                       animations: animations) { _ in
            if isOpening {
                completion()
            }
        }
        // A spring reports completion only after its last invisible wobble, which delayed the tools coming back.
        if isOpening == false {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration, execute: completion)
        }
    }

    // MARK: - Preview

    private func setPreviewing(_ isPreviewing: Bool) {
        guard isPreviewing != self.isPreviewing, configuration.isReadOnly == false else { return }
        self.isPreviewing = isPreviewing
        showPreview(isPreviewing)
        updateUI()
        if isPreviewing {
            textView.resignFirstResponder()
        } else {
            textView.becomeFirstResponder()
        }
        UIAccessibility.post(notification: .layoutChanged, argument: isPreviewing ? previewTextView : textView)
    }

    private func showPreview(_ isPreviewing: Bool) {
        if isPreviewing {
            renderPreview()
        }
        UIView.performWithoutAnimation {
            textView.isHidden = isPreviewing
            previewTextView.isHidden = isPreviewing == false
            contentStack.layoutIfNeeded()
        }
        if configuration.isReadOnly == false {
            title = isPreviewing ? "Preview" : configuration.title
        }
    }

    @objc private func renderPreviewIfNeeded() {
        guard isPreviewing else { return }
        renderPreview()
    }

    private func renderPreview() {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            previewTextView.attributedText = NSAttributedString(string: "Nothing to preview yet.",
                                                                attributes: [.font: UIFont.preferredFont(forTextStyle: .body),
                                                                             .foregroundColor: UIColor.placeholderText])
            return
        }
        previewTextView.attributedText = renderedText()
    }

    private var renderedWordCount: Int {
        if let cache = wordCountCache, cache.text == draft.text {
            return cache.count
        }
        let count = renderedText().string.wordCount
        wordCountCache = (draft.text, count)
        return count
    }

    private var canSubmit: Bool {
        if let limit = configuration.characterLimit, draft.text.count > limit {
            return false
        }
        return session.canSubmit(draft)
            && (configuration.minimumWordCount == 0 || draft.gif != nil || renderedWordCount >= configuration.minimumWordCount)
    }

    private func renderedText() -> NSAttributedString {
        let tint = UIColor(asset: .globalTint)
        markdownParser.highlight.highlightColor = tint.withAlphaComponent(0.4)
        markdownParser.link.color = tint
        markdownParser.automaticLink.color = tint
        return markdownParser.parse(draft.text.htmlDecoded.emojiUnescapedString)
    }

    // MARK: - Cancel and submit

    private func cancel() {
        guard configuration.isReadOnly == false else {
            dismiss(animated: true)
            return
        }
        switch session.cancelPolicy(for: draft) {
        case .dismiss:
            dismiss(animated: true)
        case .confirm(let title, let message, let keepTitle, let loseTitle):
            presentSheet(title: title, message: message, actions: [
                ComposerAlertAction(title: keepTitle, style: .cancel),
                ComposerAlertAction(title: loseTitle, style: .destructive) { [weak self] in
                    guard let self = self else { return }
                    self.session.discardDraft()
                    self.dismiss(animated: true)
                }
            ], anchor: cancelItem)
        case .offerDraft(let title, let message):
            presentSheet(title: title, message: message, actions: [
                ComposerAlertAction(title: "Keep Composing", style: .cancel),
                ComposerAlertAction(title: "Save Draft") { [weak self] in
                    guard let self = self else { return }
                    self.session.saveDraft(self.draft)
                    self.dismiss(animated: true)
                },
                ComposerAlertAction(title: "Lose Comment", style: .destructive) { [weak self] in
                    guard let self = self else { return }
                    self.session.discardDraft()
                    self.dismiss(animated: true)
                }
            ], anchor: cancelItem)
        }
    }

    private func submit() {
        guard configuration.isReadOnly == false, isSubmitting == false, canSubmit else { return }
        textView.resignFirstResponder()
        session.submit(draft, from: self, anchor: submitItem) { [weak self] outcome in
            guard let self = self else { return }
            self.setSubmitting(false)
            switch outcome {
            case .completed:
                // Klipy ranks GIFs on usage, so it hears about the one that just posted.
                if let slug = self.pickedGIF?.shareSlug, self.draft.gif == self.pickedGIF?.gif {
                    KlipyAPIProvider.share(slug: slug)
                }
                self.dismiss(animated: true)
            case .keptOpen, .failed:
                break
            }
        }
    }

    func setSubmitting(_ isSubmitting: Bool) {
        self.isSubmitting = isSubmitting
        view.window?.isUserInteractionEnabled = isSubmitting == false
        if isSubmitting {
            let indicator = UIActivityIndicatorView(style: .medium)
            indicator.startAnimating()
            updateRightBarItems(submit: UIBarButtonItem(customView: indicator))
        } else {
            updateRightBarItems(submit: submitItem)
        }
        updateUI()
    }

    private func scrollToCaret() {
        guard let range = textView.selectedTextRange else { return }
        let caret = textView.caretRect(for: range.end)
        guard caret.isNull == false, caret.isInfinite == false else { return }
        let rect = textView.convert(caret, to: scrollView).insetBy(dx: 0, dy: -12)
        scrollView.scrollRectToVisible(rect, animated: false)
    }

    // MARK: - Key commands

    override var keyCommands: [UIKeyCommand]? {
        var commands = [UIKeyCommand]()
        if configuration.isReadOnly == false {
            commands.append(UIKeyCommand(title: session.submitTitle(for: draft), action: #selector(submitFromKeyboard), input: "\r", modifierFlags: .command))
        }
        if configuration.tools.contains(.formatting) {
            commands.append(UIKeyCommand(title: "Insert Link", action: #selector(insertLinkFromKeyboard), input: "k", modifierFlags: .command))
        }
        let escape = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(escapeFromKeyboard))
        escape.wantsPriorityOverSystemBehavior = true
        commands.append(escape)
        return commands
    }

    @objc private func submitFromKeyboard() {
        submit()
    }

    @objc private func insertLinkFromKeyboard() {
        showInsertBubble()
    }

    @objc private func escapeFromKeyboard() {
        if insertBubble != nil {
            hideInsertBubble()
        } else {
            cancel()
        }
    }

    // MARK: - Alerts

    private func makeAlert(title: String?, message: String?, style: UIAlertController.Style, actions: [ComposerAlertAction]) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        for action in actions {
            alert.addAction(UIAlertAction(title: action.title, style: action.style) { [weak self] _ in
                action.handler?()
                guard let self = self else { return }
                self.presentNextAlert()
            })
        }
        return alert
    }

    private func enqueue(_ alert: UIAlertController) {
        pendingAlerts.append(alert)
        presentNextAlert()
    }

    private func presentNextAlert() {
        guard pendingAlerts.isEmpty == false,
              presentedViewController == nil,
              view.window != nil,
              navigationController?.isBeingDismissed != true else { return }
        let alert = pendingAlerts.removeFirst()
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension ComposerViewController: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard textView === self.textView else { return false }
        if text == "/", configuration.tools.contains(.formatting), self.textView.startsWord(at: range.location) {
            showInsertBubble(replacing: range)
            return false
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === self.textView else { return }
        self.textView.textDidChange()
        guard draft.text != textView.text else {
            updateUI()
            return
        }
        draft.text = textView.text
        draftDidChange()
        scrollToCaret()
    }

    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        textView === previewTextView ? nil : defaultAction
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ComposerViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        guard insertBubble == nil else { return }
        cancel()
    }
}
