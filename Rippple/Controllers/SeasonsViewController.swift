//
//  SeasonsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 19/08/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class SeasonsViewController: UITableViewController {
    private enum ViewControllerSegue: String {
        case comments
        case details
    }

    private let disposeBag = DisposeBag()

    private var selectedMedia: MediaModel?

    private var jumpToNextEpisode = true

    // Public
    var show: Show!
    var season: Season? {
        didSet {
            jumpToNextEpisode = false
        }
    }

    /// Empty
    @IBOutlet private var emptyView: UIView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching episodes.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching episodes..."
            }
        }
    }

    private enum Section: Int {
        case loading
        case error
        case content
    }

    @IBOutlet var jumperButtonItem: UIBarButtonItem!

    private enum Wrapper: Hashable {
        case season(Season, CardType, SeasonProgress?)
        case episode(Episode, CardType, EpisodeProgress?, Date?)
        case loading

        func hash(into hasher: inout Hasher) {
            switch self {
            case .season(let season, _, _):
                hasher.combine(season)
            case .episode(let episode, _, _, _):
                hasher.combine(episode)
            case .loading:
                break
            }
        }

        static func == (lhs: Wrapper, rhs: Wrapper) -> Bool {
            switch lhs.self {
            case .episode(let episode, _, _, _):
                switch rhs.self {
                case .episode(let episode2, _, _, _):
                    return episode == episode2
                case .season:
                    return false
                case .loading:
                    return false
                }
            case .season(let season, _, _):
                switch rhs.self {
                case .episode:
                    return false
                case .season(let season2, _, _):
                    return season == season2
                case .loading:
                    return false
                }
            case .loading:
                return false
            }
        }
    }

    private class SeasonsTableViewDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .episode:
                return true
            case .season:
                return true
            case .loading:
                return false
            }
        }
    }

    private lazy var dataSource = SeasonsTableViewDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .season(let season, let cardType, let progress):
            let cell = tableView.dequeueReusableCell(withIdentifier: "season") as! SeasonShowTableViewCell
            cell.delegate = self
            cell.media = MediaModel.season(season, self.show)
            cell.card.cardType = cardType
            cell.progress = progress
            return cell
        case .episode(let episode, let cardType, let progress, let resetDate):
            let cell = tableView.dequeueReusableCell(withIdentifier: "episode") as! EpisodeShowTableViewCell
            cell.resetDate = resetDate // needs to be set before other properties
            cell.media = MediaModel.episode(episode, self.show)
            cell.card.cardType = cardType
            cell.progress = progress
            if let progress = self.progress {
                if progress.nextEpisodeToWatch == episode {
                    cell.additionalInfo.isHidden = false
                } else {
                    cell.additionalInfo.isHidden = true
                }
            } else {
                cell.additionalInfo.isHidden = true
            }
            return cell
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        }
    }

    private var seasons: [Season]? {
        didSet {
            if let first = seasons?.first, first.number == 0 {
                seasons?.removeFirst()
                seasons?.append(first)
            }
            updateDataSource()
        }
    }

    private var progress: ShowProgress? {
        didSet {
            if progress != oldValue {
                updateDataSource()
            }
        }
    }

    private func progress(for season: Season) -> SeasonProgress? {
        guard let progress = progress else { return nil }
        for seasonProgress in progress.seasons where seasonProgress.number == season.number {
            return seasonProgress
        }
        return nil
    }

    private func progress(for episode: Episode, in season: Season) -> EpisodeProgress? {
        guard let seasonProgress = progress(for: season) else { return nil }
        for episodeProgress in seasonProgress.episodes where episodeProgress.number == episode.number {
            return episodeProgress
        }
        return nil
    }

    private func updateDataSource() {
        guard let seasons = seasons else { return }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        for season in seasons {
            if let episodes = season.episodes, !episodes.isEmpty {
                snapshot.appendItems([Wrapper.season(season, .top, progress(for: season))])
                snapshot.appendItems(episodes.map { Wrapper.episode($0, episodes.last == $0 ? .bottom : .middle, progress(for: $0, in: season), progress?.resetAt) })
            } else {
                snapshot.appendItems([Wrapper.season(season, .alone, progress(for: season))])
            }
        }
        DispatchQueue.main.async {
            self.dataSource.applySnapshotUsingReloadData(snapshot) {
                if let season = self.season {
                    self.scroll(to: season, animated: false)
                    self.season = nil
                } else if let episode = self.progress?.nextEpisodeToWatch,
                          self.jumpToNextEpisode == true {
                    self.scroll(to: episode, animated: true)
                }
            }
            self.jumperButtonItem.menu = self.jumperMenu()
            self.updateSelectButton()
        }
    }

    @IBAction func retryAfterError(_ sender: Any) {
        navigationItem.subtitle = "Loading..."

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        snapshot.appendItems([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        fetch()
    }

    @objc
    private func select() {
        if tableView.isEditing {
            let count = tableView.indexPathsForSelectedRows?.count ?? 0
            if count != 0 {
                // do something with the episodes
                guard let navigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Action Navigation Controller") as? UINavigationController else { return }

                let markWatchedActionViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Mark Watched") { [weak self] coder -> MarkWatchedActionViewController? in
                    guard let self = self else { return nil }
                    return MarkWatchedActionViewController(coder: coder,
                                                           media: self.show.mediaModel,
                                                           episodes: self.tableView.indexPathsForSelectedRows!.compactMap {
                                                               guard let item = self.dataSource.itemIdentifier(for: $0) else { return nil }
                                                               if case Wrapper.episode(let episode, _, _, _) = item {
                                                                   return episode.mediaModel(given: self.show)
                                                               }
                                                               return nil
                                                           })
                }

                navigationController.viewControllers = [markWatchedActionViewController]

                present(navigationController, animated: true)

                tableView.setEditing(false, animated: true)
            }
        } else {
            tableView.setEditing(true, animated: true)
        }
        updateSelectButton()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(show != nil, "Seasons list view controller must be fed with a show object!")

        navigationItem.style = .browser
        title = show.title
        navigationItem.subtitle = "Loading..."

        tableView.allowsFocus = false
        tableView.allowsFocusDuringEditing = false
        tableView.allowsSelectionDuringEditing = true
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.register(UINib(nibName: "SeasonShowTableViewCell", bundle: nil), forCellReuseIdentifier: "season")
        tableView.register(UINib(nibName: "EpisodeShowTableViewCell", bundle: nil), forCellReuseIdentifier: "episode")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        snapshot.appendItems([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        navigationItem.largeTitleDisplayMode = .never

        jumperButtonItem.primaryAction = nil
        jumperButtonItem.menu = jumperMenu()

        if navigationController?.viewControllers.first == self {
            navigationController?.isNavigationBarHidden = false
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done",
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(done))
        }

        fetch()

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.show.mediaModel.forceProgress { _ in }
            }
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            if progress.show == self.show {
                self.progress = progress.showProgress
            }
        }.disposed(by: disposeBag)

        show.mediaModel.progress { [weak self] progress in
            guard let self = self else { return }
            self.progress = progress
        }

        episodeListTitlesReceiver.listen { [weak self] _ in
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

    func fetch() {
        guard let showId = show.identifiers.trakt else { return }

        TraktAPIProvider.provider.request(.seasons(id: showId), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let seasons = try response.map([Season].self, using: TraktAPIProvider.decoder)

                    self.seasons = seasons
                } catch {
                    print("Seasons request JSON mapping failed! \(error)")

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.error = error
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case .failure(let error):
                print("Seasons request failure \(error)")

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.error = error
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController {
            let type = sender as! CommentsCoordinator.ListType
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }

        if let mediaViewController = segue.destination as? MediaViewController {
            let media = sender as! MediaModel
            mediaViewController.media = media
        }
    }

    @IBSegueAction
    func makeMarkWatchedActionViewController(coder: NSCoder, sender: Any?) -> MarkWatchedActionViewController? {
        guard let media = selectedMedia else { return nil }
        return MarkWatchedActionViewController(coder: coder,
                                               media: media)
    }

    private func jumperMenu() -> UIMenu? {
        guard let seasons = seasons else {
            navigationItem.rightBarButtonItem = nil
            return nil
        }

        var actions = [UIAction]()

        for season in seasons {
            var state: UIMenuElement.State = .off
            if let progress = progress(for: season) {
                if progress.aired == progress.completed {
                    state = .on
                }
            }
            actions.append(UIAction(title: season.title ?? "Season \(season.number)", state: state) { [weak self] _ in
                guard let self = self else { return }
                self.scroll(to: season, animated: true)
            })
        }

        return UIMenu(title: "What season are you looking for?", children: actions)
    }

    private func scroll(to season: Season, animated: Bool) {
        if let indexPath = dataSource.indexPath(for: Wrapper.season(season, .top, nil)) {
            tableView.scrollToRow(at: indexPath,
                                  at: .top,
                                  animated: animated)
        }
    }

    private func scroll(to episode: Episode, animated: Bool) {
        if let indexPath = dataSource.indexPath(for: Wrapper.episode(episode, .top, nil, nil)) {
            tableView.scrollToRow(at: indexPath,
                                  at: .middle,
                                  animated: animated)
        }
    }
}

extension SeasonsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateSelectButton()
            return
        }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case Wrapper.season(let season, _, _) = item {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: season.mediaModel(given: show))
        }
        if case Wrapper.episode(let episode, _, _, _) = item {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel.episode(episode, show))
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return errorView
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return emptyView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        if case Wrapper.season(let season, _, _) = item {
            return season.mediaModel(given: show).trailingSwipeActions(for: self)
        }
        if case Wrapper.episode(let episode, _, _, _) = item {
            return episode.mediaModel(given: show).trailingSwipeActions(for: self)
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }

        let action: UIContextualAction

        switch item {
        case .season(let season, _, _):
            action = UIContextualAction(style: .destructive, title: "Remove All Watch") { [weak self] _, _, completion in
                guard let self = self else { completion(false); return }
                let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                    message: "Are you sure you want to remove all watch in this season?",
                                                                    preferredStyle: .alert)
                confirmationAlertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    completion(false)
                }))
                confirmationAlertController.addAction(UIAlertAction(title: "Yes, Remove All Watch", style: .destructive, handler: { _ in
                    guard let traktId = season.identifiers.trakt else {
                        completion(false)
                        return
                    }
                    TraktAPIProvider.provider.request(.removeSeasonFromHistory(id: traktId),
                                                      callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(let moyaResponse):
                            do {
                                _ = try moyaResponse.filterSuccessfulStatusCodes()
                                DispatchQueue.main.async {
                                    completion(true)
                                    SwiftMessages.show(message: "🗑 Watch removed")
                                    self.show.mediaModel.forceProgress { _ in }
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    completion(false)
                                    SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(false)
                                SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                            }
                        }
                    }
                }))
                self.present(confirmationAlertController, animated: true)
            }
        case .episode(let episode, _, _, _):
            action = UIContextualAction(style: .destructive, title: "Remove All Watch") { [weak self] _, _, completion in
                guard let self = self else { completion(false); return }
                let confirmationAlertController = UIAlertController(title: "⚠️",
                                                                    message: "Are you sure you want to remove all watch for this episode?",
                                                                    preferredStyle: .alert)
                confirmationAlertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                    completion(false)
                }))
                confirmationAlertController.addAction(UIAlertAction(title: "Yes, Remove All Watch", style: .destructive, handler: { _ in
                    guard let traktId = episode.identifiers.trakt else {
                        completion(false)
                        return
                    }
                    TraktAPIProvider.provider.request(.removeEpisodeFromHistory(id: traktId),
                                                      callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                        guard let self = self else { return }
                        switch result {
                        case .success(let moyaResponse):
                            do {
                                _ = try moyaResponse.filterSuccessfulStatusCodes()
                                DispatchQueue.main.async {
                                    completion(true)
                                    SwiftMessages.show(message: "🗑 Watch removed")
                                    self.show.mediaModel.forceProgress { _ in }
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    completion(false)
                                    SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(false)
                                SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                            }
                        }
                    }
                }))
                self.present(confirmationAlertController, animated: true)
            }
        case .loading:
            return nil
        }

        action.image = UIImage(systemName: "trash")
        let config = UISwipeActionsConfiguration(actions: [action])
        config.performsFirstActionWithFullSwipe = false

        return config
    }
}

extension SeasonsViewController {
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    override func tableView(_ tableView: UITableView, shouldBeginMultipleSelectionInteractionAt indexPath: IndexPath) -> Bool {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return false }
        if case Wrapper.episode = item {
            return true
        }
        return false
    }

    override func tableView(_ tableView: UITableView, didBeginMultipleSelectionInteractionAt indexPath: IndexPath) {
        tableView.setEditing(true, animated: true)

        // tableView.cellForRow(at: indexPath)?.setSelected(true, animated: true)
    }

    @objc func cancelEdit() {
        tableView.setEditing(false, animated: true)
        updateSelectButton()
    }

    override func tableViewDidEndMultipleSelectionInteraction(_ tableView: UITableView) {
        updateSelectButton()
    }

    private func updateSelectButton() {
        if tableView.isEditing {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                                               target: self,
                                                               action: #selector(cancelEdit))

            guard let indexPathsForSelectedRows = tableView.indexPathsForSelectedRows else {
                navigationItem.subtitle = "Select Episodes..."
                let action = UIBarButtonItem(image: UIImage(systemName: "checkmark"))
                action.isEnabled = false
                action.style = .plain
                navigationItem.setRightBarButtonItems([action], animated: true)
                return
            }
            let count = indexPathsForSelectedRows.filter {
                if case .episode = self.dataSource.itemIdentifier(for: $0) {
                    return true
                }
                return false
            }.count
            if count == 0 {
                navigationItem.subtitle = "Select Episodes..."
                let action = UIBarButtonItem(image: UIImage(systemName: "checkmark"))
                action.isEnabled = false
                action.style = .plain
                navigationItem.setRightBarButtonItems([action], animated: true)
            } else {
                navigationItem.subtitle = "\(count) Selected"
                let action = UIBarButtonItem(image: UIImage(systemName: "checkmark"),
                                             primaryAction: UIAction(handler: { _ in
                                                 self.select()
                                             }))
                action.style = .prominent
                navigationItem.setRightBarButtonItems([action], animated: true)
            }
        } else {
            if navigationController?.viewControllers.first == self {
                navigationController?.isNavigationBarHidden = false
                navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done",
                                                                   style: .plain,
                                                                   target: self,
                                                                   action: #selector(done))
            } else {
                navigationItem.leftBarButtonItem = nil
            }

            title = show.title
            navigationItem.subtitle = "Seasons and Episodes"

            if let seasons = seasons, seasons.count > 1 {
                navigationItem.setRightBarButtonItems([jumperButtonItem, .fixedSpace(), .init(title: "Select", primaryAction: UIAction(handler: { _ in
                    self.select()
                }))], animated: true)
            } else {
                navigationItem.setRightBarButtonItems([.init(title: "Select", primaryAction: UIAction(handler: { _ in
                    self.select()
                }))], animated: true)
            }
        }
    }

    @objc func done() {
        dismiss(animated: true, completion: nil)
    }
}

extension SeasonsViewController: SeasonShowTableViewCellDelegate {
    func cell(_ cell: SeasonShowTableViewCell, action: SeasonShowTableViewCell.Action) {
        // Do nothing, now handled in TableView delegate
    }
}
