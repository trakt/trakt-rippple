//
//  CastTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 21/09/2019.
//  Copyright © 2019 Trakt. All rights reserved.
//

import UIKit

protocol CastTableViewCellDelegate: AnyObject {
    func cell(_ cell: CastTableViewCell, action: CastTableViewCell.Action)
}

final class CastTableViewCell: UITableViewCell {
    private enum Layout {
        static let compactCollectionHeight: CGFloat = 135
        static let regularCollectionHeight: CGFloat = 148
    }

    enum Action {
        case showAll
        case showCast(Cast)
        case showCrew(Job)
    }

    enum Section: Int, Hashable, CaseIterable {
        case cast
        case crew
        case placeholder // loading or empty
    }

    enum Item: Hashable {
        case cast(Cast)
        case crew(Job)
        case placeholder(Int)
    }

    weak var delegate: CastTableViewCellDelegate?

    var showsCastEpisodeCount = true {
        didSet {
            updateCollectionViewHeight()
            applySnapshot()
        }
    }

    private var isLoading = true {
        didSet {
            if isLoading == false {
                moreAction.isHidden = false
            }
            applySnapshot()
        }
    }

    private var error: Error? {
        didSet {
            if error == nil {
                moreAction.setTitle("See all", for: .normal)
                moreAction.isHidden = true
                if media.movie != nil {
                    media = media.movie!.mediaModel
                } else {
                    media = media.show!.mediaModel
                }
                applySnapshot()
            } else {
                titleLabel.text = "Error..."
                moreAction.setTitle("Retry", for: .normal)
                moreAction.isHidden = false
                applySnapshot()
            }
        }
    }

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var moreAction: UIButton!

    @IBOutlet var collectionView: UICollectionView!
    @IBOutlet var collectionViewHeightConstraint: NSLayoutConstraint!

    private var people: People? {
        didSet {
            if media.movie != nil, let people = people, let movieCrew = people.crew {
                crew = (movieCrew.directing?.filter { job -> Bool in
                    return job.jobs.contains("Director")
                } ?? [Job]()) + (movieCrew.writing ?? [Job]())
            } else if media.episode != nil, let people = people, let episodeCrew = people.crew {
                crew = (episodeCrew.directing?.filter { job -> Bool in
                    return job.jobs.contains("Director")
                } ?? [Job]())
            } else if media.show != nil, let people = people, let showCrew = people.crew {
                crew = showCrew.createdBy ?? [Job]()
            } else {
                isLoading = false
            }
            applySnapshot()
        }
    }

    private var crew: [Job]? {
        didSet {
            isLoading = false
            applySnapshot()
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false
        collectionView.register(UINib(nibName: "CastCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "cast")
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }
        moreAction.isHidden = true

        maximumContentSizeCategory = .large
        moreAction.maximumContentSizeCategory = .extraExtraLarge
        updateCollectionViewHeight()

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { [weak self] collectionView, indexPath, item in
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cast", for: indexPath) as! CastCollectionViewCell
            guard let self = self else { return cell }

            switch item {
            case .placeholder:
                cell.showsEpisodeCount = false
                cell.avatarImageView.image = nil
                cell.avatarInitialLabel.text = ""
                cell.additionalInfoLabel.text = nil
                cell.additionalInfoLabel.isHidden = true
                cell.asLabel.text = self.isLoading ? "Loading..." : "as Unknown"
                cell.personNameLabel.text = self.isLoading ? "" : "Unknown"
            case .cast(let cast):
                cell.showsEpisodeCount = self.showsCastEpisodeCount
                cell.cast = cast
            case .crew(let job):
                cell.showsEpisodeCount = true
                cell.crew = job
            }
            return cell
        }
        collectionView.dataSource = dataSource
        collectionView.delegate = self
    }

    private func updateCollectionViewHeight() {
        guard let collectionViewHeightConstraint = collectionViewHeightConstraint else { return }
        collectionViewHeightConstraint.constant = showsCastEpisodeCount ? Layout.regularCollectionHeight : Layout.compactCollectionHeight
        collectionView?.collectionViewLayout.invalidateLayout()
        invalidateIntrinsicContentSize()
    }

    var media: MediaModel! {
        didSet {
            switch media! {
            case .movie(let movie):
                TraktAPIProvider.provider.request(TraktAPIService.peopleMovie(id: movie.identifiers.trakt!),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.people = people
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                }
            case .show(let show):
                TraktAPIProvider.provider.request(TraktAPIService.peopleShow(id: show.identifiers.trakt!, extended: nil),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.people = people
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                }
            case .episode(let episode, let show):
                TraktAPIProvider.provider.request(TraktAPIService.peopleEpisode(id: show.identifiers.trakt!, season: episode.season, episode: episode.number, extended: nil),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.people = people
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                }
            case .season(let season, let show):
                TraktAPIProvider.provider.request(TraktAPIService.peopleSeason(id: show.identifiers.trakt!, season: season.number, extended: nil),
                                                  callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
                    guard let self = self else { return }
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()

                            let people = try response.map(People.self, using: TraktAPIProvider.decoder)

                            DispatchQueue.main.async {
                                self.people = people
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.error = error
                            }
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.error = error
                        }
                    }
                }
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }
            applySnapshot()
        }
    }

    private func applySnapshot() {
        guard dataSource != nil else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()

        if isLoading {
            snapshot.appendSections([.placeholder])
            snapshot.appendItems([.placeholder(0), .placeholder(1), .placeholder(2), .placeholder(3)], toSection: .placeholder)
            dataSource.apply(snapshot, animatingDifferences: true)
            return
        }

        // Error state shows placeholders and enables retry
        if error != nil {
            snapshot.appendSections([.placeholder])
            snapshot.appendItems([.placeholder(0), .placeholder(1), .placeholder(2), .placeholder(3)], toSection: .placeholder)
            dataSource.apply(snapshot, animatingDifferences: true)
            return
        }

        // Build sections based on media type and available data
        var hasCast = false
        var hasCrew = false
        if let people = people, !people.cast.isEmpty { hasCast = true }
        if let crew = crew, !crew.isEmpty { hasCrew = true }

        if !hasCast, !hasCrew {
            snapshot.appendSections([.placeholder])
            snapshot.appendItems([.placeholder(0), .placeholder(1), .placeholder(2), .placeholder(3)], toSection: .placeholder)
            dataSource.apply(snapshot, animatingDifferences: true)
            return
        }

        if hasCast { snapshot.appendSections([.cast]) }
        if hasCrew { snapshot.appendSections([.crew]) }

        if hasCast, let people = people {
            let maxCount = min(people.cast.count, 6)
            let items: [Item] = people.cast.prefix(maxCount).map { .cast($0) }
            snapshot.appendItems(items, toSection: .cast)
        }
        if hasCrew, let crew = crew {
            let items: [Item] = crew.map { .crew($0) }
            snapshot.appendItems(items, toSection: .crew)
        }

        dataSource.apply(snapshot, animatingDifferences: true)
    }

    @IBAction func showAll(_ sender: Any) {
        if error != nil { error = nil }
        if isLoading == true { return }
        guard let delegate = delegate else { return }
        delegate.cell(self, action: .showAll)
    }

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!
}

extension CastTableViewCell: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard let indexPath = indexPaths.first else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? CastCollectionViewCell {
            if cell.avatarImageView.image == nil { return nil }
            guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
            let person: Person? = {
                switch item {
                case .cast(let cast): return cast.person
                case .crew(let job): return job.person
                case .placeholder: return nil
                }
            }()
            if person == nil { return nil }

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

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? CastCollectionViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        if let cell = collectionView.cellForItem(at: indexPath) as? CastCollectionViewCell {
            return UITargetedPreview(view: cell.avatarContainer, parameters: UIPreviewParameters())
        }
        return nil
    }

    func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        guard let delegate = delegate else { return }

        if let item = dataSource.itemIdentifier(for: indexPath) {
            switch item {
            case .cast(let cast):
                delegate.cell(self, action: .showCast(cast))
            case .crew(let job):
                delegate.cell(self, action: .showCrew(job))
            case .placeholder:
                break
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isLoading == true { return }
        guard let delegate = delegate else { return }
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .cast(let cast):
            delegate.cell(self, action: .showCast(cast))
        case .crew(let job):
            delegate.cell(self, action: .showCrew(job))
        case .placeholder:
            return
        }
    }
}
