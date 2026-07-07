//
//  NotificationCenterViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 22/04/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class NotificationCenterViewController: UITableViewController {
    enum Section: Hashable {
        case empty
        case day(Date)
    }

    enum Wrapper: Hashable {
        case empty(String, String, String, String)
        case header(Date)
        case notification(RipppleNotification)
    }

    private class NotificationCenterDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private var headerDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }

    private lazy var dataSource = NotificationCenterDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, wrapper in
        guard let self = self else { return nil }

        switch wrapper {
        case .notification(let notification):
            let cell = tableView.dequeueReusableCell(withIdentifier: "notification") as! NotificationCenterTableViewCell
            if notification.title == "" {
                cell.title.text = "New Notification"
            } else {
                cell.title.text = notification.title
            }
            cell.subtitle.text = notification.subtitle
            cell.body.text = notification.body
            cell.date.text = dateFormatter.string(from: notification.date)
            return cell
        case .header(let date):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell

            cell.title.text = headerDateFormatter.string(from: date)

            let now = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date.now)!

            let diff = Calendar.current.dateComponents([.day],
                                                       from: now,
                                                       to: Calendar.current.date(bySettingHour: 0,
                                                                                 minute: 0,
                                                                                 second: 0,
                                                                                 of: date)!).day ?? 0
            if diff == 0 {
                cell.subtitle?.text = "today"
            } else if diff == -1 {
                cell.subtitle?.text = "yesterday"
            } else {
                cell.subtitle?.text = "\(abs(diff)) days ago"
            }

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

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        // force an update of the notification center because the user asked to open it
        NotificationCenterManager.shared.update()

        dataSource.defaultRowAnimation = .fade

        tableView.register(UINib(nibName: "NotificationCenterTableViewCell", bundle: nil), forCellReuseIdentifier: "notification")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")

        tableView.allowsFocus = false
        tableView.dataSource = dataSource
        tableView.delegate = self

        tableView.separatorStyle = .none

        onNotificationCenterChangedReceiver.listen { [weak self] notifications in
            guard let self = self else { return }
            self.reload(with: notifications)
        }.disposed(by: disposeBag)

        reload(with: NotificationCenterManager.shared.notifications)
    }

    deinit {
        NotificationCenterManager.shared.notificationsRead()
    }

    private func loadEmptyView() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.empty])
        snapshot.appendItems([.empty("🔔",
                                     "No Notifications",
                                     "There are currently no notifications to display",
                                     "When new notifications will arrive, you will be able to find them here later.")])
        dataSource.apply(snapshot, animatingDifferences: false, completion: nil)
    }

    private func reload(with notifications: [RipppleNotification]?) {
        guard let notifications = notifications else {
            loadEmptyView()
            return
        }

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        for notification in notifications.sorted(by: { $0.date > $1.date }) {
            let date = Calendar.current.date(bySettingHour: 0,
                                             minute: 0,
                                             second: 0,
                                             of: notification.date)!
            if let section = snapshot.sectionIdentifier(containingItem: .header(date)) {
                snapshot.appendItems([.notification(notification)], toSection: section)
            } else {
                snapshot.appendSections([.day(date)])
                snapshot.appendItems([.header(date), .notification(notification)])
            }
        }
        if snapshot.itemIdentifiers.isEmpty {
            loadEmptyView()
        } else {
            snapshot.reloadItems(snapshot.itemIdentifiers)
            dataSource.apply(snapshot, animatingDifferences: true, completion: nil)
        }
    }
}

extension NotificationCenterViewController {
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let firstIndexPath = tableView.indexPathForRow(at: CGPoint(x: 0.0,
                                                                         y: tableView.adjustedContentInset.top + tableView.contentOffset.y)) else { return }

        if tableView.contentOffset.y + tableView.adjustedContentInset.top == 0.0 {
            navigationItem.title = "Notifications"
            return
        }

        guard let section = dataSource.sectionIdentifier(for: firstIndexPath.section) else { return }
        switch section {
        case .day(let date):
            navigationItem.title = headerDateFormatter.string(from: date)
        case .empty:
            return
        }
    }
}

extension NotificationCenterViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case .notification(let notification) = item else { return }

        if let link = notification.link, let url = URL(string: link) {
            DeeplinkManager.shared.registerDeeplink(url: url)
            if SessionManager.shared.isLoggedIn,
               DeeplinkManager.shared.shouldOpenDeeplink() {
                UIApplication.shared.switchToDeeplink()
            }
        }
        if let versionToCheck = notification.versionToCheck {
            UIApplication.shared.checkVersionNow(version: versionToCheck)
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let wrapper = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch wrapper {
        case .notification(let notification):
            let clear = UIContextualAction(style: .normal,
                                           title: "Clear") { _, _, boolValue in
                NotificationCenterManager.shared.delete(notification: notification)
                boolValue(true)
            }
            clear.image = UIImage(systemName: "xmark.circle.fill")
            clear.backgroundColor = UIColor.systemRed

            return UISwipeActionsConfiguration(actions: [clear])
        default:
            return nil
        }
    }
}
