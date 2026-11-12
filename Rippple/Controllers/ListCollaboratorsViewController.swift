//
//  ListCollaboratorsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 14/10/2026.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import UIKit

final class ListCollaboratorsViewController: UITableViewController {
    private enum Section: Hashable {
        case info
        case collaborators
        case followers
    }

    private enum Item: Hashable {
        case info
        case user(User)
    }

    private let list: List

    private var collaborators = [User]()
    private var followers = [User]()
    private var friends = Set<User>()
    private var pendingUsers = Set<User>()
    private var searchQuery = ""
    private var hasLoaded = false
    private var error: Error?
    /// Bumped when a collaborator change completes, so loads that overlapped it can be discarded.
    private var mutationGeneration = 0
    private var needsReloadAfterMutations = false

    private var loadTask: _Concurrency.Task<Void, Never>?

    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var loadingView: UIView = {
        let container = UIView()
        let loading = NVActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 60, height: 60),
                                              type: .ballScaleMultiple,
                                              color: UIColor(asset: .globalTint))
        loading.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(loading)
        NSLayoutConstraint.activate([
            loading.widthAnchor.constraint(equalToConstant: 60),
            loading.heightAnchor.constraint(equalToConstant: 60),
            loading.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loading.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        loading.startAnimating()
        return container
    }()

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Item>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .info:
            let cell = TintedCanvasTableViewCell(style: .default, reuseIdentifier: "info")
            cell.selectionStyle = .none
            let font = UIFont.preferredFont(forTextStyle: .subheadline)
            let text = NSMutableAttributedString(string: "Collaborators can add and remove items on ")
            text.append(NSAttributedString(string: self.list.name.emojiUnescapedString, attributes: [.font: font.bold()]))
            text.append(NSAttributedString(string: ".\nChoose from people who follow you."))
            var content = UIListContentConfiguration.cell()
            content.textProperties.color = .secondaryLabel
            content.textProperties.font = font
            content.attributedText = text
            content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16)
            cell.contentConfiguration = content
            return cell
        case .user(let user):
            let cell = tableView.dequeueReusableCell(withIdentifier: "user") as! UserTableViewCell
            cell.user = user
            cell.accessoryControl = self.button(for: user)
            return cell
        }
    }

    init(list: List) {
        self.list = list
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = "Collaborators"
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done,
                                         target: self,
                                         action: #selector(doneTapped))
        doneButton.style = .plain
        navigationItem.rightBarButtonItem = doneButton

        tableView.backgroundColor = .ripppleViewBackground
        tableView.allowsFocus = false
        tableView.allowsSelection = false
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.register(UINib(nibName: "UserInListTableViewCell", bundle: nil), forCellReuseIdentifier: "user")
        tableView.sectionHeaderTopPadding = 0
        dataSource.defaultRowAnimation = .fade

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = "Search name or username"
        searchController.searchBar.tintColor = UIColor(asset: .globalTint)
        navigationItem.hidesSearchBarWhenScrolling = false

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        #endif

        load()
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    @objc private func refresh() {
        load()
    }

    // MARK: - Loading

    private func load() {
        loadTask?.cancel()
        error = nil
        applySnapshot()

        let list = list
        let generation = mutationGeneration
        loadTask = _Concurrency.Task { [weak self] in
            do {
                async let collaborators = TraktAPIProvider.fetchListCollaborators(list: list)
                async let followers = TraktAPIProvider.fetchFollowUsers(.followers(slug: nil))
                async let friends = TraktAPIProvider.fetchFollowUsers(.friends(slug: nil))
                let (loadedCollaborators, loadedFollowers) = try await(collaborators, followers)
                // Mutual follows only affect ordering.
                let loadedFriends = (try? await friends) ?? []

                guard let self = self, !_Concurrency.Task<Never, Never>.isCancelled else { return }
                // A change that overlapped this load may not be reflected in its response.
                guard self.mutationGeneration == generation, self.pendingUsers.isEmpty else {
                    self.reloadWhenIdle()
                    return
                }
                self.collaborators = loadedCollaborators
                self.followers = loadedFollowers
                self.friends = Set(loadedFriends)
                self.hasLoaded = true
                self.refreshControl?.endRefreshing()
                self.applySnapshot()
            } catch {
                guard let self = self, !_Concurrency.Task<Never, Never>.isCancelled else { return }
                self.refreshControl?.endRefreshing()
                if self.hasLoaded {
                    SwiftMessages.show(message: "😓 Error refreshing collaborators", style: .error(error))
                } else {
                    self.error = error
                }
                self.applySnapshot()
            }
        }
    }

    private func reloadWhenIdle() {
        if pendingUsers.isEmpty {
            load()
        } else {
            needsReloadAfterMutations = true
        }
    }

    // MARK: - Content

    /// Followers who aren't collaborators yet, mutual follows first.
    private var candidates: [User] {
        let available = followers.filter { !collaborators.contains($0) }
        return available.filter { friends.contains($0) } + available.filter { !friends.contains($0) }
    }

    private func matchesSearch(_ user: User) -> Bool {
        guard !searchQuery.isEmpty else { return true }
        return user.name.localizedCaseInsensitiveContains(searchQuery) || user.username.localizedCaseInsensitiveContains(searchQuery)
    }

    private func applySnapshot(animatingDifferences: Bool = false) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        tableView.backgroundView = hasLoaded || error != nil ? nil : loadingView

        let hasPeople = !collaborators.isEmpty || !followers.isEmpty
        // Search only makes sense once there are people to filter.
        let showsSearch = hasLoaded && error == nil && hasPeople
        if (navigationItem.searchController != nil) != showsSearch {
            navigationItem.searchController = showsSearch ? searchController : nil
        }

        guard hasLoaded else {
            updateContentUnavailable(hasPeople: false, hasMatches: false)
            dataSource.apply(snapshot, animatingDifferences: false)
            return
        }

        let matchingCollaborators = collaborators.filter(matchesSearch)
        let matchingCandidates = candidates.filter(matchesSearch)

        if searchQuery.isEmpty, hasPeople {
            snapshot.appendSections([.info])
            snapshot.appendItems([.info])
        }
        if !matchingCollaborators.isEmpty {
            snapshot.appendSections([.collaborators])
            snapshot.appendItems(matchingCollaborators.map { .user($0) })
        }
        if !matchingCandidates.isEmpty {
            snapshot.appendSections([.followers])
            snapshot.appendItems(matchingCandidates.map { .user($0) })
        }

        updateContentUnavailable(hasPeople: hasPeople, hasMatches: !matchingCollaborators.isEmpty || !matchingCandidates.isEmpty)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
    }

    private func updateContentUnavailable(hasPeople: Bool, hasMatches: Bool) {
        if let error = error {
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "exclamationmark.triangle")
            configuration.text = "Couldn’t Load Collaborators"
            configuration.secondaryText = error.localizedDescription
            configuration.button = textButton(title: "Try Again")
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                guard let self = self else { return }
                self.load()
            }
            contentUnavailableConfiguration = configuration
        } else if hasLoaded, !hasPeople {
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "person.2")
            configuration.text = "No Followers"
            configuration.secondaryText = "People who follow you can be added as collaborators. Ask your future collaborators to follow you first."
            configuration.button = textButton(title: "Share Your Profile")
            configuration.buttonProperties.primaryAction = UIAction { _ in
                guard let sharedURL = UserManager.shared.currentUser?.url else { return }
                UIApplication.shared.present(UIActivityViewController(activityItems: [sharedURL],
                                                                      applicationActivities: nil))
            }
            contentUnavailableConfiguration = configuration
        } else if hasLoaded, !hasMatches {
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.search()
        } else {
            contentUnavailableConfiguration = nil
        }
    }

    private func textButton(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.baseForegroundColor = UIColor(asset: .globalTint)
        return configuration
    }

    private func button(for user: User) -> UIButton {
        let isCollaborator = collaborators.contains(user)
        var configuration = UIButton.Configuration.plain()
        configuration.title = isCollaborator ? "Remove" : "Add"
        configuration.baseForegroundColor = isCollaborator ? .systemRed : UIColor(asset: .globalTint)
        configuration.showsActivityIndicator = pendingUsers.contains(user)

        let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.toggle(user)
        })
        button.isEnabled = !pendingUsers.contains(user)
        button.accessibilityLabel = "\(isCollaborator ? "Remove" : "Add") \(user.username) as a collaborator"
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }

    // MARK: - Actions

    private func toggle(_ user: User) {
        guard pendingUsers.insert(user).inserted else { return }
        let isCollaborator = collaborators.contains(user)
        reconfigure(user)

        let list = list
        _Concurrency.Task { [weak self] in
            do {
                if isCollaborator {
                    try await TraktAPIProvider.removeListCollaborator(user, from: list)
                } else {
                    try await TraktAPIProvider.addListCollaborator(user, to: list)
                }
                guard let self = self else { return }
                if isCollaborator {
                    self.collaborators.removeAll { $0 == user }
                } else if !self.collaborators.contains(user) {
                    self.collaborators.append(user)
                }
            } catch {
                SwiftMessages.show(message: "😓 Couldn’t \(isCollaborator ? "remove" : "add") \(user.username)", style: .error(error))
            }

            guard let self = self else { return }
            self.pendingUsers.remove(user)
            self.mutationGeneration += 1
            self.applySnapshot(animatingDifferences: true)
            self.reconfigure(user)
            if self.pendingUsers.isEmpty, self.needsReloadAfterMutations {
                self.needsReloadAfterMutations = false
                self.load()
            }
        }
    }

    private func reconfigure(_ user: User) {
        var snapshot = dataSource.snapshot()
        guard snapshot.indexOfItem(.user(user)) != nil else { return }
        snapshot.reconfigureItems([.user(user)])
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: - UITableViewDelegate

extension ListCollaboratorsViewController {
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView()
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 0 : 16
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - UISearchResultsUpdating

extension ListCollaboratorsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = (searchController.searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != searchQuery else { return }
        searchQuery = query
        applySnapshot()
    }
}
