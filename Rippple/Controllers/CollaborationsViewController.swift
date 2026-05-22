//
//  CollaborationsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 23/11/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class CollaborationsViewController: UITableViewController {
    var user: User!

    required init?(coder aDecoder: NSCoder) {
        user = UserManager.shared.currentUser
        super.init(coder: aDecoder)
    }

    private var cancellable: Cancellable?

    private var lists = [List]()

    private let disposeBag = DisposeBag()

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: UIView!
    private var showLoading = true

    // Empty state Management
    @IBOutlet private var emptyView: UIView!
    @IBOutlet private var emptyLabel: UILabel!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error? {
        didSet {
            if let error = error {
                errorLabel.text = "An error occurred while fetching your collaborations.\n\(error.localizedDescription)"
            } else {
                errorLabel.text = "An error occurred while fetching your collaborations..."
            }
        }
    }

    @IBOutlet var errorLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        while user == nil {
            user = UserManager.shared.currentUser
        }

        navigationItem.style = .browser

        if user.isCurrentUser {
            navigationItem.title = "Collaborations"
        } else {
            navigationItem.title = "\(user.username)'s Collaborations"
        }

        let loading = NVActivityIndicatorView(frame: CGRect(x: 0,
                                                            y: 0,
                                                            width: animationViewContainer.frame.width,
                                                            height: animationViewContainer.frame.height))
        loading.color = UIColor(asset: .globalTint)
        loading.type = .ballScaleMultiple
        loading.startAnimating()

        animationViewContainer.addSubview(loading)

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "CustomListTableViewCell", bundle: nil), forCellReuseIdentifier: "custom list")
        tableView.separatorStyle = .none

        tableView.dragInteractionEnabled = false
        tableView.dropDelegate = self

        if user.isCurrentUser {
            onCollaborationsChangedReceiver.listen { [weak self] lists in
                guard let self = self else { return }
                self.lists = lists
                self.showLoading = false
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
                self.error = nil
                self.tableView.reloadData()
            }.disposed(by: disposeBag)
        } else {
            fetchCollaborations()
        }

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
    }

    @objc func refresh(_ sender: Any) {
        if user.isCurrentUser {
            CollaborationsManager.shared.refresh()
        } else {
            fetchCollaborations()
        }
    }

    @IBAction func retry(_ sender: Any) {
        showLoading = true
        error = nil
        tableView.reloadData()
        if user.isCurrentUser {
            CollaborationsManager.shared.refresh()
        } else {
            fetchCollaborations()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
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
    }

    @IBSegueAction
    func makeListViewController(coder: NSCoder, sender: Any?) -> ListViewController? {
        guard let list = sender as? List else { return nil }
        return ListViewController(coder: coder,
                                  list: list,
                                  user: user == list.user ? user : nil)
    }

    private func fetchCollaborations() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        defer {
            DispatchQueue.main.async {
                self.refreshControl?.isEnabled = true
                self.refreshControl?.endRefreshing()
            }
        }

        cancellable = TraktAPIProvider.provider.request(.collaborations(slug: user.identifiers.slug ?? "me"), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let lists = try response.map([List].self, using: TraktAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.lists = lists
                        self.showLoading = false
                        self.error = nil
                        self.tableView.reloadData()
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("customLists request JSON mapping failed! \(error)")
                        self.error = error
                        self.showLoading = false
                        self.tableView.reloadData()
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    print("customLists request failure \(error)")
                    self.error = error
                    self.showLoading = false
                    self.tableView.reloadData()
                }
            }
        }
    }
}

extension CollaborationsViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return lists.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "custom list") as! ListTableViewCell
        let list = lists[indexPath.row]
        cell.list = list
        cell.isEditingMode = tableView.isEditing
        cell.delegate = self
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let list = lists[indexPath.row]
        performSegue(withIdentifier: "list", sender: list)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if error != nil {
            return errorView
        }

        if showLoading {
            return loadingView
        }

        if lists.isEmpty {
            if user.isCurrentUser {
                emptyLabel.text = "You are not a collaborator on any list."
            } else {
                emptyLabel.text = "No public collaboration for this user."
            }
            return emptyView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if error != nil {
            return 100
        }

        if showLoading {
            return 100
        }

        if lists.isEmpty {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

extension CollaborationsViewController: ListTableViewCellDelegate {
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

extension CollaborationsViewController: UITableViewDropDelegate {
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

        tableView.cellForRow(at: destinationIndexPath)?.isSelected = true
        return UITableViewDropProposal(operation: .copy)
    }

    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        for visibleCell in tableView.visibleCells {
            visibleCell.isSelected = false
        }

        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        add(models: coordinator.items.compactMap { $0.dragItem.localObject as? MediaModel }, to: lists[destinationIndexPath.row])
    }

    private func add(models: [MediaModel], to list: List) {
        SwiftMessages.show(message: "Adding to List...", style: .loading)

        if UserDefaults.standard.bool(forKey: "GeneralSettings.addtowatchlistautolistsync") {
            MediaModel.addShowsToWatchlistUndercover(medias: models)
        }

        TraktAPIProvider.provider.request(.addToList(slug: list.user.slug,
                                                     id: list.identifiers.trakt!,
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
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Adding failed", style: .error(error))
                }
            }
        }
    }
}
