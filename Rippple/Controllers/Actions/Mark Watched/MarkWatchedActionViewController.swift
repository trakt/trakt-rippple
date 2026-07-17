//
//  MarkWatchedActionViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/04/2020.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import Receiver
import UIKit

final class MarkWatchedActionViewController: UITableViewController {
    private var media: MediaModel
    private var episodes: [MediaModel]?

    private var showProgress: ShowProgress?

    private let disposeBag = DisposeBag()

    private var datePicker: UIDatePicker?
    private var dateActionLabel: UILabel?
    private var date: Date?

    private let markWatchedButton = UIButton(frame: CGRect(x: 0.0,
                                                           y: 0.0,
                                                           width: 150.0,
                                                           height: 44.0))

    private var cancellable: Cancellable? {
        willSet {
            cancelCancellable()
        }
    }

    deinit {
        print("deinit MarkWatchedActionViewController")
        cancelCancellable()
    }

    private func cancelCancellable() {
        if let cancellable = cancellable {
            cancellable.cancel()
        }
    }

    init?(coder: NSCoder, media: MediaModel) {
        self.media = media

        super.init(coder: coder)
    }

    init?(coder: NSCoder, media: MediaModel, episodes: [MediaModel]) {
        self.media = media
        self.episodes = episodes

        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        markWatchedButton.configuration = .prominentGlass()

        if let presentationController = presentationController as? UISheetPresentationController {
            presentationController.detents = [
                .medium(),
                .large()
            ]
            presentationController.prefersGrabberVisible = true
        }

        tableView.register(UINib(nibName: "MediaForActionTableViewCell", bundle: nil), forCellReuseIdentifier: "media without action")
        tableView.register(UINib(nibName: "ActionTableViewCell", bundle: nil), forCellReuseIdentifier: "action")
        tableView.register(UINib(nibName: "ActionDateTableViewCell", bundle: nil), forCellReuseIdentifier: "action date")
        tableView.register(UINib(nibName: "MultipleWatchTableViewCell", bundle: nil), forCellReuseIdentifier: "multiple watch")

        tableView.sectionHeaderTopPadding = 0.0
        tableView.separatorStyle = .none

        update(with: media)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        markWatchedButton.tintColor = UIColor(asset: .safeGlobalTint)
        markWatchedButton.addTarget(self, action: #selector(markWatched), for: .touchUpInside)

        if markWatchedButton.superview == nil {
            tableView.superview?.addSubview(markWatchedButton)

            markWatchedButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                markWatchedButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                markWatchedButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
                markWatchedButton.widthAnchor.constraint(equalToConstant: 250),
                markWatchedButton.heightAnchor.constraint(equalToConstant: 44)
            ])

            let interaction = UIScrollEdgeElementContainerInteraction()
            interaction.scrollView = tableView
            interaction.edge = .bottom
            markWatchedButton.addInteraction(interaction)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        markWatchedButton.removeFromSuperview()
    }

    @objc func markWatched() {
        UISelectionFeedbackGenerator().selectionChanged()
        if let episodes = episodes {
            performSegue(withIdentifier: "mark watched", sender: episodes)
        } else {
            if let showProgress = showProgress, let episode = media.episodeEpisode {
                var allUnwatched = [(SeasonProgress, EpisodeProgress)]()
                var unwatchedInSeason = [(SeasonProgress, EpisodeProgress)]()
                var unwatchedSinceLastWatched = [(SeasonProgress, EpisodeProgress)]()
                var stop = false
                for seasonProgress in showProgress.seasons {
                    unwatchedInSeason.removeAll()
                    for episodeProgress in seasonProgress.episodes {
                        if episode.season == seasonProgress.number, episode.number == episodeProgress.number {
                            stop = true
                            break
                        }
                        if episodeProgress.completed {
                            unwatchedInSeason.removeAll()
                            unwatchedSinceLastWatched.removeAll()
                        } else {
                            unwatchedSinceLastWatched.append((seasonProgress, episodeProgress))
                            unwatchedInSeason.append((seasonProgress, episodeProgress))
                            allUnwatched.append((seasonProgress, episodeProgress))
                        }
                    }
                    if stop { break }
                }

                var preferredStyle = UIAlertController.Style.alert
                if traitCollection.userInterfaceIdiom == .phone {
                    preferredStyle = .actionSheet
                }
                let alertController = UIAlertController(title: "Previous Unwatched Episode(s)",
                                                        message: "Also mark previous episode(s) as watched?",
                                                        preferredStyle: preferredStyle)

                let dontMark = UIAlertAction(title: "Don't Mark Previous", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "mark watched", sender: nil)
                }
                alertController.addAction(dontMark)

                let inSeason = UIAlertAction(title: "Mark \(unwatchedInSeason.count) Previous in Season", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "mark watched", sender: unwatchedInSeason)
                }
                if unwatchedInSeason.count >= 1 {
                    alertController.addAction(inSeason)
                }

                let last = UIAlertAction(title: "Mark \(unwatchedSinceLastWatched.count) Previous", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "mark watched", sender: unwatchedSinceLastWatched)
                }
                if unwatchedSinceLastWatched.count >= 1, unwatchedSinceLastWatched.count != unwatchedInSeason.count {
                    alertController.addAction(last)
                }

                let all = UIAlertAction(title: "Mark All \(allUnwatched.count) Unwatched", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    self.performSegue(withIdentifier: "mark watched", sender: allUnwatched)
                }
                if allUnwatched.count >= 1, unwatchedSinceLastWatched.count != allUnwatched.count {
                    alertController.addAction(all)
                }

                let cancel = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancel)

                alertController.popoverPresentationController?.sourceView = markWatchedButton

                if allUnwatched.count == 0 {
                    performSegue(withIdentifier: "mark watched", sender: nil)
                } else {
                    present(alertController, animated: true)
                }
            } else {
                performSegue(withIdentifier: "mark watched", sender: nil)
            }
        }
    }

    @IBSegueAction
    func makeMarkWatchedProgressActionViewController(coder: NSCoder, sender: Any?) -> MarkWatchedProgressActionViewController? {
        if let unwatched = sender as? [(SeasonProgress, EpisodeProgress)] {
            return MarkWatchedProgressActionViewController(coder: coder,
                                                           media: media,
                                                           watchedAt: date,
                                                           unwatched: unwatched)
        } else if let episodes = episodes {
            return MarkWatchedProgressActionViewController(coder: coder,
                                                           media: media,
                                                           watchedAt: date,
                                                           episodes: episodes)
        } else {
            return MarkWatchedProgressActionViewController(coder: coder,
                                                           media: media,
                                                           watchedAt: date)
        }
    }
}

extension MarkWatchedActionViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    @objc private func closeActions() {
        dismiss(animated: true, completion: nil)
        UISelectionFeedbackGenerator().selectionChanged()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        if section == 2 {
            if episodes != nil {
                return 0
            }
            return 1
        }

        return 4
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "media without action") as! MediaTableViewCell

            cell.media = media
            cell.delegate = self

            cell.closeButton?.addTarget(self, action: #selector(closeActions), for: .touchUpInside)

            return cell
        }

        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "action") as! ActionTableViewCell

            cell.layoutMargins = UIEdgeInsets(top: 0, left: 23, bottom: 0, right: 0)

            let configuration = UIImage.SymbolConfiguration(pointSize: cell.actionTitle.font.pointSize,
                                                            weight: .semibold,
                                                            scale: .large)
            cell.actionImage.preferredSymbolConfiguration = configuration

            if indexPath.row == 0 {
                cell.actionTitle.text = "Now"
                cell.actionImage.image = UIImage(systemName: "arrow.right.circle")
            } else if indexPath.row == 1 {
                switch media {
                case .episode:
                    cell.actionTitle.text = "When First Aired"
                case .movie:
                    cell.actionTitle.text = "When Released"
                case .show:
                    if episodes != nil {
                        cell.actionTitle.text = "When Each Episode Aired"
                    } else {
                        cell.actionTitle.text = "When Show First Aired"
                    }
                case .season:
                    cell.actionTitle.text = "When Show First Aired"
                default:
                    break
                }
                cell.actionImage.image = UIImage(systemName: "arrow.counterclockwise.circle")
            } else if indexPath.row == 2 {
                cell.actionTitle.text = "Unknown Date"
                cell.actionImage.image = UIImage(systemName: "eye.circle")
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "action date") as! ActionDateTableViewCell

                cell.layoutMargins = UIEdgeInsets(top: 0, left: 23, bottom: 0, right: 0)

                let configuration = UIImage.SymbolConfiguration(pointSize: cell.actionTitle.font.pointSize,
                                                                weight: .semibold,
                                                                scale: .large)
                cell.actionImage.preferredSymbolConfiguration = configuration

                cell.actionTitle.text = "Date & Time"
                cell.actionImage.image = UIImage(systemName: "calendar.circle")

                cell.datePicker.date = Date()
                cell.datePicker.maximumDate = Date()
                datePicker = cell.datePicker
                dateActionLabel = cell.actionTitle
                datePicker?.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
                date = datePicker?.date

                return cell
            }

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "multiple watch") as! MultipleWatchTableViewCell
            cell.media = media
            return cell
        }
    }

    @objc func dateChanged(_ sender: UIDatePicker) {
        date = sender.date
        dateActionLabel?.text = "Date & Time"
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 2 { return }
        if indexPath.section == 0 { return }

        if indexPath.row == 0 {
            // Now
            datePicker?.date = Date()
            dateActionLabel?.text = "Date & Time"
            date = datePicker?.date
        } else if indexPath.row == 1 {
            // Release date
            switch media {
            case .episode(let episode, _):
                datePicker?.date = episode.firstAired ?? Date()
            case .movie(let movie):
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                datePicker?.date = dateFormatter.date(from: movie.released ?? "") ?? Date()
            case .show(let show):
                if let episodes = episodes {
                    datePicker?.date = episodes.first!.episode!.firstAired ?? Date()
                } else {
                    datePicker?.date = show.firstAired ?? Date()
                }
            case .season(_, let show):
                datePicker?.date = show.firstAired ?? Date()
            default:
                break
            }
            dateActionLabel?.text = "First"
            date = nil
        } else if indexPath.row == 2 {
            // Unknown
            datePicker?.date = Date(timeIntervalSince1970: 0)
            dateActionLabel?.text = "Unknonwn"
            date = datePicker?.date
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension MarkWatchedActionViewController: MediaTableViewCellDelegate {
    func cell(_ cell: MediaTableViewCell, action: MediaTableViewCell.Action) {
        if action == .close {
            dismiss(animated: true, completion: nil)
        }
    }
}

extension MarkWatchedActionViewController {
    private func update(with media: MediaModel?) {
        switch media! {
        case .movie:
            markWatchedButton.setTitle("Mark Movie Watched", for: .normal)
        case .episode(let episode, let show):
            markWatchedButton.setTitle("Loading...", for: .normal)
            markWatchedButton.isEnabled = false
            cancellable = fetchShowProgress(for: show, given: episode)
        case .season(let season, let show):
            markWatchedButton.setTitle("Loading...", for: .normal)
            markWatchedButton.isEnabled = false
            cancellable = fetchSeasonProgress(for: show, season: season)
        case .show(let show):
            if let episodes = episodes {
                markWatchedButton.setTitle("Mark \(episodes.count) \(episodes.count > 1 ? "Episodes" : "Episode") Watched", for: .normal)
            } else {
                markWatchedButton.setTitle("Loading...", for: .normal)
                markWatchedButton.isEnabled = false
                cancellable = fetchShowProgress(for: show)
            }
        case .list:
            fatalError()
        case .showProgress:
            fatalError()
        }
    }

    private func fetchShowProgress(for show: Show, given episode: Episode) -> Cancellable {
        return TraktAPIProvider.provider.request(.showProgress(id: show.identifiers.trakt!, includesSpecials: episode.season == 0), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    self.showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        var unwatchedInShow = false
                        var stop = false
                        for seasonProgress in self.showProgress!.seasons {
                            for episodeProgress in seasonProgress.episodes {
                                if episode.season == seasonProgress.number && episode.number == episodeProgress.number {
                                    stop = true
                                    break
                                }
                                if episodeProgress.completed {
                                    unwatchedInShow = false
                                } else {
                                    unwatchedInShow = true
                                }
                            }
                            if stop { break }
                        }
                        if unwatchedInShow == false {
                            self.markWatchedButton.setTitle("Mark Episode Watched", for: .normal)
                        } else {
                            self.markWatchedButton.setTitle("Mark Episode Watched...", for: .normal)
                        }
                        self.markWatchedButton.isEnabled = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/progress) request JSON mapping failed! \(error)")
                        self.markWatchedButton.setTitle("Mark Episode Watched", for: .normal)
                        self.markWatchedButton.isEnabled = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/progress) request failure \(error)")
                    self.markWatchedButton.setTitle("Mark Episode Watched", for: .normal)
                    self.markWatchedButton.isEnabled = true
                }
            }
        }
    }

    private func fetchShowProgress(for show: Show) -> Cancellable {
        return TraktAPIProvider.provider.request(.showProgress(id: show.identifiers.trakt!, includesSpecials: false), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        let remaining = showProgress.aired
                        self.markWatchedButton.setTitle("Mark \(remaining) \(remaining > 1 ? "Episodes" : "Episode") Watched", for: .normal)
                        self.markWatchedButton.isEnabled = true
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/progress) request JSON mapping failed! \(error)")
                        self.markWatchedButton.setTitle("Mark Show Watched", for: .normal)
                        self.markWatchedButton.isEnabled = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/progress) request failure \(error)")
                    self.markWatchedButton.setTitle("Mark Show Watched", for: .normal)
                    self.markWatchedButton.isEnabled = true
                }
            }
        }
    }

    private func fetchSeasonProgress(for show: Show, season: Season) -> Cancellable {
        return TraktAPIProvider.provider.request(.showProgress(id: show.identifiers.trakt!, includesSpecials: season.number == 0), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let showProgress = try response.map(ShowProgress.self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        for seasonProgress in showProgress.seasons where seasonProgress.number == season.number {
                            let remaining = seasonProgress.aired
                            self.markWatchedButton.setTitle("Mark \(remaining) \(remaining > 1 ? "Episodes" : "Episode") Watched", for: .normal)
                            self.markWatchedButton.isEnabled = true
                            break
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("MultipleWatchTableViewCell (/progress) request JSON mapping failed! \(error)")
                        self.markWatchedButton.setTitle("Mark Season Watched", for: .normal)
                        self.markWatchedButton.isEnabled = true
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("MultipleWatchTableViewCell (/progress) request failure \(error)")
                    self.markWatchedButton.setTitle("Mark Season Watched", for: .normal)
                    self.markWatchedButton.isEnabled = true
                }
            }
        }
    }
}
