//
//  RecentSearchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class RecentSearchViewController: UITableViewController {
    var onSelect: ((RecentSearch) -> Void)?

    private let disposeBag = DisposeBag()
    private var recents = [RecentSearch]()
    private lazy var clearButton = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAll))

    override func loadView() {
        tableView = TintedPlainTableView(frame: .zero, style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recent Searches"
        navigationItem.style = .browser
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = clearButton
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "SearchTableViewCell", bundle: nil), forCellReuseIdentifier: "search")
        tableView.sectionHeaderHeight = .leastNonzeroMagnitude
        tableView.sectionFooterHeight = .leastNonzeroMagnitude
        tableView.contentInset.top = 12
        onRecentSearchChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reloadSearches()
            }
        }.disposed(by: disposeBag)
        reloadSearches()
    }

    private func reloadSearches() {
        let latestRecents = RecentSearchManager.shared.recentSearches
        let latestSearches = Set(latestRecents)
        let displayedSearches = Set(recents)
        // Keep this page's order stable while searches are reused.
        recents = recents.filter { latestSearches.contains($0) }
            + latestRecents.filter { !displayedSearches.contains($0) }
        navigationItem.subtitle = "\(recents.count) recent search\(recents.count == 1 ? "" : "es")"
        clearButton.isEnabled = !recents.isEmpty
        if recents.isEmpty {
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "clock.arrow.circlepath")
            empty.text = "No Recent Searches"
            empty.secondaryText = "Your searches will appear here so you can find them again."
            contentUnavailableConfiguration = empty
        } else {
            contentUnavailableConfiguration = nil
        }
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recents.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath) as! SearchTableViewCell
        let recent = recents[indexPath.row]
        cell.card.cardType = recents.count == 1 ? .alone : indexPath.row == 0 ? .top : indexPath.row == recents.count - 1 ? .bottom : .middle
        cell.card.alpha = 1
        cell.chevron.alpha = 1
        cell.shouldShowActivityIndicator = false
        cell.setup(with: recent.displayTitle, and: " in \(recent.scopeTitle)")
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        onSelect?(recents[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let recent = recents[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            guard let self = self else { completion(false); return }
            self.remove(recent)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash.circle.fill")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    private func remove(_ recent: RecentSearch) {
        RecentSearchManager.shared.recentSearches.removeAll { $0 == recent }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: "Clear Recent Searches?", message: "This removes your entire recent search history.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            RecentSearchManager.shared.removeAll()
            UISelectionFeedbackGenerator().selectionChanged()
        })
        present(alert, animated: true)
    }
}
