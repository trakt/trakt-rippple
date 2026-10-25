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
            // The conversation tells how the request was read: once the conditions change, it no longer describes them.
            if view.window != nil, draft.isSameDefinition(as: oldValue) == false {
                removeConversation()
            }
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
    /// How a typed request was read, kept above the sentence.
    private var conversation: SmartListConversation?
    private var conversationController: RipppleHostingController<SmartListConversationView>?
    private var conversationHeader: UIView?
    /// Where the conversation was on the prompt screen, until the builder slides up from there.
    private var conversationStart: CGFloat?
    /// Where the request sits on the prompt screen, to go back there to change it.
    private var restingOffset: CGFloat = 0
    /// Room below the results without a conversation above the sentence.
    private var baseBottomInset: CGFloat = 0
    private let disposeBag = DisposeBag()

    private static let tokenKey = NSAttributedString.Key("SmartListBuilderToken")
    private static let previewLimit = 25

    /// Presents the builder to create a smart list, or to edit one owned by the current user. New lists start from a
    /// prompt with Apple Intelligence, and from the composer without it.
    static func present(from controller: UIViewController, list: List? = nil) {
        if let list = list, list.isSmartList == false || list.user.isCurrentUser == false { return }
        if list == nil, SmartListAssistant.isModelAvailable {
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

    static func make(list: List?, draft: SmartListDraft, conversation: SmartListConversation? = nil,
                     conversationTop: CGFloat = 0) -> SmartListBuilderViewController? {
        guard SessionManager.shared.isLoggedIn, let owner = UserManager.shared.currentUser,
              let builder = UIStoryboard(name: "SmartSearch", bundle: nil)
              .instantiateViewController(withIdentifier: "SmartListBuilderViewController") as? SmartListBuilderViewController else { return nil }
        builder.list = list
        builder.owner = owner
        builder.original = draft
        builder.draft = draft
        builder.conversation = conversation
        builder.conversationStart = conversation == nil ? nil : conversationTop
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
            // Replacing a table's header removes the previous one from its superview: the conversation's container
            // takes the sentence's header directly.
            if let conversation = conversation {
                showConversation(conversation, above: header)
            } else {
                tableView.tableHeaderView = header
            }
        }

        baseBottomInset = tableView.contentInset.bottom

        // The dots under tappable words are drawn with resolved colors and the scaled font. Only the sentence is redrawn:
        // the draft, and so the preview, didn't change.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self, UITraitUserInterfaceStyle.self]) { (self: SmartListBuilderViewController, _) in
            self.sentenceLabel.attributedText = self.sentence()
            self.layoutHeader()
        }

        onUserLoggedOutReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true)
        }.disposed(by: disposeBag)

        draftDidChange()
        loadWatchNowServiceNames()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        // First shown with the conversation where the prompt screen left it.
        guard let start = conversationStart, let conversationView = conversationController?.view else { return }
        view.layoutIfNeeded()
        tableView.contentOffset.y = conversationView.frame.minY - start
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard conversationStart != nil else { return }
        conversationStart = nil
        let isReduced = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: isReduced ? 0.25 : 0.8, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .allowUserInteraction) {
            self.tableView.contentOffset.y = self.restingOffset
        }
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
            _ = await SmartListChoices.watchNowServices()
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
         .font: UIFontMetrics(forTextStyle: .title2).scaledFont(for: .systemFont(ofSize: 22, weight: .medium), maximumPointSize: 34)]
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
        case .negation(let condition):
            return negationMenu(of: condition)
        case .matchOperator(let keyPath):
            return operatorMenu(keyPath)
        case .personRole:
            return personRoleMenu()
        case .watchNowCountry:
            return removeMenu(title: "Use Your Country", image: UIImage(systemName: "arrow.uturn.backward"), attributes: []) { $0.watchnowCountry = nil }
        case .minimum(let condition, let value):
            return minimumMenu(value, of: condition)
        case .releasedWithin(let days):
            return UIMenu(title: "Released Within", children: releasedWithinElements(selected: days))
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
        let title = name(of: value, in: condition)
        let isExcluded = SmartListConditions.isExcluded(value)
        let exclusion = UIAction(title: isExcluded ? "Include \(title)" : "Exclude \(title)",
                                 image: UIImage(systemName: isExcluded ? "checkmark.circle" : "nosign")) { [weak self] _ in
            guard let self = self else { return }
            self.setExcluded(isExcluded == false, [value], of: condition)
        }
        let remove = UIAction(title: "Remove \(title)", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.toggle(value, of: condition)
        }
        var children: [UIMenuElement] = [UIMenu(options: .displayInline, children: [exclusion, remove])]
        if condition.load != nil {
            children.insert(UIMenu(title: "Add \(condition.title)", image: UIImage(systemName: "plus.circle"), children: pickElements(for: condition)), at: 0)
        } else if condition.search != nil {
            children.insert(contentsOf: pickElements(for: condition), at: 0)
        }
        return UIMenu(title: condition.title, children: children)
    }

    /// Menus name values as choices do, "For Free" rather than the sentence's "for free".
    private func name(of value: String, in condition: SmartListConditions.ValueCondition) -> String {
        (condition.choiceFormat ?? condition.format)(SmartListConditions.includedValue(value))
    }

    /// "not" applies to every excluded value of the condition: removing it includes them again.
    private func negationMenu(of condition: SmartListConditions.ValueCondition) -> UIMenu {
        let excluded = (draft.filters[keyPath: condition.keyPath] ?? []).filter(SmartListConditions.isExcluded)
        let title = excluded.count == 1 ? "Include \(name(of: excluded[0], in: condition))" : "Include All"
        return UIMenu(children: [UIAction(title: title, image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
            guard let self = self else { return }
            self.setExcluded(false, excluded, of: condition)
        }])
    }

    /// The choices of a condition: every value of short lists. Long ones offer quick picks, then a search for any value.
    private func pickElements(for condition: SmartListConditions.ValueCondition) -> [UIMenuElement] {
        var elements = [UIMenuElement]()
        if let load = condition.load {
            elements.append(UIMenu(options: .displayInline, children: [choicesMenuElement(for: condition, load: load)]))
        }
        if let search = condition.search {
            let searchAction = UIAction(title: "Search \(condition.searchTitle ?? condition.title)…", image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
                guard let self = self else { return }
                self.presentSearch(search, of: condition)
            }
            elements.append(UIMenu(options: .displayInline, children: [searchAction]))
        }
        return elements
    }

    private func presentSearch(_ source: SmartListConditions.Search, of condition: SmartListConditions.ValueCondition) {
        let search: (String) async throws -> [SmartListChoice]
        let minimumQueryLength: Int
        switch source {
        case .trakt(let kind):
            search = { try await SmartListChoices.search(kind, query: $0) }
            minimumQueryLength = 2
        case .all(let load):
            // Loaded once for the sheet, then filtered: names starting with the query first.
            let mediaType = draft.mediaType
            let all = _Concurrency.Task { try await load(mediaType) }
            search = { query in
                let matches = try await all.value.filter { $0.title.localizedStandardContains(query) }
                let isPrefix = { (choice: SmartListChoice) in
                    choice.title.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .anchored]) != nil
                }
                return matches.filter(isPrefix) + matches.filter { isPrefix($0) == false }
            }
            minimumQueryLength = 1
        }
        let title = condition.searchTitle ?? condition.title
        let format = { (value: String) in (condition.choiceFormat ?? condition.format)(SmartListConditions.includedValue(value)) }
        let searchViewController = SmartListSearchViewController(title: title, minimumQueryLength: minimumQueryLength, search: search,
                                                                 format: format, selected: { [weak self] in
                                                                     guard let self = self else { return [] }
                                                                     return self.draft.filters[keyPath: condition.keyPath] ?? []
                                                                 }, toggle: { [weak self] value in
                                                                     guard let self = self else { return }
                                                                     self.toggle(value, of: condition)
                                                                 })
        let navigation = UINavigationController(rootViewController: searchViewController)
        navigation.sheetPresentationController?.detents = [.medium(), .large()]
        navigation.sheetPresentationController?.prefersGrabberVisible = true
        present(navigation, animated: true)
    }

    private func personRoleMenu() -> UIMenu {
        let current = draft.filters.peopleRole ?? .any
        let roles: [(SmartListFilters.PersonRole, String)] = [(.any, "Any Role"), (.cast, "Cast"), (.directing, "Directing"),
                                                              (.writing, "Writing"), (.producing, "Producing")]
        return UIMenu(title: "Credited For", children: roles.map { role, title in
            UIAction(title: title, state: role == current ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters.peopleRole = role == .any ? nil : role
            }
        })
    }

    private func minimumMenu(_ value: Int, of condition: SmartListConditions.MinimumCondition) -> UIMenu {
        let steps = condition.steps.reversed().map { step in
            UIAction(title: "\(step.formatted(.number.locale(SmartListChoices.locale)))+", state: step == value ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: condition.keyPath] = [step, SmartListConditions.votesCeiling]
            }
        }
        let remove = UIAction(title: "Remove Condition", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.draft.filters[keyPath: condition.keyPath] = nil
        }
        return UIMenu(title: "Minimum \(condition.title)", children: [UIMenu(options: .displayInline, children: steps), remove])
    }

    private func releasedWithinElements(selected: Int?) -> [UIMenuElement] {
        var elements: [UIMenuElement] = SmartListConditions.releaseWindows.map { days in
            UIAction(title: "Last \(SmartListConditions.releaseWindow(days).capitalized)", state: days == selected ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters.releasedWithinDays = days
            }
        }
        if selected != nil {
            let remove = UIAction(title: "Remove Condition", image: UIImage(systemName: "minus.circle"), attributes: .destructive) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters.releasedWithinDays = nil
            }
            elements = [UIMenu(options: .displayInline, children: elements), remove]
        }
        return elements
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
        let personal: [SmartListSource] = [.recommendations, .watchlist, .library]
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
                                 UIMenu(options: .displayInline, children: personal.map(action)),
                                 UIMenu(options: .displayInline, children: [action(.discover)])])
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

    private func removeMenu(title: String, image: UIImage? = UIImage(systemName: "minus.circle"), attributes: UIMenuElement.Attributes = .destructive,
                            remove: @escaping (inout SmartListFilters) -> Void) -> UIMenu {
        UIMenu(children: [UIAction(title: title, image: image, attributes: attributes) { [weak self] _ in
            guard let self = self else { return }
            remove(&self.draft.filters)
        }])
    }

    /// The "Add Condition" menu, built like the Smart Search one with the extra smart list conditions.
    private func conditionsMenu() -> UIMenu {
        let mediaType = draft.mediaType
        var values = [UIMenuElement]()
        for condition in SmartListConditions.values where condition.isAvailable(mediaType) && condition.isPickable {
            values.append(UIMenu(title: condition.title, image: UIImage(systemName: condition.symbol), children: pickElements(for: condition)))
        }

        let ranges = SmartListConditions.ranges.map { condition -> UIMenuElement in
            let isActive = condition.get(draft.filters) != nil
            return UIAction(title: condition.title, state: isActive ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                condition.set(&self.draft.filters, isActive ? nil : condition.initial)
            }
        }
        let minimums = SmartListConditions.minimums.map { condition -> UIMenuElement in
            let isActive = draft.filters[keyPath: condition.keyPath] != nil
            return UIAction(title: "Minimum \(condition.title)", state: isActive ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.draft.filters[keyPath: condition.keyPath] = isActive ? nil : [condition.initial, SmartListConditions.votesCeiling]
            }
        }
        let releaseDates = UIMenu(title: "Release Date", image: UIImage(systemName: "calendar"), children: releaseDateElements())
        let ratings = UIMenu(title: "Runtime & Ratings", image: UIImage(systemName: "star"),
                             children: Array(ranges.dropFirst()) + [UIMenu(options: .displayInline, children: minimums)])

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
        var elements: [UIMenuElement] = [thisYear, UIMenu(title: "Decades", children: decades),
                                         UIMenu(title: "Recently Released", children: releasedWithinElements(selected: draft.filters.releasedWithinDays))]
        if current != nil {
            elements.append(UIAction(title: "Remove Release Years", image: UIImage(systemName: "minus.circle"), attributes: .destructive, handler: set([])))
        }
        return elements
    }

    /// Loads choices when the menu opens, with the selected values checked.
    private func choicesMenuElement(for condition: SmartListConditions.ValueCondition,
                                    load: @escaping (SmartListMediaType) async throws -> [SmartListChoice]) -> UIMenuElement {
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
                // Excluded values show a dash: picking one removes it, like an included one.
                let state = { (choice: SmartListChoice) -> UIMenuElement.State in
                    selected.contains(choice.value) ? .on : (selected.contains(SmartListConditions.excludedValue(choice.value)) ? .mixed : .off)
                }
                completion(self.menuElements(for: choices, state: state) { [weak self] choice in
                    guard let self = self else { return }
                    self.toggle(choice.value, of: condition)
                })
            }
        }
    }

    /// Choices first, then quick picks in their own section.
    private func menuElements(for choices: [SmartListChoice],
                              state: (SmartListChoice) -> UIMenuElement.State,
                              select: @escaping (SmartListChoice) -> Void) -> [UIMenuElement] {
        let action = { (choice: SmartListChoice) in
            UIAction(title: choice.title, subtitle: choice.subtitle, state: state(choice)) { _ in
                select(choice)
            }
        }
        var elements: [UIMenuElement] = choices.filter { $0.isQuickPick == false }.map(action)
        let quickPicks = choices.filter(\.isQuickPick)
        if quickPicks.isEmpty == false {
            elements.append(UIMenu(options: .displayInline, children: quickPicks.map(action)))
        }
        return elements
    }

    /// Adds a value as included, or removes it whether it's included or excluded. The draft is set once, so the preview
    /// refreshes once.
    private func toggle(_ value: String, of condition: SmartListConditions.ValueCondition) {
        var filters = draft.filters
        var values = filters[keyPath: condition.keyPath] ?? []
        let included = SmartListConditions.includedValue(value)
        let forms = [included, SmartListConditions.excludedValue(included)]
        if values.contains(where: forms.contains) {
            values.removeAll(where: forms.contains)
        } else {
            values.append(included)
        }
        filters[keyPath: condition.keyPath] = values.isEmpty ? nil : values
        clearHiddenOperator(of: condition, in: &filters)
        // Settings of a removed condition would be saved without showing in the sentence.
        if values.isEmpty, condition.keyPath == \SmartListFilters.people {
            filters.peopleRole = nil
        }
        if values.isEmpty, condition.keyPath == \SmartListFilters.watchnow {
            filters.watchnowCountry = nil
        }
        draft.filters = filters
    }

    private func setExcluded(_ isExcluded: Bool, _ changed: [String], of condition: SmartListConditions.ValueCondition) {
        var filters = draft.filters
        let changed = Set(changed.map(SmartListConditions.includedValue))
        guard let values = filters[keyPath: condition.keyPath] else { return }
        filters[keyPath: condition.keyPath] = values.map { value in
            let included = SmartListConditions.includedValue(value)
            guard changed.contains(included) else { return value }
            return isExcluded ? SmartListConditions.excludedValue(included) : included
        }
        clearHiddenOperator(of: condition, in: &filters)
        draft.filters = filters
    }

    /// "And" or "or" only shows between two included values: with fewer, it would be saved without showing.
    private func clearHiddenOperator(of condition: SmartListConditions.ValueCondition, in filters: inout SmartListFilters) {
        guard let operatorKeyPath = condition.operatorKeyPath else { return }
        let included = (filters[keyPath: condition.keyPath] ?? []).filter { SmartListConditions.isExcluded($0) == false }
        if included.count < 2 {
            filters[keyPath: operatorKeyPath] = nil
        }
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
        if let conversationHeader = conversationHeader {
            layoutConversation(in: conversationHeader, above: header, height: height)
        } else if header.frame.height != height {
            header.frame.size.height = height
            tableView.tableHeaderView = header
            header.layoutIfNeeded()
        }
        placeTokenButtons()
    }

    // MARK: - Conversation

    /// The conversation goes above the sentence, out of sight until scrolled back to.
    private func showConversation(_ conversation: SmartListConversation, above header: UIView) {
        let controller = RipppleHostingController(rootView: SmartListConversationView(conversation: conversation) { [weak self] in
            guard let self = self else { return }
            self.editPrompt(conversation.editablePrompt)
        })
        controller.safeAreaRegions = []
        addChild(controller)
        controller.view.backgroundColor = .clear
        let container = UIView()
        container.addSubview(controller.view)
        container.addSubview(header)
        controller.didMove(toParent: self)
        conversationController = controller
        conversationHeader = container
        tableView.tableHeaderView = container
    }

    /// The sentence stays where it is on screen as what's above it fades away.
    private func removeConversation() {
        guard let controller = conversationController, let header = sentenceLabel.superview else { return }
        let offset = tableView.contentOffset.y - header.frame.minY
        let visibleFrame = controller.view.convert(controller.view.bounds, to: view)
        if visibleFrame.intersects(view.bounds), let snapshot = controller.view.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = visibleFrame
            snapshot.isUserInteractionEnabled = false
            view.addSubview(snapshot)
            UIView.animate(withDuration: 0.25, animations: {
                snapshot.alpha = 0
            }, completion: { _ in
                snapshot.removeFromSuperview()
            })
        }
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        conversationController = nil
        conversationHeader = nil
        conversation = nil
        header.frame.origin = .zero
        tableView.tableHeaderView = header
        tableView.contentInset.bottom = baseBottomInset
        let top = -tableView.adjustedContentInset.top
        guard offset < top else {
            tableView.contentOffset.y = offset
            return
        }
        // Read down to the sentence, nothing is left above it: room is kept there for a moment, so the sentence glides up
        // as the conversation fades rather than jumping.
        let room = top - offset
        tableView.contentInset.top += room
        tableView.contentOffset.y = offset
        UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0.2 : 0.45, delay: 0, options: .curveEaseInOut) {
            self.tableView.contentInset.top -= room
            self.tableView.contentOffset.y = top
        }
    }

    /// Back to the prompt screen, the reverse of coming here: the screen fades to the prompt screen, which moves the
    /// request from where it is here to where it's typed, then makes it editable there, with the keyboard up.
    private func editPrompt(_ prompt: String) {
        guard let conversationView = conversationController?.view else { return }
        let origin = conversationView.convert(CGPoint.zero, to: nil)
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.2
        navigationController?.view.layer.add(transition, forKey: nil)
        navigationController?.setViewControllers([SmartListPromptViewController(prompt: prompt, movingFrom: prompt.isEmpty ? nil : origin)],
                                                 animated: false)
    }

    /// Laid out like on the prompt screen, 40 points in from the safe area, so it continues it in place.
    private func layoutConversation(in container: UIView, above header: UIView, height: CGFloat) {
        guard let controller = conversationController else { return }
        let width = tableView.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - 80
        let size = controller.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
        controller.view.frame = CGRect(x: view.safeAreaInsets.left + 40, y: 120, width: width, height: size.height)
        // Well apart from the sentence: seen sliding up while the builder appears, it's then out of sight, a scroll away.
        let headerFrame = CGRect(x: 0, y: controller.view.frame.maxY + 160, width: tableView.bounds.width, height: height)
        if header.frame != headerFrame {
            header.frame = headerFrame
            header.layoutIfNeeded()
        }
        let containerSize = CGSize(width: tableView.bounds.width, height: headerFrame.maxY)
        if container.frame.size != containerSize {
            container.frame.size = containerSize
            tableView.tableHeaderView = container
        }
        // At rest the sentence is where it always is. Room below keeps it there however few results follow.
        restingOffset = headerFrame.minY - tableView.adjustedContentInset.top
        let visibleHeight = tableView.bounds.height - tableView.adjustedContentInset.top - tableView.safeAreaInsets.bottom
        tableView.contentInset.bottom = max(baseBottomInset, visibleHeight - height)
    }

    /// Places a menu button over every line fragment of each tappable word, so wrapped and repeated words work, and
    /// dots them below: the underline's dot pattern draws dashes at this size.
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

        let font = highAttributes[.font] as? UIFont
        let lineHeight = font?.lineHeight ?? 28
        let dotsOffset = abs(font?.descender ?? -5) * 0.8
        text.enumerateAttribute(SmartListBuilderViewController.tokenKey, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let index = value as? Int, tokenMenus.indices.contains(index) else { return }
            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let word = (text.string as NSString).substring(with: range)
            // Per line, without the spaces a wrapped word ends its line with.
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, _, _, lineGlyphs, _ in
                let lineCharacters = layoutManager.characterRange(forGlyphRange: NSIntersectionRange(lineGlyphs, glyphRange), actualGlyphRange: nil)
                let trimmed = (text.string as NSString).substring(with: lineCharacters).replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
                guard trimmed.isEmpty == false else { return }
                let wordGlyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: lineCharacters.location, length: (trimmed as NSString).length),
                                                          actualCharacterRange: nil)
                let rect = layoutManager.boundingRect(forGlyphRange: wordGlyphs, in: container)
                let button = UIButton(frame: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: min(rect.height, lineHeight)))
                button.showsMenuAsPrimaryAction = true
                button.menu = self.tokenMenus[index]
                button.accessibilityLabel = word
                button.accessibilityHint = "Opens options for this condition."
                let baseline = lineRect.minY + layoutManager.location(forGlyphAt: wordGlyphs.location).y
                button.layer.addSublayer(self.dots(width: rect.width, y: baseline + dotsOffset - rect.minY))
                self.sentenceLabel.addSubview(button)
            }
        }
    }

    private func dots(width: CGFloat, y: CGFloat) -> CAShapeLayer {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 1, y: y))
        path.addLine(to: CGPoint(x: max(width - 1, 1), y: y))
        let dots = CAShapeLayer()
        dots.path = path.cgPath
        dots.strokeColor = UIColor.secondaryLabel.resolvedColor(with: traitCollection).cgColor
        dots.lineWidth = 2
        dots.lineCap = .round
        // Zero-length dashes with round caps draw as dots.
        dots.lineDashPattern = [0, 4]
        return dots
    }

    // MARK: - Preview

    /// The saved list shows its real items. Drafts use Trakt's smart list preview, which resolves them like saved lists.
    private var previewService: TraktAPIService? {
        let pageInfo = PageInfo.firstPage(with: SmartListBuilderViewController.previewLimit)
        if let slug = list?.smartListSlug, draft.isSameDefinition(as: original) {
            return .smartListItems(slug: slug, pageInfo: pageInfo)
        }
        guard draft.source != .unknown, draft.mediaType != .unknown else { return nil }
        return .smartListPreview(draft, pageInfo: pageInfo)
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

// MARK: - Search

/// Picks values too many to list, such as people, keywords or languages, by searching them.
/// Each pick updates the sentence behind the sheet right away.
private final class SmartListSearchViewController: UITableViewController, UISearchResultsUpdating {
    private enum State {
        case hint
        case loading
        case results([SmartListChoice])
        case failed
    }

    private let minimumQueryLength: Int
    private let search: (String) async throws -> [SmartListChoice]
    private let format: (String) -> String
    private let selected: () -> [String]
    private let toggle: (String) -> Void
    private let searchController = UISearchController(searchResultsController: nil)
    private var searchTask: _Concurrency.Task<Void, Never>?
    private var query = ""
    private var state = State.hint {
        didSet {
            tableView.reloadData()
            setNeedsUpdateContentUnavailableConfiguration()
        }
    }

    init(title: String, minimumQueryLength: Int, search: @escaping (String) async throws -> [SmartListChoice],
         format: @escaping (String) -> String, selected: @escaping () -> [String], toggle: @escaping (String) -> Void) {
        self.minimumQueryLength = minimumQueryLength
        self.search = search
        self.format = format
        self.selected = selected
        self.toggle = toggle
        super.init(style: .insetGrouped)
        self.title = title
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        searchTask?.cancel()
    }

    /// Shown before a search: the values already picked, so they can be removed here too.
    private var rows: [SmartListChoice] {
        switch state {
        case .results(let choices):
            return choices
        case .hint, .failed:
            return selected().map { SmartListChoice(value: $0, title: format($0)) }
        case .loading:
            return []
        }
    }

    override func loadView() {
        tableView = TintedTableView(frame: .zero, style: .insetGrouped)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.dismiss(animated: true)
        })
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search \(title?.lowercased() ?? "")"
        searchController.searchBar.autocapitalizationType = .none
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.preferredSearchBarPlacement = .stacked
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchController.isActive = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard query != self.query else { return }
        self.query = query
        searchTask?.cancel()
        guard query.count >= minimumQueryLength else {
            state = .hint
            return
        }
        state = .loading
        let search = search
        searchTask = _Concurrency.Task { @MainActor [weak self] in
            try? await _Concurrency.Task.sleep(for: .milliseconds(300))
            guard _Concurrency.Task.isCancelled == false else { return }
            let choices = try? await search(query)
            guard _Concurrency.Task.isCancelled == false, let self = self, self.query == query else { return }
            self.state = choices.map { .results($0) } ?? .failed
        }
    }

    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        var configuration: UIContentUnavailableConfiguration?
        switch self.state {
        case .loading:
            configuration = .loading()
        case .results(let choices) where choices.isEmpty:
            configuration = .search()
            configuration?.text = "No Matches"
            configuration?.secondaryText = "Try another spelling."
        // Values already picked stay listed rather than hidden behind the error.
        case .failed where rows.isEmpty:
            configuration = .empty()
            configuration?.image = UIImage(systemName: "wifi.exclamationmark")
            configuration?.text = "Couldn’t Search \(title ?? "")"
            configuration?.secondaryText = "Check your connection and try again."
        case .hint where rows.isEmpty:
            configuration = .empty()
            configuration?.image = UIImage(systemName: "magnifyingglass")
            configuration?.text = "Search \(title ?? "")"
            configuration?.secondaryText = minimumQueryLength > 1 ? "Type at least \(minimumQueryLength) characters." : nil
        case .hint, .results, .failed:
            configuration = nil
        }
        contentUnavailableConfiguration = configuration
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if case .results = state {
            return nil
        }
        return rows.isEmpty ? nil : "Selected"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = TintedTableViewCell(style: .default, reuseIdentifier: nil)
        let rows = rows
        guard rows.indices.contains(indexPath.row) else { return cell }
        let choice = rows[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = choice.title
        content.secondaryText = choice.subtitle
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        // Excluded values, picked from the sentence, show as such and are removed here like included ones.
        let selected = selected()
        let included = SmartListConditions.includedValue(choice.value)
        cell.accessoryType = selected.contains(included) ? .checkmark : .none
        if selected.contains(SmartListConditions.excludedValue(included)) {
            let excluded = UIImageView(image: UIImage(systemName: "nosign"))
            excluded.tintColor = .secondaryLabel
            cell.accessoryView = excluded
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let rows = rows
        guard rows.indices.contains(indexPath.row) else { return }
        toggle(rows[indexPath.row].value)
        if case .results = state {
            tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            // Removed values leave the list of selected ones.
            tableView.reloadData()
            setNeedsUpdateContentUnavailableConfiguration()
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
        Give names a person would use for the whole list, combining its most distinctive conditions, \
        such as people, studios, themes, genres or periods, and nothing the sentence doesn't say. \
        Never reply with titles of movies or shows, and never use the word Trakt. Write "TV" in capitals, and years spanning a decade as that decade, such as 90s.
        For example, popular horror movies from the 80s could be named 80s Horror Favorites, \
        unwatched shows on HBO could be named Unwatched HBO Shows, \
        and movies directed by Greta Gerwig could be named Gerwig Directed.
        """)
        // "All of Trakt" only says that no chart narrows the list: names would repeat it. Decades are named as such,
        // which the model doesn't do from years.
        let conditions = sentence.replacingOccurrences(of: " from \(SmartListSource.discover.title)", with: "")
            .replacingOccurrences(of: #"between (\d{3})0 and \19"#, with: "in the $10s", options: .regularExpression)
        // Default sampling: greedy sampling repeats the same names.
        guard let response = try? await session.respond(to: conditions, generating: Suggestions.self) else { return [] }
        return response.content.names
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"“”.").union(.whitespacesAndNewlines)) }
            // List names are at most 10 words long. A single word, such as a first name, doesn't name the list.
            .filter { (2...10).contains($0.split(whereSeparator: \.isWhitespace).count) && $0.localizedCaseInsensitiveContains("trakt") == false }
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
        case .discover: return "Every title on Trakt, narrowed by your conditions"
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
