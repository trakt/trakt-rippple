//
//  EpisodesToWatchViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

import Receiver

import SafariServices

final class EpisodesToWatchViewController: UITableViewController {

    private enum ViewControllerSegue: String {
        case comments
        case details
        case seasons
        case hidden
        case pinned
        case settings
        case completed
        case dropped
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
            cell.media = media
            cell.delegate = self
            return cell
        case .header:
            return tableView.dequeueReusableCell(withIdentifier: "empty")
        case .footer:
            let cell = tableView.dequeueReusableCell(withIdentifier: "footer") as! ToWatchFooterTableViewCell
            cell.mode = .episodes
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

            if title == "Pinned" {
                cell.chevron?.isHidden = false
            } else {
                cell.chevron?.isHidden = true
            }
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
            if UserDefaults.standard.bool(forKey: "EpisodeToWatchSettings.upcoming") == false || models.isEmpty {
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
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ToWatchCalendarTableViewCell", bundle: nil), forCellReuseIdentifier: "calendar")
        tableView.register(UINib(nibName: "ToWatchFooterTableViewCell", bundle: nil), forCellReuseIdentifier: "footer")
        tableView.register(UINib(nibName: "ToWatchStoriesTableViewCell", bundle: nil), forCellReuseIdentifier: "stories")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        dataSource.defaultRowAnimation = .fade
        tableView.dataSource = dataSource
        tableView.delegate = self

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([Section.stories, Section.header, Section.content(nil, nil), Section.footer])
        dataSource.apply(snapshot, animatingDifferences: false)

        nextEpisodesReceiver.listen { [weak self] futureModels in
            guard let self else { return }
            self.upcomingModels = futureModels
            self.updateUpcomingSnapshot(with: futureModels)
        }.disposed(by: disposeBag)

        upcomingLabelUpdatedReceiver.listen { [weak self] _ in
            guard let self else { return }
            self.updateUpcomingSnapshot(with: self.upcomingModels)
        }.disposed(by: disposeBag)

        var animate = false
        onEpisodeToWatchChangedReceiver.listen { [weak self] models in
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
                    if let allShowsInList = EpisodeToWatchManager.shared.showsInList, EpisodeToWatchGroupMode.currentValue() == .byLists {
                        for showsInList in allShowsInList.sorted(by: { $0.order < $1.order }) {
                            let section = Section.content(showsInList.name, showsInList.order)
                            let items = models.filter { showsInList.shows.contains($0.show!) }
                            if items.isEmpty { continue }
                            var episodeCount = 0
                            for model in items {
                                switch model {
                                case .showProgress(_, let progress):
                                    if progress.toRewatchCount > 0 {
                                        episodeCount += progress.toRewatchCount
                                    } else {
                                        episodeCount += max(1, progress.behind)
                                    }
                                default:
                                    break
                                }
                            }
                            snapshot.insertSections([section], beforeSection: Section.footer)
                            snapshot.appendItems([Wrapper.subheader(showsInList.name, "\(episodeCount) behind")], toSection: section)
                            snapshot.appendItems(items.removingDuplicates().map { .content($0, showsInList.name) }.removingDuplicates(),
                                                 toSection: section)
                        }
                    } else {
                        if let allShowsInList = EpisodeToWatchManager.shared.showsInList {
                            if let pinned = allShowsInList.first(where: { $0.name == "Pinned" && $0.order == 0 }) {
                                let section = Section.content(pinned.name, pinned.order)
                                let items = models.filter { pinned.shows.contains($0.show!) }
                                if !items.isEmpty {
                                    var episodeCount = 0
                                    for model in items {
                                        switch model {
                                        case .showProgress(_, let progress):
                                            if progress.toRewatchCount > 0 {
                                                episodeCount += progress.toRewatchCount
                                            } else {
                                                episodeCount += max(1, progress.behind)
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    snapshot.insertSections([section], afterSection: Section.header)
                                    snapshot.appendItems([Wrapper.subheader(pinned.name, "\(episodeCount) behind")], toSection: section)
                                    snapshot.appendItems(items.removingDuplicates().map { .content($0, pinned.name) }.removingDuplicates(),
                                                         toSection: section)
                                    episodeCount = 0
                                    for model in models {
                                        switch model {
                                        case .showProgress(_, let progress):
                                            if progress.toRewatchCount > 0 {
                                                episodeCount += progress.toRewatchCount
                                            } else {
                                                episodeCount += max(1, progress.behind)
                                            }
                                        default:
                                            break
                                        }
                                    }
                                    snapshot.appendItems([Wrapper.subheader("Up Next", "\(episodeCount) behind")], toSection: section)
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
        refreshControl?.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)

        onEpisodeToWatchStatusChangedReceiver.listen { [weak self] status in
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

        toWatchTitlesReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            var snapshot = self.dataSource.snapshot()
            for identifiers in snapshot.sectionIdentifiers {
                switch identifiers {
                case .content:
                    snapshot.reloadSections([identifiers])
                default:
                    continue
                }
            }
            self.dataSource.apply(snapshot)
        }.disposed(by: disposeBag)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(refreshEpisodes(_:)) { return true }
        return false
    }

    @objc private func refreshEpisodes(_ sender: UIKeyCommand) {
        refresh(self.refreshControl as Any)
    }

    @objc func refresh(_ sender: Any) {
        EpisodeToWatchManager.shared.forcedUserRefresh()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
            let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(media))
        } else if let commentsViewController = segue.destination as? CommentsViewController,
            let show = sender as? Show {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.show(show)))
        } else if let mediaViewController = segue.destination as? MediaViewController,
            let media = sender as? MediaModel {
            mediaViewController.media = media
        } else if let seasonsViewController = segue.destination as? SeasonsViewController {
            if let show = sender as? Show {
                seasonsViewController.show = show
            } else {
                fatalError()
            }
        }
    }
}

extension EpisodesToWatchViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return }
        switch wrapper {
        case .content(let media, _):
            guard let show = media.showProgressShow else { return }

            guard let episode = media.showProgressEpisode else {
                performSegue(withIdentifier: ViewControllerSegue.seasons.rawValue, sender: show)
                return
            }
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel.episode(episode, show))
        case .subheader(let title, _):
            if title == "Pinned" {
                performSegue(withIdentifier: ViewControllerSegue.pinned.rawValue, sender: nil)
            }
        case .anticipatedHeader(let title, _):
            if UpcomingLabelManager.shared.isToggleableLabel(title.emojiUnescapedString) {
                UpcomingLabelManager.shared.toggleLabel()
            }
        case .footer:
            var preferredStyle = UIAlertController.Style.alert
            if traitCollection.userInterfaceIdiom == .phone {
                preferredStyle = .actionSheet
            }
            let alertController = UIAlertController(title: "To Watch Options",
                                                    message: "See some lists Rippple uses to build your To Watch list and configure this list how you see fit.",
                                                    preferredStyle: preferredStyle)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)

            let pinned = UIAlertAction(title: "Pinned Shows", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: ViewControllerSegue.pinned.rawValue, sender: nil)
            }
            alertController.addAction(pinned)

            let hidden = UIAlertAction(title: "Hidden from Progress", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: ViewControllerSegue.hidden.rawValue, sender: nil)
            }
            alertController.addAction(hidden)

            let completed = UIAlertAction(title: "Completed Shows", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: ViewControllerSegue.completed.rawValue, sender: nil)
            }
            alertController.addAction(completed)

            let dropped = UIAlertAction(title: "Dropped Shows", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: ViewControllerSegue.dropped.rawValue, sender: nil)
            }
            alertController.addAction(dropped)

            let config = UIAlertAction(title: "To Watch Configuration", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.performSegue(withIdentifier: ViewControllerSegue.settings.rawValue, sender: nil)
            }
            alertController.addAction(config)

            alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

            present(alertController, animated: true)
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
            return self.contextMenu.previewViewController
        }, actionProvider: { _ in
            return self.contextMenu.menu
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
            guard let show = media.showProgressShow else { return nil }

            guard let episode = media.showProgressEpisode else {
                return UISwipeActionsConfiguration(actions: [])
            }

            let media = MediaModel.episode(episode, show)

            return media.trailingSwipeActions(for: self)
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .content(let media, _):
            guard let show = media.showProgressShow else { return nil }

            let episodes = UIContextualAction(style: .normal,
                                             title: "Episodes") { _, _, boolValue in
                self.performSegue(withIdentifier: ViewControllerSegue.seasons.rawValue, sender: show)
                boolValue(true)
            }
            episodes.image = UIImage(systemName: "list.bullet.circle.fill")
            episodes.backgroundColor = UIColor(resource: .ripppleGray).lighter()

            let hide = UIContextualAction(style: .normal,
                                             title: "Hide") { _, _, boolValue in
                media.hide(from: .progressWatched)
                boolValue(true)
            }
            hide.image = UIImage(systemName: "eye.slash.circle.fill")
            hide.backgroundColor = UIColor(resource: .ripppleGray).darker()

            let drop = UIContextualAction(style: .normal,
                                             title: "Drop") { _, _, boolValue in
                media.show?.drop()
                boolValue(true)
            }
            drop.image = UIImage(systemName: "minus.circle.fill")
            drop.backgroundColor = UIColor(resource: .ripppleGray).darker().darker()

            var pin: UIContextualAction
            if show.isPinned {
                pin = UIContextualAction(style: .normal,
                                                 title: "Unpin") { _, _, boolValue in
                    show.unpin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            } else {
                pin = UIContextualAction(style: .normal,
                                                 title: "Pin") { _, _, boolValue in
                    show.pin()
                    boolValue(true)
                }
                pin.image = UIImage(systemName: "pin.circle.fill")
                pin.backgroundColor = UIColor(resource: .ripppleGray)
            }

            return UISwipeActionsConfiguration(actions: [episodes, pin, hide, drop])
        default:
            return nil
        }
    }
}

extension EpisodesToWatchViewController: MediaTableViewCellDelegate {

    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let index = tableView.indexPath(for: cell) else { return }
        guard let wrapper = dataSource.itemIdentifier(for: index) else { return }

        switch wrapper {
        case .content(let media, _):
            if action == .details {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel.show(media.showProgressShow!))
            }
        default:
            break
        }
    }
}

extension EpisodesToWatchViewController: ActivityHeaderTableViewCellDelegate {
    func action(for cell: ActivityHeaderTableViewCell) {
        performSegue(withIdentifier: "calendar", sender: nil)
    }
}
