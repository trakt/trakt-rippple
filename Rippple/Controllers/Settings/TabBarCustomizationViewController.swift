//
//  TabBarCustomizationViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 29/04/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import UIKit

import Receiver

let (onTabBarChangedTransmitter, onTabBarChangedReceiver) = Receiver<Int>.make(with: .hot)

final class TabBarCustomizationViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.setEditing(true, animated: false)
        tableView.allowsSelectionDuringEditing = true
        isModalInPresentation = true

        let defaultTabBar = UIAction(title: "Default Tabs", subtitle: "Browse, To Watch, History, Lists, Search") { _ in
            self.save(tabs: self.defaultTabBar)
            self.tableView.reloadData()
        }

        let defaultSinglePage = UIAction(title: "Single Page", subtitle: "Browse and More") { _ in
            self.save(tabs: self.defaultSingleTabBar)
            self.tableView.reloadData()
        }

        let menu = UIMenu(children: [defaultTabBar, defaultSinglePage])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Preset",
                                                            image: nil,
                                                            primaryAction: nil,
                                                            menu: menu)
    }

    private func save(tabs: [MainTabBarController.Tab]) {
        if tabs.isEmpty {
            save(tabs: defaultTabBar)
            tableView.reloadData()
            return
        }
        if tabs.count > 5 {
            save(tabs: defaultTabBar)
            tableView.reloadData()
            return
        }
        if tabs.contains(where: { $0 == .search }) == false && tabs != defaultSingleTabBar {
            save(tabs: defaultSingleTabBar)
            tableView.reloadData()
            return
        }
        if let encoded = try? JSONEncoder().encode(tabs) {
            UserDefaults.standard.set(encoded, forKey: "MainTabBarController.tab.positions")
            UserDefaults.standard.synchronize()
            UISelectionFeedbackGenerator().selectionChanged()
            onTabBarChangedTransmitter.broadcast(1)
        }
    }

    private let defaultTabBar: [MainTabBarController.Tab] = [.browse, .toWatch, .history, .lists, .search]
    private let defaultSingleTabBar: [MainTabBarController.Tab] = [.browse]
    private var tabs: [MainTabBarController.Tab] {
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

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Your Tabs"
        } else {
            return "*Not* in Your Tabs"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Use the handle on the right to (re)move tabs."
        } else {
            return "Those won't be in your tabs."
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return tabs.count
        } else {
            return notTabs.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)

        var content = cell.defaultContentConfiguration()
        switch indexPath.section == 0 ? tabs[indexPath.row] : notTabs[indexPath.row] {
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

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        /*
        if indexPath.section == 0, indexPath.row == 0 {
            save(tabs: defaultTabBar)
            tableView.reloadData()
        }
         */

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        var tabs = tabs
        if sourceIndexPath.section == 0, destinationIndexPath.section == 1 {
            tabs.remove(at: sourceIndexPath.row)

            // if we remove the search, then we switch to default one page
            if tabs.contains(where: { $0 == .search }) == false && tabs != defaultSingleTabBar {
                save(tabs: defaultSingleTabBar)
                tableView.reloadData()
                return
            }
        }
        if sourceIndexPath.section == 1, destinationIndexPath.section == 0 {
            tabs.insert(notTabs[sourceIndexPath.row], at: destinationIndexPath.row)

            // if we insert somthing and search is not there, add it automatically
            if tabs.contains(where: { $0 == .search }) == false && tabs != defaultSingleTabBar {
                tabs.append(.search)
                save(tabs: tabs)
                tableView.reloadData()
                return
            }
        }
        if sourceIndexPath.section == 0, destinationIndexPath.section == 0 {
            tabs.swapAt(sourceIndexPath.row, destinationIndexPath.row)
        }
        save(tabs: tabs)
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let tabs = tabs

        if sourceIndexPath.section == 1, proposedDestinationIndexPath.section == 1 {
            return sourceIndexPath
        }
        if sourceIndexPath.section == 1, proposedDestinationIndexPath.section == 0, tabs.count == 5 {
            return sourceIndexPath
        }
        if proposedDestinationIndexPath.section == 1 {
            let noTabs = notTabs
            for (index, tab) in notTabs.enumerated() where tab.rawValue > tabs[sourceIndexPath.row].rawValue {
                return IndexPath(row: index, section: 1)
            }
            return IndexPath(row: noTabs.count, section: 1)
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
}
