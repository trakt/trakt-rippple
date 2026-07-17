//
//  ListActionViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 13/12/2019.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

let (onListChangedTransmitter, onListChangedReceiver) = Receiver<[List]>.make(with: .hot)

final class ListActionViewController: UITableViewController {
    var media: MediaModel!

    private var updatedLists = Set<List>()

    private var cancellable: Cancellable?

    private var lists = [List]()

    private let disposeBag = DisposeBag()

    private var listed: [List]? {
        didSet {
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .medium(),
                .large()
            ]
            presentationController.prefersGrabberVisible = true
        }

        tableView.register(UINib(nibName: "MediaForActionTableViewCell", bundle: nil), forCellReuseIdentifier: "media without action")
        tableView.register(UINib(nibName: "ListActionTableViewCell", bundle: nil), forCellReuseIdentifier: "list action")

        tableView.sectionHeaderTopPadding = 0.0
        tableView.separatorStyle = .none

        onCustomListsChangedReceiver.listen { [weak self] lists in
            guard let self = self else { return }
            if self.lists != lists.filter({ !$0.name.localizedStandardContains("[couchmoney.tv]") }) {
                self.lists = lists.filter { !$0.name.localizedStandardContains("[couchmoney.tv]") }
                self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
            }
        }.disposed(by: disposeBag)

        onWatchlistChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
        }.disposed(by: disposeBag)

        onMovieCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.media.movie != nil {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
            }
        }.disposed(by: disposeBag)

        onShowCollectionChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            if self.media.show != nil {
                self.tableView.reloadSections(IndexSet(integer: 1), with: .none)
            }
        }.disposed(by: disposeBag)

        onCollaborationsChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.tableView.reloadSections(IndexSet(integer: 3), with: .none)
        }.disposed(by: disposeBag)

        _Concurrency.Task {
            listed = await fetchLists()
        }
    }

    deinit {
        print("deinit ListActionViewController")
        if updatedLists.isEmpty == false {
            onListChangedTransmitter.broadcast(Array(updatedLists))
        }
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

        return await withCheckedContinuation { continuation in
            TraktAPIProvider.noChacheProvider.request(service,
                                                      callbackQueue: DispatchQueue.global(qos: .utility)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let lists = try response.map([List].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: lists)
                    } catch {
                        DispatchQueue.main.async {
                            print("Listed request JSON mapping failed! \(error)")
                            SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                        }
                        continuation.resume(returning: nil)
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("Listed request failure \(error)")
                        SwiftMessages.show(message: "😓 An error occurred", style: .error(error))
                    }
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}

extension ListActionViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    @objc private func closeActions() {
        UISelectionFeedbackGenerator().selectionChanged()
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if section == 1 {
            switch media {
            case .movie:
                return 2
            case .show:
                return 2
            case .episode:
                return 2
            default:
                return 1
            }
        }
        if section == 2 {
            return lists.count
        }
        return CollaborationsManager.shared.collaborations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "media without action") as! MediaTableViewCell

            cell.media = media
            cell.delegate = self

            cell.closeButton?.addTarget(self, action: #selector(closeActions), for: .touchUpInside)

            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "list action") as! ListActionTableViewCell

        if indexPath.section == 1 {
            if indexPath.row == 0 {
                cell.titleLabel.text = "Watchlist"
                cell.privacyImageView.image = nil

                switch media {
                case .movie:
                    cell.card.cardType = .top
                case .show:
                    cell.card.cardType = .top
                case .episode:
                    cell.card.cardType = .top
                default:
                    cell.card.cardType = .alone
                }
                if media.isWatchlisted {
                    cell.accessoryIndicator.image = UIImage(systemName: "checkmark.circle.fill")
                } else {
                    cell.accessoryIndicator.image = UIImage(systemName: "circle")
                }
            } else {
                cell.titleLabel.text = "Library"
                cell.privacyImageView.image = nil

                cell.card.cardType = .bottom
                if media.isInCollection {
                    cell.accessoryIndicator.image = UIImage(systemName: "checkmark.circle.fill")
                } else {
                    cell.accessoryIndicator.image = UIImage(systemName: "circle")
                }
            }
        } else if indexPath.section == 2 {
            let list = lists[indexPath.row]
            cell.media = media

            switch list.privacy {
            case .all:
                cell.privacyImageView.image = UIImage(systemName: "globe")
            case .me:
                cell.privacyImageView.image = UIImage(systemName: "lock.fill")
            case .friends:
                cell.privacyImageView.image = UIImage(systemName: "lock.open.fill")
            case .link:
                cell.privacyImageView.image = UIImage(systemName: "link")
            case .unknown:
                cell.privacyImageView.image = UIImage()
            }

            if indexPath.row == 0 && lists.count == 1 {
                cell.card.cardType = .alone
            } else if indexPath.row == 0 {
                cell.card.cardType = .top
            } else if indexPath.row == (lists.count - 1) {
                cell.card.cardType = .bottom
            } else {
                cell.card.cardType = .middle
            }

            if let listed = listed {
                cell.titleLabel.text = list.name.emojiUnescapedString
                if listed.contains(list) {
                    cell.accessoryIndicator.image = UIImage(systemName: "checkmark.circle.fill")
                } else {
                    cell.accessoryIndicator.image = UIImage(systemName: "circle")
                }
            } else {
                cell.titleLabel.text = "Loading..."
                cell.accessoryIndicator.image = UIImage(systemName: "circle.dotted")
            }
        } else {
            let list = CollaborationsManager.shared.collaborations[indexPath.row]
            cell.media = media
            cell.list = list

            if indexPath.row == 0 && CollaborationsManager.shared.collaborations.count == 1 {
                cell.card.cardType = .alone
            } else if indexPath.row == 0 {
                cell.card.cardType = .top
            } else if indexPath.row == (CollaborationsManager.shared.collaborations.count - 1) {
                cell.card.cardType = .bottom
            } else {
                cell.card.cardType = .middle
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            return
        }
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                if media.isWatchlisted {
                    media.removeFromWatchlist()
                } else {
                    media.addToWatchlist()
                }
            } else {
                if media.isInCollection {
                    media.removeFromCollection()
                } else {
                    media.addToCollection()
                }
            }
            return
        }

        if indexPath.section == 2 {
            let list = lists[indexPath.row]

            if listed == nil {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

            if let cell = tableView.cellForRow(at: indexPath) as? ListActionTableViewCell {
                cell.accessoryIndicator.image = UIImage(systemName: "circle.dotted")
                tableView.deselectRow(at: indexPath, animated: true)
                updatedLists.insert(list)
                if let movie = media.movie {
                    if listed?.contains(list) == true {
                        remove(item: WatchlistedItem(movie: movie), from: list)
                    } else {
                        add(item: WatchlistedItem(movie: movie), in: list)
                    }
                    return
                }
                if let episode = media.episode {
                    if listed?.contains(list) == true {
                        remove(item: WatchlistedItem(episode: episode), from: list)
                    } else {
                        add(item: WatchlistedItem(episode: episode), in: list)
                    }
                    return
                }
                if let season = media.season {
                    if listed?.contains(list) == true {
                        remove(item: WatchlistedItem(season: season), from: list)
                    } else {
                        add(item: WatchlistedItem(season: season), in: list)
                    }
                    return
                }
                if let show = media.show {
                    if listed?.contains(list) == true {
                        remove(item: WatchlistedItem(show: show), from: list)
                    } else {
                        add(item: WatchlistedItem(show: show), in: list)
                    }
                    return
                }
            }
        }

        let list = CollaborationsManager.shared.collaborations[indexPath.row]

        if let cell = tableView.cellForRow(at: indexPath) as? ListActionTableViewCell {
            if cell.isLoading == true {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            cell.accessoryIndicator.image = UIImage(systemName: "circle.dotted")
            tableView.deselectRow(at: indexPath, animated: true)
            updatedLists.insert(list)
            if let movie = media.movie {
                if cell.isInList {
                    remove(item: WatchlistedItem(movie: movie), from: list)
                } else {
                    add(item: WatchlistedItem(movie: movie), in: list)
                }
                return
            }
            if let episode = media.episode {
                if cell.isInList {
                    remove(item: WatchlistedItem(episode: episode), from: list)
                } else {
                    add(item: WatchlistedItem(episode: episode), in: list)
                }
                return
            }
            if let season = media.season {
                if cell.isInList {
                    remove(item: WatchlistedItem(season: season), from: list)
                } else {
                    add(item: WatchlistedItem(season: season), in: list)
                }
                return
            }
            if let show = media.show {
                if cell.isInList {
                    remove(item: WatchlistedItem(show: show), from: list)
                } else {
                    add(item: WatchlistedItem(show: show), in: list)
                }
                return
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 4
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 4
    }
}

extension ListActionViewController {
    private func reload(list: List) {
        // if the cell has a list, it's a collaboration and it needs to be updated manually
        for cell in tableView.visibleCells {
            if let cell = cell as? ListActionTableViewCell, cell.list == list {
                cell.list = list
                return
            }
        }
        // otherwise, it's a custom personal list and it's updated with /listed
        _Concurrency.Task {
            listed = await fetchLists()
        }
    }

    private func add(item: WatchlistedItem, in list: List) {
        if SessionManager.shared.isLoggedOut { return }

        DispatchQueue.main.async {
            if let index = self.lists.firstIndex(of: list) {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 2)) as? ListActionTableViewCell {
                    cell.titleLabel.text = "Adding to \(list.name.emojiUnescapedString)..."
                }
            }
        }

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            if let shows = item.shows {
                MediaModel.addShowsToWatchlistUndercover(medias: shows.map { $0.mediaModel })
            }
        }

        TraktAPIProvider.provider.request(.addToList(slug: list.user.slug,
                                                     id: list.identifiers.trakt!,
                                                     item: item), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if response.statusCode == 201 {
                        DispatchQueue.main.async {
                            self.reload(list: list)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("List items request JSON mapping failed! \(error)")
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                        self.reload(list: list)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("List items request failure \(error)")
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    self.reload(list: list)
                }
            }
        }
    }

    private func remove(item: WatchlistedItem, from list: List) {
        if SessionManager.shared.isLoggedOut { return }

        DispatchQueue.main.async {
            if let index = self.lists.firstIndex(of: list) {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 2)) as? ListActionTableViewCell {
                    cell.titleLabel.text = "Removing from \(list.name.emojiUnescapedString)..."
                }
            }
        }

        TraktAPIProvider.provider.request(.removeFromList(slug: list.user.slug,
                                                          id: list.identifiers.trakt!,
                                                          item: item), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    if response.statusCode == 200 {
                        DispatchQueue.main.async {
                            self.reload(list: list)
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("List items request JSON mapping failed! \(error)")
                        SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                        self.reload(list: list)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("List items request failure \(error)")
                    SwiftMessages.show(message: "😓 Removing failed", style: .error(error))
                    self.reload(list: list)
                }
            }
        }
    }
}

extension ListActionViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        if action == .close {
            dismiss(animated: true, completion: nil)
        }
    }
}
