//
//  PeopleSearchResultsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 05/10/2018.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import NVActivityIndicatorView
import Receiver
import UIKit

final class PeopleSearchResultsViewController: UITableViewController {
    /// Public
    var service: TraktAPIService!

    private let disposeBag = DisposeBag()

    /// Empty
    @IBOutlet private var emptyView: UIView!

    // Paging Management
    @IBOutlet private var loadingView: UIView!
    @IBOutlet private var animationViewContainer: NVActivityIndicatorView!

    // Error Management
    @IBOutlet private var errorView: UIView!
    private var error: Error?

    private enum Section: Int {
        case loading
        case error
        case content
    }

    private enum Wrapper: Hashable {
        case people(PersonItem)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .people(let personItem):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "people") as? PeopleTableViewCell else {
                fatalError("Could not dequeue a people cell")
            }

            cell.person = personItem.person

            return cell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        precondition(service != nil, "Search results view controller must be fed with a service object!")

        navigationItem.style = .browser
        navigationItem.subtitle = "Loading..."
        navigationItem.largeTitleDisplayMode = .never

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "PeopleTableViewCell", bundle: nil), forCellReuseIdentifier: "people")
        tableView.separatorStyle = .none
        tableView.dataSource = dataSource
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 20, right: 0)

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        animationViewContainer.tintColor = UIColor(asset: .globalTint)
        animationViewContainer.startAnimating()

        fetch()

        errorView.removeFromSuperview()
        loadingView.removeFromSuperview()
        emptyView.removeFromSuperview()
    }

    @IBAction func refresh(_ sender: Any) {
        fetch()
    }

    func fetch() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let searchResults = try response.map([PersonItem].self, using: TraktAPIProvider.decoder)

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.content])
                    snapshot.appendItems(searchResults.map { Wrapper.people($0) })
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "\(searchResults.count) result\(searchResults.count < 2 ? "" : "s")"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                } catch {
                    print("Comments request JSON mapping failed! \(error)")
                    self.error = error

                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.error])
                    DispatchQueue.main.async {
                        self.navigationItem.subtitle = "Error"
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                    }
                }
            case .failure(let error):
                print("Comments request failure \(error)")
                self.error = error

                var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                snapshot.appendSections([.error])
                DispatchQueue.main.async {
                    self.navigationItem.subtitle = "Error"
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
        }
    }

    @IBSegueAction
    func makePeopleViewController(coder: NSCoder, sender: Any?) -> PeopleViewController? {
        PeopleViewController(coder: coder,
                             cast: sender as? Cast ?? nil,
                             job: sender as? Job ?? nil,
                             person: sender as? Person ?? nil)
    }
}

extension PeopleSearchResultsViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.people(let personItem) = item else { return }
        performSegue(withIdentifier: "people", sender: personItem.person)
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return errorView
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return loadingView
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return emptyView
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == dataSource.snapshot().indexOfSection(Section.error) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.loading) {
            return 100
        }

        if section == dataSource.snapshot().indexOfSection(Section.content), dataSource.snapshot().numberOfItems == 0 {
            return 100
        }

        return 0
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
            guard case Wrapper.people(let personItem) = item else { return nil }

            let person = personItem.person

            if cell.avatarImageView.image == nil { return nil }

            return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                              previewProvider: {
                                                  let mediaPreviewViewController = UIStoryboard(name: "PersonPreview", bundle: nil).instantiateInitialViewController() as! PeoplePreviewViewController

                                                  mediaPreviewViewController.person = person
                                                  mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                                                           height: 500 * 1.5)
                                                  return mediaPreviewViewController
                                              }, actionProvider: { _ -> UIMenu? in
                                                  return UIMenu(children: [])
                                              })
        }

        return nil
    }

    override func tableView(_ tableView: UITableView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = tableView.cellForRow(at: indexPath) as? PeopleTableViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    override func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        guard case Wrapper.people(let personItem) = item else { return }
        performSegue(withIdentifier: "people", sender: personItem.person)
    }
}
