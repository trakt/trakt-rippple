//
//  PulseViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/05/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import UIKit

final class PulseViewController: UITableViewController {

    public var media: MediaModel!

    private let relativeDateTimeFormatter: RelativeDateTimeFormatter = {
        let dateFormatter = RelativeDateTimeFormatter()
        dateFormatter.unitsStyle = .full
        dateFormatter.dateTimeStyle = .numeric
        dateFormatter.formattingContext = .listItem
        return dateFormatter
    }()

    private struct ActivityItem: Hashable {
        let activity: String
        let title: String
        let notes: String
        let meta: String
        let date: Date
        let systemImageName: String
        let historyItem: HistoryItem?
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.title = "Pulse"
        navigationItem.subtitle = media.mediaTitle

        tableView.register(UINib(nibName: "PulseTableViewCell", bundle: nil), forCellReuseIdentifier: "activity")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.separatorStyle = .none

        tableView.allowsFocus = false

        refresh()

        configureOptionButton()
    }

    private func configureOptionButton() {
        let removeAllWatch = UIAction(title: "Remove All Watch",
                                      image: UIImage(systemName: "minus.circle"),
                                      attributes: .destructive,
                                      handler: { _ in
                let confirmationAlertController = UIAlertController(title: "⚠️",
                                                        message: "Are you sure you want to remove all watch?",
                                                        preferredStyle: .alert)

                let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                confirmationAlertController.addAction(cancel)

                let delete = UIAlertAction(title: "Yes, Remove All Watch", style: .destructive) { _ in
                    switch self.media! {
                    case .movie(let movie):
                        TraktAPIProvider.provider.request(.removeMovieFromHistory(id: movie.identifiers.trakt!),
                                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                                    DispatchQueue.main.async {
                                        SwiftMessages.show(message: "🗑 Watch removed")
                                        onRemoveWatchMediaTransmitter.broadcast(self.media)
                                        onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                        self.refresh()
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
                    case .show(let show):
                        TraktAPIProvider.provider.request(.removeShowFromHistory(id: show.identifiers.trakt!),
                                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                                    DispatchQueue.main.async {
                                        SwiftMessages.show(message: "🗑 Watch removed")
                                        onRemoveWatchMediaTransmitter.broadcast(self.media)
                                        onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                        self.refresh()
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
                    case .episode(let episode, _):
                        TraktAPIProvider.provider.request(.removeEpisodeFromHistory(id: episode.identifiers.trakt!),
                                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                                    DispatchQueue.main.async {
                                        SwiftMessages.show(message: "🗑 Watch removed")
                                        onRemoveWatchMediaTransmitter.broadcast(self.media)
                                        onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                        self.refresh()
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
                    case .season(let season, _):
                        TraktAPIProvider.provider.request(.removeSeasonFromHistory(id: season.identifiers.trakt!),
                                                          callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                            guard let self = self else { return }
                            switch result {
                            case let .success(moyaResponse):
                                do {
                                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                                    DispatchQueue.main.async {
                                        SwiftMessages.show(message: "🗑 Watch removed")
                                        onRemoveWatchMediaTransmitter.broadcast(self.media)
                                        onRemoveMultipleMediaTransmitter.broadcast(self.media)
                                        self.refresh()
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
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                }
                confirmationAlertController.addAction(delete)

                self.present(confirmationAlertController, animated: true)
        })

        let menu = UIMenu(children: [removeAllWatch])

        navigationItem.rightBarButtonItems = [UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: menu)]
    }

    private func refresh() {
        var loading = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        loading.appendSections([.loading])
        loading.appendItems([.loading])
        dataSource.apply(loading, animatingDifferences: false)

        Task {
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            snapshot.appendSections([.content])

            var activityItems = [ActivityItem]()

            if let episode = media.episode, let show = media.show {
                if let firstAired = episode.firstAired {

                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter.init()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let country = show.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = show.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }
            }

            if let season = media.season, let show = media.show {
                if let firstAired = season.firstAired {

                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter.init()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let country = show.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = show.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }
            }

            if let show = media.showShow {
                let fullShow = await fetchDetails(for: show)

                if let firstAired = fullShow.firstAired {

                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter.init()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    var meta = [String]()
                    if let network = fullShow.network {
                        meta.append(network)
                    }
                    if let country = fullShow.country {
                        meta.append("\(Locale.current.localizedString(forRegionCode: country) ?? country)")
                    }
                    if let certification = fullShow.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "First Aired",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: meta.joined(separator: " · "),
                                            date: firstAired.addingTimeInterval(-5), // make sure this is displayed before anythin else,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }

                if let lastEpisode = await fetchLastEpisode(for: show),
                   let firstAired = lastEpisode.firstAired {

                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter.init()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    let item = ActivityItem(activity: "Last Aired Episode",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: "\(lastEpisode.localizedEpisodeNumber)",
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }

                if let nextEpisode = await fetchNextEpisode(for: show),
                   let firstAired = nextEpisode.firstAired {

                    let dateFormatter: DateFormatter = {
                        let dateFormatter = DateFormatter.init()
                        dateFormatter.dateStyle = .medium
                        dateFormatter.timeStyle = .short
                        return dateFormatter
                    }()

                    let item = ActivityItem(activity: "Next Airing Episode",
                                            title: "\(dateFormatter.string(from: firstAired))",
                                            notes: "",
                                            meta: "\(nextEpisode.localizedEpisodeNumber)",
                                            date: firstAired,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }
            }

            if let movie = media.movie, let movieActivities = await fetchMovieReleases(for: movie) {

                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    return dateFormatter
                }()

                let localCountry = Locale.current.language.region?.identifier ?? "us"
                for activity in movieActivities.filter({ $0.country.lowercased() == movie.country?.lowercased() || $0.country.lowercased() == localCountry.lowercased() }) {
                    var meta = [String]()
                    meta.append("\(Locale.current.localizedString(forRegionCode: activity.country) ?? activity.country)")
                    if let certification = activity.certification {
                        meta.append(certification)
                    }

                    let item = ActivityItem(activity: "\(activity.releaseType.localizedCapitalized) Release",
                                            title: "\(dateFormatter.string(from: activity.releaseDate))",
                                            notes: activity.note ?? "",
                                            meta: meta.joined(separator: " · "),
                                            date: activity.releaseDate,
                                            systemImageName: "calendar",
                                            historyItem: nil)
                    activityItems.append(item)
                }
            }

            if let lists = await fetchLists() {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for list in lists {
                    if let item = await fetchItem(in: list) {
                        let item = ActivityItem(activity: "Listed",
                                                title: "\(dateFormatter.string(from: item .listedAt))",
                                                notes: item.notes ?? "",
                                                meta: "Added to \(list.name)",
                                                date: item.listedAt,
                                                systemImageName: "plus",
                                                historyItem: nil)
                        activityItems.append(item)
                    }
                }
            }

            if let watchlistMediaItem = media.watchlistMediaItem, let watchlistedAt = watchlistMediaItem.listedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Watchlisted",
                                        title: "\(dateFormatter.string(from: watchlistedAt))",
                                        notes: watchlistMediaItem.notes ?? "",
                                        meta: "",
                                        date: watchlistedAt,
                                        systemImageName: "bookmark.fill",
                                        historyItem: nil)
                activityItems.append(item)
            }

            if let recommendedMediaItem = media.recommendedMediaItem, let recommendedAt = recommendedMediaItem.listedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Favorited",
                                        title: "\(dateFormatter.string(from: recommendedAt))",
                                        notes: recommendedMediaItem.notes ?? "",
                                        meta: "",
                                        date: recommendedAt,
                                        systemImageName: "star.fill",
                                        historyItem: nil)
                activityItems.append(item)
            }

            if let collectedMediaItem = media.collectedMediaItem, let collectedAt = collectedMediaItem.collectedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Collected",
                                        title: "\(dateFormatter.string(from: collectedAt))",
                                        notes: collectedMediaItem.notes ?? "",
                                        meta: "",
                                        date: collectedAt,
                                        systemImageName: "book.circle",
                                        historyItem: nil)
                activityItems.append(item)
            }

            if let collectedMediaItem = media.collectedMediaItem, let collectedAt = collectedMediaItem.lastCollectedAt {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Collected",
                                        title: "\(dateFormatter.string(from: collectedAt))",
                                        notes: collectedMediaItem.notes ?? "",
                                        meta: "",
                                        date: collectedAt,
                                        systemImageName: "book.circle",
                                        historyItem: nil)
                activityItems.append(item)
            }

            if let ratedMediaItems = media.ratedItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for ratedMediaItem in ratedMediaItems {
                    let media = MediaModel(item: ratedMediaItem)

                    switch media {
                    case .movie:
                        let item = ActivityItem(activity: "Rated Movie: \(ratedMediaItem.rating)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                historyItem: nil)
                        activityItems.append(item)
                    case .show:
                        let item = ActivityItem(activity: "Rated Show: \(ratedMediaItem.rating)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                historyItem: nil)
                        activityItems.append(item)
                    case .season(let season, _):
                        let item = ActivityItem(activity: "Rated \(season.localizedSeasonNumber): \(ratedMediaItem.rating)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                historyItem: nil)
                        activityItems.append(item)
                    case .episode(let episode, _):
                        let item = ActivityItem(activity: "Rated \(episode.localizedEpisodeNumber): \(ratedMediaItem.rating)",
                                                title: "\(dateFormatter.string(from: ratedMediaItem.rateDate))",
                                                notes: ratedMediaItem.note ?? "",
                                                meta: "",
                                                date: ratedMediaItem.rateDate,
                                                systemImageName: "heart.fill",
                                                historyItem: nil)
                        activityItems.append(item)
                    case .list:
                        fatalError()
                    case .showProgress:
                        fatalError()
                    }
                }
            }

            if let noteItems = media.noteItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                for noteItem in noteItems {
                    var meta = [String]()
                    switch noteItem.noteAttachement.type {
                    case .movie:
                        meta.append("Movie Notes")
                    case .show:
                        meta.append("Show Notes")
                    case .season:
                        meta.append("Season Notes")
                    case .episode:
                        meta.append("Episode Notes")
                    default:
                        fatalError("This case shouldn't be handled here")
                    }
                    switch noteItem.note.privacy {
                    case .all:
                        meta.append("Public")
                    case .friends:
                        meta.append("Friends")
                    case .me:
                        meta.append("Private")
                    case .unknown:
                        break
                    }
                    if noteItem.note.spoiler {
                        meta.append("Spoiler Alert!")
                    }

                    let item = ActivityItem(activity: "Note Added",
                                            title: "\(dateFormatter.string(from: noteItem.note.createdAt))",
                                            notes: noteItem.note.notes,
                                            meta: meta.joined(separator: " · "),
                                            date: noteItem.note.createdAt,
                                            systemImageName: "note.text",
                                            historyItem: nil)

                    activityItems.append(item)
                }
            }

            for commentItem in media.ownCommentItems {
                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                let item = ActivityItem(activity: "Commented",
                                        title: "\(dateFormatter.string(from: commentItem.comment.createDate))",
                                        notes: commentItem.comment.body,
                                        meta: "\(CommentModel(commentItem: commentItem, spoilerStrategy: .showAllSpoilers).media.mediaTitle)",
                                        date: commentItem.comment.createDate,
                                        systemImageName: "pencil.circle.fill",
                                        historyItem: nil)

                activityItems.append(item)
            }

            if let activities = await fetchHistory()?.sorted(by: { $0.watchDate < $1.watchDate }) {

                let dateFormatter: DateFormatter = {
                    let dateFormatter = DateFormatter.init()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .short
                    return dateFormatter
                }()

                var ordinalCount = 1
                let formatter = NumberFormatter()
                formatter.numberStyle = .ordinal
                for activity in activities {
                    var header = "Watched"
                    var systemImage = "checkmark"
                    if activity.action == .scrobble {
                        header = "Scrobbled"
                        systemImage = "play.fill"
                    } else if activity.action == .checkin {
                        header = "Checked in"
                        systemImage = "play.fill"
                    }

                    // if it's an episode from a season or a show VS the episode level or movie
                    if let episode = activity.episode, media.episode == nil {
                        let meta = if let title = episode.title { "\(episode.localizedEpisodeNumber) - \(title)" } else { episode.localizedEpisodeNumber }
                        let item = ActivityItem(activity: header,
                                                title: "\(dateFormatter.string(from: activity.watchDate))",
                                                notes: activity.note ?? "",
                                                meta: meta,
                                                date: activity.watchDate,
                                                systemImageName: systemImage,
                                                historyItem: activity)
                        activityItems.append(item)
                    } else {
                        let meta = "\(formatter.string(from: ordinalCount as NSNumber) ?? "1st") watch"
                        let item = ActivityItem(activity: header,
                                                title: "\(dateFormatter.string(from: activity.watchDate))",
                                                notes: activity.note ?? "",
                                                meta: meta,
                                                date: activity.watchDate,
                                                systemImageName: systemImage,
                                                historyItem: activity)
                        activityItems.append(item)
                    }
                    ordinalCount += 1
                }
            }

            let dateFormatter: DateFormatter = {
                let dateFormatter = DateFormatter.init()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                return dateFormatter
            }()
            let today = ActivityItem(activity: "Today",
                                     title: dateFormatter.string(from: .now),
                                     notes: "",
                                     meta: "",
                                     date: .now,
                                     systemImageName: "calendar.badge.clock",
                                     historyItem: nil)
            activityItems.append(today)

            activityItems.sort { $0.date > $1.date }
            snapshot.appendItems(activityItems.map { .activity($0) })

            if snapshot.itemIdentifiers(inSection: .content).count == 0 {
                snapshot.appendItems([.empty("😵",
                                             "No Pulse",
                                             "There are currently no activities to show",
                                             "Come back later to see something new... or don't.")])
            }

            DispatchQueue.main.async {
                self.dataSource.apply(snapshot, animatingDifferences: false)
            }
        }
    }

    private enum Section: Int {
        case content
        case empty
        case loading
    }

    private enum Wrapper: Hashable {
        case activity(ActivityItem)
        case empty(String, String, String, String)
        case loading
    }

    private class MediaActivitesDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let wrapper = itemIdentifier(for: indexPath) else { return false }
            switch wrapper {
            case .activity:
                return true
            default:
                return false
            }
        }
    }

    private lazy var dataSource = MediaActivitesDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .activity(let activityItem):
            let cell = tableView.dequeueReusableCell(withIdentifier: "activity") as! PulseTableViewCell
            if activityItem.activity == "Today" {
                cell.activityType.text = "Today"
            } else {
                if activityItem.date.timeIntervalSince1970 == 0 {
                    cell.activityType.text = "\(activityItem.activity)"
                } else {
                    cell.activityType.text = "\(activityItem.activity), \(relativeDateTimeFormatter.localizedString(for: activityItem.date, relativeTo: .now))"
                }
            }
            cell.metaInfo.text = activityItem.meta
            cell.metaInfo.isHiddenInStackView = activityItem.meta.isEmpty
            if activityItem.date.timeIntervalSince1970 == 0 {
                cell.referenceDate.text = "At Unknown Date"
            } else {
                cell.referenceDate.text = activityItem.title
            }
            cell.notes.activityText = activityItem.notes
            cell.notes.isHiddenInStackView = activityItem.notes.isEmpty

            if activityItem.systemImageName.hasPrefix("calendar") {
                cell.picto.image = UIImage(systemName: activityItem.systemImageName)
                cell.picto.tintColor = .secondaryLabel
                cell.picto.isHidden = false
                cell.picto.isHiddenInStackView = false

                cell.ownEventIndicator.superview?.isHidden = true
                cell.ownEventIndicator.superview?.isHiddenInStackView = true
            } else {
                cell.picto.isHidden = true
                cell.picto.isHiddenInStackView = true

                cell.ownEventIndicator.superview?.isHidden = false
                cell.ownEventIndicator.superview?.isHiddenInStackView = false
            }

            cell.cardType = .alone

            if media.show != nil && media.episode == nil,
               let historyItem = activityItem.historyItem {
                cell.backdrop.media = MediaModel(item: historyItem)
                cell.backdrop.isHidden = false
                cell.backdrop.isHiddenInStackView = false
            } else {
                cell.backdrop.isHidden = true
                cell.backdrop.isHiddenInStackView = true
            }

            return cell
        case .loading:
            let cell = tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case .activity(let activity) = item else { return }

        if let historyItem = activity.historyItem {
            let alertController = UIAlertController(title: nil,
                                                    message: nil,
                                                    preferredStyle: .actionSheet)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)

            let media = MediaModel(item: historyItem)!
            let goToMedia = UIAlertAction(title: "Open \(media.mediaTitle)", style: .default) { _ in
                UIApplication.shared.open(media.deeplink!)
            }
            alertController.addAction(goToMedia)

            let delete = UIAlertAction(title: "Remove", style: .destructive) { _ in
                let alertController = UIAlertController(title: "Do you want to remove this from your watch history?",
                                                        message: nil,
                                                        preferredStyle: .actionSheet)

                let cancel = UIAlertAction(title: "Don't remove", style: .cancel)
                alertController.addAction(cancel)

                let delete = UIAlertAction(title: "Remove", style: .destructive) { _ in
                    guard let window = self.view.window else { return }
                    window.isUserInteractionEnabled = false
                    SwiftMessages.show(message: "Removing from History...", style: .loading)
                    TraktAPIProvider.provider.request(.removeFromHistory(id: historyItem.identifier),
                                                      callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                        defer {
                            DispatchQueue.main.async {
                                window.isUserInteractionEnabled = true
                            }
                        }
                        guard let self = self else { return }
                        switch result {
                        case let .success(moyaResponse):
                            do {
                                let response = try moyaResponse.filterSuccessfulStatusCodes()

                                DispatchQueue.main.async {
                                    if response.statusCode == 200 {
                                        SwiftMessages.show(message: "🗑 Activity removed")
                                        self.refresh()
                                        onRemoveWatchTransmitter.broadcast(historyItem.identifier)
                                        onRemoveWatchMediaTransmitter.broadcast(self.media)
                                    }
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    print("removeFromHistory request JSON mapping failed! \(error)")
                                    SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                                }
                            }
                        case let .failure(error):
                            DispatchQueue.main.async {
                                print("removeFromHistory request failure \(error)")
                                SwiftMessages.show(message: "😓 Error removing", style: .error(error))
                            }
                        }
                    }
                }
                alertController.addAction(delete)

                alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

                self.present(alertController, animated: true)
            }
            alertController.addAction(delete)

            alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

            present(alertController, animated: true)
        }
    }

    private func fetchMovieReleases(for movie: Movie) async -> [MovieReleaseActivity]? {
        let result: [MovieReleaseActivity]? = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.movieReleases(id: movie.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()

                        let movieActivities = try response.map([MovieReleaseActivity].self, using: TraktAPIProvider.decoder)

                        continuation.resume(returning: movieActivities)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    private var fetchHistoryService: TraktAPIService? {
        switch media! {
        case .movie(let movie):
            return .history(type: .movies, id: movie.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 100), endDate: nil)
        case .show(let show):
            return .history(type: .shows, id: show.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 100), endDate: nil)
        case .episode(let episode, _):
            return .history(type: .episodes, id: episode.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 100), endDate: nil)
        case .season(let season, _):
            return .history(type: .seasons, id: season.identifiers.trakt!, pageInfo: PageInfo.firstPage(with: 100), endDate: nil)
        case .list:
            return nil
        case .showProgress:
            return nil
        }
    }

    private func fetchHistory() async -> [HistoryItem]? {
        guard let fetchHistoryService = fetchHistoryService else { return nil }
        let result: [HistoryItem]? = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(fetchHistoryService,
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let history = try response.map([HistoryItem].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: history)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    private func fetchDetails(for show: Show) async -> Show {
        let result: Show = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.show(id: show.identifiers.traktIdOrSlug, extended: .full),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let fullShow = try response.map(Show.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: fullShow)
                    } catch {
                        continuation.resume(returning: show)
                    }
                case .failure:
                    continuation.resume(returning: show)
                }
            }
        }
        return result
    }

    private func fetchLastEpisode(for show: Show) async -> Episode? {
        let result: Episode? = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.lastEpisode(id: show.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: episode)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    private func fetchNextEpisode(for show: Show) async -> Episode? {
        let result: Episode? = await withCheckedContinuation { continuation in
            TraktAPIProvider.provider.request(.nextEpisode(id: show.identifiers.trakt!),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let episode = try response.map(Episode.self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: episode)
                    } catch {
                        continuation.resume(returning: nil)
                    }
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    private func fetchLists() async -> [List]? {
        let service: TraktAPIService = {
            switch self.media! {
            case .movie(let movie):
                return .movieListed(id: movie.identifiers.trakt!)
            case .show(let show):
                return .showListed(id: show.identifiers.trakt!)
            case .episode(let episode, let show):
                return .episodeListed(id: show.identifiers.trakt!,
                                      season: episode.season,
                                      episode: episode.number)
            case .season(let season, let show):
                return .seasonListed(id: show.identifiers.trakt!,
                                     season: season.number)
            case .list:
                fatalError("List not handled for fetching listed")
            case .showProgress:
                fatalError("showProgress not handled for fetching listed")
            }
        }()

        let result: [List]? = await withCheckedContinuation { continuation in
            TraktAPIProvider.noChacheProvider.request(service,
                                                    callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case let .success(moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: lists)
                    } catch {
                        print("Listed request JSON mapping failed! \(error)")
                        continuation.resume(returning: nil)
                    }
                case let .failure(error):
                    print("Listed request failure \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
        return result
    }

    private func fetchItem(in list: List) async -> WatchlistItem? {
        guard let media = media else { return nil }
        let listItemsType: ListMediaType? = {
            switch media {
            case .movie:
                return .movies
            case .show:
                return .shows
            case .episode:
                return .episodes
            case .season:
                return .seasons
            case .list:
                return nil
            case .showProgress:
                fatalError()
            }
        }()

        do {
            let items = try await TraktAPIProvider.fetchAllListItems(slug: list.user.identifiers.slug,
                                                                     id: list.identifiers.trakt!,
                                                                     type: listItemsType,
                                                                     extended: nil)
            return items.first { MediaModel(item: $0).traktId == media.traktId }
        } catch {
            print("Items request failure \(error)")
            return nil
        }
    }
}
