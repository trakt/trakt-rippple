//
//  CalendarViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 05/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

// Nice to have
// (nice to have) refactor cell,... setup
// (nice to have) would be cool to see the list of hidden from calendar somewhere
// (nice to have) group 10 episodes released the same day/hour
// (nice to have) Find a way to better show what is past and present+future -> maybe with an empty section or something...

import NVActivityIndicatorView
import Receiver
import SwiftUI
import UIKit

final class Debouncer {
    var callback: () -> Void
    var delay: Double
    private var workItem: DispatchWorkItem?
    private let lock = NSLock()

    init(delay: Double, callback: @escaping (() -> Void)) {
        self.delay = delay
        self.callback = callback
    }

    func call() {
        print("Debouncer called")
        let item: DispatchWorkItem
        lock.lock()
        // Cancel any pending work
        workItem?.cancel()

        // Create a new work item
        item = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            print("Debouncer execute")
            self.callback()
        }

        // Keep a strong reference so we can cancel if needed
        workItem = item
        lock.unlock()

        // Schedule on the main queue after the specified delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func fireNow() {
        let callback: () -> Void
        lock.lock()
        // Cancel any pending debounced work
        workItem?.cancel()
        workItem = nil
        callback = self.callback
        lock.unlock()

        // Execute immediately on main queue to match previous semantics
        DispatchQueue.main.async {
            callback()
        }
    }
}

extension Locale {
    func localizedCountry(for regionCode: String) -> String {
        let countriesWithThe = ["Bahamas",
                                "Cayman Islands",
                                "Central African Republic",
                                "Channel Islands",
                                "Comoros",
                                "Czech Republic",
                                "Dominican Republic",
                                "Falkland Islands",
                                "Gambia",
                                "Isle of Man",
                                "Ivory Coast",
                                "Leeward Islands",
                                "Maldives",
                                "Maldive Islands",
                                "Marshall Islands",
                                "Netherlands",
                                "Netherlands Antilles",
                                "Philippines",
                                "Solomon Islands",
                                "Turks and Caicos Islands",
                                "United Arab Emirates",
                                "United Kingdom",
                                "United Kingdom of Great Britain and Northern Ireland",
                                "United States",
                                "United States of America",
                                "Virgin Islands"]
        if let localizedCountry = localizedString(forRegionCode: regionCode) {
            if countriesWithThe.contains(localizedCountry) {
                return "the \(localizedCountry)"
            } else {
                return localizedCountry
            }
        } else {
            return "unknown"
        }
    }
}

final class CalendarViewController: UITableViewController {
    private enum ViewControllerSegue: String {
        case details
    }

    private let contextMenu = ContextMenuHelper()

    private let disposeBag = DisposeBag()

    private var debouncedReloadData: Debouncer!

    @IBOutlet var loadingView: UIView!
    @IBOutlet var animationViewContainer: NVActivityIndicatorView!

    enum Section: Hashable {
        case day(Date)
        case loading
        case empty
    }

    enum Wrapper: Hashable {
        case empty(String, String, String, String)
        case loading
        case nothing
        case header(Date)
        case media(MediaModel, String?, String?)
    }

    private var now = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date.now)!

    private class CalendarViewDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private var headerDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter
    }

    private lazy var dataSource = CalendarViewDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, wrapper in
        guard let self = self else { return nil }

        switch wrapper {
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        case .nothing:
            return UITableViewCell()
        case .header(let date):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell

            let now = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date.now)!

            let diff = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
            if diff == 0 {
                cell.title.text = "— \(headerDateFormatter.string(from: date))"
                cell.title.textColor = UIColor(asset: .globalTint)
                cell.subtitle?.text = "today"
                cell.subtitle?.textColor = UIColor(asset: .globalTint)
            } else if diff == 1 {
                cell.title.text = "↑ \(headerDateFormatter.string(from: date))"
                cell.title.textColor = .label
                cell.subtitle?.text = "tomorrow"
                cell.subtitle?.textColor = .secondaryLabel
            } else if diff == -1 {
                cell.title.text = "↓ \(headerDateFormatter.string(from: date))"
                cell.title.textColor = .secondaryLabel
                cell.subtitle?.text = "yesterday"
                cell.subtitle?.textColor = .secondaryLabel
            } else if date > now {
                cell.title.text = "↑ \(headerDateFormatter.string(from: date))"
                cell.title.textColor = .label
                cell.subtitle?.text = "in \(abs(diff)) days"
                cell.subtitle?.textColor = .secondaryLabel
            } else {
                cell.title.text = "↓ \(headerDateFormatter.string(from: date))"
                cell.title.textColor = .secondaryLabel
                cell.subtitle?.text = "\(abs(diff)) days ago"
                cell.subtitle?.textColor = .secondaryLabel
            }
            return cell
        case .media(let media, let subtitle, let meta):
            let cell = tableView.dequeueReusableCell(withIdentifier: "media") as! MediaTableViewCell
            cell.calendarMode = true
            cell.media = media
            cell.delegate = self
            cell.hiddenStatus?.isHidden = true
            cell.contentView.alpha = 1.0
            switch media {
            case .episode(let episode, let show):
                if episode.isWatched {
                    cell.contentView.alpha = 0.6
                }
                if show.isHiddenFromCalendar {
                    cell.contentView.alpha = 0.6
                    cell.hiddenStatus?.isHidden = false
                }
            case .movie(let movie):
                if movie.isWatched {
                    cell.contentView.alpha = 0.6
                }
                if movie.isHiddenFromCalendar {
                    cell.contentView.alpha = 0.6
                    cell.hiddenStatus?.isHidden = false
                }
            default:
                break
            }
            if let subtitle = subtitle { cell.submeta?.text = subtitle }
            if let meta = meta { cell.meta?.text = meta }
            return cell
        case .empty(let emoji, let title, let subtitle, let body):
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = emoji
            cell.title.text = title
            cell.subtitle.text = subtitle
            cell.body.text = body
            cell.action.isHidden = true
            return cell
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        view.bringSubviewToFront(loadingView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        debouncedReloadData = Debouncer(delay: 0.8) { [weak self] in
            guard let self = self else { return }
            Task {
                await self.reloadData()
            }
        }

        dataSource.defaultRowAnimation = .fade

        tableView.allowsFocus = false
        tableView.separatorStyle = .none

        tableView.register(UINib(nibName: "MediaTableViewCell", bundle: nil), forCellReuseIdentifier: "media")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.dataSource = dataSource
        tableView.delegate = self

        calendarDataUpdatedReceiver.listen { [weak self] data in
            guard let self = self else { return }
            Task { await self.applyCalendarData(data) }
        }.disposed(by: disposeBag)

        Task {
            await reloadData()
        }

        let down = UIBarButtonItem(image: UIImage(systemName: "chevron.down"),
                                   primaryAction: UIAction { [weak self] _ in
                                       guard let self = self else { return }
                                       self.scrollToNextBestPosition()
                                   })
        let up = UIBarButtonItem(image: UIImage(systemName: "chevron.up"),
                                 primaryAction: UIAction { [weak self] _ in
                                     guard let self = self else { return }
                                     self.scrollToPreviousBestPosition()
                                 })
        let settings = navigationItem.rightBarButtonItem!
        navigationItem.rightBarButtonItems = [down, up, .fixedSpace(), settings]

        navigationItem.style = .browser
        navigationItem.title = "Calendar"
        navigationItem.subtitle = "Loading..."
    }

    @objc func dayChanged(_ notification: Notification) {
        now = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date.now)!
        debouncedReloadData.call()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, do not show a left bar button item.
        navigationItem.leftBarButtonItem = nil
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            // On iPad, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
        }
        #endif

        // not the first thing in the navigation controller, remove the profile
        if navigationController?.viewControllers.first != self {
            navigationItem.leftBarButtonItem = nil
        }
    }

    private var didAppear: Bool?
    private var shouldReload: Bool?
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didAppear = true
        if shouldReload == true {
            debouncedReloadData.call()
        }

        view.insertSubview(loadingView,
                           aboveSubview: tableView)

        loadingView.alpha = 0.0
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            loadingView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            loadingView.heightAnchor.constraint(equalToConstant: 3),
            loadingView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
        ])

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        didAppear = false
    }

    private var isReloading: Bool?
    private func reloadData() async {
        // _ = try? await CalendarManager.shared.reload(referenceDate: .now)
    }

    fileprivate func applyCalendarData(_ data: CalendarData) async {
        let firstLoad = dataSource.snapshot().numberOfItems == 0

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        var dates = [Date]()
        for i in -33...33 {
            let date = Calendar.current.date(bySettingHour: 0,
                                             minute: 0,
                                             second: 0,
                                             of: Date.now.advanced(by: Double(i) * 60 * 60 * 24))!
            dates.append(date)
        }
        snapshot.appendSections(dates.removingDuplicates().map { .day($0) })

        for media in data.movies.map({ $0.mediaModel }) {
            guard let released = media.movie!.released else { continue }
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let date = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: df.date(from: released)!)!
            if let index = snapshot.indexOfSection(.day(date)) {
                let section = snapshot.sectionIdentifiers[index]
                if !snapshot.itemIdentifiers(inSection: section).contains(.header(date)) {
                    snapshot.appendItems([.header(date)], toSection: section)
                }
                var subtitle = ""
                if let movie = media.movie, data.trendingMovies.contains(movie) {
                    subtitle = "🔥 Trending"
                } else if let movie = media.movie, data.anticipatedMovies.contains(movie) {
                    subtitle = "👀 Anticipated"
                }
                var localizedCountry = "In unknown"
                if let movieCountry = media.movie!.country {
                    localizedCountry = "In \(Locale(identifier: "en_US").localizedCountry(for: movieCountry))"
                }
                snapshot.appendItems([.media(media, subtitle, localizedCountry)], toSection: section)
            }
        }

        for media in data.shows.map({ $0.episode.mediaModel(given: $0.show) }) {
            let date = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: media.episode!.firstAired!)!
            if let index = snapshot.indexOfSection(.day(date)) {
                let section = snapshot.sectionIdentifiers[index]
                if !snapshot.itemIdentifiers(inSection: section).contains(.header(date)) {
                    snapshot.appendItems([.header(date)], toSection: section)
                }
                var meta = ""
                if let firstAired = media.episode!.firstAired {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "en_US")
                    dateFormatter.dateStyle = .none
                    dateFormatter.timeStyle = .short
                    meta += dateFormatter.string(from: firstAired)
                }
                if let network = media.show!.network {
                    meta += " on \(network)"
                }
                var subtitle = ""
                if let show = media.show, data.trendingShows.contains(show) {
                    subtitle = "🔥 Trending"
                } else if let show = media.show, data.anticipatedShows.contains(show) {
                    subtitle = "👀 Anticipated"
                }
                snapshot.appendItems([.media(media, subtitle, meta)], toSection: section)
            }
        }

        if snapshot.itemIdentifiers.isEmpty {
            snapshot.appendSections([.empty])
            snapshot.appendItems([.empty("🗓️", "Nothing ahead", "We couldn't find anything right now", "Add stuff to your lists, start watching something or update the filters on the top right to fill this calendar.")])
            DispatchQueue.main.async {
                self.loadingView.alpha = 0.0
                self.dataSource.apply(snapshot, animatingDifferences: false, completion: nil)
            }
        } else if firstLoad {
            DispatchQueue.main.async {
                self.loadingView.alpha = 0.0
                self.dataSource.apply(snapshot, animatingDifferences: false)
                self.scrollToClosestToNow(animated: false)
            }
        } else {
            DispatchQueue.main.async {
                self.loadingView.alpha = 0.0
                self.dataSource.apply(snapshot, animatingDifferences: true)
            }
        }
    }

    @objc private func addTapped() {}

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController,
           let media = sender as? MediaModel {
            mediaViewController.media = media
        }
    }
}

extension CalendarViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let firstIndexPath = tableView.indexPathForRow(at: CGPoint(x: 0.0,
                                                                         y: tableView.adjustedContentInset.top + tableView.contentOffset.y + 1.0)) else { return }

        guard let section = dataSource.sectionIdentifier(for: firstIndexPath.section) else { return }
        switch section {
        case .day(let date):
            let diff = Calendar.current.dateComponents([.day], from: now, to: date).day ?? 0
            if diff == 0 {
                navigationItem.subtitle = "— \(headerDateFormatter.string(from: date))"
            } else if date > now {
                navigationItem.subtitle = "↑ \(headerDateFormatter.string(from: date))"
            } else {
                navigationItem.subtitle = "↓ \(headerDateFormatter.string(from: date))"
            }
        case .loading:
            return
        case .empty:
            return
        }
    }

    func scrollToClosestToNow(animated: Bool) {
        let now = Calendar.current.date(bySettingHour: 0,
                                        minute: 0,
                                        second: 0,
                                        of: Date.now)!
        for section in dataSource.snapshot().sectionIdentifiers {
            switch section {
            case .day(let date):
                if date >= now {
                    if let indexPath = dataSource.indexPath(for: .header(date)) {
                        tableView.scrollToRow(at: indexPath,
                                              at: .top,
                                              animated: animated)
                        return
                    }
                }
            case .loading:
                break
            case .empty:
                break
            }
        }
    }

    func scrollToNextBestPosition() {
        guard let firstIndexPath = tableView.indexPathForRow(at: CGPoint(x: 0.0,
                                                                         y: tableView.adjustedContentInset.top + tableView.contentOffset.y + 1.0)) else { return }
        guard let currentSection = dataSource.sectionIdentifier(for: firstIndexPath.section) else { return }
        guard case .day(let currentDate) = currentSection else { return }

        for section in dataSource.snapshot().sectionIdentifiers {
            switch section {
            case .day(let date):
                if date > currentDate {
                    if let indexPath = dataSource.indexPath(for: .header(date)) {
                        tableView.scrollToRow(at: indexPath,
                                              at: .top,
                                              animated: true)
                        return
                    }
                }
            case .loading:
                break
            case .empty:
                break
            }
        }
    }

    func scrollToPreviousBestPosition() {
        guard let previousIndexPath = tableView.indexPathForRow(at: CGPoint(x: 0.0,
                                                                            y: tableView.adjustedContentInset.top + tableView.contentOffset.y - 1)) else { return }
        guard let previousSection = dataSource.sectionIdentifier(for: previousIndexPath.section) else { return }
        guard case .day(let previousDate) = previousSection else { return }

        if let indexPath = dataSource.indexPath(for: .header(previousDate)) {
            tableView.scrollToRow(at: indexPath,
                                  at: .top,
                                  animated: true)
        }
    }

    override func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        scrollToClosestToNow(animated: true)

        return false
    }
}

extension CalendarViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return 0 }
        switch wrapper {
        case .media:
            return UITableView.automaticDimension
        case .header:
            return UITableView.automaticDimension
        case .loading:
            return 100
        case .nothing:
            return 0
        case .empty:
            return UITableView.automaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        if case Wrapper.media(let media, _, _) = item {
            performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                         sender: media)
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
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .media(let media, _, _):
            let hide = UIContextualAction(style: .normal,
                                          title: "Hide") { _, _, boolValue in
                if media.movie != nil {
                    media.hide(from: .calendar)
                    boolValue(true)
                } else {
                    media.show?.mediaModel.hide(from: .calendar)
                    boolValue(true)
                }
            }
            hide.image = UIImage(systemName: "eye.slash.circle.fill")
            hide.backgroundColor = UIColor(resource: .ripppleGray).darker()

            let list = UIContextualAction(style: .normal,
                                          title: "List") { _, _, boolValue in
                let listViewController = UIStoryboard(name: "Actions", bundle: nil).instantiateViewController(identifier: "Lists Action") as! ListActionViewController

                if media.show != nil {
                    listViewController.media = media.show!.mediaModel
                } else {
                    listViewController.media = media
                }

                self.present(listViewController, animated: true)

                boolValue(true)
            }
            list.image = UIImage(systemName: "plusminus.circle.fill")
            list.backgroundColor = UIColor(resource: .ripppleGray)

            return UISwipeActionsConfiguration(actions: [list, hide])
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .media(let media, _, _):
            return media.trailingSwipeActions(for: self)
        default:
            return nil
        }
    }
}

extension CalendarViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }

        guard case Wrapper.media(let media, _, _) = item else { return }

        if action == .details {
            if media.movie != nil {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: media)
            } else {
                performSegue(withIdentifier: ViewControllerSegue.details.rawValue,
                             sender: MediaModel.show(media.show!))
            }
        }
    }
}

let (calendarSettingsUpdatedTransmitter, calendarSettingsUpdatedReceiver) = Receiver<Int>.make(with: .hot)

final class CalendarSettingsViewController: UIViewController {
    @IBOutlet var myShowsSwitch: UISwitch!
    @IBOutlet var filterToWatchSwitch: UISwitch!
    @IBOutlet var addTrendingShowsSwitch: UISwitch!
    @IBOutlet var addAnticipatedShowsSwitch: UISwitch!
    @IBOutlet var myMoviesSwitch: UISwitch!
    @IBOutlet var addTrendingMoviesSwitch: UISwitch!
    @IBOutlet var addAnticipatedMoviesSwitch: UISwitch!
    @IBOutlet var hideHiddenMoviesSwitch: UISwitch!
    @IBOutlet var hideHiddenShowsSwitch: UISwitch!
    @IBOutlet var hideRecentlyWatchedMoviesSwitch: UISwitch!
    @IBOutlet var hideRecentlyWatchedShowsSwitch: UISwitch!

    private var settingsHostingController: UIHostingController<CalendarSettingsSwiftUIView>?

    @IBAction func switchChanged(_ sender: UISwitch) {
        if sender == myShowsSwitch {
            myShows = sender.isOn
            filterToWatchSwitch.isEnabled = myShows
        } else if sender == filterToWatchSwitch {
            filtersShowToWatch = sender.isOn
        } else if sender == addTrendingShowsSwitch {
            addTrendingShows = sender.isOn
        } else if sender == addAnticipatedShowsSwitch {
            addAnticipatedShows = sender.isOn
        } else if sender == myMoviesSwitch {
            myMovies = sender.isOn
        } else if sender == addTrendingMoviesSwitch {
            addTrendingMovies = sender.isOn
        } else if sender == addAnticipatedMoviesSwitch {
            addAnticipatedMovies = sender.isOn
        } else if sender == hideHiddenMoviesSwitch {
            hideHiddenMovies = sender.isOn
        } else if sender == hideHiddenShowsSwitch {
            hideHiddenShows = sender.isOn
        } else if sender == hideRecentlyWatchedMoviesSwitch {
            hideRecentlyWatchedMovies = sender.isOn
        } else if sender == hideRecentlyWatchedShowsSwitch {
            hideRecentlyWatchedShows = sender.isOn
        }

        if myShows == false, filtersShowToWatch == false, addTrendingShows == false, addAnticipatedShows == false, myMovies == false, addTrendingMovies == false, addAnticipatedMovies == false {
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem?.isEnabled = true
        }

        didUpdateSettings = true
    }

    var didUpdateSettings = false

    var myShows = true {
        didSet {
            UserDefaults.standard.set(myShows, forKey: "CalendarSettings.myShows")
            UserDefaults.standard.synchronize()
        }
    }

    var filtersShowToWatch = true {
        didSet {
            UserDefaults.standard.set(filtersShowToWatch, forKey: "CalendarSettings.filtersShowToWatch")
            UserDefaults.standard.synchronize()
        }
    }

    var addTrendingShows = true {
        didSet {
            UserDefaults.standard.set(addTrendingShows, forKey: "CalendarSettings.addTrendingShows")
            UserDefaults.standard.synchronize()
        }
    }

    var addAnticipatedShows = true {
        didSet {
            UserDefaults.standard.set(addAnticipatedShows, forKey: "CalendarSettings.addAnticipatedShows")
            UserDefaults.standard.synchronize()
        }
    }

    var myMovies = true {
        didSet {
            UserDefaults.standard.set(myMovies, forKey: "CalendarSettings.myMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var addTrendingMovies = true {
        didSet {
            UserDefaults.standard.set(addTrendingMovies, forKey: "CalendarSettings.addTrendingMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var addAnticipatedMovies = true {
        didSet {
            UserDefaults.standard.set(addAnticipatedMovies, forKey: "CalendarSettings.addAnticipatedMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var hideHiddenMovies = true {
        didSet {
            UserDefaults.standard.set(hideHiddenMovies, forKey: "CalendarSettings.hideHiddenMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var hideHiddenShows = true {
        didSet {
            UserDefaults.standard.set(hideHiddenShows, forKey: "CalendarSettings.hideHiddenShows")
            UserDefaults.standard.synchronize()
        }
    }

    var hideRecentlyWatchedMovies = false {
        didSet {
            UserDefaults.standard.set(hideRecentlyWatchedMovies, forKey: "CalendarSettings.hideRecentlyWatchedMovies")
            UserDefaults.standard.synchronize()
        }
    }

    var hideRecentlyWatchedShows = false {
        didSet {
            UserDefaults.standard.set(hideRecentlyWatchedShows, forKey: "CalendarSettings.hideRecentlyWatchedShows")
            UserDefaults.standard.synchronize()
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true)
        if didUpdateSettings {
            calendarSettingsUpdatedTransmitter.broadcast(1)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationController?.presentationController?.delegate = self
        view.backgroundColor = .systemBackground

        myShows = UserDefaults.standard.bool(forKey: "CalendarSettings.myShows")
        filtersShowToWatch = UserDefaults.standard.bool(forKey: "CalendarSettings.filtersShowToWatch")
        addTrendingShows = UserDefaults.standard.bool(forKey: "CalendarSettings.addTrendingShows")
        addAnticipatedShows = UserDefaults.standard.bool(forKey: "CalendarSettings.addAnticipatedShows")
        myMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.myMovies")
        addTrendingMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.addTrendingMovies")
        addAnticipatedMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.addAnticipatedMovies")
        hideHiddenMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.hideHiddenMovies")
        hideHiddenShows = UserDefaults.standard.bool(forKey: "CalendarSettings.hideHiddenShows")
        hideRecentlyWatchedMovies = UserDefaults.standard.bool(forKey: "CalendarSettings.hideRecentlyWatchedMovies")
        hideRecentlyWatchedShows = UserDefaults.standard.bool(forKey: "CalendarSettings.hideRecentlyWatchedShows")
        updateDoneButtonState()
        setupSwiftUISettings()
    }

    private func setupSwiftUISettings() {
        if settingsHostingController != nil { return }

        let settingsView = makeSettingsView()

        let hostingController = UIHostingController(rootView: settingsView)
        settingsHostingController = hostingController
        hostingController.view.backgroundColor = .systemBackground
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addChild(hostingController)
        view.addSubview(hostingController.view)
        view.bringSubviewToFront(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    private func makeSettingsView() -> CalendarSettingsSwiftUIView {
        CalendarSettingsSwiftUIView(
            myShows: binding(for: \.myShows),
            filtersShowToWatch: binding(for: \.filtersShowToWatch),
            addTrendingShows: binding(for: \.addTrendingShows),
            addAnticipatedShows: binding(for: \.addAnticipatedShows),
            hideHiddenShows: binding(for: \.hideHiddenShows),
            hideRecentlyWatchedShows: binding(for: \.hideRecentlyWatchedShows),
            myMovies: binding(for: \.myMovies),
            addTrendingMovies: binding(for: \.addTrendingMovies),
            addAnticipatedMovies: binding(for: \.addAnticipatedMovies),
            hideHiddenMovies: binding(for: \.hideHiddenMovies),
            hideRecentlyWatchedMovies: binding(for: \.hideRecentlyWatchedMovies)
        )
    }

    private func refreshSettingsView() {
        settingsHostingController?.rootView = makeSettingsView()
    }

    private func binding(for keyPath: ReferenceWritableKeyPath<CalendarSettingsViewController, Bool>) -> Binding<Bool> {
        Binding(get: { [weak self] in
            guard let self = self else { return false }
            return self[keyPath: keyPath]
        }, set: { [weak self] newValue in
            guard let self = self else { return }
            if self[keyPath: keyPath] != newValue {
                self[keyPath: keyPath] = newValue
                self.didUpdateSettings = true
                self.updateDoneButtonState()
                self.refreshSettingsView()
            }
        })
    }

    private func updateDoneButtonState() {
        if myShows == false, filtersShowToWatch == false, addTrendingShows == false, addAnticipatedShows == false, myMovies == false, addTrendingMovies == false, addAnticipatedMovies == false {
            navigationItem.leftBarButtonItem?.isEnabled = false
        } else {
            navigationItem.leftBarButtonItem?.isEnabled = true
        }
    }
}

private struct CalendarSettingsSwiftUIView: View {
    @Binding var myShows: Bool
    @Binding var filtersShowToWatch: Bool
    @Binding var addTrendingShows: Bool
    @Binding var addAnticipatedShows: Bool
    @Binding var hideHiddenShows: Bool
    @Binding var hideRecentlyWatchedShows: Bool

    @Binding var myMovies: Bool
    @Binding var addTrendingMovies: Bool
    @Binding var addAnticipatedMovies: Bool
    @Binding var hideHiddenMovies: Bool
    @Binding var hideRecentlyWatchedMovies: Bool

    var body: some View {
        Form {
            Section {
                CalendarSettingsToggleRow(title: "Include Your Shows",
                                          subtitle: "Adds episodes from shows you watch or keep in your watchlist, plus individually watchlisted episodes.",
                                          isOn: $myShows)
                if myShows {
                    CalendarSettingsToggleRow(title: "Only Shows in To Watch",
                                              subtitle: "Limits \"Include Your Shows\" to titles currently in Rippple's \"To Watch\" list.",
                                              isOn: $filtersShowToWatch)
                }
                CalendarSettingsToggleRow(title: "Include Trending Premieres",
                                          subtitle: "Adds trending show premieres from Trakt to your calendar.",
                                          isOn: $addTrendingShows)
                CalendarSettingsToggleRow(title: "Include Anticipated Premieres",
                                          subtitle: "Adds anticipated show premieres from Trakt to your calendar.",
                                          isOn: $addAnticipatedShows)
                CalendarSettingsToggleRow(title: "Hide \"Hidden from Calendar\"",
                                          subtitle: "When enabled, shows marked \"Hidden from Calendar\" are removed. When disabled, they remain visible but toned down.",
                                          isOn: $hideHiddenShows)
                CalendarSettingsToggleRow(title: "Hide Recently Watched",
                                          subtitle: "When enabled, recently watched episodes are removed. When disabled, they remain visible but toned down.",
                                          isOn: $hideRecentlyWatchedShows)
            }

            Section {
                CalendarSettingsToggleRow(title: "Include Your Movies",
                                          subtitle: "Adds movies you watch or keep in your watchlist.",
                                          isOn: $myMovies)
                CalendarSettingsToggleRow(title: "Include Trending",
                                          subtitle: "Adds trending movies from Trakt to your calendar.",
                                          isOn: $addTrendingMovies)
                CalendarSettingsToggleRow(title: "Include Anticipated",
                                          subtitle: "Adds anticipated movies from Trakt to your calendar.",
                                          isOn: $addAnticipatedMovies)
                CalendarSettingsToggleRow(title: "Hide \"Hidden from Calendar\"",
                                          subtitle: "When enabled, movies marked \"Hidden from Calendar\" are removed. When disabled, they remain visible but toned down.",
                                          isOn: $hideHiddenMovies)
                CalendarSettingsToggleRow(title: "Hide Watched",
                                          subtitle: "When enabled, watched movies are removed. When disabled, they remain visible but toned down.",
                                          isOn: $hideRecentlyWatchedMovies)
            }
        }.animation(.default, value: myShows)
    }
}

private struct CalendarSettingsToggleRow: View {
    let title: String
    let subtitle: String

    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }.tint(Color(uiColor: UIColor(asset: .globalTint)))
                .toggleStyle(.switch)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 75)
        }.padding(.vertical, 4)
    }
}

extension CalendarSettingsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
        if myShows == false, filtersShowToWatch == false, addTrendingShows == false, addAnticipatedShows == false, myMovies == false, addTrendingMovies == false, addAnticipatedMovies == false {
            return false
        }
        return true
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if didUpdateSettings {
            calendarSettingsUpdatedTransmitter.broadcast(1)
        }
    }
}
