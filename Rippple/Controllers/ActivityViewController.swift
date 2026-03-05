//
//  ActivityViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 12/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import UIKit

import NVActivityIndicatorView

import Moya

import Receiver

final class ActivityViewController: UITableViewController {

    var user: User?

    private var slug: String {
        if user == nil { user = UserManager.shared.currentUser }
        if let user = user { return user.slug }
        if let user = UserManager.shared.currentUser { return user.slug }
        return "me"
    }

    required init?(coder aDecoder: NSCoder) {
        self.user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    private enum ViewControllerSegue: String {
        case comments
        case details
    }

    private enum Filter: Int {
        case none
        case movies
        case episodes
        case shows
    }

    private let disposeBag = DisposeBag()

    // @IBOutlet var loadingView: UIView!
    // @IBOutlet weak var animationViewContainer: NVActivityIndicatorView!

    @IBOutlet var emptyView: UIView!

    // Error Management
    private var error: Error? {
        didSet {
            DispatchQueue.main.async {
                if let error = self.error {
                    self.errorLabel.text = "An error occurred while fetching History.\n\(error.localizedDescription)"
                } else {
                    self.errorLabel.text = "An error occurred while fetching History..."
                }
            }

            updateDataSource()
        }
    }
    @IBOutlet var errorView: UIView!
    @IBOutlet weak var errorLabel: UILabel!

    private var cancellable: Cancellable?

    private let contextMenu = ContextMenuHelper()

    private var currentPage: PageInfo?

    private var activities = [HistoryItem]() {
        didSet {
            updateDataSource()
        }
    }

    private var shouldUpdateDataSource = true

    private func updateDataSource() {
        if shouldUpdateDataSource == false { return }

        let sortedActivities = activities.removingDuplicates().sorted(by: { $0.watchDate > $1.watchDate })
        let filteredActivities: [HistoryItem] = {
            switch currentFilter {
            case .none:
                return sortedActivities
            case .movies:
                return sortedActivities.filter { $0.movie != nil }
            case .episodes:
                return sortedActivities.filter { $0.movie == nil }
            case .shows:
                let showActivities = sortedActivities.filter { $0.show != nil }
                return latestShowActivities(from: showActivities)
            }
        }()

        if filteredActivities.isEmpty {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()

            if error != nil {
                snapshot.appendSections([.error])
            } else {
                if let currentPage = currentPage,
                    currentPage.page < currentPage.pageCount {
                    snapshot.appendSections([.loading(currentPage.nextPage)])
                    snapshot.appendItems([.loading(currentPage.nextPage)])
                } else {
                    snapshot.appendSections([.empty])
                }
            }

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }

        } else {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()

            snapshot.appendSections([.mir])
            let isCurrentUser = user?.isCurrentUser ?? true
            if isCurrentUser, UserManager.shared.currentUserCanWatchOnlyOnce {
                snapshot.appendItems([.watchOnlyOnceWarning], toSection: .mir)
            }
            snapshot.appendItems([.mir])

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US")
            var newTimeMap = [String: Int]()
            formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d, yyyy")
            for activity in filteredActivities {
                let relativeDate = if activity.watchDate.timeIntervalSince1970 == 0 { "Unknown Date"
                } else {
                    formatter.string(from: activity.watchDate)
                }
                if let index = snapshot.indexOfSection(.time(relativeDate)) {
                    snapshot.appendItems([Wrapper.item(activity, currentFilter)], toSection: snapshot.sectionIdentifiers[index])
                    newTimeMap[relativeDate] = (newTimeMap[relativeDate] ?? 0) + (activity.episode?.runtime ?? activity.movie?.runtime ?? 0)
                } else {
                    snapshot.appendSections([.time(relativeDate)])
                    snapshot.appendItems([Wrapper.header(relativeDate)])
                    snapshot.appendItems([Wrapper.item(activity, currentFilter)])
                    newTimeMap[relativeDate] = activity.episode?.runtime ?? activity.movie?.runtime ?? 0
                }
            }
            timeMap = newTimeMap

            if error != nil {
                snapshot.appendSections([.error])
            } else {
                if let currentPage = currentPage,
                    currentPage.page < currentPage.pageCount {
                    snapshot.appendSections([.loading(currentPage.nextPage)])
                    snapshot.appendItems([.loading(currentPage.nextPage)])
                }
            }

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }

    private func mediaModel(for historyItem: HistoryItem) -> MediaModel? {
        if currentFilter == .shows, let show = historyItem.show {
            return .show(show)
        }
        return MediaModel(item: historyItem)
    }

    private func latestShowActivities(from activities: [HistoryItem]) -> [HistoryItem] {
        var seenShowIdentifiers = Set<String>()
        var latestActivities = [HistoryItem]()
        for activity in activities {
            guard let show = activity.show,
                  let identifier = show.identifiers.slug else { continue }
            if seenShowIdentifiers.insert(identifier).inserted {
                latestActivities.append(activity)
            } // else it's not inserted which means it's already inserted and we already have the latest
        }
        return latestActivities
    }

    @IBOutlet weak var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.none {
        didSet {
            if navigationController?.viewControllers.first == self {
                UserDefaults.standard.set(currentFilter.rawValue, forKey: "ActivityViewController.currentFilter")
                UserDefaults.standard.synchronize()
            }

            let isCurrentUser = user?.isCurrentUser ?? true

            navigationItem.title = isCurrentUser ? "History" : "\(user!.username)'s History"

            updateSubtitle()

            updateDataSource()
        }
    }

    private func updateSubtitle() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMM d, yyyy")

        switch currentFilter {
        case .none:
            if endAtDate?.timeIntervalSince1970 == 0 {
                navigationItem.subtitle = "All Plays · Unknown Date"
            } else {
                navigationItem.subtitle = "All Plays" + (endAtDate == nil ? "" : " · \(formatter.string(from: endAtDate!))")
            }
        case .movies:
            if endAtDate?.timeIntervalSince1970 == 0 {
                navigationItem.subtitle = "Movies · Unknown Date"
            } else {
                navigationItem.subtitle = "Movies" + (endAtDate == nil ? "" : " · \(formatter.string(from: endAtDate!))")
            }
        case .episodes:
            if endAtDate?.timeIntervalSince1970 == 0 {
                navigationItem.subtitle = "Episodes · Unknown Date"
            } else {
                navigationItem.subtitle = "Episodes" + (endAtDate == nil ? "" : " · \(formatter.string(from: endAtDate!))")
            }
        case .shows:
            if endAtDate?.timeIntervalSince1970 == 0 {
                navigationItem.subtitle = "Shows · Unknown Date"
            } else {
                navigationItem.subtitle = "Shows" + (endAtDate == nil ? "" : " · \(formatter.string(from: endAtDate!))")
            }
        }
    }

    deinit {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    private enum Section: Hashable {
        case mir
        case time(String)
        case empty
        case loading(PageInfo)
        case error
    }

    private enum Wrapper: Hashable {
        case header(String)
        case item(HistoryItem, Filter)
        case loading(PageInfo)
        case mir
        case watchOnlyOnceWarning
    }

    private class ActivityTableViewDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .header:
                return false
            case .item:
                return true
            case .mir:
                return false
            case .loading:
                return false
            case .watchOnlyOnceWarning:
                return true
            }
        }
    }

    private var timeMap = [String: Int]()

    private func updateNotes(for historyItem: HistoryItem, for cell: MediaTableViewCell) {
        if user?.isCurrentUser == false { return }
        let notes = historyItem.note
        cell.note = notes
        cell.notesButton?.enumerateEventHandlers { action, _, event, _ in
            if let action = action {
                cell.notesButton?.removeAction(action, for: event)
            }
        }
        if let notes = notes, notes.isEmpty == false {
            cell.notesButton?.toolTip = notes
            cell.notesButton?.addAction(UIAction { _ in
                NotesManager.shared.showNotes(for: historyItem)
                UISelectionFeedbackGenerator().selectionChanged()
            }, for: .touchUpInside)
        }
    }

    private lazy var dataSource = ActivityTableViewDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .item(let historyItem, _):
            let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! MediaTableViewCell
            cell.watchedStatus?.removeFromSuperview()
            cell.whereToWatchImageView?.removeFromSuperview()
            cell.ratedStatus?.removeFromSuperview()

            cell.rateButton?.isHidden = false

            cell.dimmedIfWatched = false
            cell.media = mediaModel(for: historyItem)
            cell.delegate = self

            updateNotes(for: historyItem, for: cell)

            return cell
        case .header(let headerTitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = headerTitle
            let runtime = self.timeMap[headerTitle] ?? 0
            let hours = runtime / 60
            let minutes = runtime % 60
            if hours > 0 {
                cell.subtitle?.text = "\(hours) hr, \(minutes) min"
            } else {
                cell.subtitle?.text = "\(minutes) min"
            }
            return cell
        case .mir:
            let cell = tableView.dequeueReusableCell(withIdentifier: "mir") as! MirTableViewCell
            var calendar = Calendar.current
            calendar.locale = Locale(identifier: "en_US")
            cell.setup(user: user!,
                       year: calendar.component(.year, from: endAtDate ?? Date.now),
                       month: calendar.component(.month, from: endAtDate ?? Date.now))
            return cell
        case .watchOnlyOnceWarning:
            let cell = tableView.dequeueReusableCell(withIdentifier: "browse link") as! BrowseLinkCardViewCell
            cell.titleLabel.text = "Multiple Plays is Disabled"
            cell.subtitleLabel.text = "Only one play per movie or episode will be saved"
            cell.indicatorImageView.image = UIImage(systemName: "gearshape")
            cell.cardView.isHidden = true
            cell.topLayoutConstraint.constant = 4.0
            return cell
        case .loading:
            let cell = tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
            return cell
        }
    }

    private var backgroundButton: UIButton!
    private var dateSelection: UICalendarSelectionSingleDate!
    private var calendarView: UICalendarView!
    private var calendarViewConstraint: NSLayoutConstraint!
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        view.bringSubviewToFront(backgroundButton)
        view.bringSubviewToFront(calendarView)
    }

    private func configureFloatingButton() {
        backgroundButton = UIButton()
        backgroundButton.backgroundColor = .systemBackground.withAlphaComponent(0.4)
        backgroundButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundButton.alpha = 0.0
        view.addSubview(backgroundButton)
        NSLayoutConstraint.activate([
            backgroundButton.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor, constant: 100),
            backgroundButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            backgroundButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            backgroundButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
        ])

        calendarView = UICalendarView()

        dateSelection = UICalendarSelectionSingleDate(delegate: self)
        calendarView.selectionBehavior = dateSelection

        calendarView.backgroundColor = .tertiarySystemBackground
        calendarView.layer.borderColor = UIColor.secondarySystemBackground.cgColor
        calendarView.layer.borderWidth = 0.5
        calendarView.translatesAutoresizingMaskIntoConstraints = false
        calendarView.layer.cornerRadius = 10
        calendarView.layer.shadowRadius = 50
        calendarView.layer.shadowColor = UIColor.systemGray.cgColor
        calendarView.alpha = 0.0
        view.addSubview(calendarView)
        calendarViewConstraint = calendarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 640)
        NSLayoutConstraint.activate([
            calendarViewConstraint,
            calendarView.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        backgroundButton.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.dismissCalendarView(refresh: false)
            UISelectionFeedbackGenerator().selectionChanged()
        }, for: .touchUpInside)

        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90"), menu: buildMoreMenu()), .fixedSpace(), navigationItem.rightBarButtonItem!]
    }

    fileprivate func buildMoreMenu() -> UIMenu {

        var children = [UIAction]()

        let today = UIAction(title: "Reset to Now") { _ in
            self.endAtDate = nil
            self.fetchFirstActivities()
        }
        children.append(today)

        for date in getLastDaysOfPreviousMonths(from: .now, monthsBack: 6) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM"
            let pastMonth = UIAction(title: "Jump to \(formatter.string(from: date))") { _ in
                self.endAtDate = date.advanced(by: -60*60*24)
                self.fetchFirstActivities()
            }
            children.append(pastMonth)
        }

        let unknownDate = UIAction(title: "Jump to Unknown") { _ in
            self.endAtDate = Date(timeIntervalSince1970: 0)
            self.fetchFirstActivities()
        }
        children.append(unknownDate)

        let date = UIAction(title: "Pick a Date") { _ in
            self.calendarView.alpha = 1.0
            UIView.animate(withDuration: 0.6,
                           delay: 0.0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 2,
                           animations: {
                self.backgroundButton.alpha = 1.0
                self.calendarViewConstraint.constant = -40.0
                self.calendarView.layer.maskedCorners = [.layerMaxXMinYCorner,
                                                    .layerMinXMinYCorner,
                                                    .layerMaxXMaxYCorner,
                                                    .layerMinXMaxYCorner]
                self.view.layoutIfNeeded()
            })
        }
        children.append(date)

        return UIMenu(title: "Want to have a look back?", children: children)
    }

    private func getLastDaysOfPreviousMonths(from date: Date, monthsBack: Int = 6) -> [Date] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current

        var dates: [Date] = []

        for monthOffset in 1...monthsBack {
            if let targetMonth = calendar.date(byAdding: .month, value: -monthOffset, to: date) {
                let components = calendar.dateComponents([.year, .month], from: targetMonth)
                if let firstDayOfMonth = calendar.date(from: components),
                   let firstDayOfNextMonth = calendar.date(byAdding: .month, value: 1, to: firstDayOfMonth),
                   let lastMoment = calendar.date(byAdding: .second, value: -1, to: firstDayOfNextMonth) {
                    dates.append(lastMoment)
                }
            }
        }

        return dates
    }

    fileprivate func dismissCalendarView(refresh: Bool) {
        UIView.animate(withDuration: 0.4,
                       delay: 0.0,
                       animations: {
            self.backgroundButton.alpha = 0.0
            self.calendarViewConstraint.constant = 640
            self.view.layoutIfNeeded()
        }, completion: { _ in
            if refresh {
                self.fetchFirstActivities()
            }
        })
    }

    private var debouncedRefresh: Debouncer!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser

        filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")

        debouncedRefresh = Debouncer(delay: 1.0) { [weak self] in
            guard let self = self else { return }
            self.refresh(self)
        }

        configureFloatingButton()

        while user == nil {
            user = UserManager.shared.currentUser
        }

        tableView.allowsFocus = false
        tableView.separatorStyle = .none
        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "MirTableViewCell", bundle: nil), forCellReuseIdentifier: "mir")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "BrowseLinkCardViewCell", bundle: nil), forCellReuseIdentifier: "browse link")
        tableView.dataSource = dataSource
        tableView.delegate = self
        dataSource.defaultRowAnimation = .none

        shouldUpdateDataSource = false
        // if it's not the first VC on the stack, it means it's not the main user activities view but another user's
        if navigationController?.viewControllers.first != self {
            navigationItem.leftBarButtonItem = nil
            currentFilter = Filter.none
        } else {
            if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "ActivityViewController.currentFilter")) {
                currentFilter = filter
            }
            #if targetEnvironment(macCatalyst)
            // On Mac Catalyst, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                // On iPad, do not show a left bar button item.
                navigationItem.leftBarButtonItem = nil
            }
            #endif
        }
        shouldUpdateDataSource = true
        fetchFirstActivities()

        // animationViewContainer.tintColor = UIColor(asset: .globalTint)
        // animationViewContainer.startAnimating()

        WatchingManager.shared.onWatchingItemChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefresh.call()
        }.disposed(by: disposeBag)

        onMarkWatchedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefresh.call()
        }.disposed(by: disposeBag)

        onNotesChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            for indexPathsForVisibleRow in self.tableView.indexPathsForVisibleRows ?? [] {
                let item = self.dataSource.itemIdentifier(for: indexPathsForVisibleRow)
                switch item {
                case .item(let historyItem, _):
                    if let cell = self.tableView.cellForRow(at: indexPathsForVisibleRow) as? MediaTableViewCell {
                        self.updateNotes(for: historyItem, for: cell)
                    }
                default: break
                    // do nothing
                }
            }
        }.disposed(by: disposeBag)

        onRemoveWatchReceiver.listen { [weak self] historyItemIdentifier in
            guard let self = self else { return }
            self.activities.removeAll(where: { $0.identifier == historyItemIdentifier })
        }.disposed(by: disposeBag)

        onRemoveMultipleMediaReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.debouncedRefresh.call()
        }.disposed(by: disposeBag)

        applicationLifecycleReceiver.listen { [weak self] applicationLifecycle in
            guard let self = self else { return }
            switch applicationLifecycle {
            case .didFinishLaunching:
                break
            case .didBecomeActive(let time):
                if time > 60 * 60 * 1 {
                    self.debouncedRefresh.call()
                }
            case .didEnterBackground:
                break
            }
        }.disposed(by: disposeBag)

        refreshControl?.isEnabled = false

        filterButtonItem.primaryAction = nil
        filterButtonItem.menu = filterMenu()

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
    }

    @objc func refresh(_ sender: Any) {
        endAtDate = nil
        // addCalendarAction()
        fetchFirstActivities()
    }

    @IBAction func retry(_ sender: Any) {
        // retry after an error
        fetchLatestActivities()
    }

    @IBAction func unwindFromCommentComposer(segue: UIStoryboardSegue) {

    }

    private func filterMenu() -> UIMenu {
        let deferredMenuElement = UIDeferredMenuElement.uncached { completion in
            let all = UIAction(title: "Everything", image: nil, state: (self.currentFilter == .none ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .none
            }
            let movies = UIAction(title: "Movies", image: nil, state: (self.currentFilter == .movies ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .movies
            }
            let episodes = UIAction(title: "Episodes", image: nil, state: (self.currentFilter == .episodes ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .episodes
            }
            let shows = UIAction(title: "Shows", image: nil, state: (self.currentFilter == .shows ? .on : .off)) { [weak self] _ in
                guard let self = self else { return }
                self.currentFilter = .shows
            }
            completion([UIMenu(title: "What do you want to see?", options: .displayInline, children: [all, movies, episodes, shows])])
        }
        return UIMenu(children: [deferredMenuElement])
    }

    private var isLoading = false

    private func fetchFirstActivities() {
        shouldUpdateDataSource = false
        cancellable?.cancel()
        isLoading = false
        error = nil
        activities.removeAll()
        currentPage = nil
        shouldUpdateDataSource = true

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading(PageInfo.firstPage(with: 10))])
        snapshot.appendItems([.loading(PageInfo.firstPage(with: 10))])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func fetchLatestActivities() {
        shouldUpdateDataSource = false
        cancellable?.cancel()
        isLoading = false
        error = nil
        shouldUpdateDataSource = true

        var snapshot = dataSource.snapshot()
        snapshot.deleteSections([.error])
        if let currentPage = currentPage,
            currentPage.page < currentPage.pageCount {
            snapshot.appendSections([.loading(currentPage.nextPage)])
            snapshot.appendItems([.loading(currentPage.nextPage)])
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private var endAtDate: Date? {
        didSet {
            if let endAtDate = endAtDate {
                dateSelection.selectedDate = Calendar.current.dateComponents([.year, .month, .day], from: endAtDate)
            } else {
                dateSelection.selectedDate = nil
            }
            updateSubtitle()
        }
    }
    private func fetchActivity(for page: PageInfo) {
        if isLoading {
            return
        }

        print("######## Fetching activity for page: \(page.page)#####")
        cancellable = TraktAPIProvider.provider.request(.history(slug: slug,
                                                                 type: nil,
                                                                 id: nil,
                                                                 pageInfo: page,
                                                                 endDate: endAtDate?.timeIntervalSince1970 == 0 ? endAtDate : endAtDate?.advanced(by: 60*60*24)),
                                                        callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
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

                    let activities = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)

                    if let response = response.response,
                        let pageInfo = PageInfo(headers: response.allHeaderFields) {
                        self.currentPage = pageInfo
                    }

                    self.activities.append(contentsOf: activities)
                } catch {
                    print("Activity/History request JSON mapping failed! \(error)")

                    self.error = error
                }
            case let .failure(error):
                print("Activity/History request failure \(error)")
                self.error = error
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController,
            let activity = sender as? HistoryItem {
            switch activity.type {
            case .movie:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.movie(activity.movie!)))
            case .episode:
                commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.episode(activity.episode!, activity.show!)))
            case .unknown:
                fatalError("Unknown activity type")
            }
        } else if let commentsViewController = segue.destination as? CommentsViewController,
            let show = sender as? Show {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.media(.show(show)))
        } else if let mediaViewController = segue.destination as? MediaViewController,
            let media = sender as? MediaModel {
            mediaViewController.media = media
        }
    }
}

extension ActivityViewController {

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        switch item {
        case .item(let historyItem, _):
            if let media = mediaModel(for: historyItem) {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: media)
            } else {
                performSegue(withIdentifier: ViewControllerSegue.comments.rawValue,
                             sender: historyItem)
            }
        case .watchOnlyOnceWarning:
            tableView.deselectRow(at: indexPath, animated: true)
            if let url = URL(string: "https://trakt.tv/settings#global"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = dataSource.sectionIdentifier(for: section) else { return nil }

        switch section {
        case .loading:
            return nil
        case .empty:
            return emptyView
        case .error:
            return errorView
        case .time:
            return nil
        case .mir:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let section = dataSource.sectionIdentifier(for: section) else { return 0 }

        switch section {
        case .empty, .error:
            return 100
        case .loading:
            return 0
        case .time:
            return 0
        case .mir:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .loading(let page):
            fetchActivity(for: page)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
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

        guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case let Wrapper.item(historyItem, _) = item else { return nil }

        let displayMedia = mediaModel(for: historyItem)

        let next = UIContextualAction(style: .normal,
                                         title: "Next") { _, _, boolValue in
            let nextEpisodeToWatchNavigationController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "next episode") as! UINavigationController

            if let nextEpisodeViewController = nextEpisodeToWatchNavigationController.topViewController as? MediaShowNextLoadingViewController {
                if let media = displayMedia {
                    nextEpisodeViewController.media = media
                }
            }

            UIApplication.shared.present(nextEpisodeToWatchNavigationController)
            boolValue(true)
        }
        next.image = UIImage(systemName: "chevron.right.circle.fill")
        next.backgroundColor = UIColor(resource: .ripppleGray)

        let share = UIContextualAction(style: .normal,
                                      title: "Share") { _, _, boolValue in
            guard let sharedURL = displayMedia?.traktWebsiteMediaLink else { return }
            let activityViewController = UIActivityViewController(activityItems: [sharedURL], applicationActivities: nil)
            UIApplication.shared.present(activityViewController)
            boolValue(true)
        }
        share.backgroundColor = UIColor(resource: .ripppleGray).lighter()
        share.image = UIImage(systemName: "arrow.up.circle.fill")

        let comment = UIContextualAction(style: .normal,
                                         title: "Write") { [weak self] _, _, boolValue in
            guard let self = self else { return }
            let composer = UIStoryboard(name: "Compose", bundle: nil).instantiateInitialViewController() as! ComposeNavigationController
            composer.mediaModel = displayMedia
            self.present(composer, animated: true)
            boolValue(true)
        }
        comment.backgroundColor = UIColor(resource: .ripppleGray)
        comment.image = UIImage(systemName: "pencil.circle.fill")

        let recommend = UIContextualAction(style: .normal,
                                         title: "Favorite") { _, _, boolValue in
            SwiftMessages.show(message: "Adding to Favorites...", style: .loading)
            TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: WatchlistedItem(movie: historyItem.movie!)),
                                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { /*[weak self]*/ result in
        //                                                    guard let self = self else { return }
                                                            switch result {
                                                            case let .success(moyaResponse):
                                                                do {
                                                                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                                                                    DispatchQueue.main.async {
                                                                        RecommendedManager.shared.refresh()
                                                                        SwiftMessages.show(message: "⭐️ Added to Favorites")
                                                                        print("Recommendation successful \(response)")
                                                                    }

                                                                } catch {
                                                                    DispatchQueue.main.async {
                                                                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                                    }
                                                                }
                                                            case let .failure(error):
                                                                DispatchQueue.main.async {
                                                                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                                                                }
                                                            }
            }
            boolValue(false)
        }
        recommend.backgroundColor = UIColor(resource: .ripppleGray).darker()
        recommend.image = UIImage(systemName: "star.circle.fill")

        if let movie = historyItem.movie {
            if movie.isRecommended == false {
                let configuration = UISwipeActionsConfiguration(actions: [share, comment, recommend])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            } else {
                let configuration = UISwipeActionsConfiguration(actions: [share, comment])
                configuration.performsFirstActionWithFullSwipe = true

                return configuration
            }
        } else {

            next.backgroundColor = UIColor(resource: .ripppleGray).lighter()
            share.backgroundColor = UIColor(resource: .ripppleGray)
            comment.backgroundColor = UIColor(resource: .ripppleGray).darker()

            let configuration = UISwipeActionsConfiguration(actions: [next, share, comment])
            configuration.performsFirstActionWithFullSwipe = true

            return configuration
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if !user!.isCurrentUser { return nil }

        guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return nil }
        guard case let Wrapper.item(historyItem, _) = item else { return nil }

        if currentFilter == .shows, let show = mediaModel(for: historyItem) {
            let notes = UIContextualAction(style: .normal,
                                             title: "Notes") { _, _, boolValue in
                NotesManager.shared.showNotes(for: show)
                boolValue(true)
            }
            notes.backgroundColor = UIColor(resource: .ripppleGray)
            notes.image = UIImage(systemName: "note.text")

            let configuration = UISwipeActionsConfiguration(actions: [notes])
            configuration.performsFirstActionWithFullSwipe = false

            return configuration
        }

        let remove = UIContextualAction(style: .normal,
                                         title: "Remove") { [weak self] _, _, boolValue in
            guard let self = self else { return }
            guard let item = self.dataSource.itemIdentifier(for: indexPath) else { return }
            if case let Wrapper.item(historyItem, _) = item {
                SwiftMessages.show(message: "Removing from History...", style: .loading)
                TraktAPIProvider.provider.request(.removeFromHistory(id: historyItem.identifier), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                    switch result {
                    case let .success(moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            DispatchQueue.main.async {
                                if response.statusCode == 200 {
                                    SwiftMessages.show(message: "🗑 Activity removed")
                                    onRemoveWatchTransmitter.broadcast(historyItem.identifier)
                                    onRemoveWatchMediaTransmitter.broadcast(MediaModel(item: historyItem)!)
                                }
                            }
                        } catch {
                            DispatchQueue.main.async {
                                SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                            }
                        }
                    case let .failure(error):
                        DispatchQueue.main.async {
                            SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                        }
                    }
                }
            }
            boolValue(true)
        }
        remove.backgroundColor = .systemRed
        remove.image = UIImage(systemName: "trash.circle.fill")

        let notes = UIContextualAction(style: .normal,
                                         title: "Notes") { _, _, boolValue in
            NotesManager.shared.showNotes(for: historyItem)
            boolValue(true)
        }
        notes.backgroundColor = UIColor(resource: .ripppleGray)
        notes.image = UIImage(systemName: "note.text")

        let configuration = UISwipeActionsConfiguration(actions: [remove, notes])
        configuration.performsFirstActionWithFullSwipe = false

        return configuration
    }
}

extension ActivityViewController: MediaTableViewCellDelegate {

    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        guard case let Wrapper.item(historyItem, _) = item else { return }

        if action == .details {
            switch historyItem.type {
            case .movie:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel.movie(historyItem.movie!))
            case .episode:
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue, sender: MediaModel.show(historyItem.show!))
            case .unknown:
                return
            }
        }
    }
}

protocol ActivityHeaderTableViewCellDelegate: AnyObject {
    func action(for cell: ActivityHeaderTableViewCell)
}

final class ActivityHeaderTableViewCell: UITableViewCell {
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var subtitle: UILabel?
    @IBOutlet weak var chevron: UIImageView?

    @IBOutlet weak var button: UIButton?

    weak var delegate: ActivityHeaderTableViewCellDelegate? {
        didSet {
            button?.isHidden = false
        }
    }

    @IBAction func touchUpInside(_ sender: Any) {
        guard let delegate = delegate else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        delegate.action(for: self)
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        button?.isHidden = true
        chevron?.isHidden = true
        button?.contentHorizontalAlignment = .right
        selectionStyle = .none
        backgroundColor = .systemBackground

        maximumContentSizeCategory = .extraExtraExtraLarge
        button?.maximumContentSizeCategory = .extraExtraExtraLarge
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        button?.isHidden = true
        chevron?.isHidden = true
    }
}

extension ActivityViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if calendarViewConstraint.constant != 640 {
            dismissCalendarView(refresh: false)
        }
    }
}

extension ActivityViewController: UICalendarSelectionSingleDateDelegate {
    func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
        var shouldRefresh = false
        if let date = dateComponents?.date, Calendar.current.isDateInToday(date) == false {
            let newDate: Date? = date
            shouldRefresh = endAtDate != newDate
            endAtDate = newDate
        } else {
            let newDate: Date? = nil
            shouldRefresh = endAtDate != newDate
            endAtDate = newDate
        }
        dismissCalendarView(refresh: shouldRefresh)
    }
}
