//
//  SwipeActionsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/05/2021.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import UIKit

final class SwipeActionsViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Swipe Options"
    }

    private let disposeBag = DisposeBag()

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Right To Left Swipe"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "First (Default) Action"
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.default") as? String {
                if swipeDefault == "checkin" {
                    cell.detailTextLabel?.text = "Check-in"
                } else if swipeDefault == "watched" {
                    cell.detailTextLabel?.text = "Watched Now"
                } else if swipeDefault == "watched_released" {
                    cell.detailTextLabel?.text = "Watched when Released"
                } else {
                    cell.detailTextLabel?.text = "Check-in"
                }
            } else {
                cell.detailTextLabel?.text = "Check-in"
            }
        } else {
            cell.textLabel?.text = "Secondary Action"
            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.secondary") as? String {
                if swipeDefault == "checkin" {
                    cell.detailTextLabel?.text = "Check-in"
                } else if swipeDefault == "watched" {
                    cell.detailTextLabel?.text = "Watched Now"
                } else if swipeDefault == "watched_released" {
                    cell.detailTextLabel?.text = "Watched when Released"
                } else {
                    cell.detailTextLabel?.text = "Watched Now"
                }
            } else {
                cell.detailTextLabel?.text = "Watched Now"
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "You can customize the primary (default) and secondary action for movies and episodes. The last action is always the full \"mark as watched\" with time options."
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.row == 0 {
            let alertController = UIAlertController(title: "Choose Wisely",
                                                    message: "What is the first action you want to see when swiping from right to left on an episode or movie?",
                                                    preferredStyle: .actionSheet)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)

            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.default") as? String {
                if swipeDefault == "checkin" {
                    let checkin = UIAlertAction(title: "Check-in ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else if swipeDefault == "watched" {
                    let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else if swipeDefault == "watched_released" {
                    let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else {
                    let checkin = UIAlertAction(title: "Check-in ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.default")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                }
            } else {
                let checkin = UIAlertAction(title: "Check-in ✓", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.default")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(checkin)

                let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.default")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(watched)

                let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.default")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(watchedReleased)
            }

            alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

            present(alertController, animated: true)
        } else if indexPath.row == 1 {
            let alertController = UIAlertController(title: "Choose Carefully",
                                                    message: "What is the second action you want to see when swiping from right to left on an episode or movie?",
                                                    preferredStyle: .actionSheet)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)

            if let swipeDefault = UserDefaults.standard.object(forKey: "Swipe.ToWatch.secondary") as? String {
                if swipeDefault == "checkin" {
                    let checkin = UIAlertAction(title: "Check-in ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else if swipeDefault == "watched" {
                    let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else if swipeDefault == "watched_released" {
                    let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                } else {
                    let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(checkin)

                    let watched = UIAlertAction(title: "Watched Now ✓", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watched)

                    let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                        guard let self = self else { return }
                        UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.secondary")
                        UserDefaults.standard.synchronize()
                        self.tableView.reloadData()
                    }
                    alertController.addAction(watchedReleased)
                }
            } else {
                let checkin = UIAlertAction(title: "Check-in", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("checkin", forKey: "Swipe.ToWatch.secondary")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(checkin)

                let watched = UIAlertAction(title: "Watched Now ✓", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("watched", forKey: "Swipe.ToWatch.secondary")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(watched)

                let watchedReleased = UIAlertAction(title: "Watched when Released", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue("watched_released", forKey: "Swipe.ToWatch.secondary")
                    UserDefaults.standard.synchronize()
                    self.tableView.reloadData()
                }
                alertController.addAction(watchedReleased)
            }

            alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

            present(alertController, animated: true)
        }
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    #endif
}
