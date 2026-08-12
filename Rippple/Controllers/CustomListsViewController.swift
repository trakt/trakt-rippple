//
//  CustomListsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 10/12/2019.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import SafariServices
import UIKit

final class CustomListsViewController: UITableViewController {
    enum Section: Int, Hashable {
        case loading
        case error
        case standard
        case content
        case liked
    }

    enum Wrapper: Hashable {
        case standard(name: String, card: CardType, segue: String)
        case list(List, isLiked: Bool)
        case spacer(Float)
        case header(String, String)
    }

    final class ListsDiffableDataSource: UITableViewDiffableDataSource<Section, Wrapper> {
        override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            guard let item = itemIdentifier(for: indexPath) else { return false }
            switch item {
            case .list(_, let isLiked):
                return !isLiked
            default:
                return false
            }
        }

        override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            guard editingStyle == .delete else { return }
            guard let item = itemIdentifier(for: indexPath) else { return }
            guard case .list(let list, let isLiked) = item, isLiked == false else { return }

            if list.name.localizedCaseInsensitiveContains("[couchmoney.tv]") {
                UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://couchmoney.tv/mylists")!))
                return
            }

            if SessionManager.shared.isLoggedOut { return }

            SwiftMessages.show(message: "Deleting List...", style: .loading)

            TraktAPIProvider.provider.request(.deleteList(id: list.identifiers.trakt!), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success:
                    DispatchQueue.main.async {
                        ListsManager.shared.refresh()
                        SwiftMessages.show(message: "👍 Your list has been deleted")
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("customLists request failure \(error)")
                        ListsManager.shared.refresh()
                        SwiftMessages.show(message: "😓 Error deleting", style: .error(error))
                    }
                }
            }
        }

        override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            guard let item = itemIdentifier(for: indexPath) else { return false }
            switch item {
            case .list(_, let isLiked):
                return !isLiked
            default:
                return false
            }
        }

        override func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            if SessionManager.shared.isLoggedOut { return }

            if sectionIdentifier(for: sourceIndexPath.section) != .content { return }
            if sectionIdentifier(for: destinationIndexPath.section) != .content { return }
            if sourceIndexPath == destinationIndexPath { return }

            ListsManager.shared.lists.move(fromOffsets: IndexSet(integer: sourceIndexPath.row),
                                           toOffset: destinationIndexPath.row)
            let ids = ListsManager.shared.lists.compactMap { $0.identifiers.trakt }

            TraktAPIProvider.noRatingProvider.request(.reorderLists(ids: ids), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success:
                    ListsManager.shared.refresh()
                case .failure(let error):
                    DispatchQueue.main.async {
                        print("customLists request failure \(error)")
                        ListsManager.shared.refresh()
                        SwiftMessages.show(message: "😓 Error reordering", style: .error(error))
                    }
                }
            }
        }
    }

    var user: User!

    required init?(coder aDecoder: NSCoder) {
        user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    private var lists = [List]()
    private var likedLists = [List]()

    private let disposeBag = DisposeBag()

    @IBOutlet private var addListBarButtonItem: UIBarButtonItem?

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: UIView!
    private var showLoading = true

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching your lists.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching your lists..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    private lazy var dataSource = ListsDiffableDataSource(tableView: tableView) { [weak self] tableView, indexPath, item in
        guard let self = self else { return UITableViewCell() }
        switch item {
        case .standard(let name, let card, _):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "standard list", for: indexPath) as? StandardListTableViewCell else {
                return UITableViewCell()
            }
            cell.title.text = name
            cell.card.cardType = card
            cell.chevron.isHidden = tableView.isEditing
            return cell
        case .list(let list, let isLiked):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "custom list", for: indexPath) as? ListTableViewCell else {
                return UITableViewCell()
            }
            cell.user = isLiked ? nil : self.user
            cell.list = list
            cell.isEditingMode = tableView.isEditing && !isLiked
            cell.delegate = self
            return cell
        case .spacer(let space):
            if let cell = tableView.dequeueReusableCell(withIdentifier: "spacer") as? SpacerTableViewCell {
                cell.space = space
                return cell
            } else {
                return UITableViewCell()
            }
        case .header(let headerTitle, let headerSubtitle):
            let cell = tableView.dequeueReusableCell(withIdentifier: "header") as! ActivityHeaderTableViewCell
            cell.title.text = headerTitle
            cell.subtitle?.text = headerSubtitle
            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."

        // TODO: fix when on main thread
        while user == nil {
            user = UserManager.shared.currentUser
        }

        // if it's not the first VC on the stack, it means it's not the main user activities view but another user's
        if navigationController?.viewControllers.first != self {
            navigationItem.leftBarButtonItem = nil
        } else {
            restore()
            #if targetEnvironment(macCatalyst)
            // On Mac Catalyst, do not show a left bar button item.
            navigationItem.leftBarButtonItem = nil
            #else
            if UIDevice.current.userInterfaceIdiom == .pad {
                // On iPad, do not show a left bar button item.
                navigationItem.leftBarButtonItem = nil
            }
            #endif
        }

        if user.isCurrentUser {
            navigationItem.title = "Lists"
        } else {
            navigationItem.title = "\(user.username)'s Lists"
            navigationItem.rightBarButtonItems = nil
        }

        tableView.allowsSelectionDuringEditing = true

        tableView.separatorStyle = .none

        let loading = NVActivityIndicatorView(frame: CGRect(x: 0,
                                                            y: 0,
                                                            width: animationViewContainer.frame.width,
                                                            height: animationViewContainer.frame.height))
        loading.color = UIColor(asset: .globalTint)
        loading.type = .ballScaleMultiple
        loading.startAnimating()

        animationViewContainer.addSubview(loading)

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "StandardListTableViewCell", bundle: nil), forCellReuseIdentifier: "standard list")
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.register(UINib(nibName: "SpacerTableViewCell", bundle: nil), forCellReuseIdentifier: "spacer")
        tableView.register(UINib(nibName: "ActivityHeaderTableViewCell", bundle: nil), forCellReuseIdentifier: "header")

        tableView.sectionHeaderHeight = 0
        tableView.sectionFooterHeight = 0

        tableView.dragInteractionEnabled = false
        tableView.dropDelegate = self

        tableView.dataSource = dataSource

        // Initial data source state with loading if necessary
        if showLoading {
            applySnapshot(animating: false)
        }

        if user.isCurrentUser {
            onCustomListsChangedReceiver.listen { [weak self] lists in
                guard let self = self else { return }
                if UserManager.shared.currentUser == nil { return }
                self.lists = lists
                self.showLoading = false
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
                self.error = nil
                self.applySnapshot(animating: true, reload: true)
                self.updateListCreationButton()
            }.disposed(by: disposeBag)
        } else {
            fetchCustomLists()
        }

        navigationController?.delegate = self

        onLikedListsChangedReceiver.listen { [weak self] likedList in
            guard let self = self else { return }
            if self.user.isCurrentUser == false { return }
            self.likedLists = likedList
            if self.tableView.isEditing { return }
            self.applySnapshot(animating: true)
        }.disposed(by: disposeBag)

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.refresh(self.refreshControl as Any)
            }
        }.disposed(by: disposeBag)

        updateListCreationButton()
    }

    private func updateListCreationButton() {
        if ListsManager.shared.lists.count < UserManager.shared.currentUserListLimit {
            var actions = [UIAction]()
            actions.append(UIAction(title: "New Custom List",
                                    handler: { _ in
                                        self.performSegue(withIdentifier: "add", sender: nil)
                                    }))
            actions.append(UIAction(title: "New couchmoney.tv TV List",
                                    handler: { _ in
                                        UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://couchmoney.tv/tvaddlist")!))
                                    }))
            actions.append(UIAction(title: "New couchmoney.tv Movie List",
                                    handler: { _ in
                                        UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://couchmoney.tv/addlist")!))
                                    }))
            addListBarButtonItem?.menu = UIMenu(children: actions)
            addListBarButtonItem?.target = nil
            addListBarButtonItem?.action = nil
        } else {
            addListBarButtonItem?.menu = nil
            addListBarButtonItem?.target = self
            addListBarButtonItem?.action = #selector(VIPLimit)
        }
    }

    @objc func VIPLimit() {
        let alertController = UIAlertController(title: "Trakt Limit Reached",
                                                message: "You are currently limited to \(UserManager.shared.currentUserListLimit) lists on Trakt. You can delete a custom list. Upgrading to Track VIP may also help. If you are VIP, you've just hit a hard limit.",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Okay", style: .cancel))

        alertController.addAction(UIAlertAction(title: "Get Trakt VIP", style: .default, handler: { _ in
            if let url = URL(string: "https://app.trakt.tv/vip"),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }))
        present(alertController, animated: true)
    }

    private func restore() {
        if UserDefaults.standard.bool(forKey: "CustomListsViewController.displayList") == true {
            if let savedList = UserDefaults.standard.object(forKey: "CustomListsViewController.customList") as? Data {
                if let list = try? JSONDecoder().decode(List.self, from: savedList) {
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "list-no-animation", sender: list)
                    UIView.setAnimationsEnabled(true)
                }
            } else {
                if UserDefaults.standard.string(forKey: "CustomListsViewController.standardList") == "recommended" {
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "recommended-no-animation", sender: self)
                    UIView.setAnimationsEnabled(true)
                } else if UserDefaults.standard.string(forKey: "CustomListsViewController.standardList") == "collection" {
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "collection-no-animation", sender: self)
                    UIView.setAnimationsEnabled(true)
                } else if UserDefaults.standard.string(forKey: "CustomListsViewController.standardList") == "watched" {
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "watched-no-animation", sender: self)
                    UIView.setAnimationsEnabled(true)
                } else if UserDefaults.standard.string(forKey: "CustomListsViewController.standardList") == "collaborations" {
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "collaborations-no-animation", sender: self)
                    UIView.setAnimationsEnabled(true)
                } else { // watchlist or default behaviour (retro-compatibility)
                    UIView.setAnimationsEnabled(false)
                    performSegue(withIdentifier: "watchlist-no-animation", sender: self)
                    UIView.setAnimationsEnabled(true)
                }
            }
        }
    }

    @objc func refresh(_ sender: Any) {
        if user.isCurrentUser {
            ListsManager.shared.refresh()
        } else {
            fetchCustomLists()
        }
    }

    @IBAction func retry(_ sender: Any) {
        showLoading = true
        error = nil
        applySnapshot(animating: true)
        fetchCustomLists()
    }

    @IBAction func edit(_ sender: UIBarButtonItem) {
        // Toggle editing mode
        let isEditingNow = !tableView.isEditing
        tableView.setEditing(isEditingNow, animated: true)

        sender.title = isEditingNow ? "Done" : "Edit"

        applySnapshot(animating: true, reload: true)
    }

    private func applySnapshot(animating: Bool = false, reload: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()

        let contentItems = lists.map { Wrapper.list($0, isLiked: false) }

        if showLoading {
            navigationItem.subtitle = "Loading..."
            snapshot.appendSections([.loading])
            snapshot.appendItems([.spacer(100)], toSection: .loading)
        } else if error != nil {
            navigationItem.subtitle = "Error!"
            snapshot.appendSections([.error])
            snapshot.appendItems([.spacer(101)], toSection: .error)
        } else {
            // Standard section
            if tableView.isEditing == false {
                snapshot.appendSections([.standard])
                let standards: [Wrapper] = [
                    .standard(name: "Watchlist", card: .top, segue: "watchlist"),
                    .standard(name: "Favorites", card: .middle, segue: "recommended"),
                    .standard(name: "Library", card: .middle, segue: "collection"),
                    .standard(name: "Watched", card: .middle, segue: "watched"),
                    .standard(name: "Collaborations", card: .bottom, segue: "collaborations")
                ]
                snapshot.appendItems(standards, toSection: .standard)
                snapshot.appendItems([.spacer(5)], toSection: .standard)
            }

            // Content (custom lists)
            navigationItem.subtitle = "\(lists.count) Custom List\(lists.count > 1 ? "s" : "")"
            snapshot.appendSections([.content])
            snapshot.appendItems(contentItems, toSection: .content)
            if reload {
                snapshot.reloadItems(contentItems)
            }

            if user.isCurrentUser, tableView.isEditing == false {
                // Liked lists
                snapshot.appendSections([.liked])
                snapshot.appendItems([.spacer(10)], toSection: .liked)
                snapshot.appendItems([Wrapper.header("Lists you Like", "\(likedLists.count) list\(likedLists.count > 1 ? "s" : "")")])
                let likedItems = likedLists.map { Wrapper.list($0, isLiked: true) }
                snapshot.appendItems(likedItems, toSection: .liked)
            }
        }

        DispatchQueue.main.async {
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    private func fetchCustomLists() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        defer {
            DispatchQueue.main.async {
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
            }
        }

        TraktAPIProvider.fetchAllCustomLists(slug: user.identifiers.slug ?? "me") { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let lists):
                DispatchQueue.main.async {
                    self.lists = lists
                    self.showLoading = false
                    self.error = nil
                    self.applySnapshot(animating: true)
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("customLists request failure \(error)")
                    self.error = error
                    self.showLoading = false
                    self.applySnapshot(animating: true)
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "edit",
           let listFormViewController = (segue.destination as? UINavigationController)?.viewControllers.first as? ListFormViewController,
           let list = sender as? List {
            listFormViewController.list = list
        }

        if segue.identifier == "user",
           let list = sender as? List,
           let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.user(list.user))
        }

        if segue.identifier == "user",
           let user = sender as? User,
           let commentsViewController = segue.destination as? CommentsViewController {
            commentsViewController.coordinator = CommentsCoordinator(type: CommentsCoordinator.ListType.user(user))
        }

        if let watchlistViewController = segue.destination as? WatchlistViewController {
            watchlistViewController.user = user
        }

        if let userFavoritesViewController = segue.destination as? UserFavoritesViewController {
            userFavoritesViewController.user = user
        }

        if let collectionViewController = segue.destination as? CollectionViewController {
            collectionViewController.user = user
        }

        if let watchedViewController = segue.destination as? WatchedViewController {
            watchedViewController.user = user
        }

        if let collaborationsViewController = segue.destination as? CollaborationsViewController {
            collaborationsViewController.user = user
        }
    }

    @IBSegueAction
    func makeListViewController(coder: NSCoder, sender: Any?) -> ListViewController? {
        guard let list = sender as? List else { return nil }
        return ListViewController(coder: coder,
                                  list: list,
                                  user: user == list.user ? user : nil)
    }
}

extension CustomListsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        if tableView.isEditing {
            switch item {
            case .list(let list, let isLiked):
                if isLiked {
                    // Don't allow editing liked lists
                    break
                }
                if list.name.localizedCaseInsensitiveContains("[couchmoney.tv]") == false {
                    performSegue(withIdentifier: "edit", sender: list)
                } else {
                    UIApplication.shared.present(SFSafariViewController(url: URL(string: "https://couchmoney.tv/mylists")!))
                }
            default:
                break
            }
        } else if navigationController?.viewControllers.first == self {
            switch item {
            case .standard(let name, _, let segueId):
                UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                UserDefaults.standard.set(name.lowercased(), forKey: "CustomListsViewController.standardList")
                UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
                UserDefaults.standard.synchronize()
                performSegue(withIdentifier: segueId, sender: self)
            case .list(let list, _):
                if let encoded = try? JSONEncoder().encode(list) {
                    UserDefaults.standard.set(true, forKey: "CustomListsViewController.displayList")
                    UserDefaults.standard.set(encoded, forKey: "CustomListsViewController.customList")
                    UserDefaults.standard.removeObject(forKey: "CustomListsViewController.standardList")
                    UserDefaults.standard.synchronize()
                }
                performSegue(withIdentifier: "list", sender: list)
            default:
                break
            }
        } else {
            switch item {
            case .standard(_, _, let segueId):
                performSegue(withIdentifier: segueId, sender: self)
            case .list(let list, _):
                performSegue(withIdentifier: "list", sender: list)
            default:
                break
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let snapshot = dataSource.snapshot()
        let sectionType = snapshot.sectionIdentifiers[section]

        if sectionType == .loading {
            return loadingView
        }
        if sectionType == .error {
            return errorView
        }
        if sectionType == .liked {
            return UIView()
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        guard tableView.isEditing else { return .none }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return .none }
        switch item {
        case .list(_, let isLiked):
            return isLiked ? .none : .delete
        default:
            return .none
        }
    }

    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let snapshot = dataSource.snapshot()
        let destSection = snapshot.sectionIdentifiers[proposedDestinationIndexPath.section]

        if destSection != .content {
            // Move into first row of content section
            if let contentSectionIndex = snapshot.indexOfSection(.content) {
                return IndexPath(row: 0, section: contentSectionIndex)
            } else {
                return proposedDestinationIndexPath
            }
        }
        return proposedDestinationIndexPath
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension CustomListsViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        if navigationController.viewControllers.first == self, navigationController.viewControllers.firstIndex(of: viewController) == 0 {
            UserDefaults.standard.removeObject(forKey: "CustomListsViewController.displayList")
            UserDefaults.standard.removeObject(forKey: "CustomListsViewController.customList")
            UserDefaults.standard.removeObject(forKey: "CustomListsViewController.standardList")
            UserDefaults.standard.synchronize()
        } else {
            // do nothing
        }
    }
}

extension CustomListsViewController: ListTableViewCellDelegate {
    func cell(_ cell: ListTableViewCell, action: ListTableViewCell.Action) {
        guard let list = cell.list else { return }
        if action == .touch {
            performSegue(withIdentifier: "list", sender: list)
        } else if action == .user {
            if let type = list.type, type == "official" {
                let alert = UIAlertController(title: "Trakt Official List",
                                              message: "This is an official list created and maintained by Trakt.",
                                              preferredStyle: .alert)
                let okay = UIAlertAction(title: "Okay", style: .default) { [weak self] _ in
                    guard let self = self else { return }

                    self.dismiss(animated: true)
                }
                alert.addAction(okay)
                present(alert, animated: true)
            } else {
                if let user = cell.user {
                    performSegue(withIdentifier: "user", sender: user)
                } else {
                    performSegue(withIdentifier: "user", sender: list)
                }
            }
        }
    }
}

extension CustomListsViewController: UITableViewDropDelegate {
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        for item in session.items where item.itemProvider.canLoadObject(ofClass: NSURL.self) {
            return true
        }
        return false
    }

    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        for visibleCell in tableView.visibleCells {
            visibleCell.isSelected = false
        }

        guard let destinationIndexPath = destinationIndexPath else { return UITableViewDropProposal(operation: .cancel) }
        let snapshot = dataSource.snapshot()
        let destSection = snapshot.sectionIdentifiers[destinationIndexPath.section]

        if destSection == .liked {
            return UITableViewDropProposal(operation: .cancel)
        }
        if destSection == .standard && destinationIndexPath.row == 3 {
            return UITableViewDropProposal(operation: .cancel)
        }
        tableView.cellForRow(at: destinationIndexPath)?.isSelected = true
        return UITableViewDropProposal(operation: .copy)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for visibleCell in tableView.visibleCells {
            visibleCell.isSelected = false
        }

        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        let snapshot = dataSource.snapshot()
        let destSection = snapshot.sectionIdentifiers[destinationIndexPath.section]

        switch destSection {
        case .standard:
            if let item = dataSource.itemIdentifier(for: destinationIndexPath) {
                switch item {
                case .standard(let name, _, _):
                    switch name {
                    case "Watchlist":
                        addToWatchlist(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
                    case "Favorites":
                        addToRecommendations(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
                    case "Library":
                        addToCollection(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel })
                    default:
                        break
                    }
                default:
                    break
                }
            }
        case .content:
            if let item = dataSource.itemIdentifier(for: destinationIndexPath) {
                switch item {
                case .list(let list, _):
                    add(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel }, to: list)
                default:
                    break
                }
            }
        default:
            break
        }
    }

    private func add(models: [MediaModel], to list: List) {
        SwiftMessages.show(message: "Adding to List...", style: .loading)

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            MediaModel.addShowsToWatchlistUndercover(medias: models)
        }

        TraktAPIProvider.provider.request(.addToList(id: list.identifiers.trakt!,
                                                     item: WatchlistedItem(models: models)), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Add to list successful \(response)")

                    DispatchQueue.main.async {
                        onListChangedTransmitter.broadcast([list])
                        SwiftMessages.show(message: "✅ Added \(models.count) to list")
                    }

                } catch {
                    print("Error adding to recommendations \(error)")
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    }
                }
            case .failure(let error):
                print("Error adding to recommendations \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                }
            }
        }
    }

    private func addToCollection(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Library...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToCollection(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Library successful \(response)")

                    DispatchQueue.main.async {
                        CollectionManager.shared.refresh()
                        SwiftMessages.show(message: "📚 Added \(models.count) to Library")
                    }

                } catch {
                    print("Error adding to collection \(error)")
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                print("Error adding to collection \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    private func addToRecommendations(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Favorites...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToRecommendations(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Recommendation successful \(response)")

                    DispatchQueue.main.async {
                        UserFavoritesManager.shared.refresh()
                        SwiftMessages.show(message: "⭐️ Added \(models.count) to Favorites")
                    }

                } catch {
                    print("Error adding to recommendations \(error)")
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                print("Error adding to recommendations \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }

    private func addToWatchlist(models: [MediaModel]) {
        SwiftMessages.show(message: "Adding to Watchlist...", style: .loading)
        TraktAPIProvider.provider.request(TraktAPIService.addToWatchlist(item: WatchlistedItem(models: models)),
                                          callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    print("Add to watchlist successful \(response)")

                    DispatchQueue.main.async {
                        WatchlistManager.shared.refresh()
                        SwiftMessages.show(message: "🕒 Added \(models.count) to Watchlist")
                    }

                } catch {
                    print("Error adding to watchlist \(error)")
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                    }
                }
            case .failure(let error):
                print("Error adding to watchlist \(error)")
                DispatchQueue.main.async {
                    SwiftMessages.show(message: " 😓 An error occurred", style: .error(error))
                }
            }
        }
    }
}
