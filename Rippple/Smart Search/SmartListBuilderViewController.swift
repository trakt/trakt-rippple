//
//  SmartListBuilderViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 30/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import FoundationModels
import LRUCache
import Moya
import Receiver
import UIKit

/// Builds a Trakt smart list from a plain English sentence, like `SmartSearchBuilderViewController`.
/// Tapping a highlighted word edits it, and "Add Condition" appends clauses to the sentence.
final class SmartListBuilderViewController: SearchResultsViewController {
    @IBOutlet private var sentenceLabel: UILabel!
    @IBOutlet private var addConditionButton: UIButton!
    @IBOutlet private var emptyLabel: UILabel!
    @IBOutlet private var saveButton: UIBarButtonItem!

    private var list: List?
    private var owner: User?
    private var original = SmartListDraft()
    private var draft = SmartListDraft() {
        didSet {
            guard isViewLoaded else { return }
            if draft.mediaType != oldValue.mediaType {
                clearShowOnlyConditions()
            }
            draftDidChange()
        }
    }

    private var isSaving = false
    private var nameSuggestionsPrefetch: _Concurrency.Task<Void, Never>?
    private weak var detailsViewController: SmartListDetailsViewController?
    private var tokenMenus = [UIMenu]()
    private var laidOutSize = CGSize.zero
    private let disposeBag = DisposeBag()

    private static let tokenKey = NSAttributedString.Key("SmartListBuilderToken")
    private static let previewLimit = 25

    /// Presents the builder to create a smart list, or to edit one owned by the current user. New lists start from a
    /// prompt when the on-device model can turn it into conditions.
    static func present(from controller: UIViewController, list: List? = nil) {
        if let list = list, list.isSmartList == false || list.user.isCurrentUser == false { return }
        if list == nil, SmartListAssistant.isAvailable {
            guard canCreate() else { return }
            controller.present(UINavigationController(rootViewController: SmartListPromptViewController()), animated: true)
            return
        }
        present(from: controller, list: list, draft: list?.smartList.map { SmartListDraft(smartList: $0) } ?? SmartListDraft())
    }

    /// Presents the builder to create a new smart list with the conditions of any smart list the user can see.
    static func present(from controller: UIViewController, duplicating list: List) {
        guard let smartList = list.smartList else { return }
        var draft = SmartListDraft(smartList: smartList)
        draft.name = "\(smartList.name) (Copy)"
        draft.privacy = SmartListDraft().privacy
        present(from: controller, list: nil, draft: draft)
    }

    private static func present(from controller: UIViewController, list: List?, draft: SmartListDraft) {
        guard list != nil || canCreate(), let builder = make(list: list, draft: draft) else { return }
        controller.present(UINavigationController(rootViewController: builder), animated: true)
    }

    /// New lists count toward the account limit, checked here so every way of creating one is covered.
    private static func canCreate() -> Bool {
        guard SessionManager.shared.isLoggedIn else { return false }
        guard ListsManager.shared.smartLists.count < UserManager.shared.currentUserSmartListLimit else {
            UIApplication.shared.presentAccountLimitReached()
            return false
        }
        return true
    }

    static func make(list: List?, draft: SmartListDraft) -> SmartListBuilderViewController? {
        guard SessionManager.shared.isLoggedIn, let owner = UserManager.shared.currentUser,
              let builder = UIStoryboard(name: "SmartSearch", bundle: nil)
              .instantiateViewController(withIdentifier: "SmartListBuilderViewController") as? SmartListBuilderViewController else { return nil }
        builder.list = list
        builder.owner = owner
        builder.original = draft
        builder.draft = draft
        return builder
    }

    override func viewDidLoad() {
        resultsLimit = SmartListBuilderViewController.previewLimit
        super.viewDidLoad()
        // Enabled after the first refresh, which runs before the preview service is set: it keeps "Loading..." meanwhile.
        showsEmptyStateWithoutService = true

        isModalInPresentation = true

        sentenceLabel.isUserInteractionEnabled = true
        addConditionButton.showsMenuAsPrimaryAction = true
        emptyLabel.text = "Nothing matches these conditions right now.\nTry removing one."
        if let header = sentenceLabel.superview {
            tableView.tableHeaderView = header
        }

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: SmartListBuilderViewController, _) in
            self.draftDidChange()
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }.disposed(by: disposeBag)

        draftDidChange()
        loadWatchNowServiceNames()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if laidOutSize != view.bounds.size {
            laidOutSize = view.bounds.size
            layoutHeader()
        }
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction func save(_ sender: Any) {
        guard isSaving == false else { return }
        let sentence = SmartListSentence(source: draft.source, mediaType: draft.mediaType, filters: draft.filters).string
        let details = SmartListDetailsViewController(name: draft.name, privacy: draft.privacy, isNew: list == nil, sentence: sentence) { [weak self] name, privacy in
            guard let self = self else { return }
            self.draft.name = name
            self.draft.privacy = privacy
            self.submit()
        }
        detailsViewController = details
        navigationController?.pushViewController(details, animated: true)
    }

    /// Services of an existing list read with their Trakt names once they are loaded.
    private func loadWatchNowServiceNames() {
        let broadValues = SmartListChoices.watchNow.map(\.value)
        guard draft.filters.watchnow?.contains(where: { broadValues.contains($0) == false }) == true else { return }
        _Concurrency.Task { @MainActor [weak self] in
            _ = await SmartListChoices.watchNowChoices()
            guard let self = self else { return }
            self.sentenceLabel.attributedText = self.sentence()
            self.layoutHeader()
        }
    }

    // MARK: - Sentence

    private func draftDidChange() {
        title = draft.name.isEmpty ? (list == nil ? "Smart List" : list?.name) : draft.name
        saveButton.isEnabled = isSaving == false
        addConditionButton.menu = conditionsMenu()
        sentenceLabel.attributedText = sentence()
        service = previewService
        layoutHeader()
        prefetchNameSuggestions()
    }

    deinit {
        nameSuggestionsPrefetch?.cancel()
    }

    /// Names are suggested ahead of the save form, once conditions stop changing for a moment, so they show up at once.
    private func prefetchNameSuggestions() {
        nameSuggestionsPrefetch?.cancel()
        guard SmartListNameSuggestion.isAvailable else { return }
        let sentence = SmartListSentence(source: draft.source, mediaType: draft.mediaType, filters: draft.filters).string
        nameSuggestionsPrefetch = _Concurrency.Task { @MainActor in
            try? await _Concurrency.Task.sleep(for: .seconds(1))
            guard _Concurrency.Task.isCancelled == false else { return }
            SmartListNameSuggestion.prefetch(for: sentence)
        }
    }

    private func sentence() -> NSAttributedString {
        tokenMenus = []
        let text = NSMutableAttributedString()
        for segment in SmartListSentence(source: draft.source, mediaType: draft.mediaType, filters: draft.filters).segments {
            switch segment {
            case .text(let string):
                text.append(NSAttributedString(string: string, attributes: lowAttributes))
            case .token(let string, let token):
                // Remembers the menu each tappable word opens.
                var attributes = highAttributes
                attributes[SmartListBuilderViewController.tokenKey] = tokenMenus.count
                tokenMenus.append(menu(for: token))
                text.append(NSAttributedString(string: string, attributes: attributes))
            }
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 18
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        return text
    }

    private var lowAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor.secondaryLabel,
         .font: UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .regular), maximumPointSize: 34)]
    }

    private var highAttributes: [NSAttributedString.Key: Any] {
        [.foregroundColor: UIColor.label,
         .font: UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .medium), maximumPointSize: 34),
         .underlineStyle: NSUnderlineStyle.single.union(.patternDot).rawValue,
         .underlineColor: UIColor.secondaryLabel]
    }

    // MARK: - Menus

    private func menu(for token: SmartListSentence.Token) -> UIMenu {
        switch token {
        case .mediaType:
            return mediaTypeMenu()
        case .source:
            return sourceMenu()
        case .value(let condition, let value):
            return valueMenu(value, of: condition)
        case .matchOperator(let keyPath):
            return operatorMenu(keyPath)
        case .singleValue(let condition, let value):
            return singleValueMenu(value, of: condition)
        case .lowerBound(let condition, let lower, let upper):
            let values = condition.values.filter { $0 <= upper }.reversed().map { value in
                UIAction(title: condition.format(value), state: value == lower ? .on : .off) { [weak self] _ in
                    guard let self = self else { return }
                    condition.set(&self.draft.filters, [value, upper])
                }
            }
            return UIMenu(title: "From", children: [UIMenu(options: .displayInline, children: values), removeRangeAction(condition)])
        case .upperBound(let condition, let lower, let upper):
            let values = condition.values.filter { $0 >= lower }.reversed().map { value in
                UIAction(title: condition.format(value), state: value == upper ? .on : .off) { [weak self] _ in
                    guard let self = self else { return }
                    condition.set(&self.draft.filters, [lower, value])
                }
            }
            return UIMenu(title: "To", children: [UIMenu(options: .displayInline, children: values), removeRangeAction(condition)])
        case .parental(let condition, let level):
            return parentalMenu(level: level, of: condition)
        case .includeUnrated:
            return removeMenu(title: "Only Titles With a Parents Guide") { $0.parentalIncludeUnrated = nil }
        case .hidden(let condition):
            return removeMenu(title: "Remove “\(condition.token)”") { $0[keyPath: condition.keyPath] = nil }
        }
    }

    private func valueMenu(_ value: String, of condition: SmartListConditions.ValueCondition) -> UIMenu {
        let title = condition.format(value)
        let remove = UIAction(title: "Remove \(title)", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.toggle(value, of: condition)
        }
        var children: [UIMenuElement] = [remove]
        if let load = condition.load {
            children.insert(UIMenu(title: "Add \(condition.title)", image: UIImage(systemName: "plus.circle"), children: [choicesMenuElement(for: condition, load: load)]), at: 0)
        }
        return UIMenu(title: condition.title, children: children)
    }

    private func singleValueMenu(_ value: Double, of condition: SmartListConditions.RangeCondition) -> UIMenu {
        let values = UIMenu(title: condition.title, options: .displayInline, children: condition.values.reversed().map { candidate in
            UIAction(title: condition.format(candidate), state: candidate == value ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                condition.set(&self.draft.filters, [candidate, candidate])
            }
        })
        let makeRange = UIAction(title: "Set a Range", image: UIImage(systemName: "arrow.left.and.right")) { [weak self] _ in
            guard let self = self, let maximum = condition.values.last else { return }
            condition.set(&self.draft.filters, [value, max(value, maximum)])
        }
        return UIMenu(title: condition.title, children: [makeRange, UIMenu(title: "Values", children: [values]), removeRangeAction(condition)])
    }

    private func removeRangeAction(_ condition: SmartListConditions.RangeCondition) -> UIAction {
        UIAction(title: "Remove Condition", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            condition.set(&self.draft.filters, nil)
        }
    }

    private func parentalMenu(level: Int, of condition: SmartListConditions.ParentalCondition) -> UIMenu {
        let severities = SmartListConditions.severities
        let levels = severities.indices.map { index in
            UIAction(title: severities[index].capitalized, state: index == level ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: condition.keyPath] = [0, Double(index)]
            }
        }
        let remove = UIAction(title: "Remove Condition", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.draft.filters[keyPath: condition.keyPath] = nil
        }
        return UIMenu(title: condition.title, children: [UIMenu(options: .displayInline, children: levels), remove])
    }

    private func mediaTypeMenu() -> UIMenu {
        UIMenu(children: SmartListMediaType.selectableCases.map { mediaType in
            UIAction(title: mediaType.title, state: mediaType == draft.mediaType ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.mediaType = mediaType
            }
        })
    }

    private func sourceMenu() -> UIMenu {
        let charts: [SmartListSource] = [.trending, .popular, .anticipated]
        let personal: [SmartListSource] = [.recommendations, .watchlist]
        let current = draft.source
        let action = { [weak self] (source: SmartListSource) -> UIAction in
            UIAction(title: source.title,
                     subtitle: source.details,
                     state: source == current ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.source = source
                if source == .watchlist {
                    self.draft.filters.ignoreWatchlisted = nil
                }
            }
        }
        return UIMenu(children: [UIMenu(options: .displayInline, children: charts.map(action)),
                                 UIMenu(options: .displayInline, children: personal.map(action))])
    }

    private func operatorMenu(_ keyPath: WritableKeyPath<SmartListFilters, SmartListFilters.Operator?>) -> UIMenu {
        let matchesAll = draft.filters[keyPath: keyPath] == .and
        return UIMenu(title: "Titles Must Match", children: [
            UIAction(title: "Any of These", state: matchesAll ? .off : .on) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: keyPath] = nil
            },
            UIAction(title: "All of These", state: matchesAll ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: keyPath] = .and
            }
        ])
    }

    private func removeMenu(title: String, remove: @escaping (inout SmartListFilters) -> Void) -> UIMenu {
        UIMenu(children: [UIAction(title: title, image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            remove(&self.draft.filters)
        }])
    }

    /// The "Add Condition" menu, built like the Smart Search one with the extra smart list conditions.
    private func conditionsMenu() -> UIMenu {
        let mediaType = draft.mediaType
        var values = [UIMenuElement]()
        for condition in SmartListConditions.values where condition.isAvailable(mediaType) {
            guard let load = condition.load else { continue }
            values.append(UIMenu(title: condition.title, image: UIImage(systemName: condition.symbol), children: [choicesMenuElement(for: condition, load: load)]))
        }

        let ranges = SmartListConditions.ranges.map { condition -> UIMenuElement in
            let isActive = condition.get(draft.filters) != nil
            return UIAction(title: condition.title, state: isActive ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                condition.set(&self.draft.filters, isActive ? nil : condition.initial)
            }
        }
        let releaseDates = UIMenu(title: "Release Date", image: UIImage(systemName: "calendar"), children: releaseDateElements())
        let ratings = UIMenu(title: "Runtime & Ratings", image: UIImage(systemName: "star"), children: Array(ranges.dropFirst()))

        let parental = SmartListConditions.parental.map { condition -> UIMenuElement in
            let isActive = draft.filters[keyPath: condition.keyPath] != nil
            return UIAction(title: condition.title, state: isActive ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: condition.keyPath] = isActive ? nil : [0, 1]
            }
        }
        let includeUnrated = UIAction(title: "Include Titles Without a Parents Guide",
                                      state: draft.filters.parentalIncludeUnrated == true ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.draft.filters.parentalIncludeUnrated = self.draft.filters.parentalIncludeUnrated == true ? nil : true
        }
        let parentsGuide = UIMenu(title: "Parents Guide", image: UIImage(systemName: "figure.and.child.holdinghands"),
                                  children: parental + [UIMenu(options: .displayInline, children: [includeUnrated])])

        let hidden = SmartListConditions.hidden
            .filter { $0.isAvailable(mediaType) && ($0.keyPath != \SmartListFilters.ignoreWatchlisted || draft.source != .watchlist) }
            .map { condition -> UIMenuElement in
                let isActive = draft.filters[keyPath: condition.keyPath] == true
                return UIAction(title: condition.title, state: isActive ? .on : .off) { [weak self] _ in
                    guard let self = self else { return }
                    self.draft.filters[keyPath: condition.keyPath] = isActive ? nil : true
                }
            }
        let hide = UIMenu(title: "Hide", image: UIImage(systemName: "eye.slash"), children: hidden)

        return UIMenu(children: [UIMenu(options: .displayInline, children: values),
                                 UIMenu(options: .displayInline, children: [releaseDates, ratings, parentsGuide]),
                                 UIMenu(options: .displayInline, children: [hide])])
    }

    private func releaseDateElements() -> [UIMenuElement] {
        guard let years = SmartListConditions.ranges.first else { return [] }
        let year = Double(SmartListConditions.currentYear)
        let set = { [weak self] (range: [Double]) -> UIActionHandler in
            { [weak self] _ in
                guard let self = self else { return }
                years.set(&self.draft.filters, range)
            }
        }
        let current = years.get(draft.filters)
        let thisYear = UIAction(title: "This Year (\(Int(year)))", state: current == [year, year] ? .on : .off, handler: set([year, year]))
        let decades = stride(from: 2020, through: 1950, by: -10).map { decade -> UIAction in
            let range = [Double(decade), Double(decade + 9)]
            return UIAction(title: "\(decade)s", state: current == range ? .on : .off, handler: set(range))
        }
        var elements: [UIMenuElement] = [thisYear, UIMenu(title: "Decades", children: decades)]
        if current != nil {
            elements.append(UIAction(title: "Remove Condition", image: UIImage(systemName: "minus.circle"), attributes: .destructive, handler: set([])))
        }
        return elements
    }

    /// Loads choices when the menu opens, with the selected values checked. Long lists are grouped alphabetically.
    private func choicesMenuElement(for condition: SmartListConditions.ValueCondition, load: @escaping (SmartListMediaType) async throws -> [SmartListChoice]) -> UIMenuElement {
        let mediaType = draft.mediaType
        return UIDeferredMenuElement.uncached { [weak self] completion in
            _Concurrency.Task { @MainActor [weak self] in
                guard let self = self else {
                    completion([])
                    return
                }
                guard let choices = try? await load(mediaType), choices.isEmpty == false else {
                    completion([UIAction(title: "Couldn’t Load \(condition.title)", attributes: .disabled) { _ in }])
                    return
                }
                let selected = self.draft.filters[keyPath: condition.keyPath] ?? []
                let ungrouped = choices.filter { $0.group == nil }
                var elements = self.choiceElements(for: ungrouped.filter { $0.isQuickPick == false }, selected: selected, of: condition)
                let quickPicks = ungrouped.filter(\.isQuickPick)
                if quickPicks.isEmpty == false {
                    let children = self.choiceElements(for: quickPicks, selected: selected, of: condition, groupsByLetter: false)
                    elements.append(UIMenu(options: .displayInline, children: children))
                }
                let groups = choices.compactMap(\.group).removingDuplicates()
                for group in groups {
                    let children = self.choiceElements(for: choices.filter { $0.group == group }, selected: selected, of: condition, groupsByLetter: group.groupsByLetter)
                    elements.append(UIMenu(options: .displayInline, children: [UIMenu(title: group.title, children: children)]))
                }
                completion(elements)
            }
        }
    }

    private func choiceElements(for choices: [SmartListChoice],
                                selected: [String],
                                of condition: SmartListConditions.ValueCondition,
                                groupsByLetter: Bool = true) -> [UIMenuElement] {
        let actions = choices.map { choice in
            UIAction(title: choice.title, subtitle: choice.subtitle, state: selected.contains(choice.value) ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.toggle(choice.value, of: condition)
            }
        }
        guard groupsByLetter, actions.count > 40 else { return actions }
        let groups = Dictionary(grouping: actions) { action -> String in
            let letter = action.title.prefix(1).uppercased()
            return letter.rangeOfCharacter(from: .letters) == nil ? "#" : letter
        }
        return groups.keys.sorted().map { UIMenu(title: $0, children: groups[$0] ?? []) }
    }

    private func toggle(_ value: String, of condition: SmartListConditions.ValueCondition) {
        var values = draft.filters[keyPath: condition.keyPath] ?? []
        if let index = values.firstIndex(of: value) {
            values.remove(at: index)
        } else {
            values.append(value)
        }
        draft.filters[keyPath: condition.keyPath] = values.isEmpty ? nil : values
    }

    /// Show-only conditions are cleared when switching to movies so they are not saved silently.
    private func clearShowOnlyConditions() {
        guard draft.mediaType == .movies else { return }
        draft.filters.networks = nil
        draft.filters.ignoreWatching = nil
        draft.filters.ignoreEnded = nil
        draft.filters.ignoreAiring = nil
    }

    // MARK: - Layout

    private func layoutHeader() {
        guard let header = sentenceLabel.superview, tableView.bounds.width > 0 else { return }
        header.frame.size.width = tableView.bounds.width
        header.setNeedsLayout()
        header.layoutIfNeeded()
        // Same proportions as the Smart Search builder: the sentence fills most of the screen above the results.
        let height = max(view.bounds.height - 300, sentenceLabel.bounds.height + 300)
        if header.frame.height != height {
            header.frame.size.height = height
            tableView.tableHeaderView = header
            header.layoutIfNeeded()
        }
        placeTokenButtons()
    }

    /// Places a menu button over every line fragment of each tappable word, so wrapped and repeated words work.
    private func placeTokenButtons() {
        sentenceLabel.subviews.forEach { $0.removeFromSuperview() }
        guard let text = sentenceLabel.attributedText, sentenceLabel.bounds.width > 0 else { return }

        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: sentenceLabel.bounds.width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = sentenceLabel.lineBreakMode
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)

        let lineHeight = (highAttributes[.font] as? UIFont)?.lineHeight ?? 28
        text.enumerateAttribute(SmartListBuilderViewController.tokenKey, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let index = value as? Int, tokenMenus.indices.contains(index) else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let word = (text.string as NSString).substring(with: range)
            layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                                  withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                                  in: container) { rect, _ in
                let button = UIButton(frame: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(rect.height, lineHeight)))
                button.showsMenuAsPrimaryAction = true
                button.menu = self.tokenMenus[index]
                button.accessibilityLabel = word
                button.accessibilityHint = "Opens options for this condition."
                self.sentenceLabel.addSubview(button)
            }
        }
    }

    // MARK: - Preview

    /// The saved list shows its real items. Drafts preview the Trakt endpoint of their source with their conditions:
    /// Trakt applies the same filters there as it does for smart lists, like trakt-web's preview.
    private var previewService: TraktAPIService? {
        let pageInfo = PageInfo.firstPage(with: SmartListBuilderViewController.previewLimit)
        if let slug = list?.smartListSlug, draft.isSameDefinition(as: original) {
            return .smartListItems(slug: slug, pageInfo: pageInfo)
        }
        guard let path = previewPath else { return nil }
        return .savedFilter(section: "smart_list_preview", path: path, query: draft.filters.previewQuery, pageInfo: pageInfo)
    }

    private var previewPath: String? {
        guard draft.mediaType != .unknown else { return nil }
        let mediaType = draft.mediaType.rawValue
        switch draft.source {
        case .trending, .popular, .anticipated, .recommendations:
            return "/\(mediaType)/\(draft.source.rawValue)"
        case .watchlist:
            // Sorted like Trakt resolves watchlist smart lists.
            let types = draft.mediaType == .movies ? "movie" : (draft.mediaType == .shows ? "show" : "movie,show")
            return "/sync/watchlist/\(types)/added/desc"
        case .discover, .library, .unknown:
            // Not offered by the builder: lists created elsewhere preview their saved items until their source changes.
            return nil
        }
    }

    // MARK: - Saving

    private func submit() {
        guard isSaving == false, SessionManager.shared.isLoggedIn else { return }
        isSaving = true
        saveButton.isEnabled = false
        SwiftMessages.show(message: "Saving Smart List...", style: .loading)

        let draft = self.draft
        if let slug = list?.smartListSlug {
            // Trakt answers updates with an empty 204 (the contract documents a 200 with the definition), and keeps the slug.
            TraktAPIProvider.provider.request(.updateSmartList(slug: slug, draft),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                let updated = Result<String, Error> {
                    _ = try result.get().filterSuccessfulStatusCodes()
                    return slug
                }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.didSave(updated, message: "👍 Your Smart List has been updated")
                }
            }
            return
        }

        // Creations only return identifiers.
        TraktAPIProvider.provider.request(.createSmartList(draft),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            let created = Result<String, Error> {
                let response = try result.get().filterSuccessfulStatusCodes()
                let created = try response.map(SmartListCreated.self, using: TraktAPIProvider.decoder)
                guard let slug = created.identifiers.slug else { throw MoyaError.jsonMapping(response) }
                return slug
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.didSave(created, message: "✨ Your Smart List has been created")
            }
        }
    }

    /// Fetches the definition Trakt stored, which owner requests read uncached.
    private func didSave(_ result: Result<String, Error>, message: String) {
        guard let owner = owner else { return }
        let slug: String
        switch result {
        case .success(let savedSlug):
            slug = savedSlug
        case .failure(let error):
            isSaving = false
            saveButton.isEnabled = true
            detailsViewController?.didFailToSave()
            // Account limits are presented by the retry policy.
            if (error as? MoyaError)?.response?.statusCode != 420 {
                SwiftMessages.show(message: "😓 Couldn’t save your Smart List", style: .error(error))
            }
            return
        }

        TraktAPIProvider.fetchSmartList(slug: slug, user: owner) { [weak self] result in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                switch result {
                case .success(let list):
                    ListsManager.shared.save(smartList: list)
                    onListChangedTransmitter.broadcast([list])
                case .failure(let error):
                    // The list was saved: refresh everything rather than reporting a failure.
                    print("smartList request failure \(error)")
                    ListsManager.shared.refresh()
                }
                SwiftMessages.show(message: message)
                self.dismiss(animated: true)
            }
        }
    }
}

// MARK: - Name & Privacy

/// The last step before saving: names the smart list and sets who can see it, like the custom list form.
private final class SmartListDetailsViewController: UITableViewController, UITextFieldDelegate {
    /// Trakt only enforces public and private smart lists: friends lists are visible to their owner alone.
    private static let privacies: [ListPrivacy] = [.me, .all]
    private static let nameRow = 1

    private let isNew: Bool
    private let sentence: String
    private let onSave: (String, ListPrivacy) -> Void
    private let nameField = UITextField()
    private let privacyControl = RipppleSegmentedControl(items: ["Private", "Public"])
    private var nameSuggestionTask: _Concurrency.Task<Void, Never>?
    /// `nil` while the on-device model is suggesting names.
    private var nameSuggestions: [String]?
    private var showsNameSuggestions = SmartListNameSuggestion.isAvailable

    init(name: String, privacy: ListPrivacy, isNew: Bool, sentence: String, onSave: @escaping (String, ListPrivacy) -> Void) {
        self.isNew = isNew
        self.sentence = sentence
        self.onSave = onSave
        super.init(style: .insetGrouped)
        nameField.text = name
        privacyControl.selectedSegmentIndex = SmartListDetailsViewController.privacies.firstIndex(of: privacy) ?? 0
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        nameSuggestionTask?.cancel()
    }

    private var trimmedName: String {
        nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    override func loadView() {
        // Matches the custom list form.
        tableView = TintedTableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        // Room to scroll every suggestion above the keyboard, which scrolling puts away.
        tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 160))
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = isNew ? "Add a smart list" : "Update your smart list"
        navigationItem.rightBarButtonItem = saveItem

        nameField.placeholder = "Name your list"
        nameField.font = .preferredFont(forTextStyle: .body)
        nameField.adjustsFontForContentSizeCategory = true
        nameField.autocapitalizationType = .sentences
        nameField.clearButtonMode = .whileEditing
        nameField.returnKeyType = .done
        nameField.delegate = self
        nameField.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.navigationItem.rightBarButtonItem?.isEnabled = self.trimmedName.isEmpty == false
            self.reloadNameSuggestions()
        }, for: .editingChanged)

        suggestNames()
    }

    /// Names suggested by the on-device model from the sentence, offered below the form. They are hidden when none come back.
    private func suggestNames() {
        guard showsNameSuggestions else { return }
        let sentence = sentence
        nameSuggestionTask = _Concurrency.Task { @MainActor [weak self] in
            let suggestions = await SmartListNameSuggestion.names(for: sentence)
            guard let self = self else { return }
            self.nameSuggestions = suggestions
            // Only the suggestions are reloaded: reloading the name's row would end editing and put the keyboard away.
            if suggestions.isEmpty {
                self.showsNameSuggestions = false
                self.tableView.deleteSections(IndexSet(integer: 1), with: .fade)
            } else {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .fade)
            }
        }
    }

    /// Refreshes which suggestion matches the typed name.
    private func reloadNameSuggestions() {
        guard showsNameSuggestions, nameSuggestions != nil else { return }
        UIView.performWithoutAnimation {
            tableView.reloadSections(IndexSet(integer: 1), with: .none)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if trimmedName.isEmpty {
            nameField.becomeFirstResponder()
        }
    }

    /// Restores the save button when Trakt rejects the list.
    func didFailToSave() {
        navigationItem.rightBarButtonItem = saveItem
        nameField.isEnabled = true
        privacyControl.isEnabled = true
    }

    private var saveItem: UIBarButtonItem {
        let item = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.save()
        })
        item.style = .prominent
        item.isEnabled = trimmedName.isEmpty == false
        return item
    }

    private func save() {
        let name = trimmedName
        guard name.isEmpty == false else { return }
        nameField.resignFirstResponder()
        nameField.isEnabled = false
        privacyControl.isEnabled = false
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: activityIndicator)
        onSave(name, SmartListDetailsViewController.privacies[max(0, privacyControl.selectedSegmentIndex)])
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        save()
        return false
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        showsNameSuggestions ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 2 : max(nameSuggestions?.count ?? 1, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 1 {
            return nameSuggestionCell(at: indexPath.row)
        }
        let cell = TintedTableViewCell(style: .default, reuseIdentifier: nil)
        cell.selectionStyle = .none
        // Privacy first, so the name sits right above its suggestions.
        let isNameRow = indexPath.row == SmartListDetailsViewController.nameRow
        let control: UIView = isNameRow ? nameField : privacyControl
        control.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(control)
        let margins = cell.contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            control.topAnchor.constraint(equalTo: margins.topAnchor),
            control.bottomAnchor.constraint(equalTo: margins.bottomAnchor),
            // The custom list form's name field height.
            control.heightAnchor.constraint(greaterThanOrEqualToConstant: isNameRow ? 34 : 32)
        ])
        return cell
    }

    /// Suggestions are the prompt's example buttons, below the form, the chosen one in full color.
    private func nameSuggestionCell(at row: Int) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.backgroundConfiguration = .clear()
        cell.selectionStyle = .none
        // Hides the separator: these aren't rows of the form.
        cell.separatorInset = UIEdgeInsets(top: 0, left: .greatestFiniteMagnitude, bottom: 0, right: 0)
        let button: UIButton
        if let suggestions = nameSuggestions, suggestions.indices.contains(row) {
            let suggestion = suggestions[row]
            button = UIButton.smartListOption(suggestion) { [weak self] in
                guard let self = self, self.nameField.isEnabled else { return }
                self.nameField.text = suggestion
                self.navigationItem.rightBarButtonItem?.isEnabled = true
                self.reloadNameSuggestions()
            }
            if suggestion == trimmedName {
                button.configuration?.baseForegroundColor = .label
            }
        } else {
            button = UIButton.smartListOption("Suggesting names…") {}
            button.isEnabled = false
        }
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(button)
        // The examples' stack keeps 2 points between buttons.
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 1),
            button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -1),
            button.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
            button.trailingAnchor.constraint(lessThanOrEqualTo: cell.contentView.layoutMarginsGuide.trailingAnchor)
        ])
        return cell
    }

    /// The prompt's spacing between the field and its examples.
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 1 ? 24 : UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == 0 && showsNameSuggestions ? .leastNonzeroMagnitude : UITableView.automaticDimension
    }

    /// Suggestions are buttons: their rows aren't selectable.
    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        updateSuggestionOpacity(of: cell, at: indexPath)
    }

    /// UITableViewController declares this without implementing it: calling super crashes.
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for cell in tableView.visibleCells {
            guard let indexPath = tableView.indexPath(for: cell) else { continue }
            updateSuggestionOpacity(of: cell, at: indexPath)
        }
    }

    /// As in the prompt's examples, suggestions low on the screen are dimmed and brighten as they scroll up.
    private func updateSuggestionOpacity(of cell: UITableViewCell, at indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        let top = tableView.contentOffset.y + tableView.adjustedContentInset.top
        let height = tableView.bounds.height - tableView.adjustedContentInset.top - tableView.adjustedContentInset.bottom
        guard height > 0 else { return }
        // Full strength in the top 40% of the visible area, down to 30% at its bottom.
        let fade = min(max(((cell.frame.midY - top) / height - 0.4) / 0.6, 0), 1)
        cell.contentView.alpha = 1 - 0.7 * fade
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == SmartListDetailsViewController.nameRow {
            nameField.becomeFirstResponder()
        }
    }
}

/// Suggests smart list names with the on-device Apple Intelligence model, when it is available.
private enum SmartListNameSuggestion {
    @Generable
    struct Suggestions {
        @Guide(description: "Distinct names for the whole list, of at most 10 words each, in Title Case, without quotes, emoji or final punctuation.", .count(10))
        var names: [String]
    }

    static var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    /// One request per sentence, shared by the builder, which starts it early, and the save form, which shows its names.
    private static let requests = LRUCache<String, _Concurrency.Task<[String], Never>>(countLimit: 20)

    static func prefetch(for sentence: String) {
        _ = request(for: sentence)
    }

    static func names(for sentence: String) async -> [String] {
        let names = await request(for: sentence).value
        if names.isEmpty {
            // Asked again next time rather than remembered as having no names.
            requests.removeValue(forKey: sentence)
        }
        return names
    }

    private static func request(for sentence: String) -> _Concurrency.Task<[String], Never> {
        if let request = requests.value(forKey: sentence) {
            return request
        }
        let request = _Concurrency.Task { await generatedNames(for: sentence) }
        requests.setValue(request, forKey: sentence)
        return request
    }

    private static func generatedNames(for sentence: String) async -> [String] {
        // Said to be a set of conditions, or "name a list of movies" gets titles of movies. Examples are described rather
        // than given as sentences, which get their names copied as they are.
        let session = LanguageModelSession(instructions: """
        You name smart lists in a movie and TV show tracking app. A smart list is a saved set of conditions, described by a sentence. \
        Give names a person would use for the whole list, combining its most distinctive conditions. \
        Never reply with titles of movies or shows. Write "TV" in capitals.
        For example, popular horror movies from the 80s could be named 80s Horror Favorites, \
        and unwatched shows on HBO could be named Unwatched HBO Shows.
        """)
        // Default sampling: greedy sampling repeats the same names.
        guard let response = try? await session.respond(to: sentence, generating: Suggestions.self) else { return [] }
        return response.content.names
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”.").union(.whitespacesAndNewlines)) }
            // List names are at most 10 words long.
            .filter { $0.isEmpty == false && $0.split(whereSeparator: \.isWhitespace).count <= 10 }
            .removingDuplicates()
    }
}

private extension SmartListSource {
    var details: String {
        switch self {
        case .trending: return "Titles people are watching right now"
        case .popular: return "The most popular titles on Trakt"
        case .anticipated: return "The most awaited upcoming titles"
        case .recommendations: return "Titles recommended for you"
        case .discover: return ""
        case .watchlist: return "Titles on your watchlist"
        case .library: return "Titles in your library"
        case .unknown: return ""
        }
    }
}

private extension SmartListDraft {
    /// Whether the saved list's items still reflect this draft. Names and privacy do not change items.
    func isSameDefinition(as other: SmartListDraft) -> Bool {
        source == other.source && mediaType == other.mediaType && filters == other.filters
    }
}

private extension SmartListFilters {
    /// Trakt chart filters matching this definition. Every change produces a new request, so previews are never
    /// served from the cache of a previous definition. Charts take the smart list `ignore_*` options as `hide_*`,
    /// apart from watched and watchlisted.
    var previewQuery: String {
        func range<Value: Numeric>(_ values: [Value]?, format: (Value) -> String) -> String? {
            guard let values = values, let lower = values.first else { return nil }
            return "\(format(lower))-\(format(values.count > 1 ? values[1] : lower))"
        }
        let list = { (values: [String]?) -> String? in
            // The saved filter request splits its query on "&" and "=".
            let values = (values ?? []).filter { !$0.contains("&") && !$0.contains("=") }
            return values.isEmpty ? nil : values.joined(separator: ",")
        }
        let decimal = { (value: Double) in String(format: "%.1f", value) }
        let integer = { (value: Double) in "\(Int(value))" }
        let parameters: [(String, String?)] = [
            ("genres", list(genres)),
            ("genres_operator", genresOperator == .and ? "and" : nil),
            ("subgenres", list(subgenres)),
            ("keywords", list(keywords)),
            ("keywords_operator", keywordsOperator == .and ? "and" : nil),
            ("certifications", list(certifications)),
            ("languages", list(languages)),
            ("countries", list(countries)),
            ("networks", list(networks)),
            ("statuses", list(statuses)),
            ("watchnow", list(watchnow)),
            ("years", range(years) { "\($0)" }),
            ("runtimes", range(runtimes) { "\($0)" }),
            ("ratings", range(ratings) { "\($0)" }),
            ("imdb_ratings", range(imdbRatings, format: decimal)),
            ("rt_meters", range(rtMeters) { "\($0)" }),
            ("rt_user_meters", range(rtUserMeters) { "\($0)" }),
            ("letterboxd_ratings", range(letterboxdRatings, format: decimal)),
            ("mal_ratings", range(malRatings, format: decimal)),
            ("parental_nudity", range(parentalNudity, format: integer)),
            ("parental_violence", range(parentalViolence, format: integer)),
            ("parental_profanity", range(parentalProfanity, format: integer)),
            ("parental_alcohol", range(parentalAlcohol, format: integer)),
            ("parental_frightening", range(parentalFrightening, format: integer)),
            ("parental_include_unrated", parentalIncludeUnrated == true ? "true" : nil),
            ("ignore_watched", ignoreWatched == true ? "true" : nil),
            ("ignore_watchlisted", ignoreWatchlisted == true ? "true" : nil),
            ("hide_watching", ignoreWatching == true ? "true" : nil),
            ("hide_unreleased", ignoreUnreleased == true ? "true" : nil),
            ("hide_released", ignoreReleased == true ? "true" : nil),
            ("hide_ended", ignoreEnded == true ? "true" : nil),
            ("hide_airing", ignoreAiring == true ? "true" : nil),
            ("hide_no_release_date", ignoreNoReleaseDate == true ? "true" : nil)
        ]
        return parameters.compactMap { key, value in value.map { "\(key)=\($0)" } }.joined(separator: "&")
    }
}
