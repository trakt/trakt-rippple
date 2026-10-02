//
//  SmartListPromptViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 02/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import UIKit

/// The first step of a new smart list: describe it in a few words, and the on-device model fills in the builder's
/// sentence, or skip to build it from scratch.
final class SmartListPromptViewController: UIViewController, UITextViewDelegate, UIScrollViewDelegate {
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let examplesStack = UIStackView()
    private let contentStack = UIStackView()
    private let scrollView = UIScrollView()
    private let loader = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
    private var promptTask: Task<Void, Never>?

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
                self.textView.text = example
                self.textViewDidChange(self.textView)
                self.submit()
            })
        }
        let skipButton = UIButton.smartListOption("Skip and build it yourself", image: UIImage(systemName: "arrow.right")) { [weak self] in
            guard let self = self else { return }
            self.showBuilder(with: SmartListDraft())
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
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = self
        scrollView.addSubview(contentStack)
        view.addSubview(scrollView)

        loader.translatesAutoresizingMaskIntoConstraints = false
        // Same loader as the rest of the app.
        loader.color = UIColor(asset: .globalTint)
        loader.type = .ballScaleMultiple
        loader.isHidden = true
        view.addSubview(loader)

        // Lined up with the builder's sentence, which starts 40 points in.
        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        // Content as tall as the screen, growing only when the examples need more room.
        let fitsScreen = content.heightAnchor.constraint(equalTo: frame.heightAnchor)
        fitsScreen.priority = .defaultLow
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 120),
            // Room to scroll the last examples up, where they're no longer dimmed.
            content.bottomAnchor.constraint(greaterThanOrEqualTo: contentStack.bottomAnchor, constant: 160),
            content.heightAnchor.constraint(greaterThanOrEqualTo: frame.heightAnchor),
            fitsScreen,
            contentStack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -40),
            content.widthAnchor.constraint(equalTo: frame.widthAnchor),
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: textView.widthAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualTo: placeholderLabel.heightAnchor),
            loader.widthAnchor.constraint(equalToConstant: 50),
            loader.heightAnchor.constraint(equalToConstant: 50),
            loader.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loader.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

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
            showBuilder(with: SmartListDraft())
            return
        }
        textView.resignFirstResponder()
        setProcessing(true)

        promptTask = Task { @MainActor [weak self] in
            let definition = await SmartListAssistant.definition(from: prompt)
            guard Task.isCancelled == false else { return }
            guard let self = self else { return }
            self.promptTask = nil
            guard let definition = definition else {
                self.setProcessing(false)
                SwiftMessages.show(message: "🤔 Couldn’t turn that into a Smart List. Try again or rephrase your request")
                self.textView.becomeFirstResponder()
                return
            }
            var draft = SmartListDraft()
            draft.source = definition.source
            draft.mediaType = definition.mediaType
            draft.filters = definition.filters
            self.showBuilder(with: draft)
        }
    }

    /// Only the Rippple loader is shown while the model works. Cancel remains available.
    private func setProcessing(_ isProcessing: Bool) {
        view.isUserInteractionEnabled = isProcessing == false
        navigationController?.isModalInPresentation = isProcessing
        contentStack.isHidden = isProcessing
        loader.isHidden = isProcessing == false
        if isProcessing {
            loader.startAnimating()
        } else {
            loader.stopAnimating()
        }
        navigationItem.rightBarButtonItem = isProcessing ? nil : nextItem
    }

    /// Replaces this step, so going forward can't come back to it.
    private func showBuilder(with draft: SmartListDraft) {
        guard let builder = SmartListBuilderViewController.make(list: nil, draft: draft) else { return }
        textView.resignFirstResponder()
        navigationController?.setViewControllers([builder], animated: true)
    }
}

// MARK: - Examples

/// Examples change with each visit: a few about now (the season, this year, the device language), then a rotating
/// selection of the others. Each one reads as the conditions it turns into.
private enum SmartListPromptExamples {
    private static let count = 16

    private static let others = [
        "Trending horror movies from the 80s",
        "Korean dramas on Netflix I haven’t watched",
        "Popular comedies under 90 minutes with a good rating",
        "Movies I can watch with my kids",
        "Trending movies I can watch with my teenagers",
        "Upcoming sci-fi shows",
        "Anime from Japan that has ended",
        "Well rated thrillers on my watchlist",
        "Free movies from the 90s that aren’t too scary",
        "Crime shows from the UK that have ended",
        "Superhero movies that are coming soon",
        "Japanese anime I haven’t watched",
        "PG-13 action movies",
        "Comedies from the eighties",
        "Recommended thrillers I haven’t watched",
        "Trending shows on Disney Plus",
        "French movies from the 60s",
        "Popular westerns from before 1980",
        "Short horror movies under 90 minutes",
        "War movies with a great rating",
        "Spanish crime shows on Netflix",
        "Mystery shows that are still running",
        "Family movies on Disney Plus",
        "Upcoming fantasy movies",
        "Trending documentaries",
        "Popular action movies from the 2000s",
        "Fantasy shows that have ended",
        "Highly rated dramas from Korea",
        "Free horror movies",
        "Musicals I can watch with my kids",
        "Popular thrillers with no nudity"
    ]

    static func current(on date: Date = .now, locale: Locale = .current) -> [String] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        var timely = [String]()
        switch calendar.component(.month, from: date) {
        case 2: timely.append("Popular romance movies for Valentine’s Day")
        case 10: timely.append("Popular horror movies for Halloween")
        case 12: timely.append("Holiday movies I can watch with my kids")
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
