//
//  RatingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 31/01/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Moya

import Receiver

final class RatingsViewController: UITableViewController {

    var user: User!

    required init?(coder aDecoder: NSCoder) {
        self.user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    private enum ViewControllerSegue: String {
        case details
        case seasons
        case comments
    }

    private enum Filter: Int {
        case all
        case movies
        case shows
        case seasons
        case episodes
    }

    private let disposeBag = DisposeBag()

    @IBOutlet var emptyView: UIView!

    @IBOutlet var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!

    private var filteredRatings = Array(1...10) {
        didSet {
            reset()
        }
    }

    private var service: TraktAPIService = .rated(slug: "me", type: .all, extended: .full) {
        didSet {
            reset()
        }
    }
    private var cancellable: Cancellable?

    private let contextMenu = ContextMenuHelper()

    @IBOutlet weak var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.all {
        didSet {
            navigationItem.title = user.isCurrentUser ? "Ratings" : "\(user.username)'s Ratings"
            switch currentFilter {
            case .all:
                service = .rated(slug: user.slug, type: .all, extended: .full)
                navigationItem.subtitle = "All Items"
            case .movies:
                service = .rated(slug: user.slug, type: .movies, extended: .full)
                navigationItem.subtitle = "Movies"
            case .shows:
                service = .rated(slug: user.slug, type: .shows, extended: .full)
                navigationItem.subtitle = "Shows"
            case .seasons:
                service = .rated(slug: user.slug, type: .seasons, extended: .full)
                navigationItem.subtitle = "Seasons"
            case .episodes:
                service = .rated(slug: user.slug, type: .episodes, extended: .full)
                navigationItem.subtitle = "Episodes"
            }
        }
    }

    deinit {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    // Error Management
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching Ratings.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching Ratings..."
            }
        }
    }

    private enum Wrapper: Hashable {
        case stats(TraktRatings)
        case header(String)
        case item(RatedItem)
    }

    private class RatingsDiffibleDataSource: UITableViewDiffableDataSource<String, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .header:
                return false
            case .item:
                return true
            case .stats:
                return false
            }
        }
    }

    private var timeMap = [String: Int]()

    private func updateNotes(for ratedItem: RatedItem, for cell: MediaTableViewCell) {
        if user.isCurrentUser == false { return }
        let notes = ratedItem.note
        cell.note = notes
        cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                cell.notesButton?.removeAction(action, for: event)
            }
        }
        if let notes = notes, notes.isEmpty == false {
            cell.notesButton?.toolTip = notes
            cell.notesButton?.addAction(UIAction { _ in
                NotesManager.shared.showNotes(for: ratedItem)
                UISelectionFeedbackGenerator().selectionChanged()
            }, for: .touchUpInside)
        }
    }

    private lazy var dataSource = RatingsDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .item(let ratedItem):
            let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! MediaTableViewCell
            cell.watchedStatus?.removeFromSuperview()
            cell.watchlistedStatus?.removeFromSuperview()
            cell.toWatchStatus?.removeFromSuperview()
            cell.collectedStatus?.removeFromSuperview()
            cell.commentedStatus?.removeFromSuperview()
            cell.hiddenStatus?.removeFromSuperview()
            cell.recommendedStatus?.removeFromSuperview()
            cell.whereToWatchImageView?.removeFromSuperview()
            cell.dimmedIfWatched = false
            if self.user.isCurrentUser {
                cell.media = MediaModel(item: ratedItem)
            } else {
                cell.ratedItem = ratedItem
            }
            cell.delegate = self

            updateNotes(for: ratedItem, for: cell)

            return cell
        case .header(let headerTitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! RatingsHeaderTableViewCell
            cell.title.text = headerTitle
            return cell
        case .stats(let ratings):
            let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as! RatingsStatTableViewCell
            cell.filteredRatings = filteredRatings
            cell.ratings = ratings
            cell.delegate = self
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        while user == nil {
            user = UserManager.shared.currentUser
        }

        navigationItem.style = .browser

        currentFilter = Filter.all

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "RatingsHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "RatingsStatTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.dataSource = dataSource
        tableView.delegate = self
        dataSource.defaultRowAnimation = .none

        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
        snapshot.appendSections(["loading"])
        dataSource.apply(snapshot, animatingDifferences: false)

        refreshControl?.isEnabled = false

        #if targetEnvironment(macCatalyst)
        let filterButton = UIButton()
        filterButton.setImage(filterButtonItem.image?.withConfiguration(UIImage.SymbolConfiguration(scale: .large)),
                              for: .normal)
        filterButton.tintColor = .gray
        filterButton.showsMenuAsPrimaryAction = true
        filterButton.menu = filterMenu()
        filterButtonItem.customView = filterButton
        filterButton.sizeToFit()
        #else
        filterButtonItem.primaryAction = nil
        filterButtonItem.menu = filterMenu()
        #endif

        #if !targetEnvironment(macCatalyst)
        self.refreshControl = UIRefreshControl()
        #endif
        self.refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        onNotesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            for indexPathsForVisibleRow in self.tableView.indexPathsForVisibleRows ?? [] {
                let item = self.dataSource.itemIdentifier(for: indexPathsForVisibleRow)
                switch item {
                case .item(let ratedItem):
                    if let cell = self.tableView.cellForRow(at: indexPathsForVisibleRow) as? MediaTableViewCell {
                        self.updateNotes(for: ratedItem, for: cell)
                    }
                default: break
                    // do nothing
                }
            }
        }.disposed(by: disposeBag)
    }

    @objc func refresh(_ sender: Any) {
        fetchRatings()
    }

    @IBAction func retry(_ sender: Any) {
        error = nil
        fetchRatings()
    }

    @IBAction func unwindFromCommentComposer(segue: UIStoryboardSegue) {

    }

    private func reset() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }

        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
        snapshot.appendSections(["loading"])
        dataSource.apply(snapshot, animatingDifferences: false)

        retry(self)
    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let all = UIAction(title: "Everything", image: nil, state: (self.currentFilter == .all ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .all
            }

            let movies = UIAction(title: "Movies", image: nil, state: (self.currentFilter == .movies ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .movies
            }

            let shows = UIAction(title: "Shows", image: nil, state: (self.currentFilter == .shows ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .shows
            }

            let seasons = UIAction(title: "Seasons", image: nil, state: (self.currentFilter == .seasons ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .seasons
            }

            let episodes = UIAction(title: "Episodes", image: nil, state: (self.currentFilter == .episodes ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .episodes
            }

            let everyRating = UIAction(title: "All") { [weak self] _ in
                guard let self = self else { return }
                self.filteredRatings = Array(1...10)
            }

            var children = [UIAction]()

            for i in 1...9 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.filteredRatings = Array((i+1)...10)
                })
            }
            let above = UIMenu(title: "Above...", children: children)

            children.removeAll()
            for i in 2...10 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.filteredRatings = Array(1...(i-1))
                })
            }
            let below = UIMenu(title: "Below...", children: children)

            children.removeAll()
            for i in 1...10 {
                children.append(UIAction(title: "\(i)") { [weak self] _ in
                    guard let self = self else { return }
                    self.filteredRatings = [i]
                })
            }
            let exactly = UIMenu(title: "Exactly...", children: children)

            let ratings = UIMenu(title: "Ratings...", children: [everyRating, above, below, exactly])

            completion([UIMenu(title: "What do you want to see?", options: .displayInline, children: [all, movies, shows, seasons, episodes, ratings])])
        }
        return UIMenu(children: [deferredMenuElement])
    }

    func fetchRatings() {
        cancellable = TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            defer {
                DispatchQueue.main.async {
                    self.refreshControl?.isEnabled = true
                    self.refreshControl?.endRefreshing()
                }
            }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let rated = try response.map([RatedItem].self, using: TraktAPIProvider.decoder)

                    if rated.isEmpty {
                        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                        snapshot.appendSections(["empty"])
                        DispatchQueue.main.async {
                            self.dataSource.apply(snapshot, animatingDifferences: false)
                        }
                    } else {
                        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                        let formatter = DateFormatter()
                        var newTimeMap = [String: Int]()
                        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d, yyyy")

                        // stats
                        snapshot.appendSections(["stats"])
                        var votes = 0
                        var one = 0
                        var two = 0
                        var three = 0
                        var four = 0
                        var five = 0
                        var six = 0
                        var seven = 0
                        var eight = 0
                        var nine = 0
                        var ten = 0

                        for ratedItem in rated {
                            if self.filteredRatings.contains(ratedItem.rating) {
                                let relativeDate = formatter.string(from: ratedItem.rateDate)
                                if let index = snapshot.indexOfSection(relativeDate) {
                                    snapshot.appendItems([Wrapper.item(ratedItem)], toSection: snapshot.sectionIdentifiers[index])
                                    newTimeMap[relativeDate] = 0
                                } else {
                                    snapshot.appendSections([relativeDate])
                                    snapshot.appendItems([Wrapper.header(relativeDate)])
                                    snapshot.appendItems([Wrapper.item(ratedItem)])
                                    newTimeMap[relativeDate] = 0
                                }
                            }
                            switch ratedItem.rating {
                            case 1:
                                one += 1
                            case 2:
                                two += 1
                            case 3:
                                three += 1
                            case 4:
                                four += 1
                            case 5:
                                five += 1
                            case 6:
                                six += 1
                            case 7:
                                seven += 1
                            case 8:
                                eight += 1
                            case 9:
                                nine += 1
                            case 10:
                                ten += 1
                            default:
                                break
                            }
                            votes += 1
                        }
                        let avgRating = Float((one*1)+(two*2)+(three*3)+(four*4)+(five*5)+(six*6)+(seven*7)+(eight*8)+(nine*9)+(ten*10))/Float(votes)
                        let ratings = TraktRatings(rating: avgRating,
                                              votes: votes,
                                              distribution: RatingDistribution(one: one,
                                                                               two: two,
                                                                               three: three,
                                                                               four: four,
                                                                               five: five,
                                                                               six: six,
                                                                               seven: seven,
                                                                               eight: eight,
                                                                               nine: nine,
                                                                               ten: ten))
                        snapshot.appendItems([Wrapper.stats(ratings)], toSection: "stats")
                        DispatchQueue.main.async {
                            self.timeMap = newTimeMap
                            self.dataSource.apply(snapshot, animatingDifferences: false)
                        }
                    }
                } catch {
                    print("Comments request JSON mapping failed! \(error)")

                    var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                    snapshot.appendSections(["error"])
                    DispatchQueue.main.async {
                        self.error = error
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case let .failure(error):
                print("Comments request failure \(error)")

                var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                snapshot.appendSections(["error"])
                DispatchQueue.main.async {
                    self.error = error
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
            let media = sender as? MediaModel {
            commentsViewController.coordinator = CommentsCoordinator(type: .media(media))
        }

        if let mediaViewController = segue.destination as? MediaViewController,
           let media = sender as? MediaModel {
            mediaViewController.media = media
        }

        if let seasonsViewController = segue.destination as? SeasonsViewController,
            let show = sender as? Show {
            seasonsViewController.show = show
        }
    }
}

extension RatingsViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .item(let ratedItem):
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: MediaModel(item: ratedItem))
        default:
            return
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection("error") {
            return errorView
        }

        if section == dataSource.snapshot().indexOfSection("empty") {
            return emptyView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection("error") {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection("empty") {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return 0 }
        switch wrapper {
        case .item:
            return UITableView.automaticDimension
        case .header:
            return UITableView.automaticDimension
        case .stats:
            return 120
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

    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch item {
        case .item(let ratedItem):
            let notes = UIContextualAction(style: .normal, title: "Notes") { _, _, boolValue in
                NotesManager.shared.showNotes(for: ratedItem)
                boolValue(true)
            }
            notes.backgroundColor = UIColor(resource: .ripppleGray)
            notes.image = UIImage(systemName: "note.text")

            let configuration = UISwipeActionsConfiguration(actions: [notes])

            return configuration
        default:
            return nil
        }
    }
}

extension RatingsViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        guard case let Wrapper.item(ratedItem) = item else { return }

        if action == .details {
            if let show = ratedItem.show {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: show.mediaModel)
            } else if let movie = ratedItem.movie {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: movie.mediaModel)
            }
        }
    }
}

extension RatingsViewController: RatingsStatTableViewCellDelegate {
    func updateFilteredRatings(filteredRatings: [Int]) {
        self.filteredRatings = filteredRatings
    }
}

final class RatingsHeaderTableViewCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
}
