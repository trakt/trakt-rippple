//
//  PeopleChronologyTableViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 18/09/2025.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class PeopleChronologyTableViewController: UITableViewController {
    var filteredMedia: [MediaModel]? {
        didSet {
            updateDataSource()
        }
    }

    var inMovies: People? {
        didSet {
            updateDataSource()
        }
    }

    var inShows: People? {
        didSet {
            updateDataSource()
        }
    }

    var searchQuery = "" {
        didSet {
            updateDataSource()
        }
    }

    weak var displayingViewController: UIViewController?

    private enum Section: Int {
        case content
    }

    private enum Wrapper: Hashable {
        case media(Entry)
        case header(String, String)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .header(let title, let subtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = title
            cell.subtitle?.text = subtitle
            return cell
        case .media(let entry):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "media") as? MediaTableViewCell else {
                fatalError("Could not dequeue a media cell")
            }

            cell.media = entry.media

            let meta = entry.meta.compactMap { $0 }.joined(separator: ", ")
            cell.submeta?.isHidden = false
            if meta.isEmpty == false {
                cell.submeta?.text = meta
            } else {
                cell.submeta?.text = nil
                cell.submeta?.isHidden = true
            }

            cell.delegate = self

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = .ripppleViewBackground
        tableView.allowsFocus = false
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")

        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        updateDataSource()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController {
            if let media = sender as? MediaModel {
                mediaViewController.media = media
            }
        }
    }

    private struct Entry: Hashable {
        let year: Int?
        let firstAired: Date?
        let media: MediaModel

        let meta: [String?]

        func matches(searchQuery: String) -> Bool {
            if searchQuery.isEmpty { return true }
            if let year = year {
                if String(year).localizedStandardContains(searchQuery) { return true }
            }
            if let movie = media.movie {
                if movie.title.localizedStandardContains(searchQuery) { return true }
                if movie.originalTitle?.localizedStandardContains(searchQuery) == true { return true }
            }
            if let show = media.show {
                if show.title.localizedStandardContains(searchQuery) { return true }
                if show.originalTitle?.localizedStandardContains(searchQuery) == true { return true }
            }
            for searchable in meta.compactMap({ $0 }) where searchable.localizedStandardContains(searchQuery) {
                return true
            }
            return false
        }
    }

    private func updateDataSource() {
        var entries: [Entry] = []

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        if let inMovies = inMovies {
            for movie in inMovies.allMovies {
                let year = movie.releaseYear
                var meta = [String?]()
                if let cast = inMovies.cast.first(where: { $0.movie == movie }) {
                    meta += cast.characters
                }
                if let jobs = inMovies.crew?.jobs(for: movie) {
                    for job in jobs {
                        meta += job.jobs
                    }
                }
                if let released = movie.released {
                    entries.append(Entry(year: year,
                                         firstAired: dateFormatter.date(from: released),
                                         media: movie.mediaModel,
                                         meta: meta))
                } else {
                    entries.append(Entry(year: year,
                                         firstAired: nil,
                                         media: movie.mediaModel,
                                         meta: meta))
                }
            }
        }

        if let inShows = inShows {
            for show in inShows.allShows {
                let year = show.releaseYear
                var meta = [String?]()
                if let cast = inShows.cast.first(where: { $0.show == show }) {
                    meta += cast.characters
                }
                if let jobs = inShows.crew?.jobs(for: show) {
                    for job in jobs {
                        meta += job.jobs
                    }
                }
                entries.append(Entry(year: year,
                                     firstAired: show.firstAired,
                                     media: show.mediaModel,
                                     meta: meta))
            }
        }

        entries = entries.filter { $0.matches(searchQuery: searchQuery) }
        if let filteredMedia = filteredMedia {
            entries = entries.filter { filteredMedia.contains($0.media) }
        }
        let grouped = Dictionary(grouping: entries, by: { $0.year })
        let sortedYears = grouped.keys.sorted { $0 ?? 0 > $1 ?? 0 }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])

        for year in sortedYears {
            let title = if let year = year { String(year) } else { "Unknown Year" }
            let items = grouped[year]?.sorted { $0.firstAired ?? .now > $1.firstAired ?? .now } ?? []

            snapshot.appendItems([.header(title, "\(items.count) item\(items.count > 1 ? "s" : "")")])
            for entry in items {
                snapshot.appendItems([.media(entry)])
            }
        }

        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .media(let entry):
            if let displayingViewController = displayingViewController {
                displayingViewController.performSegue(withIdentifier: "media", sender: entry.media)
            } else {
                performSegue(withIdentifier: "media", sender: entry.media)
            }
        case .header:
            return
        }
    }

    private let contextMenu = ContextMenuHelper()

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if indexPath.section == dataSource.snapshot().indexOfSection(Section.content) {
            let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell
            contextMenu.cell = cell
            contextMenu.controller = self

            return UIContextMenuConfiguration(identifier: nil, previewProvider: {
                self.contextMenu.previewViewController
            }, actionProvider: { _ in
                self.contextMenu.menu
            })
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let poster = contextMenu.previewView else { return nil }
        return UITargetedPreview(view: poster, parameters: UIPreviewParameters())
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let controller = contextMenu.commitViewController else { return }

        if let displayingViewController = displayingViewController {
            displayingViewController.show(controller, sender: nil)
        } else {
            show(controller, sender: nil)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.media(let entry) = item else { return nil }
        let media = entry.media
        return media.trailingSwipeActions(for: self)
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case Wrapper.media(let entry) = item else { return nil }
        let media = entry.media
        return media.leadingSwipeActions(for: self)
    }
}

extension PeopleChronologyTableViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        guard case Wrapper.media(let entry) = item else { return }

        if let displayingViewController = displayingViewController {
            displayingViewController.performSegue(withIdentifier: "media", sender: entry.media)
        } else {
            performSegue(withIdentifier: "media", sender: entry.media)
        }
    }
}
