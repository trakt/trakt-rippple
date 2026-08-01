//
//  MediaNextEpisodeErrorViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 04/03/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class MediaNextEpisodeErrorViewController: UITableViewController {
    var media: MediaModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "ActionTableViewCell", bundle: nil), forCellReuseIdentifier: "action")
        tableView.separatorStyle = .none
    }

    deinit {
        print("deinit MediaNextEpisodeErrorViewController")
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let actionViewController = segue.destination as? MediaShowNextLoadingViewController {
            actionViewController.media = media
        }
    }
}

extension MediaNextEpisodeErrorViewController {
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
            performSegue(withIdentifier: "next episode", sender: nil)
        } else if navigationController?.viewControllers.count == 2 { // if only two, we dismiss
            dismiss(animated: true, completion: nil)
        } else { // if more, we pop to root
            navigationController?.popToRootViewController(animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
