//
//  GeneralSettingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 08/10/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit
import SwiftUI

import Receiver

let (toWatchDroppedEnabledTransmitter, toWatchDroppedEnabledReceiver) = Receiver<Bool>.make(with: .hot)
let (dragEnabledTransmitter, dragEnabledReceiver) = Receiver<Bool>.make(with: .hot)
let (onCommentsDisplayTransmitter, onCommentsDisplayReceiver) = Receiver<Bool>.make(with: .hot)
let (onCommentsCountDisplayTransmitter, onCommentsCountDisplayReceiver) = Receiver<Int>.make(with: .hot)

final class GeneralSettingsViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 {
            return "Choose how the Comments section in Movies, TV Shows, Episodes and Seasons is displayed."
        } else if section == 1 {
            return "Choose what's displayed in some media list: comment count, Trakt rating or nothing."
        } else if section == 2 {
            return "Allows you to drag and drop Movies, TV Shows and Episodes from a list to another. Dragging can sometimes interfere with Contextual Actions. Enable or disable Drag and Drop based on your own usage."
        } else if PurchaseManager.shared.purchased && section == 3 {
            return "Disable Dropped TV Shows only if you manage your To Watch manually. Let's keep the list of TV Shows' progress manageable to ensure the smooth operation of Rippple and Trakt's servers 🙏"
        } else {
            return "Configure how images are cached on your device. You can favor offline usage or always-fresh artwork."
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Comments"
        } else if section == 1 {
            return "Comment Count"
        } else if section == 2 {
            return "Drag & Drop"
        } else if PurchaseManager.shared.purchased && section == 3 {
            return "Dropped Shows"
        } else {
            return "Image Cache"
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        PurchaseManager.shared.purchased ? 5 : 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if indexPath.section == 0 {
            cell.textLabel?.text = "Comments in Detail"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.comments") == true {
                cell.detailTextLabel?.text = "Preview by most reacted"
            } else {
                cell.detailTextLabel?.text = "Just a count, no spoilers"
            }
        } else if indexPath.section == 1 {
            cell.textLabel?.text = "Ratings & Comments in Lists"
            if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 3 {
                cell.detailTextLabel?.text = "Ratings and Comment Count"
            } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 1 {
                cell.detailTextLabel?.text = "Ratings Only"
            } else if UserDefaults.standard.integer(forKey: "GeneralSettings.commentscount") == 0 {
                cell.detailTextLabel?.text = "Comment Count Only"
            } else {
                cell.detailTextLabel?.text = "Nothing (hidden)" // = 2
            }
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "Dragging"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.dragging") == true {
                cell.detailTextLabel?.text = "Enabled"
            } else {
                cell.detailTextLabel?.text = "Disabled"
            }
        } else if PurchaseManager.shared.purchased && indexPath.section == 3 {
            cell.textLabel?.text = "Dropped TV Shows"
            if UserDefaults.standard.bool(forKey: "GeneralSettings.droppedshows") == true {
                cell.detailTextLabel?.text = "Drop Shows after 6 month"
            } else {
                cell.detailTextLabel?.text = "Never Drop Shows"
            }
        } else {
            cell.textLabel?.text = "Image Cache Settings"
            cell.detailTextLabel?.text = ImagesManager.shared.cacheMode.name
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if UserDefaults.standard.bool(forKey: "GeneralSettings.comments") == true {
                UserDefaults.standard.setValue(false, forKey: "GeneralSettings.comments")
                UserDefaults.standard.synchronize()
                onCommentsDisplayTransmitter.broadcast(false)
            } else {
                UserDefaults.standard.setValue(true, forKey: "GeneralSettings.comments")
                UserDefaults.standard.synchronize()
                onCommentsDisplayTransmitter.broadcast(true)
            }
            tableView.reloadData()
        } else if indexPath.section == 1 {
            let alertController = UIAlertController(title: "What do you want to see?",
                                                    message: "Choose what's displayed on the Lists you'll see in app.",
                                                    preferredStyle: .alert)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)
            let ratings = UIAlertAction(title: "Ratings Only", style: .default) { _ in
                UserDefaults.standard.setValue(1, forKey: "GeneralSettings.commentscount")
                UserDefaults.standard.synchronize()
                onCommentsCountDisplayTransmitter.broadcast(1)
                self.tableView.reloadData()
            }
            alertController.addAction(ratings)
            let both = UIAlertAction(title: "Ratings and Comment Count", style: .default) { _ in
                UserDefaults.standard.setValue(3, forKey: "GeneralSettings.commentscount")
                UserDefaults.standard.synchronize()
                onCommentsCountDisplayTransmitter.broadcast(3)
                self.tableView.reloadData()
            }
            alertController.addAction(both)
            let commentCount = UIAlertAction(title: "Comment Count Only", style: .default) { _ in
                UserDefaults.standard.setValue(0, forKey: "GeneralSettings.commentscount")
                UserDefaults.standard.synchronize()
                onCommentsCountDisplayTransmitter.broadcast(0)
                self.tableView.reloadData()
            }
            alertController.addAction(commentCount)
            let nothing = UIAlertAction(title: "Nothing", style: .default) { _ in
                UserDefaults.standard.setValue(2, forKey: "GeneralSettings.commentscount")
                UserDefaults.standard.synchronize()
                onCommentsCountDisplayTransmitter.broadcast(2)
                self.tableView.reloadData()
            }
            alertController.addAction(nothing)
            present(alertController, animated: true)
        } else if indexPath.section == 2 {
            if UserDefaults.standard.bool(forKey: "GeneralSettings.dragging") == true {
                UserDefaults.standard.setValue(false, forKey: "GeneralSettings.dragging")
                UserDefaults.standard.synchronize()
                dragEnabledTransmitter.broadcast(false)
            } else {
                UserDefaults.standard.setValue(true, forKey: "GeneralSettings.dragging")
                UserDefaults.standard.synchronize()
                dragEnabledTransmitter.broadcast(true)
            }
            tableView.reloadData()
        } else if PurchaseManager.shared.purchased && indexPath.section == 3 {
            if UserDefaults.standard.bool(forKey: "GeneralSettings.droppedshows") == true {
                UserDefaults.standard.setValue(false, forKey: "GeneralSettings.droppedshows")
                UserDefaults.standard.synchronize()
                toWatchDroppedEnabledTransmitter.broadcast(false)
            } else {
                UserDefaults.standard.setValue(true, forKey: "GeneralSettings.droppedshows")
                UserDefaults.standard.synchronize()
                toWatchDroppedEnabledTransmitter.broadcast(true)
            }
            tableView.reloadData()
        } else {
            let view = ImageCacheSettingsView()
            let controller = UIHostingController(rootView: view)
            navigationController?.pushViewController(controller, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
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
