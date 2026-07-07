//
//  MoviesToWatchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import Receiver
import SafariServices
import UIKit

final class MoviesToWatchViewController: UITableViewController {
    private enum ViewControllerSegue: String {
        case comments
        case details
        case settings
    }

    private let disposeBag = DisposeBag()

    private let contextMenu = ContextMenuHelper()

    private var upcomingModels = [MediaModel]()

    enum Section: Hashable {
        case stories
        case header
        case content(String?, Int?)
        case footer
    }

    enum Wrapper: Hashable {
        case content(MediaModel, String?)
        case subheader(String, String)
        case anticipatedHeader(String, String)
        case header
        case footer
        case stories([MediaModel])
    }

    private class ToWatchTableViewDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .content:
                return true
            default:
                return false
            }
        }
    }

    private lazy var dataSource = ToWatchTableViewDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, wrapper in
        guard let self = self else { return nil }

        switch wrapper {
        case .content(let media, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! MediaTableViewCell
            cell.dimmedIfWatched = false
            cell.toWatchMode = true // set this before setting the media!!
            cell.media = media
            cell.note = media.movie.flatMap { MovieToWatchManager.shared.releaseLabel(for: $0) }
            cell.notesButton?.isUserInteractionEnabled = false
            cell.notesButton?.toolTip = nil
            cell.delegate = self
            return cell
        case .header:
            return tableView.dequeueReusableCell(withIdentifier: "empty")
        case .footer:
            let cell = tableView.dequeueReusableCell(withIdentifier: "footer") as! ToWatchFooterTableViewCell
            cell.mode = .movies
            return cell
        case .stories(let mediaModels):
            let cell = tableView.dequeueReusableCell(withIdentifier: "stories") as! ToWatchStoriesTableViewCell
            cell.mediaModels = mediaModels
            cell.presentingController = self
            return cell
        case .subheader(let title, let subtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = title.emojiUnescapedString
            cell.subtitle?.text = subtitle
            return cell
        case .anticipatedHeader(let title, let action):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = title.emojiUnescapedString
            cell.subtitle?.text = ""
            cell.delegate = self

            var configuration = UIButton.Configuration.borderless()
            configuration.title = action
            configuration.titleAlignment = .trailing
            configuration.baseForegroundColor = UIColor(asset: .globalTint)
            configuration.buttonSize = .mini

            cell.button?.configuration = configuration
            cell.button?.preferredBehavioralStyle = .pad
            cell.button?.isPointerInteractionEnabled = true

            return cell
        }
    }

    private func updateUpcomingSnapshot(with models: [MediaModel]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var snapshot = self.dataSource.snapshot()

            snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.stories))
            if UserDefaults.standard.bool(forKey: "MovieToWatchSettings.upcoming") == false || models.isEmpty {
                // Do nothing
            } else {
                snapshot.appendItems([Wrapper.anticipatedHeader(UpcomingLabelManager.shared.label, "See more"),
                                      Wrapper.stories(models)], toSection: Section.stories)
            }
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ToWatchStoriesTableViewCell", bundle: nil), forCellReuseIdentifier: "stories")
        tableView.register(UINib(nibName: "ToWatchFooterTableViewCell", bundle: nil), forCellReuseIdentifier: "footer")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        dataSource.defaultRowAnimation = .fade
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.separatorStyle = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([Section.stories, Section.header, Section.content(nil, nil), Section.footer])
        dataSource.apply(snapshot, animatingDifferences: false)

        nextMoviesReceiver.listen { [weak self] futureModels in
            guard let self else { return }
            self.upcomingModels = futureModels
            self.updateUpcomingSnapshot(with: futureModels)
        }.disposed(by: disposeBag)

        upcomingLabelUpdatedReceiver.listen { [weak self] _ in
            guard let self else { return }
            self.updateUpcomingSnapshot(with: self.upcomingModels)
        }.disposed(by: disposeBag)

        var animate = false
        onMovieToWatchChangedReceiver.listen { [weak self] models in
            guard let self = self else { return }
            DispatchQueue.main.async {
                var snapshot = self.dataSource.snapshot()

                if models.isEmpty {
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.content(nil, nil)))
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.footer))
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.header))
                    for identifiers in snapshot.sectionIdentifiers {
                        switch identifiers {
                        case .content(let name, _) where name != nil:
                            snapshot.deleteSections([identifiers])
                        default:
                            continue
                        }
                    }
                    snapshot.appendItems([.footer], toSection: Section.footer)
                } else {
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.content(nil, nil)))
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.footer))
                    snapshot.deleteItems(snapshot.itemIdentifiers(inSection: Section.header))
                    for identifiers in snapshot.sectionIdentifiers {
                        switch identifiers {
                        case .content(let name, _) where name != nil:
                            snapshot.deleteSections([identifiers])
                        default:
                            continue
                        }
                    }
                    if let allMoviesInList = MovieToWatchManager.shared.moviesInList, MovieToWatchGroupMode.currentValue() == .byLists {
                        for moviesInList in allMoviesInList.sorted(by: { $0.order < $1.order }) {
                            let section = Section.content(moviesInList.name, moviesInList.order)
                            let items = models.filter { moviesInList.shows.contains($0.movie!) }
                            if items.isEmpty { continue }
                            snapshot.insertSections([section], beforeSection: Section.footer)
                            snapshot.appendItems([Wrapper.subheader(moviesInList.name, items.count > 1 ? "\(items.count) movies" : "\(items.count) movie")], toSection: section)
                            snapshot.appendItems(items.removingDuplicates().map { .content($0, moviesInList.name) }.removingDuplicates(),
                                                 toSection: section)
                        }
                    } else {
                        if let moviesInList = MovieToWatchManager.shared.moviesInList {
                            if let pinned = moviesInList.first(where: { $0.name == "Pinned" && $0.order == 0 }) {
                                let section = Section.content(pinned.name, pinned.order)
                                let items = models.filter { pinned.shows.contains($0.movie!) }
                                if !items.isEmpty {
                                    snapshot.insertSections([section], afterSection: Section.header)
                                    snapshot.appendItems([Wrapper.subheader(pinned.name, items.count > 1 ? "\(items.count) movies" : "\(items.count) movie")], toSection: section)
                                    snapshot.appendItems(items.removingDuplicates().map { .content($0, pinned.name) }.removingDuplicates(),
                                                         toSection: section)
                                    snapshot.appendItems([Wrapper.subheader("To Watch", models.count > 1 ? "\(models.count) movies" : "\(models.count) movie")], toSection: section)
                                }
                            }
                        }
                        snapshot.appendItems(models.map { .content($0, nil) }.removingDuplicates(), toSection: Section.content(nil, nil))
                    }
                    snapshot.appendItems([.footer], toSection: Section.footer)
                }
                self.dataSource.apply(snapshot, animatingDifferences: animate)
                animate = true
            }
        }.disposed(by: disposeBag)

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        onMovieToWatchStatusChangedReceiver.listen { [weak self] status in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch status {
                case .loading:
                    break
                case .content:
                    self.refreshControl?.endRefreshing()
                }
            }
        }.disposed(by: disposeBag)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(refreshMovies(_:)) { return true }
        return false
    }

    @objc private func refreshMovies(_ sender: UIKeyCommand) {
        refresh(refreshControl as Any)
    }

    @objc func refresh(_ sender: Any) {
        MovieToWatchManager.shared.forcedUserRefresh()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController, let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(media))
        } else if let mediaViewController = segue.destination as? MediaViewController,
                  let media = sender as? MediaModel {
            mediaViewController.media = media
        }
    }
}

extension MoviesToWatchViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return }
        switch wrapper {
        case .content(let media, _):
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: media.movie!.mediaModel)
        case .anticipatedHeader(let title, _):
            if UpcomingLabelManager.shared.isToggleableLabel(title.emojiUnescapedString) {
                UpcomingLabelManager.shared.toggleLabel()
            }
        case .footer:
            performSegue(withIdentifier: ViewControllerSegue.settings.rawValue, sender: nil)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let cell = tableView.cellForRow(at: indexPath) as? MediaTableViewCell else {
            return nil
        }

        contextMenu.cell = cell
        contextMenu.controller = self

        return UIContextMenuConfiguration(identifier: nil, previewProvider: {
            self.contextMenu.previewViewController
        }, actionProvider: { _ in
            self.contextMenu.menu
        })
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
        navigationController?.show(controller, sender: self)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return 100 }
        switch wrapper {
        case .content:
            return UITableView.automaticDimension
        case .header:
            return (tableView.frame.size.height * 0.7) - 100
        case .footer:
            return UITableView.automaticDimension
        case .stories:
            return 135
        case .subheader, .anticipatedHeader:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .content(let media, _):
            return media.trailingSwipeActions(for: self)
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .content(let media, _):
            guard let movie = media.movie else { return nil }

            var pin: UIContextualAction
            if movie.isPinned {
                pin = UIContextualAction(style: .normal,
                                         title: "Unpin") { _, _, boolValue in
                    movie.unpin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            } else {
                pin = UIContextualAction(style: .normal,
                                         title: "Pin") { _, _, boolValue in
                    movie.pin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            }

            return UISwipeActionsConfiguration(actions: [pin])
        default:
            return nil
        }
    }
}

extension MoviesToWatchViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let index = tableView.indexPath(for: cell) else { return }
        guard let wrapper = dataSource.itemIdentifier(for: index) else { return }

        switch wrapper {
        case .content(let media, _):
            if action == .details {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel.movie(media.movie!))
            }
        default:
            break
        }
    }
}

extension MoviesToWatchViewController: ActivityHeaderTableViewCellDelegate {
    func action(for cell: ActivityHeaderTableViewCell) {
        performSegue(withIdentifier: "calendar", sender: nil)
    }
}
