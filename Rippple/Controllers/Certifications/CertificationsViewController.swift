//
//  CertificationsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2023.
//  Copyright © Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class CertificationsViewController: UITableViewController {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    var media: MediaModel?

    private let disposeBag = DisposeBag()

    private enum Section: Hashable {
        case empty
        case content
    }

    private enum Wrapper: Hashable {
        case empty
        case loading
        case certification(Certification)
    }

    private class CertificationsDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private lazy var dataSource = CertificationsDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .certification(let certification):
            let cell = tableView.dequeueReusableCell(withIdentifier: "certification") as! CertificationTableViewCell
            cell.certification = certification
            if let media = media, media.movie?.certification == certification.name || media.show?.certification == certification.name {
                cell.nameLabel.text = "→ " + cell.nameLabel.text!
                cell.nameLabel.textColor = UIColor(asset: .globalTint)
                cell.descriptionLabel.isHidden = false
            } else {
                cell.nameLabel.textColor = .label
                cell.descriptionLabel.isHidden = true
            }
            return cell
        case .empty:
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = "🤷‍♂️"
            cell.title.text = "No Certifications"
            cell.subtitle.text = "We couldn't fetch the Age Rating Certifications on trakt."
            cell.body.text = "Try again later..."
            cell.action.isHidden = true
            return cell
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Age Rating Certifications"

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "CertificationTableViewCell", bundle: nil), forCellReuseIdentifier: "certification")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.separatorStyle = .none

        dataSource.defaultRowAnimation = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.empty])
        snapshot.appendItems([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        refresh(self)
    }

    @objc func refresh(_ sender: Any) {
        let service = if let media = media, media.movie != nil {
            TraktAPIService.certifications(type: .movies)
        } else {
            TraktAPIService.certifications(type: .shows)
        }
        TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let certifications = try response.map(CertificationsCounties.self, using: TraktAPIProvider.decoder).us.filter { !$0.name.localizedStandardContains("Not Rated") }

                    DispatchQueue.main.async {
                        if certifications.isEmpty {
                            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                            snapshot.appendSections([.empty])
                            snapshot.appendItems([.empty])
                            self.dataSource.apply(snapshot, animatingDifferences: false)
                        } else {
                            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                            snapshot.appendSections([.content])
                            snapshot.appendItems(certifications.map { Wrapper.certification($0) })
                            self.dataSource.apply(snapshot, animatingDifferences: false)
                        }
                        self.refreshControl?.endRefreshing()
                    }
                } catch {
                    print("Error Fetching Certification \(error)")
                    DispatchQueue.main.async {
                        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                        snapshot.appendSections([.empty])
                        snapshot.appendItems([.empty])
                        self.dataSource.apply(snapshot, animatingDifferences: false)
                        self.refreshControl?.endRefreshing()
                    }
                }
            case .failure(let error):
                print("Error Fetching Certification \(error)")
                DispatchQueue.main.async {
                    var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
                    snapshot.appendSections([.empty])
                    snapshot.appendItems([.empty])
                    self.dataSource.apply(snapshot, animatingDifferences: false)
                    self.refreshControl?.endRefreshing()
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true)
    }
}
