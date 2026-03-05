//
//  SpoilersViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 10/03/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import UIKit

import Receiver

let (episodeDetailTitlesTransmitter, episodeDetailTitlesReceiver) = Receiver<Bool>.make(with: .hot)
let (episodeListTitlesTransmitter, episodeListTitlesReceiver) = Receiver<Bool>.make(with: .hot)
let (toWatchTitlesTransmitter, toWatchTitlesReceiver) = Receiver<Bool>.make(with: .hot)

final class SpoilersViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Spoiler Alert! Display episodes titles and images at your own risk."
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Episode Spoilers"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Title and Image in Detail Page"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.detailepisodetitle") == true {
                cell.detailTextLabel?.text = "Always Displayed"
            } else {
                cell.detailTextLabel?.text = "Hidden if Not Watched"
            }
        } else if indexPath.row == 1 {
            cell.textLabel?.text = "Titles in Lists"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.listsepisodetitle") == true {
                cell.detailTextLabel?.text = "Always Displayed"
            } else {
                cell.detailTextLabel?.text = "Always Hidden"
            }
        } else {
            cell.textLabel?.text = "Titles and Images in To Watch/Up Next"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle") == true {
                cell.detailTextLabel?.text = "Always Displayed"
            } else {
                cell.detailTextLabel?.text = "Always Hidden"
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row == 0 {
            let currentValue = UserDefaults.standard.bool(forKey: "GeneralSettings.detailepisodetitle")
            UserDefaults.standard.setValue(!currentValue, forKey: "GeneralSettings.detailepisodetitle")
            UserDefaults.standard.synchronize()
            episodeDetailTitlesTransmitter.broadcast(!currentValue)
        } else if indexPath.row == 1 {
            let currentValue = UserDefaults.standard.bool(forKey: "GeneralSettings.listsepisodetitle")
            UserDefaults.standard.setValue(!currentValue, forKey: "GeneralSettings.listsepisodetitle")
            UserDefaults.standard.synchronize()
            episodeListTitlesTransmitter.broadcast(!currentValue)
        } else {
            let currentValue = UserDefaults.standard.bool(forKey: "GeneralSettings.towatchepisodetitle")
            UserDefaults.standard.setValue(!currentValue, forKey: "GeneralSettings.towatchepisodetitle")
            UserDefaults.standard.synchronize()
            toWatchTitlesTransmitter.broadcast(!currentValue)
        }
        tableView.reloadData()
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54.0
    }
    #endif

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 44
    }
    #endif
}
