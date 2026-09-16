//
//  CertificationsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 31/12/2023.
//  Copyright © Trakt. All rights reserved.
//

import Moya
import UIKit

final class CertificationsViewController: UITableViewController {
    var media: MediaModel?

    private var certification: Certification?
    private var guide: ParentalGuide?
    private var certificationsLoading = false
    private var guideLoading = false
    private var certificationsFailed = false
    private var guideFailed = false
    private var certificationsRequest: Cancellable?
    private var guideRequest: Cancellable?
    private var requestID = UUID()

    private enum Section: Hashable {
        case content
    }

    private enum Wrapper: Hashable {
        case certification
        case guide(ParentalGuide.Category)
        case notice(String)
    }

    private lazy var dataSource = UITableViewDiffableDataSource<Section, Wrapper>(tableView: tableView) { [weak self] tableView, indexPath, item in
        guard let self = self else { return nil }
        return self.cell(in: tableView, at: indexPath, for: item)
    }

    private var currentCertification: String? {
        return media?.movie?.certification ?? media?.show?.certification
    }

    deinit {
        certificationsRequest?.cancel()
        guideRequest?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Certifications & Parental Guide"

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "CertificationTableViewCell", bundle: nil), forCellReuseIdentifier: "certification")
        tableView.register(ParentalGuideTableViewCell.self, forCellReuseIdentifier: "guide")
        tableView.register(TintedCanvasTableViewCell.self, forCellReuseIdentifier: "text")
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = dataSource

        dataSource.defaultRowAnimation = .none

        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.refresh()
        })

        refresh()
    }

    private func refresh() {
        certificationsRequest?.cancel()
        guideRequest?.cancel()
        requestID = UUID()
        let requestID = requestID
        certificationsLoading = true
        certificationsFailed = false
        guideFailed = false
        let target = ParentalGuideTarget(media: media)
        guideLoading = target != nil && TraktAPIProvider.source.token != nil
        reloadContent()

        let service = TraktAPIService.certifications(type: media?.movie != nil ? .movies : .shows)
        certificationsRequest = TraktAPIProvider.provider.request(service, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
            var certifications = [Certification]()
            var failed = false
            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()
                    certifications = try response.map(CertificationsCounties.self, using: TraktAPIProvider.decoder).us
                } catch {
                    failed = true
                }
            case .failure:
                failed = true
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.requestID == requestID else { return }
                self.certificationsLoading = false
                self.certificationsFailed = failed
                self.certification = certifications.first { $0.name == self.currentCertification }
                self.reloadContent()
            }
        }
        if let target = target, guideLoading {
            guideRequest = TraktAPIProvider.provider.request(.parentalGuide(target: target), callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                var guide: ParentalGuide?
                var failed = false
                switch result {
                case .success(let moyaResponse):
                    do {
                        if moyaResponse.statusCode != 204, moyaResponse.statusCode != 404 {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()
                            guide = try response.map(ParentalGuide.self, using: TraktAPIProvider.decoder)
                        }
                    } catch {
                        failed = true
                    }
                case .failure:
                    failed = true
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.requestID == requestID else { return }
                    self.guideLoading = false
                    self.guideFailed = failed
                    if failed == false {
                        self.guide = guide
                    }
                    self.reloadContent()
                }
            }
        }
    }

    private func reloadContent() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.content])
        snapshot.appendItems([.certification])
        if ParentalGuideTarget(media: media) != nil {
            snapshot.appendItems(ParentalGuide.Category.allCases.map { .guide($0) })
            if let notice = guideNotice {
                snapshot.appendItems([.notice(notice)])
            }
        }
        let existingItems = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existingItems.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private var guideNotice: String? {
        if TraktAPIProvider.source.token == nil {
            return "Sign in to load parental guidance."
        }
        if guideFailed {
            return "Couldn't load parental guidance. Use Refresh to try again."
        }
        if guideLoading == false, guide?.guide.isEmpty != false {
            return "Parental guidance is unavailable for this title."
        }
        return nil
    }

    private func cell(in tableView: UITableView, at indexPath: IndexPath, for item: Wrapper) -> UITableViewCell {
        switch item {
        case .guide(let category):
            let cell = tableView.dequeueReusableCell(withIdentifier: "guide", for: indexPath) as! ParentalGuideTableViewCell
            cell.configure(category: category, severity: guide?.severity(for: category), loading: guideLoading && guide == nil)
            if category == ParentalGuide.Category.allCases.first {
                cell.cardType = .top
            } else if category == ParentalGuide.Category.allCases.last {
                cell.cardType = .bottom
            } else {
                cell.cardType = .middle
            }
            return cell
        case .certification:
            let cell = tableView.dequeueReusableCell(withIdentifier: "certification", for: indexPath) as! CertificationTableViewCell
            cell.certification = certification
            cell.nameLabel.textColor = UIColor(asset: .globalTint)
            if certification == nil {
                let name = currentCertification?.trimmingCharacters(in: .whitespacesAndNewlines)
                cell.nameLabel.text = name?.isEmpty == false ? name : "Not rated"
                cell.metadataLabel.text = name == "NR" ? "Not Rated" : nil
                if certificationsLoading {
                    cell.descriptionLabel.text = "Loading certification details…"
                } else {
                    cell.descriptionLabel.text = certificationsFailed ? "Couldn't load certification details. Use Refresh to try again." : "No certification details available for this title."
                }
            }
            cell.metadataLabel.isHidden = cell.metadataLabel.text?.isEmpty != false
            cell.descriptionLabel.isHidden = cell.descriptionLabel.text?.isEmpty != false
            return cell
        case .notice(let notice):
            let cell = tableView.dequeueReusableCell(withIdentifier: "text", for: indexPath)
            cell.selectionStyle = .none
            var content = UIListContentConfiguration.subtitleCell()
            content.textProperties.numberOfLines = 0
            content.secondaryTextProperties.numberOfLines = 0
            content.text = notice
            content.textProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            return cell
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true)
    }
}
