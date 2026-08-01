//
//  MediaNoNextEpisodeViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 04/03/2019.
//  Copyright © Trakt. All rights reserved.
//

import UIKit

final class MediaNoNextEpisodeViewController: UITableViewController {
    var media: MediaModel!

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(UINib(nibName: "ActionTableViewCell", bundle: nil), forCellReuseIdentifier: "action")
        tableView.separatorStyle = .none
    }

    deinit {
        print("deinit MediaNoNextEpisodeViewController")
    }
}

extension MediaNoNextEpisodeViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
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
            cell.actionTitle.text = "Okay"
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let navigationController = navigationController else {
            dismiss(animated: true, completion: nil)
            return
        }
        if navigationController.viewControllers.count <= 2 {
            dismiss(animated: true, completion: nil)
            return
        }
        navigationController.popToRootViewController(animated: true)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
