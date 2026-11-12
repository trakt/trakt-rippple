//
//  RecentlyViewedViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 20/09/2026.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class RecentlyViewedViewController: UITableViewController {
    private let disposeBag = DisposeBag()
    private var items = [RecentlyViewedItem]()
    /// Items are synced without ratings, stats or status, so rows load the full movie or show to match other lists.
    private var fullMedia = [String: MediaModel]()
    private var requests = [String: Cancellable]()
    private lazy var clearButton = UIBarButtonItem(title: "Clear All", style: .plain, target: self, action: #selector(clearAll))

    override func loadView() {
        tableView = TintedPlainTableView(frame: .zero, style: .grouped)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Recently Viewed"
        navigationItem.style = .browser
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = clearButton
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsFocus = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "PeopleTableViewCell", bundle: nil), forCellReuseIdentifier: "people")
        tableView.sectionHeaderHeight = .leastNonzeroMagnitude
        tableView.sectionFooterHeight = .leastNonzeroMagnitude
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)
        onRecentlyViewedChangedReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.reloadItems()
            }
        }.disposed(by: disposeBag)
        reloadItems()
    }

    private func reloadItems() {
        items = RecentlyViewedManager.shared.items
        navigationItem.subtitle = "\(items.count) item\(items.count == 1 ? "" : "s")"
        clearButton.isEnabled = !items.isEmpty
        if items.isEmpty {
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "clock.arrow.circlepath")
            empty.text = "Nothing Viewed Yet"
            empty.secondaryText = "Movies, shows and people you open will appear here, on all your devices."
            contentUnavailableConfiguration = empty
        } else {
            contentUnavailableConfiguration = nil
        }
        tableView.reloadData()
    }

    private func media(for item: RecentlyViewedItem) -> MediaModel? {
        fullMedia[item.key] ?? item.media
    }

    private func loadFullMedia(for item: RecentlyViewedItem) {
        guard fullMedia[item.key] == nil, requests[item.key] == nil, let id = item.ids.trakt else { return }
        let target: TraktAPIService
        switch item.kind {
        case .movie:
            target = .movie(id: String(id), extended: .full)
        case .show:
            target = .show(id: String(id), extended: .full)
        case .person:
            return
        }
        let key = item.key
        requests[key] = TraktAPIProvider.provider.request(target, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            var media: MediaModel?
            if case .success(let moyaResponse) = result,
               let response = try? moyaResponse.filterSuccessfulStatusCodes() {
                switch item.kind {
                case .movie:
                    media = (try? response.map(Movie.self, using: TraktAPIProvider.decoder)).map { .movie($0) }
                case .show:
                    media = (try? response.map(Show.self, using: TraktAPIProvider.decoder)).map { .show($0) }
                case .person:
                    break
                }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.requests[key] = nil
                guard let media = media else { return }
                self.fullMedia[key] = media
                guard let row = self.items.firstIndex(where: { $0.key == key }) else { return }
                self.tableView.reconfigureRows(at: [IndexPath(row: row, section: 0)])
            }
        }
    }

    private func open(_ item: RecentlyViewedItem) {
        if let media = media(for: item) {
            guard let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "MediaViewController") as? MediaViewController else { return }
            controller.media = media
            navigationController?.show(controller, sender: self)
        } else if let person = item.person {
            let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(identifier: "PeopleViewController") { coder in
                PeopleViewController(coder: coder, cast: nil, job: nil, person: person)
            }
            navigationController?.show(controller, sender: self)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        if let media = media(for: item) {
            loadFullMedia(for: item)
            let cell = tableView.dequeueReusableCell(withIdentifier: "media", for: indexPath) as! MediaTableViewCell
            cell.dimmedIfWatched = false
            cell.media = media
            cell.delegate = self
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "people", for: indexPath) as! PeopleTableViewCell
        cell.person = item.person
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard items.indices.contains(indexPath.row) else { return }
        open(items[indexPath.row])
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        true
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        media(for: items[indexPath.row])?.leadingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = items[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            RecentlyViewedManager.shared.remove(item)
            UISelectionFeedbackGenerator().selectionChanged()
            completion(true)
        }
        delete.image = UIImage(systemName: "trash.circle.fill")
        return UISwipeActionsConfiguration(actions: [delete])
    }

    @objc private func clearAll() {
        let alert = UIAlertController(title: "Clear Recently Viewed?", message: "This removes everything you recently viewed, on all your devices.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            RecentlyViewedManager.shared.removeAll()
            UISelectionFeedbackGenerator().selectionChanged()
        })
        present(alert, animated: true)
    }

    deinit {
        requests.values.forEach { $0.cancel() }
    }
}

extension RecentlyViewedViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard action == .details,
              let indexPath = tableView.indexPath(for: cell),
              items.indices.contains(indexPath.row) else { return }
        open(items[indexPath.row])
    }
}
