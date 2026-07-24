//
//  RatingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 31/01/2022.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class RatingsViewController: UITableViewController {
    var user: User!

    required init?(coder aDecoder: NSCoder) {
        user = UserManager.shared.currentUser
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

    private enum GroupingMode: Int {
        case date
        case rating

        var menuTitle: String {
            switch self {
            case .date:
                return "Group by Dates"
            case .rating:
                return "Group by Ratings"
            }
        }
    }

    private struct Header: Hashable {
        let title: String
        let count: Int
    }

    private let disposeBag = DisposeBag()

    @IBOutlet var emptyView: UIView!

    @IBOutlet var errorView: UIView!
    @IBOutlet var errorLabel: UILabel!

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

    @IBOutlet var filterButtonItem: UIBarButtonItem!

    private var groupingMode = GroupingMode.date {
        didSet {
            if user.isCurrentUser == true {
                UserDefaults.standard.set(groupingMode.rawValue, forKey: "RatingsViewController.groupingMode")
                UserDefaults.standard.synchronize()
            }
            updateFilterMenu()
        }
    }

    private var ratedItems: [RatedItem]?

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

            updateFilterMenu()
        }
    }

    func cycleFilter() {
        let cycle: [Filter] = [.movies, .shows, .seasons, .episodes, .all]
        guard let currentIndex = cycle.firstIndex(of: currentFilter) else {
            currentFilter = cycle[0]
            return
        }

        currentFilter = cycle[(currentIndex + 1) % cycle.count]
    }

    deinit {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    /// Error Management
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
        case header(Header)
        case item(RatedItem)
        case loading
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
            case .loading:
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
            cell.userFavoriteStatus?.removeFromSuperview()
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
        case .header(let header):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! RatingsHeaderTableViewCell
            cell.title.text = header.title
            cell.count.text = "\(header.count) \(header.count == 1 ? "item" : "items")"
            return cell
        case .stats(let ratings):
            let cell = tableView.dequeueReusableCell(withIdentifier: "stats") as! RatingsStatTableViewCell
            cell.filteredRatings = filteredRatings
            cell.ratings = ratings
            cell.delegate = self
            return cell
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        while user == nil {
            user = UserManager.shared.currentUser
        }

        navigationItem.style = .browser

        if user.isCurrentUser,
           tabBarController != nil,
           navigationController?.viewControllers.first == self {
            let profileButton = ProfileButton()
            let profileAction = UIAction(handler: { [weak self] _ in
                guard let self = self else { return }
                let profileViewController = UIStoryboard(name: "Profile", bundle: nil).instantiateInitialViewController()!
                self.present(profileViewController, animated: true)
                UISelectionFeedbackGenerator().selectionChanged()
            })
            profileButton.addAction(profileAction, for: .touchUpInside)
            profileButton.setImage(UIImage(imageLiteralResourceName: "bg_placeholder_avatar_small"), for: .normal)
            navigationItem.leftBarButtonItem = UIBarButtonItem(customView: profileButton)
        }

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "RatingsHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "RatingsStatTableViewCell", bundle: nil), forCellReuseIdentifier: "stats")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.dataSource = dataSource
        tableView.delegate = self
        dataSource.defaultRowAnimation = .none

        dataSource.apply(loadingSnapshot(), animatingDifferences: false)

        refreshControl?.isEnabled = false

        if user.isCurrentUser,
           let groupingMode = GroupingMode(rawValue: UserDefaults.standard.integer(forKey: "RatingsViewController.groupingMode")) {
            self.groupingMode = groupingMode
        }

        filterButtonItem.primaryAction = nil
        updateFilterMenu()

        currentFilter = Filter.all

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

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

    private func setGroupingMode(_ groupingMode: GroupingMode) {
        guard self.groupingMode != groupingMode else { return }

        self.groupingMode = groupingMode
        UISelectionFeedbackGenerator().selectionChanged()

        guard let ratedItems = ratedItems else { return }
        applyRatingsSnapshot(for: ratedItems, animatingDifferences: true)
    }

    @IBAction func retry(_ sender: Any) {
        error = nil
        fetchRatings()
    }

    @IBAction func unwindFromCommentComposer(segue: UIStoryboardSegue) {}

    private func reset() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
        ratedItems = nil

        dataSource.apply(loadingSnapshot(), animatingDifferences: false)

        retry(self)
    }

    private func loadingSnapshot() -> NSDiffableDataSourceSnapshot<String, Wrapper> {
        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
        snapshot.appendSections(["loading"])
        snapshot.appendItems([.loading], toSection: "loading")
        return snapshot
    }

    private func updateFilterMenu() {
        guard isViewLoaded, filterButtonItem != nil else { return }
        filterButtonItem.menu = filterMenu()
    }

    private func ratingTitle(for rating: Int) -> String {
        switch rating {
        case 1:
            return "1/10 · I fell asleep"
        case 2:
            return "2/10 · Terrible"
        case 3:
            return "3/10 · Bad"
        case 4:
            return "4/10 · Poor"
        case 5:
            return "5/10 · Meh"
        case 6:
            return "6/10 · Fair"
        case 7:
            return "7/10 · Good"
        case 8:
            return "8/10 · Great"
        case 9:
            return "9/10 · Superb"
        case 10:
            return "10/10 · Masterpiece"
        default:
            return "\(rating)/10"
        }
    }

    private func filterMenu() -> UIMenu {
        let dateGrouping = UIAction(title: GroupingMode.date.menuTitle,
                                    state: groupingMode == .date ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.setGroupingMode(.date)
        }

        let ratingsGrouping = UIAction(title: GroupingMode.rating.menuTitle,
                                       state: groupingMode == .rating ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.setGroupingMode(.rating)
        }

        let all = UIAction(title: "Everything", image: nil, state: currentFilter == .all ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.currentFilter = .all
        }

        let movies = UIAction(title: "Movies", image: nil, state: currentFilter == .movies ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.currentFilter = .movies
        }

        let shows = UIAction(title: "Shows", image: nil, state: currentFilter == .shows ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.currentFilter = .shows
        }

        let seasons = UIAction(title: "Seasons", image: nil, state: currentFilter == .seasons ? .on : .off) { [weak self] _ in
            guard let self = self else { return }
            self.currentFilter = .seasons
        }

        let episodes = UIAction(title: "Episodes", image: nil, state: currentFilter == .episodes ? .on : .off) { [weak self] _ in
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
                self.filteredRatings = Array((i + 1)...10)
            })
        }
        let above = UIMenu(title: "Above...", children: children)

        children.removeAll()
        for i in 2...10 {
            children.append(UIAction(title: "\(i)") { [weak self] _ in
                guard let self = self else { return }
                self.filteredRatings = Array(1...(i - 1))
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
        let grouping = UIMenu(title: "What do you want to see?", options: .displayInline, children: [dateGrouping, ratingsGrouping])
        let mediaFilters = UIMenu(options: .displayInline, children: [all, movies, shows, seasons, episodes])

        return UIMenu(children: [grouping, mediaFilters, ratings])
    }

    private struct RatingsSnapshot {
        let snapshot: NSDiffableDataSourceSnapshot<String, Wrapper>
        let timeMap: [String: Int]
    }

    private func makeRatingsSnapshot(for rated: [RatedItem]) -> RatingsSnapshot {
        var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
        var newTimeMap = [String: Int]()

        if rated.isEmpty {
            snapshot.appendSections(["empty"])
            return RatingsSnapshot(snapshot: snapshot, timeMap: newTimeMap)
        }

        snapshot.appendSections(["stats"])
        snapshot.appendItems([Wrapper.stats(ratingsStats(for: rated))], toSection: "stats")

        let visibleRatedItems = rated
            .filter { filteredRatings.contains($0.rating) }
            .removingDuplicates()

        switch groupingMode {
        case .date:
            let formatter = DateFormatter()
            formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d, yyyy")

            var itemsByDate = [String: [RatedItem]]()
            var dateTitles = [String]()

            for ratedItem in visibleRatedItems {
                let dateTitle = formatter.string(from: ratedItem.rateDate)
                if itemsByDate[dateTitle] == nil {
                    dateTitles.append(dateTitle)
                    itemsByDate[dateTitle] = []
                }
                itemsByDate[dateTitle]?.append(ratedItem)
            }

            for dateTitle in dateTitles {
                guard let items = itemsByDate[dateTitle] else { continue }

                if let index = snapshot.indexOfSection(dateTitle) {
                    snapshot.appendItems(items.map(Wrapper.item), toSection: snapshot.sectionIdentifiers[index])
                } else {
                    snapshot.appendSections([dateTitle])
                    snapshot.appendItems([Wrapper.header(Header(title: dateTitle, count: items.count))], toSection: dateTitle)
                    snapshot.appendItems(items.map(Wrapper.item), toSection: dateTitle)
                }
                newTimeMap[dateTitle] = 0
            }
        case .rating:
            for rating in (1...10).reversed() {
                let items = visibleRatedItems
                    .filter { $0.rating == rating }
                    .sorted { $0.rateDate > $1.rateDate }

                guard items.isEmpty == false else { continue }

                let sectionIdentifier = "rating-\(rating)"
                let headerTitle = ratingTitle(for: rating)
                snapshot.appendSections([sectionIdentifier])
                snapshot.appendItems([Wrapper.header(Header(title: headerTitle, count: items.count))], toSection: sectionIdentifier)
                snapshot.appendItems(items.map(Wrapper.item), toSection: sectionIdentifier)
                newTimeMap[headerTitle] = 0
            }
        }

        return RatingsSnapshot(snapshot: snapshot, timeMap: newTimeMap)
    }

    private func ratingsStats(for rated: [RatedItem]) -> TraktRatings {
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

        let avgRating = Float((one * 1) + (two * 2) + (three * 3) + (four * 4) + (five * 5) + (six * 6) + (seven * 7) + (eight * 8) + (nine * 9) + (ten * 10)) / Float(votes)
        return TraktRatings(rating: avgRating,
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
    }

    private func applyRatingsSnapshot(for rated: [RatedItem], animatingDifferences: Bool) {
        let ratingsSnapshot = makeRatingsSnapshot(for: rated)
        timeMap = ratingsSnapshot.timeMap
        dataSource.apply(ratingsSnapshot.snapshot, animatingDifferences: animatingDifferences)
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
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let rated = try response.map([RatedItem].self, using: TraktAPIProvider.decoder)
                    DispatchQueue.main.async {
                        self.ratedItems = rated
                        self.applyRatingsSnapshot(for: rated, animatingDifferences: false)
                    }
                } catch {
                    print("Comments request JSON mapping failed! \(error)")

                    var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                    snapshot.appendSections(["error"])
                    DispatchQueue.main.async {
                        self.ratedItems = nil
                        self.error = error
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case .failure(let error):
                print("Comments request failure \(error)")

                var snapshot = NSDiffableDataSourceSnapshot<String, Wrapper>()
                snapshot.appendSections(["error"])
                DispatchQueue.main.async {
                    self.ratedItems = nil
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
        case .loading:
            return 116
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

            return UISwipeActionsConfiguration(actions: [notes])
        default:
            return nil
        }
    }
}

extension RatingsViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        guard case Wrapper.item(let ratedItem) = item else { return }

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
    @IBOutlet var title: UILabel!
    @IBOutlet var count: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        selectionStyle = .none
        title.textColor = .label
        count.textColor = .secondaryLabel
    }
}
