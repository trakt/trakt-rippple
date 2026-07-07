//
//  MarkWatchedActionErrorViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/04/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import UIKit

final class MarkWatchedActionErrorViewController: UITableViewController {
    private var media: MediaModel!
    private var watchedAt: Date?
    private var unwatched: [(SeasonProgress, EpisodeProgress)]?
    private var episodes: [MediaModel]?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "ActionTableViewCell", bundle: nil), forCellReuseIdentifier: "action")
        tableView.separatorStyle = .none
    }

    deinit {
        print("deinit MarkWatchedActionErrorViewController")
    }

    init?(coder: NSCoder, media: MediaModel, watchedAt: Date?, unwatched: [(SeasonProgress, EpisodeProgress)]? = nil, episodes: [MediaModel]? = nil) {
        self.media = media
        self.watchedAt = watchedAt
        self.unwatched = unwatched
        self.episodes = episodes

        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @IBSegueAction
    func makeMarkWatchedProgressActionViewController(coder: NSCoder, sender: Any?) -> MarkWatchedProgressActionViewController? {
        if let episodes = episodes {
            return MarkWatchedProgressActionViewController(coder: coder,
                                                           media: media,
                                                           watchedAt: watchedAt,
                                                           episodes: episodes)
        } else {
            return MarkWatchedProgressActionViewController(coder: coder,
                                                           media: media,
                                                           watchedAt: watchedAt,
                                                           unwatched: unwatched)
        }
    }
}

extension MarkWatchedActionErrorViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "action") as! ActionTableViewCell

        cell.layoutMargins = UIEdgeInsets(top: 0, left: 23, bottom: 0, right: 0)

        let configuration = UIImage.SymbolConfiguration(pointSize: cell.actionTitle.font.pointSize,
                                                        weight: .semibold,
                                                        scale: .large)
        cell.actionImage.preferredSymbolConfiguration = configuration
        cell.actionImage.tintColor = UIColor(asset: .globalTint)

        if indexPath.row == 0 {
            cell.actionTitle.text = "Retry"
            cell.actionImage.image = UIImage(systemName: "arrow.clockwise.circle")
        } else if indexPath.row == 1 {
            cell.actionTitle.text = "Cancel"
            cell.actionImage.image = UIImage(systemName: "xmark.circle")
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            performSegue(withIdentifier: "mark watched", sender: nil)
        } else {
            navigationController?.popToRootViewController(animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
