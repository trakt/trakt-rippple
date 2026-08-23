//
//  TabBarCustomizationViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/04/2022.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

let (onTabBarChangedTransmitter, onTabBarChangedReceiver) = Receiver<Int>.make(with: .hot)

final class TabBarCustomizationViewController: UITableViewController {
    private enum Mode: Int, CaseIterable {
        case defaultTabs
        case island
        case onePage

        var storageKey: String {
            switch self {
            case .defaultTabs:
                return "default"
            case .island:
                return "island"
            case .onePage:
                return "onePage"
            }
        }
    }

    private enum Section {
        case tabs
        case search
        case notTabs
    }

    private let modeSegmentedControl = ReselectableSegmentedControl(items: ["Default", "Island", "One Page"])
    private let tabStoreKeyPrefix = "TabBarCustomizationViewController.tab.positions"
    private var selectedMode = Mode.defaultTabs
    private var tabStores = [Mode: [MainTabBarController.Tab]]()
    private var currentTabs = [MainTabBarController.Tab]()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.setEditing(true, animated: false)
        tableView.allowsSelectionDuringEditing = true
        isModalInPresentation = true

        modeSegmentedControl.addTarget(self,
                                       action: #selector(modeValueChanged),
                                       for: .valueChanged)
        let headerView = UIView(frame: CGRect(x: 0,
                                              y: 0,
                                              width: tableView.bounds.width,
                                              height: 60))
        modeSegmentedControl.frame = headerView.bounds.insetBy(dx: 20, dy: 10)
        modeSegmentedControl.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        headerView.addSubview(modeSegmentedControl)
        tableView.tableHeaderView = headerView
        setupTabStores()
    }

    private func save(tabs: [MainTabBarController.Tab]) {
        let tabs = tabsAddingBrowseIfNeeded(tabs, for: selectedMode)
        guard isValid(tabs: tabs, for: selectedMode) else { return }
        self.tabs = tabs
        applyToMainTabStore(tabs: tabs)
    }

    private func applyToMainTabStore(tabs: [MainTabBarController.Tab]) {
        if let encoded = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(encoded, forKey: "MainTabBarController.tab.positions")
            UserDefaults.standard.synchronize()
            UISelectionFeedbackGenerator().selectionChanged()
            onTabBarChangedTransmitter.broadcast(1)
        }
    }

    private func save(neverMinimize: Bool) {
        UserDefaults.standard.set(neverMinimize, forKey: "MainTabBarController.neverMinimize")
        UserDefaults.standard.synchronize()
        neverMinimizeTabBarTransmitter.broadcast(neverMinimize)
    }

    @objc
    private func modeValueChanged(_ sender: UISegmentedControl) {
        guard let mode = Mode(rawValue: sender.selectedSegmentIndex) else { return }
        if mode == selectedMode {
            save(tabs: defaultTabs(for: mode))
        } else {
            selectedMode = mode
            currentTabs = tabStores[mode] ?? defaultTabs(for: mode)
            applyToMainTabStore(tabs: tabs)
        }
        save(neverMinimize: mode == .island)
        reloadTableView()
    }

    private func reloadTableView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
        }
    }

    private func setupTabStores() {
        for mode in Mode.allCases {
            let persistedTabs = persistedTabs(for: mode).map { tabsAddingBrowseIfNeeded($0, for: mode) }
            tabStores[mode] = persistedTabs.map { isValid(tabs: $0, for: mode) ? $0 : defaultTabs(for: mode) } ?? defaultTabs(for: mode)
        }

        if mainTabStore == defaultSingleTabBar {
            selectedMode = .onePage
        } else if mainNeverMinimize {
            selectedMode = .island
        }
        currentTabs = mainTabStore
        modeSegmentedControl.selectedSegmentIndex = selectedMode.rawValue
    }

    private func persistedTabs(for mode: Mode) -> [MainTabBarController.Tab]? {
        guard let data = UserDefaults.standard.data(forKey: tabStoreKey(for: mode)) else { return nil }
        return try? JSONDecoder().decode([MainTabBarController.Tab].self, from: data)
    }

    private func tabStoreKey(for mode: Mode) -> String {
        return "\(tabStoreKeyPrefix).\(mode.storageKey)"
    }

    private func persist(tabs: [MainTabBarController.Tab], for mode: Mode) {
        guard let encoded = try? JSONEncoder().encode(tabs) else { return }
        UserDefaults.standard.set(encoded, forKey: tabStoreKey(for: mode))
    }

    private func isValid(tabs: [MainTabBarController.Tab], for mode: Mode) -> Bool {
        switch mode {
        case .defaultTabs, .island:
            return tabs.contains(.search) && tabs.contains(where: { $0 != .search }) && tabs.count <= 5
        case .onePage:
            return tabs == defaultSingleTabBar
        }
    }

    private func tabsAddingBrowseIfNeeded(_ tabs: [MainTabBarController.Tab], for mode: Mode) -> [MainTabBarController.Tab] {
        guard mode != .onePage,
              tabs.contains(.search),
              tabs.contains(where: { $0 != .search }) == false else { return tabs }
        return tabs + [.browse]
    }

    private func defaultTabs(for mode: Mode) -> [MainTabBarController.Tab] {
        switch mode {
        case .defaultTabs:
            return defaultTabBar
        case .island:
            return islandTabBar
        case .onePage:
            return defaultSingleTabBar
        }
    }

    private func remove(tab: MainTabBarController.Tab) {
        guard selectedMode != .onePage, tab != .search else { return }
        var tabs = tabs
        guard tabs.count > 1, tabs.contains(tab) else { return }
        tabs.removeAll { $0 == tab }
        save(tabs: tabs)
        reloadTableView()
    }

    private func add(tab: MainTabBarController.Tab) {
        guard selectedMode != .onePage else { return }
        var tabs = tabs
        guard tabs.contains(tab) == false, tabs.count < 5 else { return }

        tabs.append(tab)
        save(tabs: tabs)
        reloadTableView()
    }

    private let defaultTabBar: [MainTabBarController.Tab] = [.browse, .toWatch, .history, .lists, .search]
    private let islandTabBar: [MainTabBarController.Tab] = [.browse, .search, .profile]
    private let defaultSingleTabBar: [MainTabBarController.Tab] = [.browse]
    private var neverMinimize: Bool {
        return selectedMode == .island
    }

    private var tabs: [MainTabBarController.Tab] {
        get {
            return currentTabs
        }
        set {
            currentTabs = newValue
            tabStores[selectedMode] = newValue
            persist(tabs: newValue, for: selectedMode)
        }
    }

    private var mainNeverMinimize: Bool {
        return UserDefaults.standard.bool(forKey: "MainTabBarController.neverMinimize")
    }

    private var mainTabStore: [MainTabBarController.Tab] {
        guard let data = UserDefaults.standard.value(forKey: "MainTabBarController.tab.positions") as? Data,
              let decodedData = try? JSONDecoder().decode([MainTabBarController.Tab].self, from: data) else {
            return defaultTabBar
        }
        return decodedData
    }

    private var notTabs: [MainTabBarController.Tab] {
        let tabs = tabs
        var all = MainTabBarController.Tab.allCases
        all.removeAll { $0 == .purchase || tabs.contains($0) }
        return all
    }

    private var displaysSearchSeparately: Bool {
        return neverMinimize == false && tabs.contains(.search)
    }

    private var displayedTabs: [MainTabBarController.Tab] {
        return displaysSearchSeparately ? tabs.filter { $0 != .search } : tabs
    }

    private var sections: [Section] {
        if selectedMode == .onePage {
            return [.tabs]
        }
        var sections: [Section] = [.tabs]
        if displaysSearchSeparately {
            sections.append(.search)
        }
        sections.append(.notTabs)
        return sections
    }

    private func section(at index: Int) -> Section? {
        guard sections.indices.contains(index) else { return nil }
        return sections[index]
    }

    private func insertionIndex(forDisplayedRow row: Int, in tabs: [MainTabBarController.Tab]) -> Int {
        let displayedTabs = displayedTabs
        guard displayedTabs.indices.contains(row),
              let index = tabs.firstIndex(of: displayedTabs[row]) else { return tabs.endIndex }
        return index
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch self.section(at: section) {
        case .tabs:
            return "Your Tabs"
        case .search:
            return nil
        case .notTabs:
            return "*Not* in Your Tabs"
        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch self.section(at: section) {
        case .tabs:
            if tabs.contains(.search) == false {
                return "Just the Browse and a floating button for more."
            } else {
                return "Use the handle on the right to (re)move tabs."
            }
        case .search:
            return nil
        case .notTabs:
            return "Those won't be in your tabs."
        case nil:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.section(at: section) {
        case .tabs:
            return displayedTabs.count
        case .search:
            return 1
        case .notTabs:
            return notTabs.count
        case nil:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)

        var content = cell.defaultContentConfiguration()
        let tab: MainTabBarController.Tab
        switch section(at: indexPath.section) {
        case .tabs:
            tab = displayedTabs[indexPath.row]
        case .search:
            tab = .search
        case .notTabs:
            tab = notTabs[indexPath.row]
        case nil:
            tab = .purchase
        }
        switch tab {
        case .purchase:
            content.text = "Not Possible"
            content.image = nil
        case .toWatch:
            content.text = "To Watch"
            content.image = UIImage(systemName: "checklist")
        case .history:
            content.text = "History"
            content.image = UIImage(systemName: "memories")
        case .lists:
            content.text = "Lists"
            content.image = UIImage(systemName: "text.justify.left")
        case .search:
            content.text = "Search"
            content.image = UIImage(systemName: "magnifyingglass")
        case .watchlist:
            content.text = "Watchlist"
            content.image = UIImage(systemName: "bookmark")
        case .recommended:
            content.text = "Favorites"
            content.image = UIImage(systemName: "star")
        case .collection:
            content.text = "Library"
            content.image = UIImage(systemName: "book")
        case .watched:
            content.text = "Watched"
            content.image = UIImage(systemName: "checkmark")
        case .ratings:
            content.text = "Ratings"
            content.image = UIImage(systemName: "heart")
        case .profile:
            content.text = "Profile"
            content.image = UIImage(systemName: "person.crop.circle")
        case .calendar:
            content.text = "Calendar"
            content.image = UIImage(systemName: "calendar.day.timeline.left")
        case .wall:
            content.text = "Wall"
            content.image = UIImage(systemName: "rectangle.grid.3x2")
        case .browse:
            content.text = "Browse"
            content.image = UIImage(systemName: "sparkles.rectangle.stack")
        case .shelf:
            content.text = "Shelf"
            content.image = UIImage(systemName: "square.grid.3x1.below.line.grid.1x2")
        case .comments:
            content.text = "Comments"
            content.image = UIImage(systemName: "text.bubble")
        }
        cell.contentConfiguration = content
        cell.selectionStyle = .none

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch section(at: indexPath.section) {
        case .tabs:
            remove(tab: displayedTabs[indexPath.row])
        case .search:
            remove(tab: .search)
        case .notTabs:
            add(tab: notTabs[indexPath.row])
        case nil:
            return
        }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        guard selectedMode != .onePage else { return false }
        return section(at: indexPath.section) != .search
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard selectedMode != .onePage else {
            tableView.reloadData()
            return
        }

        var tabs = tabs
        let sourceSection = section(at: sourceIndexPath.section)
        let destinationSection = section(at: destinationIndexPath.section)
        guard sourceSection != .search, destinationSection != .search else {
            tableView.reloadData()
            return
        }
        if sourceSection == .tabs, destinationSection == .notTabs {
            let tab = displayedTabs[sourceIndexPath.row]
            guard tab != .search else {
                tableView.reloadData()
                return
            }
            tabs.removeAll { $0 == tab }
        }
        if sourceSection == .notTabs, destinationSection == .tabs {
            guard tabs.count < 5 else {
                tableView.reloadData()
                return
            }
            let tab = notTabs[sourceIndexPath.row]
            let destinationIndex = insertionIndex(forDisplayedRow: destinationIndexPath.row, in: tabs)
            tabs.insert(tab, at: destinationIndex)
        }
        if sourceSection == .tabs, destinationSection == .tabs {
            let displayedTabs = displayedTabs
            guard let sourceIndex = tabs.firstIndex(of: displayedTabs[sourceIndexPath.row]),
                  let destinationIndex = tabs.firstIndex(of: displayedTabs[destinationIndexPath.row]) else { return }
            tabs.swapAt(sourceIndex, destinationIndex)
        }
        save(tabs: tabs)
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let tabs = tabs
        let sourceSection = section(at: sourceIndexPath.section)
        let destinationSection = section(at: proposedDestinationIndexPath.section)

        if selectedMode == .onePage || sourceSection == .search || destinationSection == .search {
            return sourceIndexPath
        }
        if selectedMode == .island,
           sourceSection == .tabs,
           displayedTabs[sourceIndexPath.row] == .search,
           destinationSection == .notTabs {
            return sourceIndexPath
        }
        if sourceSection == .notTabs, destinationSection == .notTabs {
            return sourceIndexPath
        }
        if sourceSection == .notTabs, destinationSection == .tabs, tabs.count == 5 {
            return sourceIndexPath
        }
        if destinationSection == .notTabs {
            let noTabs = notTabs
            let sourceTab = sourceSection == .search ? MainTabBarController.Tab.search : displayedTabs[sourceIndexPath.row]
            for (index, tab) in notTabs.enumerated() where tab.rawValue > sourceTab.rawValue {
                return IndexPath(row: index, section: proposedDestinationIndexPath.section)
            }
            return IndexPath(row: noTabs.count, section: proposedDestinationIndexPath.section)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard selectedMode != .onePage else { return false }
        return section(at: indexPath.section) != .search
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}

private final class ReselectableSegmentedControl: UISegmentedControl {
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let previousSelectedSegmentIndex = selectedSegmentIndex
        let wasTappedInside = touches.first.map { bounds.contains($0.location(in: self)) } ?? false
        super.touchesEnded(touches, with: event)

        if wasTappedInside, selectedSegmentIndex == previousSelectedSegmentIndex {
            sendActions(for: .valueChanged)
        }
    }
}
