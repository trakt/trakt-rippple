//
//  EpisodeToWatchSettingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 30/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Receiver
import SwiftUI
import UIKit

let (episodeToWatchSettingsUpdatedTransmitter, episodeToWatchSettingsUpdatedReceiver) = Receiver<EpisodeToWatchSettings>.make(with: .hot)

let (episodeUpcomingEnabledTransmitter, episodeUpcomingEnabledReceiver) = Receiver<Bool>.make(with: .hot)
let (episodeToWatchGroupModeTransmitter, episodeToWatchGroupModeReceiver) = Receiver<EpisodeToWatchGroupMode>.make(with: .hot)

private let episodeToWatchGroupModeStorageKey = "EpisodeToWatchSettings.groupMode"

enum EpisodeToWatchGroupMode: Int, CaseIterable {
    case byLists = 0
    case singleList = 1
}

extension EpisodeToWatchGroupMode {
    static func currentValue(using defaults: UserDefaults = .standard) -> EpisodeToWatchGroupMode {
        EpisodeToWatchGroupMode(rawValue: defaults.integer(forKey: episodeToWatchGroupModeStorageKey)) ?? .byLists
    }

    func persist(using defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: episodeToWatchGroupModeStorageKey)
        defaults.synchronize()
    }

    var label: String {
        switch self {
        case .byLists:
            return "By Lists"
        case .singleList:
            return "In One List"
        }
    }
}

struct EpisodeToWatchListItem: Codable, Identifiable, Hashable {
    enum Kind: String, Codable {
        case smartSearch
        case customList
        case likedList
        case collaboration
    }

    var kind: Kind
    var smartSearch: SmartSearch?
    var list: List?
    var enabled: Bool
    var rank: Int

    var id: String {
        EpisodeToWatchListItem.identifier(kind: kind, smartSearch: smartSearch, list: list)
    }

    static func identifier(kind: Kind, smartSearch: SmartSearch?, list: List?) -> String {
        switch kind {
        case .smartSearch:
            return "smart-\(smartSearch?.uuid ?? smartSearch?.name ?? UUID().uuidString)"
        case .customList, .likedList, .collaboration:
            if let trakt = list?.identifiers.trakt {
                return "\(kind.rawValue)-\(trakt)"
            }
            if let slug = list?.identifiers.slug {
                return "\(kind.rawValue)-\(slug)"
            }
            return "\(kind.rawValue)-\(list?.name ?? UUID().uuidString)"
        }
    }

    func matches(kind: Kind, smartSearch: SmartSearch? = nil, list: List? = nil) -> Bool {
        switch kind {
        case .smartSearch:
            guard let smartSearch else { return false }
            return self.kind == kind && self.smartSearch == smartSearch
        case .customList, .likedList, .collaboration:
            guard let list else { return false }
            return self.kind == kind && self.list == list
        }
    }

    var title: String {
        if let smartSearch {
            return smartSearch.name ?? "A Smart List"
        }
        if let list {
            return list.name.emojiUnescapedString
        }
        return "A List"
    }

    var subtitle: String? {
        switch kind {
        case .smartSearch:
            return "Smart List"
        case .customList:
            return "Custom List"
        case .likedList:
            return "Liked List"
        case .collaboration:
            return "Collaboration"
        }
    }

    enum CodingKeys: String, CodingKey {
        case kind
        case smartSearch
        case list
        case enabled
        case rank
    }

    init(kind: Kind, smartSearch: SmartSearch?, list: List?, enabled: Bool, rank: Int) {
        self.kind = kind
        self.smartSearch = smartSearch
        self.list = list
        self.enabled = enabled
        self.rank = rank
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(Kind.self, forKey: .kind)
        smartSearch = try container.decodeIfPresent(SmartSearch.self, forKey: .smartSearch)
        list = try container.decodeIfPresent(List.self, forKey: .list)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        rank = try container.decodeIfPresent(Int.self, forKey: .rank) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encodeIfPresent(smartSearch, forKey: .smartSearch)
        try container.encodeIfPresent(list, forKey: .list)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(rank, forKey: .rank)
    }
}

@MainActor
final class EpisodeToWatchSettingsViewModel: ObservableObject {
    @Published var watched: Bool
    @Published var watchlist: Bool
    @Published var recommended: Bool
    @Published var collected: Bool

    @Published var availableSmartSearches: [SmartSearch]
    @Published var availableCustomLists: [List]
    @Published var availableLikedLists: [List]
    @Published var availableCollaborations: [List]

    @Published var otherListItems: [EpisodeToWatchListItem]

    @Published var sort: EpisodeToWatchSettings.Sort
    @Published var reverse: Bool
    @Published var upcomingEnabled: Bool
    @Published var groupMode: EpisodeToWatchGroupMode

    @Published private(set) var shouldRefresh = false

    private let disposeBag = DisposeBag()
    private let settings = EpisodeToWatchSettings.shared

    init() {
        watched = settings.watched
        watchlist = settings.watchlist
        recommended = settings.recommended
        collected = settings.collected
        sort = settings.sort
        reverse = settings.reverse
        upcomingEnabled = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.upcoming")
        groupMode = EpisodeToWatchGroupMode.currentValue()

        availableSmartSearches = SmartSearch.smartSearches(for: .show)
        availableCustomLists = ListsManager.shared.lists
        availableLikedLists = [] // Will be set by the receiver once it's binded
        availableCollaborations = CollaborationsManager.shared.collaborations
        otherListItems = [] // Will be set by the receiver once it's binded

        rebuildOtherListItems()
        bindReceivers()
    }

    var sortedSorts: [EpisodeToWatchSettings.Sort] {
        EpisodeToWatchSettings.Sort.allCases
    }

    var watchlistWarning: String? {
        guard watchlist,
              UserDefaults.standard.bool(forKey: "GeneralSettings.watchlistaddback") == false,
              UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautowatchedsync") == false else {
            return nil
        }
        return "Once you watch an episode of a show, Trakt automatically removes it from your Watchlist and adds it to your Watched."
    }

    func setWatched(_ newValue: Bool) {
        updateSetting(\.watched, settingsKeyPath: \.watched, to: newValue)
    }

    func setWatchlist(_ newValue: Bool) {
        updateSetting(\.watchlist, settingsKeyPath: \.watchlist, to: newValue)
    }

    func setRecommended(_ newValue: Bool) {
        updateSetting(\.recommended, settingsKeyPath: \.recommended, to: newValue)
    }

    func setCollected(_ newValue: Bool) {
        updateSetting(\.collected, settingsKeyPath: \.collected, to: newValue)
    }

    func addSmartSearch(_ smartSearch: SmartSearch) {
        addOtherList(kind: .smartSearch, smartSearch: smartSearch, list: nil)
    }

    func addCustomList(_ list: List) {
        addOtherList(kind: .customList, smartSearch: nil, list: list)
    }

    func addLikedList(_ list: List) {
        addOtherList(kind: .likedList, smartSearch: nil, list: list)
    }

    func addCollaboration(_ list: List) {
        addOtherList(kind: .collaboration, smartSearch: nil, list: list)
    }

    func setOtherList(_ item: EpisodeToWatchListItem, enabled: Bool) {
        updateOtherLists { configs in
            guard let index = configs.firstIndex(where: { $0.id == item.id }) else { return }
            configs[index].enabled = enabled
        }
    }

    func moveOtherLists(from offsets: IndexSet, to destination: Int) {
        var items = otherListItems
        items.move(fromOffsets: offsets, toOffset: destination)
        replaceOtherLists(with: items)
    }

    func deleteOtherLists(at offsets: IndexSet) {
        var items = otherListItems
        items.remove(atOffsets: offsets)
        replaceOtherLists(with: items)
    }

    func isAdded(_ smartSearch: SmartSearch) -> Bool {
        settings.otherLists.contains { $0.matches(kind: .smartSearch, smartSearch: smartSearch) }
    }

    func isAdded(_ list: List, kind: EpisodeToWatchListItem.Kind) -> Bool {
        settings.otherLists.contains { $0.matches(kind: kind, list: list) }
    }

    func select(sort newSort: EpisodeToWatchSettings.Sort) {
        applyChange {
            if sort != newSort {
                reverse = false
                settings.reverse = false
            }
            sort = newSort
            settings.sort = newSort
        }
    }

    func setReverse(_ newValue: Bool) {
        updateSetting(\.reverse, settingsKeyPath: \.reverse, to: newValue)
    }

    func setUpcomingEnabled(_ newValue: Bool) {
        guard PurchaseManager.shared.purchased else {
            UIApplication.shared.switchToPurchase()
            return
        }
        upcomingEnabled = newValue
        UserDefaults.standard.setValue(newValue, forKey: "EpisodeToWatchSettings.upcoming")
        UserDefaults.standard.synchronize()
        episodeUpcomingEnabledTransmitter.broadcast(newValue)
    }

    func setGroupMode(_ newValue: EpisodeToWatchGroupMode) {
        guard PurchaseManager.shared.purchased else {
            UIApplication.shared.switchToPurchase()
            return
        }
        groupMode = newValue
        newValue.persist()
        episodeToWatchGroupModeTransmitter.broadcast(newValue)
    }

    func label(for sort: EpisodeToWatchSettings.Sort) -> String {
        let reversed = reverse && self.sort == sort
        switch sort {
        case .automatic:
            return reversed ? "Auto (Reversed)" : "Automatic"
        case .watched:
            return reversed ? "Oldest Watched" : "Recently Watched"
        case .released:
            return reversed ? "Oldest Release" : "Recently Released"
        case .leastEpisodeRemaining:
            return reversed ? "Most Episodes Left" : "Least Episodes Left"
        case .mostCompleted:
            return reversed ? "Least Completed (%)" : "Most Completed (%)"
        case .mostPlayed:
            return reversed ? "Least Played" : "Most Played"
        case .releaseYear:
            return reversed ? "Most Recent (year)" : "Least Recent (year)"
        case .rating:
            return reversed ? "Worst Trakt Rating (%)" : "Best Trakt Rating (%)"
        case .voteCount:
            return reversed ? "Least Vote Count" : "Most Vote Count"
        case .random:
            return reversed ? "Still Random" : "Random"
        case .userRating:
            return reversed ? "Your Worst Rating" : "Your Best Rating"
        case .title:
            return reversed ? "Reverse Alphabetical" : "Alphabetical"
        case .timeLeft:
            return reversed ? "Most Time Left" : "Least Time Left"
        }
    }

    func broadcastIfNeeded() {
        guard shouldRefresh else { return }
        settings.setDefaultIfNeeded()
        shouldRefresh = false
        episodeToWatchSettingsUpdatedTransmitter.broadcast(settings)
    }

    private func addOtherList(kind: EpisodeToWatchListItem.Kind,
                              smartSearch: SmartSearch?,
                              list: List?) {
        updateOtherLists { configs in
            let identifier = EpisodeToWatchListItem.identifier(kind: kind,
                                                               smartSearch: smartSearch,
                                                               list: list)
            if let index = configs.firstIndex(where: { $0.id == identifier }) {
                configs[index].enabled = true
                if let smartSearch { configs[index].smartSearch = smartSearch }
                if let list { configs[index].list = list }
            } else {
                configs.append(.init(kind: kind,
                                     smartSearch: smartSearch,
                                     list: list,
                                     enabled: true,
                                     rank: nextRank(from: configs)))
            }
        }
    }

    private func updateOtherLists(_ transform: (inout [EpisodeToWatchListItem]) -> Void) {
        var configs = settings.otherLists
        transform(&configs)
        configs.sort { $0.rank < $1.rank }
        configs = configs.enumerated().map { index, item in
            var updated = item
            updated.rank = index
            return updated
        }
        guard configs != settings.otherLists else {
            rebuildOtherListItems()
            return
        }
        applyChange {
            settings.otherLists = configs
        }
        rebuildOtherListItems()
    }

    private func rebuildOtherListItems() {
        otherListItems = settings.otherLists
            .sorted { $0.rank < $1.rank }
    }

    private func nextRank(from configs: [EpisodeToWatchListItem]? = nil) -> Int {
        let source = configs ?? settings.otherLists
        return (source.map { $0.rank }.max() ?? -1) + 1
    }

    private func pruneUnavailableOtherLists() {
        updateOtherLists { configs in
            configs = configs.compactMap { config in
                switch config.kind {
                case .smartSearch:
                    guard let search = config.smartSearch else { return nil }
                    guard let available = availableSmartSearches.first(where: { $0 == search }) else { return nil }
                    var updated = config
                    updated.smartSearch = available
                    return updated
                case .customList:
                    guard let list = config.list else { return nil }
                    guard let available = availableCustomLists.first(where: { $0 == list }) else { return nil }
                    var updated = config
                    updated.list = available
                    return updated
                case .likedList:
                    guard let list = config.list else { return nil }
                    guard let available = availableLikedLists.first(where: { $0 == list }) else { return nil }
                    var updated = config
                    updated.list = available
                    return updated
                case .collaboration:
                    guard let list = config.list else { return nil }
                    guard let available = availableCollaborations.first(where: { $0 == list }) else { return nil }
                    var updated = config
                    updated.list = available
                    return updated
                }
            }
        }
    }

    private func replaceOtherLists(with items: [EpisodeToWatchListItem]) {
        let ranked = items.enumerated().map { index, item in
            var updated = item
            updated.rank = index
            return updated
        }
        updateOtherLists { configs in
            configs = ranked
        }
    }

    private func updateSetting(_ stateKeyPath: ReferenceWritableKeyPath<EpisodeToWatchSettingsViewModel, Bool>,
                               settingsKeyPath: ReferenceWritableKeyPath<EpisodeToWatchSettings, Bool>,
                               to newValue: Bool) {
        applyChange {
            self[keyPath: stateKeyPath] = newValue
            settings[keyPath: settingsKeyPath] = newValue
        }
    }

    private func applyChange(_ updates: () -> Void) {
        guard PurchaseManager.shared.purchased else {
            UIApplication.shared.switchToPurchase()
            return
        }
        updates()
        settings.setDefaultIfNeeded()
        syncFromSettings()
        shouldRefresh = true
    }

    private func bindReceivers() {
        episodeToWatchSettingsUpdatedReceiver.listen { [weak self] _ in
            guard let self else { return }
            syncFromSettings()
        }.disposed(by: disposeBag)

        onCustomListsChangedReceiver.hotOnly().listen { [weak self] lists in
            guard let self else { return }
            availableCustomLists = lists
            pruneUnavailableOtherLists()
        }.disposed(by: disposeBag)

        onLikedListsChangedReceiver.listen { [weak self] likedList in
            guard let self else { return }
            availableLikedLists = likedList
            pruneUnavailableOtherLists()
        }.disposed(by: disposeBag)

        onCollaborationsChangedReceiver.hotOnly().listen { [weak self] collaborations in
            guard let self else { return }
            availableCollaborations = collaborations
            pruneUnavailableOtherLists()
        }.disposed(by: disposeBag)

        onShowSmartSearchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self else { return }
            availableSmartSearches = SmartSearch.smartSearches(for: .show)
            pruneUnavailableOtherLists()
        }.disposed(by: disposeBag)
    }

    private func syncFromSettings() {
        watched = settings.watched
        watchlist = settings.watchlist
        recommended = settings.recommended
        collected = settings.collected
        sort = settings.sort
        reverse = settings.reverse
        upcomingEnabled = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.upcoming")
        groupMode = EpisodeToWatchGroupMode.currentValue()
        rebuildOtherListItems()
    }
}

struct EpisodeToWatchSettingsView: View {
    @ObservedObject var viewModel: EpisodeToWatchSettingsViewModel
    @State private var editMode: EditMode = .inactive
    @State private var isPresentingAddListPicker = false

    var body: some View {
        SwiftUI.List {
            Section {
                toggleRow(title: "Watched",
                          value: Binding(get: { viewModel.watched },
                                         set: { viewModel.setWatched($0) }))
                watchlistedRow
                toggleRow(title: "Favorites",
                          value: Binding(get: { viewModel.recommended },
                                         set: { viewModel.setRecommended($0) }))
                toggleRow(title: "Collected",
                          value: Binding(get: { viewModel.collected },
                                         set: { viewModel.setCollected($0) }))
            } header: {
                Text("Find next episodes for shows in:")
            }

            Section {
                ForEach(viewModel.otherListItems) { item in
                    otherListRow(item: item)
                }.onMove(perform: viewModel.moveOtherLists)
                    .onDelete(perform: viewModel.deleteOtherLists)
                addListMenuRow
            } header: {
                HStack {
                    Text("And also for shows in:")
                    Spacer()
                    Button(editMode == .active ? "Done" : "Edit") {
                        editMode = editMode == .active ? .inactive : .active
                    }
                }
            }

            Section {
                sortingRow
                reverseRow
            } header: {
                Text("Then:")
            }

            Section {
                upcomingRow
                groupingRow
            } header: {
                Text("Display options:")
            }
        }.listStyle(.insetGrouped)
            .onDisappear {
                viewModel.broadcastIfNeeded()
            }
            .environment(\.editMode, $editMode)
            .sheet(isPresented: $isPresentingAddListPicker) {
                AddListPickerView(viewModel: viewModel)
            }
            .toggleStyle(.switch)
            .buttonStyle(.borderless)
    }

    private func toggleRow(title: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(Color(UIColor(asset: .globalTint)))
        }.contentShape(Rectangle())
    }

    private var watchlistedRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading) {
                Text("Watchlisted")
                    .foregroundStyle(.primary)
                if let warning = viewModel.watchlistWarning {
                    Text(warning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { viewModel.watchlist }, set: { viewModel.setWatchlist($0) }))
                .labelsHidden()
                .tint(Color(UIColor(asset: .globalTint)))
        }.contentShape(Rectangle())
    }

    private func otherListRow(item: EpisodeToWatchListItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(.primary)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: Binding(get: { item.enabled }, set: { viewModel.setOtherList(item, enabled: $0) }))
                .labelsHidden()
                .tint(Color(UIColor(asset: .globalTint)))
        }.contentShape(Rectangle())
    }

    private var addListMenuRow: some View {
        Button {
            isPresentingAddListPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                Text("Add List")
            }
        }
    }

    private var sortingRow: some View {
        HStack {
            Text("Sort By")
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                ForEach(viewModel.sortedSorts, id: \.self) { sort in
                    Button {
                        viewModel.select(sort: sort)
                    } label: {
                        HStack {
                            Text(viewModel.label(for: sort))
                            Spacer()
                            if viewModel.sort == sort {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.label(for: viewModel.sort))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.callout)
                }
            }
        }
    }

    private var reverseRow: some View {
        HStack {
            Text("Reversed")
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: Binding(get: { viewModel.reverse },
                                     set: { viewModel.setReverse($0) }))
                .labelsHidden()
                .tint(Color(UIColor(asset: .globalTint)))
        }
    }

    private var groupingRow: some View {
        HStack {
            Text("Group")
                .foregroundStyle(.primary)
            Spacer()
            Menu {
                Button {
                    viewModel.setGroupMode(.byLists)
                } label: {
                    HStack {
                        Text("By Lists")
                        Spacer()
                        if viewModel.groupMode == .byLists {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    viewModel.setGroupMode(.singleList)
                } label: {
                    HStack {
                        Text("In One List")
                        Spacer()
                        if viewModel.groupMode == .singleList {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(viewModel.groupMode.label)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.callout)
                }
            }
        }
    }

    private var upcomingRow: some View {
        HStack {
            Text(UpcomingLabelManager.shared.label)
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: Binding(get: { viewModel.upcomingEnabled },
                                     set: { viewModel.setUpcomingEnabled($0) }))
                .labelsHidden()
                .tint(Color(UIColor(asset: .globalTint)))
        }
    }
}

struct AddListPickerView: View {
    @ObservedObject var viewModel: EpisodeToWatchSettingsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedIDs: Set<String>

    init(viewModel: EpisodeToWatchSettingsViewModel) {
        self.viewModel = viewModel
        let addedIDs = Set(viewModel.otherListItems.map(\.id))
        _selectedIDs = State(initialValue: addedIDs)
    }

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                smartSearchSection
                listSection(title: "Custom Lists",
                            lists: viewModel.availableCustomLists,
                            kind: .customList)
                listSection(title: "Liked Lists",
                            lists: viewModel.availableLikedLists,
                            kind: .likedList)
                listSection(title: "Collaborations",
                            lists: viewModel.availableCollaborations,
                            kind: .collaboration)
                if hasNoResults {
                    Section {
                        Text("No Smart Search, Custom List, Liked List or Collaboration found.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add List")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }

    private var hasNoResults: Bool {
        filteredSmartSearches.isEmpty &&
            filteredCustomLists.isEmpty &&
            filteredLikedLists.isEmpty &&
            filteredCollaborations.isEmpty
    }

    private var filteredSmartSearches: [SmartSearch] {
        viewModel.availableSmartSearches.filter { matchesSearch($0.name ?? "A Smart List") }
    }

    private var filteredCustomLists: [List] {
        viewModel.availableCustomLists.filter { matchesSearch($0.name.emojiUnescapedString) }
    }

    private var filteredLikedLists: [List] {
        viewModel.availableLikedLists.filter { matchesSearch($0.name.emojiUnescapedString) }
    }

    private var filteredCollaborations: [List] {
        viewModel.availableCollaborations.filter { matchesSearch($0.name.emojiUnescapedString) }
    }

    @ViewBuilder
    private var smartSearchSection: some View {
        if filteredSmartSearches.isEmpty == false {
            Section("Smart Lists") {
                ForEach(filteredSmartSearches, id: \.self) { smartSearch in
                    let id = EpisodeToWatchListItem.identifier(kind: .smartSearch,
                                                               smartSearch: smartSearch,
                                                               list: nil)
                    selectionRow(id: id,
                                 title: smartSearch.name ?? "A Smart List",
                                 subtitle: itemCountText(count: smartSearch.count))
                }
            }
        }
    }

    @ViewBuilder
    private func listSection(title: String,
                             lists: [List],
                             kind: EpisodeToWatchListItem.Kind) -> some View {
        let filtered = lists.filter { matchesSearch($0.name.emojiUnescapedString) }
        if filtered.isEmpty == false {
            Section(title) {
                ForEach(filtered, id: \.self) { list in
                    let id = EpisodeToWatchListItem.identifier(kind: kind,
                                                               smartSearch: nil,
                                                               list: list)
                    selectionRow(id: id,
                                 title: list.name.emojiUnescapedString,
                                 subtitle: itemCountText(count: list.itemCount))
                }
            }
        }
    }

    private func selectionRow(id: String,
                              title: String,
                              subtitle: String) -> some View {
        Button {
            toggleSelection(for: id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedIDs.contains(id) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color(UIColor(asset: .globalTint)))
                }
            }.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggleSelection(for id: String) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
            disableItem(with: id)
        } else {
            selectedIDs.insert(id)
            addItem(with: id)
        }
    }

    private func matchesSearch(_ text: String) -> Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return true }
        return text.range(of: trimmed, options: .caseInsensitive) != nil
    }

    private func itemCountText(count: Int?) -> String {
        let value = count ?? 0
        return value == 1 ? "1 item" : "\(value) items"
    }

    private func addItem(with id: String) {
        if let smartSearch = viewModel.availableSmartSearches.first(where: { EpisodeToWatchListItem.identifier(kind: .smartSearch, smartSearch: $0, list: nil) == id }) {
            viewModel.addSmartSearch(smartSearch)
            return
        }
        if let list = viewModel.availableCustomLists.first(where: { EpisodeToWatchListItem.identifier(kind: .customList, smartSearch: nil, list: $0) == id }) {
            viewModel.addCustomList(list)
            return
        }
        if let list = viewModel.availableLikedLists.first(where: { EpisodeToWatchListItem.identifier(kind: .likedList, smartSearch: nil, list: $0) == id }) {
            viewModel.addLikedList(list)
            return
        }
        if let list = viewModel.availableCollaborations.first(where: { EpisodeToWatchListItem.identifier(kind: .collaboration, smartSearch: nil, list: $0) == id }) {
            viewModel.addCollaboration(list)
            return
        }
    }

    private func disableItem(with id: String) {
        guard let index = viewModel.otherListItems.firstIndex(where: { $0.id == id }) else { return }
        viewModel.deleteOtherLists(at: IndexSet(integer: index))
    }
}

final class EpisodeToWatchSettingsViewController: UIHostingController<EpisodeToWatchSettingsView> {
    private let viewModel = EpisodeToWatchSettingsViewModel()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: EpisodeToWatchSettingsView(viewModel: viewModel))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        presentationController?.delegate = self
        navigationController?.presentationController?.delegate = self
    }

    @IBAction func info(_ sender: Any) {
        let controller = UIHostingController(rootView: EpisodeToWatchInfoView())
        controller.modalPresentationStyle = .formSheet
        present(controller, animated: true, completion: nil)
    }

    @IBAction func done(_ sender: Any) {
        viewModel.broadcastIfNeeded()
        dismiss(animated: true, completion: nil)
    }
}

final class EpisodeToWatchSettings {
    private let disposeBag = DisposeBag()

    private init() {
        watched = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.watched") || UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.allWatched")
        watchlist = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.watchlist")
        recommended = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.recommended")
        collected = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.collected")

        sort = Sort(rawValue: UserDefaults.standard.integer(forKey: "EpisodeToWatchSettings.sort")) ?? Sort.automatic
        reverse = UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.reverse")

        // Load otherLists from new format
        if let encodedOtherLists = UserDefaults.standard.object(forKey: "EpisodeToWatchSettings.otherLists") as? Data,
           let storedOtherLists = try? JSONDecoder().decode([EpisodeToWatchListItem].self, from: encodedOtherLists) {
            otherLists = storedOtherLists
        }

        ensureSequentialRanks()
        setDefaultIfNeeded()

        onCustomListsChangedReceiver.hotOnly().listen { [weak self] lists in
            guard let self else { return }
            refreshOtherLists(customLists: lists)
        }.disposed(by: disposeBag)

        onLikedListsChangedReceiver.hotOnly().listen { [weak self] likedList in
            guard let self else { return }
            refreshOtherLists(likedLists: likedList)
        }.disposed(by: disposeBag)

        onCollaborationsChangedReceiver.hotOnly().listen { [weak self] collaborations in
            guard let self else { return }
            refreshOtherLists(collaborations: collaborations)
        }.disposed(by: disposeBag)

        onShowSmartSearchChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self else { return }
            let smartSearchShows = SmartSearch.smartSearches(for: .show)
            refreshOtherLists(smartSearches: smartSearchShows)
        }.disposed(by: disposeBag)
    }

    fileprivate func setDefaultIfNeeded() {
        if watchlist == false,
           watched == false,
           recommended == false,
           collected == false,
           !(otherLists.contains(where: { $0.enabled }) == true) {
            watched = true
        }
    }

    enum Sort: Int, CaseIterable {
        case automatic = 0
        case watched = 1
        case released = 5
        case leastEpisodeRemaining = 3
        case mostCompleted = 2
        case timeLeft = 12
        case mostPlayed = 4
        case releaseYear = 6
        case rating = 7
        case voteCount = 8
        case userRating = 9
        case random = 10
        case title = 11
    }

    static let shared = EpisodeToWatchSettings()

    var otherLists = [EpisodeToWatchListItem]() {
        didSet {
            if let encoded = try? JSONEncoder().encode(otherLists) {
                UserDefaults.standard.set(encoded, forKey: "EpisodeToWatchSettings.otherLists")
                UserDefaults.standard.synchronize()
            }
            setDefaultIfNeeded()
        }
    }

    /// Computed properties for backward compatibility
    var smartSearches: [SmartSearch] {
        let ordered = otherLists.sorted { $0.rank < $1.rank }
        return ordered.compactMap { config in
            guard config.enabled else { return nil }
            if case .smartSearch = config.kind {
                return config.smartSearch
            }
            return nil
        }
    }

    var lists: [List] {
        let ordered = otherLists.sorted { $0.rank < $1.rank }
        return ordered.compactMap { config in
            guard config.enabled else { return nil }
            if case .customList = config.kind {
                return config.list
            }
            return nil
        }
    }

    var watchlist = true {
        didSet {
            UserDefaults.standard.set(watchlist, forKey: "EpisodeToWatchSettings.watchlist")
            UserDefaults.standard.synchronize()
        }
    }

    var recommended = true {
        didSet {
            UserDefaults.standard.set(recommended, forKey: "EpisodeToWatchSettings.recommended")
            UserDefaults.standard.synchronize()
        }
    }

    var collected = true {
        didSet {
            UserDefaults.standard.set(collected, forKey: "EpisodeToWatchSettings.collected")
            UserDefaults.standard.synchronize()
        }
    }

    var watched = true {
        didSet {
            UserDefaults.standard.set(watched, forKey: "EpisodeToWatchSettings.watched")
            UserDefaults.standard.synchronize()
        }
    }

    var sort = Sort.automatic {
        didSet {
            UserDefaults.standard.set(sort.rawValue, forKey: "EpisodeToWatchSettings.sort")
            UserDefaults.standard.synchronize()
        }
    }

    var reverse = false {
        didSet {
            UserDefaults.standard.set(reverse, forKey: "EpisodeToWatchSettings.reverse")
            UserDefaults.standard.synchronize()
        }
    }

    private func ensureSequentialRanks() {
        let normalized = otherLists.enumerated().map { index, item -> EpisodeToWatchListItem in
            var updated = item
            updated.rank = index
            return updated
        }
        if normalized != otherLists {
            otherLists = normalized
        }
    }

    private func refreshOtherLists(customLists: [List]? = nil,
                                   likedLists: [List]? = nil,
                                   collaborations: [List]? = nil,
                                   smartSearches: [SmartSearch]? = nil) {
        var updated = otherLists

        if let provided = smartSearches {
            updated = updated.map { item in
                guard item.kind == .smartSearch, let current = item.smartSearch,
                      let refreshed = provided.first(where: { $0 == current }) else { return item }
                var copy = item
                copy.smartSearch = refreshed
                return copy
            }
        } else if let provided = customLists {
            updated = updated.map { item in
                guard item.kind == .customList, let current = item.list,
                      let refreshed = provided.first(where: { $0 == current }) else { return item }
                var copy = item
                copy.list = refreshed
                return copy
            }
        } else if let provided = likedLists {
            updated = updated.map { item in
                guard item.kind == .likedList, let current = item.list,
                      let refreshed = provided.first(where: { $0 == current }) else { return item }
                var copy = item
                copy.list = refreshed
                return copy
            }
        } else if let provided = collaborations {
            updated = updated.map { item in
                guard item.kind == .collaboration, let current = item.list,
                      let refreshed = provided.first(where: { $0 == current }) else { return item }
                var copy = item
                copy.list = refreshed
                return copy
            }
        }

        // Normalize ranks without changing order
        updated = updated.enumerated().map { index, item in
            var copy = item
            copy.rank = index
            return copy
        }

        otherLists = updated
        episodeToWatchSettingsUpdatedTransmitter.broadcast(self)
    }
}

extension EpisodeToWatchSettingsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        viewModel.broadcastIfNeeded()
    }
}
