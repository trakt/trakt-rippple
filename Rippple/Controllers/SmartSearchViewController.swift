//
//  SmartSearchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class SmartSearchViewController: UITableViewController {
    private enum Section {
        case filters
        case movies
        case shows
    }

    private let disposeBag = DisposeBag()
    private var savedFilters = [SavedFilter]()
    private var movies = [SmartSearch]()
    private var shows = [SmartSearch]()

    private var sections: [Section] = [.movies, .shows]

    override func loadView() {
        tableView = TintedPlainTableView(frame: .zero, style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Smart Searches"
        navigationItem.style = .browser
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(toggleEditing))
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.allowsSelectionDuringEditing = true
        tableView.register(UINib(nibName: "SearchTableViewCell", bundle: nil), forCellReuseIdentifier: "search")
        tableView.register(UINib(nibName: "SearchHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "header")

        onMovieSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.scheduleReload()
        }.disposed(by: disposeBag)
        onShowSmartSearchChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.scheduleReload()
        }.disposed(by: disposeBag)
        onSavedFiltersChangedReceiver.listen { [weak self] filters in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.savedFilters = filters
                self.reloadSearches()
            }
        }.disposed(by: disposeBag)
        reloadSearches()
    }

    private func scheduleReload() {
        // Store events can arrive during a row move; finish that transaction first.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.reloadSearches()
        }
    }

    private func reloadSearches() {
        movies = SmartSearch.smartSearches(for: .movie)
        shows = SmartSearch.smartSearches(for: .show)
        sections = (isEditing || savedFilters.isEmpty ? [] : [.filters]) + [.movies, .shows]
        tableView.reloadData()
    }

    private func smartSearch(at indexPath: IndexPath) -> SmartSearch? {
        guard sections.indices.contains(indexPath.section) else { return nil }
        switch sections[indexPath.section] {
        case .filters: return nil
        case .movies: return movies.indices.contains(indexPath.row) ? movies[indexPath.row] : nil
        case .shows: return shows.indices.contains(indexPath.row) ? shows[indexPath.row] : nil
        }
    }

    private func savedFilter(at indexPath: IndexPath) -> SavedFilter? {
        guard sections.indices.contains(indexPath.section), sections[indexPath.section] == .filters,
              savedFilters.indices.contains(indexPath.row) else { return nil }
        return savedFilters[indexPath.row]
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard sections.indices.contains(section) else { return 0 }
        switch sections[section] {
        case .filters: return savedFilters.count
        case .movies: return movies.count
        case .shows: return shows.count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath) as! SearchTableViewCell
        let count = tableView.numberOfRows(inSection: indexPath.section)
        cell.card.cardType = count == 1 ? .alone : indexPath.row == 0 ? .top : indexPath.row == count - 1 ? .bottom : .middle
        cell.card.alpha = isEditing ? 0 : 1
        cell.chevron.alpha = isEditing ? 0 : 1
        cell.shouldShowActivityIndicator = false
        if let search = smartSearch(at: indexPath) {
            cell.setup(with: search.name ?? "Smart Search")
        } else {
            cell.setup(with: savedFilter(at: indexPath)?.name ?? "")
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard sections.indices.contains(section) else { return nil }
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header") as! SearchHeaderView
        header.button.removeTarget(self, action: nil, for: .touchUpInside)
        header.button.isHidden = isEditing || sections[section] == .filters
        header.button.setTitle("Add Smart Search", for: .normal)
        switch sections[section] {
        case .filters:
            header.title.text = "💾 Saved Filters"
        case .movies:
            header.title.text = "📽 Movies"
            header.button.addTarget(self, action: #selector(addMovieSearch), for: .touchUpInside)
        case .shows:
            header.title.text = "📺 TV Shows"
            header.button.addTarget(self, action: #selector(addShowSearch), for: .touchUpInside)
        }
        return header
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        if isEditing, let search = smartSearch(at: indexPath) {
            editSearch(search)
            return
        }
        guard let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SearchResultsViewController") as? SearchResultsViewController else { return }
        if let search = smartSearch(at: indexPath) {
            controller.aSmartSearch = search
        } else if let filter = savedFilter(at: indexPath) {
            controller.title = filter.name
            controller.savedFilter = filter
        } else {
            return
        }
        navigationController?.show(controller, sender: self)
    }

    @objc private func addMovieSearch() {
        editSearch(SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/movies/trending", count: 10))
    }

    @objc private func addShowSearch() {
        editSearch(SmartSearch(urlString: "\(TraktAPIConfiguration.baseURL)/shows/trending", count: 10))
    }

    private func editSearch(_ search: SmartSearch) {
        guard PurchaseManager.shared.purchased else {
            UIApplication.shared.switchToPurchase()
            return
        }
        guard let navigation = UIStoryboard(name: "SmartSearch", bundle: nil).instantiateInitialViewController() as? UINavigationController,
              let builder = navigation.viewControllers.first as? SmartSearchBuilderViewController else { return }
        builder.smartSearch = search
        present(navigation, animated: true)
    }

    @objc private func toggleEditing() {
        setEditing(!isEditing, animated: true)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        guard !editing || PurchaseManager.shared.purchased else {
            UIApplication.shared.switchToPurchase()
            return
        }
        // UIKit queries the displayed rows while changing editing mode; keep their section mapping until it finishes.
        super.setEditing(editing, animated: animated)
        navigationItem.rightBarButtonItem?.title = editing ? "Done" : "Edit"
        reloadSearches()
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        PurchaseManager.shared.purchased && smartSearch(at: indexPath) != nil
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        smartSearch(at: indexPath) == nil ? .none : .delete
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete { smartSearch(at: indexPath)?.delete() }
    }

    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        PurchaseManager.shared.purchased && smartSearch(at: indexPath) != nil
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        sourceIndexPath.section == proposedDestinationIndexPath.section ? proposedDestinationIndexPath : sourceIndexPath
    }

    override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        smartSearch(at: sourceIndexPath)?.move(at: destinationIndexPath.row)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isEditing, let search = smartSearch(at: indexPath) else { return nil }
        let edit = UIContextualAction(style: .normal, title: "Edit") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            self.editSearch(search)
            completion(true)
        }
        edit.image = UIImage(systemName: "pencil.circle.fill")
        edit.backgroundColor = UIColor(resource: .ripppleGray)
        return UISwipeActionsConfiguration(actions: [edit])
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard !isEditing, PurchaseManager.shared.purchased, let search = smartSearch(at: indexPath) else { return nil }
        let remove = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            search.delete()
            completion(true)
        }
        remove.image = UIImage(systemName: "trash.circle.fill")
        let configuration = UISwipeActionsConfiguration(actions: [remove])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
