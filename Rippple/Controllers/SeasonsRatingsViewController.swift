//
//  SeasonsRatingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/12/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import CoreMedia
import Receiver
import SpreadsheetView
import UIKit

final class SeasonsRatingsViewController: UIViewController, SpreadsheetViewDataSource, SpreadsheetViewDelegate {
    private enum Filter: Int {
        case trakt
        case yours
    }

    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    private var currentFilter = Filter.trakt {
        didSet {
            UserDefaults.standard.set(currentFilter.rawValue, forKey: "SeasonsRatingsViewController.currentFilter")
            UserDefaults.standard.synchronize()

            navigationItem.style = .browser

            filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            switch currentFilter {
            case .trakt:
                navigationItem.title = "Trakt Ratings"
                filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
            case .yours:
                navigationItem.title = "Your Ratings"
            }

            spreadsheetView.reloadData()
        }
    }

    @IBAction func currentFilterChanged() {
        if currentFilter == .trakt {
            currentFilter = .yours
        } else {
            currentFilter = .trakt
        }
    }

    private let disposeBag = DisposeBag()

    var media: MediaModel! {
        didSet {
            if media.show == nil { fatalError("Not okay") }
        }
    }

    @IBOutlet var spreadsheetView: SpreadsheetView!

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItems!.first!,
                                              .flexibleSpace(),
                                              navigationItem.rightBarButtonItems!.last!]
        tabBarController?.setContentScrollView(spreadsheetView.scrollView)

        if let filter = Filter(rawValue: UserDefaults.standard.integer(forKey: "SeasonsRatingsViewController.currentFilter")) {
            currentFilter = filter
        }

        spreadsheetView.dataSource = self
        spreadsheetView.delegate = self

        spreadsheetView.contentInset = UIEdgeInsets(top: 0,
                                                    left: 12,
                                                    bottom: 0,
                                                    right: 0)

        spreadsheetView.intercellSpacing = CGSize(width: 4, height: 4)
        spreadsheetView.gridStyle = .none
        spreadsheetView.showsVerticalScrollIndicator = false
        spreadsheetView.showsHorizontalScrollIndicator = false

        spreadsheetView.backgroundColor = .systemBackground

        spreadsheetView.register(SeasonsRatingsHeaderCell.self,
                                 forCellWithReuseIdentifier: String(describing: SeasonsRatingsHeaderCell.self))
        spreadsheetView.register(SeasonsRatingsContentCell.self,
                                 forCellWithReuseIdentifier: String(describing: SeasonsRatingsContentCell.self))
        spreadsheetView.register(EmptyContentCell.self,
                                 forCellWithReuseIdentifier: String(describing: EmptyContentCell.self))

        fetch()

        commandReceiver.listen { [weak self] keyCommand in
            guard let self = self else { return }
            if keyCommand.input == "R", keyCommand.modifierFlags == .command {
                self.media.forceProgress { _ in }
            }
        }.disposed(by: disposeBag)

        onProgressCacheChangedReceiver.listen { [weak self] progress in
            guard let self = self else { return }
            if progress.show == media.show {
                self.progress = progress.showProgress
            }
        }.disposed(by: disposeBag)

        media.progress { [weak self] progress in
            guard let self = self else { return }
            self.progress = progress
        }

        RatingsManager.shared.onRatedItemsChangedReceiver.hotOnly().listen { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.currentFilter == .yours {
                    self.spreadsheetView.reloadData()
                }
            }
        }.disposed(by: disposeBag)
    }

    func fetch() {
        guard let showId = media.show!.identifiers.trakt else { return }

        TraktAPIProvider.provider.request(.seasons(id: showId), callbackQueue: DispatchQueue.global(qos: .userInitiated)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let seasons = try response.map([Season].self, using: TraktAPIProvider.decoder).filter { $0.number != 0 }

                    DispatchQueue.main.async {
                        self.seasons = seasons
                    }
                } catch {
                    print("Seasons request JSON mapping failed! \(error)")
                }
            case .failure(let error):
                print("Seasons request failure \(error)")
            }
        }
    }

    private var progress: ShowProgress? {
        didSet {
            DispatchQueue.main.async {
                self.spreadsheetView.reloadData()
            }
        }
    }

    private var seasons: [Season]? {
        didSet {
            spreadsheetView.reloadData()
            if case .episode(let episode, _) = media {
                spreadsheetView.scrollToItem(at: IndexPath(row: episode.number, column: episode.season),
                                             at: [.centeredVertically, .centeredHorizontally],
                                             animated: false)
            }
            if case .season(let season, _) = media {
                spreadsheetView.scrollToItem(at: IndexPath(row: 0, column: season.number),
                                             at: [.centeredVertically, .centeredHorizontally],
                                             animated: false)
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController {
            if let media = sender as? MediaModel {
                mediaViewController.media = media
            }
        }
        if let navigationController = segue.destination as? UINavigationController,
           let legendViewController = navigationController.viewControllers.first as? SeasonsRatingsLegendViewController {
            legendViewController.media = media
            legendViewController.seasons = seasons
        }
    }

    // Delegate

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row == 0 { return }
        if indexPath.column == 0 { return }

        guard let seasons = seasons else { return }
        guard let episodes = seasons[indexPath.column - 1].episodes else { return }
        if episodes.count < indexPath.row { return }

        let episode = episodes[indexPath.row - 1]

        performSegue(withIdentifier: "media", sender: episode.mediaModel(given: media.show!))
    }

    // Datasource

    func numberOfColumns(in spreadsheetView: SpreadsheetView) -> Int {
        guard let seasons = seasons else { return 0 }
        return seasons.count + 1
    }

    func numberOfRows(in spreadsheetView: SpreadsheetView) -> Int {
        guard let seasons = seasons else { return 0 }
        var max = 0
        for season in seasons {
            if let count = season.episodes?.count, count > max {
                max = count
            }
        }
        return max + 1
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, widthForColumn column: Int) -> CGFloat {
        return 60
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, heightForRow row: Int) -> CGFloat {
        return 40
    }

    func frozenColumns(in spreadsheetView: SpreadsheetView) -> Int {
        if seasons == nil { return 0 }
        return 1
    }

    func frozenRows(in spreadsheetView: SpreadsheetView) -> Int {
        if seasons == nil { return 0 }
        return 1
    }

    func spreadsheetView(_ spreadsheetView: SpreadsheetView, cellForItemAt indexPath: IndexPath) -> Cell? {
        if indexPath.row == 0, indexPath.column == 0 {
            return spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: EmptyContentCell.self),
                                                       for: indexPath)
        }
        if indexPath.row == 0 {
            let cell = spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: SeasonsRatingsHeaderCell.self),
                                                           for: indexPath) as! SeasonsRatingsHeaderCell
            cell.label.text = "S\(String(format: "%02d", indexPath.column))"
            return cell
        }
        if indexPath.column == 0 {
            let cell = spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: SeasonsRatingsHeaderCell.self),
                                                           for: indexPath) as! SeasonsRatingsHeaderCell
            cell.label.text = "E\(String(format: "%02d", indexPath.row))"
            return cell
        }

        guard let seasons = seasons else {
            return spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: EmptyContentCell.self), for: indexPath)
        }
        guard let episodes = seasons[indexPath.column - 1].episodes else {
            return spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: EmptyContentCell.self), for: indexPath)
        }
        if episodes.count < indexPath.row {
            return spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: EmptyContentCell.self), for: indexPath)
        }

        let episode = episodes[indexPath.row - 1]

        let cell = spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: SeasonsRatingsContentCell.self), for: indexPath) as! SeasonsRatingsContentCell

        if currentFilter == .trakt {
            guard let r = episode.rating else {
                return spreadsheetView.dequeueReusableCell(withReuseIdentifier: String(describing: EmptyContentCell.self), for: indexPath)
            }
            let rating = round(r * 10) / 10.0

            cell.label.text = String(format: "%.1f", rating)
            if rating < 4 {
                cell.label.textColor = .white
                cell.label.backgroundColor = .systemRed
            } else if rating < 6 {
                cell.label.textColor = .white
                cell.label.backgroundColor = .systemOrange
            } else if rating < 8 {
                cell.label.textColor = .white
                cell.label.backgroundColor = .systemYellow
            } else {
                cell.label.textColor = .white
                cell.label.backgroundColor = .systemGreen
            }

            cell.progress.alpha = 0.0
            if let date = episode.firstAired { // have a date -> check the date
                if date > Date.now {
                    cell.label.text = "..."
                    cell.label.backgroundColor = .lightGray
                } else {
                    if let progress = progress {
                        cell.progress.alpha = 1.0
                        cell.progress.progress = 0.0
                        for season in progress.seasons where season.number == episodes[indexPath.row - 1].season {
                            for episode in season.episodes where episode.number == episodes[indexPath.row - 1].number && episode.completed {
                                cell.progress.progress = 1.0
                            }
                        }
                    }
                }
            } else { // no date
                cell.label.text = "..."
                cell.label.backgroundColor = .lightGray
            }
        } else {
            cell.label.textColor = .white

            if let ownRating = episode.userRating(for: media.show!) {
                cell.label.text = "\(ownRating)"
                if ownRating < 4 {
                    cell.label.backgroundColor = .systemRed
                } else if ownRating < 6 {
                    cell.label.backgroundColor = .systemOrange
                } else if ownRating < 8 {
                    cell.label.backgroundColor = .systemYellow
                } else {
                    cell.label.backgroundColor = .systemGreen
                }
            } else {
                cell.label.text = "?"
                cell.label.backgroundColor = .lightGray
            }

            cell.progress.alpha = 0.0
            if let date = episode.firstAired { // have a date -> check the date
                if date > Date.now {
                    cell.label.text = "..."
                    cell.label.backgroundColor = .lightGray
                } else {
                    if let progress = progress {
                        cell.progress.alpha = 1.0
                        cell.progress.progress = 0.0
                        for season in progress.seasons where season.number == episodes[indexPath.row - 1].season {
                            for episode in season.episodes where episode.number == episodes[indexPath.row - 1].number && episode.completed {
                                cell.progress.progress = 1.0
                            }
                        }
                    }
                }
            } else { // no date
                cell.label.text = "..."
                cell.label.backgroundColor = .lightGray
            }
        }

        if let watchingItem = WatchingManager.shared.watchingItem,
           watchingItem.show == media.show,
           watchingItem.episode == episode {
            cell.progress.progress = Float(WatchingManager.shared.progress)
        }

        let interaction = UIContextMenuInteraction(delegate: self)
        cell.addInteraction(interaction)

        return cell
    }
}

extension SeasonsRatingsViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let rightLocation = interaction.view?.convert(location,
                                                            to: spreadsheetView) else { return nil }
        guard let indexPath = spreadsheetView.indexPathForItem(at: rightLocation) else { return nil }

        if indexPath.row == 0 { return nil }
        if indexPath.column == 0 { return nil }

        guard let show = media.show else { return nil }
        guard let seasons = seasons else { return nil }
        guard let episodes = seasons[indexPath.column - 1].episodes else { return nil }
        if episodes.count < indexPath.row { return nil }

        let episode = episodes[indexPath.row - 1]
        let episodeMedia = episode.mediaModel(given: show)

        return UIContextMenuConfiguration(identifier: indexPath as NSCopying,
                                          previewProvider: {
                                              let mediaPreviewViewController = UIStoryboard(name: "EpisodePreview", bundle: nil).instantiateInitialViewController() as! EpisodePreviewViewController

                                              mediaPreviewViewController.media = episodeMedia
                                              mediaPreviewViewController.preferredContentSize = CGSize(width: 500,
                                                                                                       height: 500 * 0.5)
                                              return mediaPreviewViewController
                                          }, actionProvider: { _ -> UIMenu? in
                                              return UIMenu(title: episodeMedia.mediaTitle,
                                                            children: episodeMedia.rateMenu.children)
                                          })
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration, highlightPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        guard let cell = spreadsheetView.cellForItem(at: indexPath) as? SeasonsRatingsContentCell else { return nil }
        cell.layer.zPosition = 100
        return UITargetedPreview(view: cell.label, parameters: UIPreviewParameters())
    }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configuration: UIContextMenuConfiguration, dismissalPreviewForItemWithIdentifier identifier: any NSCopying) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath else { return nil }
        guard let cell = spreadsheetView.cellForItem(at: indexPath) as? SeasonsRatingsContentCell else { return nil }
        cell.layer.zPosition = 0
        return UITargetedPreview(view: cell.label, parameters: UIPreviewParameters())
    }
}

final class SeasonsRatingsHeaderCell: Cell {
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.frame = bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.font = UIFont.preferredFont(forTextStyle: .subheadline,
                                          compatibleWith: nil)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.backgroundColor = .systemBackground

        contentView.backgroundColor = .systemBackground
        contentView.addSubview(label)

//        contentView.layer.cornerRadius = 6
//        contentView.layer.cornerCurve = .continuous
//
//        contentView.layer.borderColor = UIColor.init(asset: .shadow).cgColor
//        contentView.layer.borderWidth = 0.5
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

final class SeasonsRatingsContentCell: Cell {
    let label = UILabel()
    let progress = UIProgressView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        label.frame = bounds // .applying(CGAffineTransform(scaleX: 0.8, y: 0.8))
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.adjustsFontForContentSizeCategory = true
        label.maximumContentSizeCategory = .extraExtraExtraLarge
        label.font = UIFont.preferredFont(forTextStyle: .headline,
                                          compatibleWith: nil)
        label.textAlignment = .center

        label.layer.cornerRadius = ViewRadius.medium.rawValue
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true

        label.layer.borderColor = UIColor(asset: .shadow).cgColor
        label.layer.borderWidth = 0.5

        contentView.backgroundColor = .clear
        contentView.addSubview(label)

        progress.frame = CGRect(x: 0.0,
                                y: frame.height - 3.0,
                                width: 0.0,
                                height: 3.0)
        progress.progress = 0.8
        progress.progressTintColor = .white
        progress.trackTintColor = .white.withAlphaComponent(0.3)

        progress.translatesAutoresizingMaskIntoConstraints = false
        label.addSubview(progress)

        NSLayoutConstraint.activate([
            progress.leadingAnchor.constraint(equalTo: label.leadingAnchor, constant: 5),
            progress.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: -5),
            progress.bottomAnchor.constraint(equalTo: label.bottomAnchor, constant: -3),
            progress.heightAnchor.constraint(equalToConstant: 3.0)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

final class EmptyContentCell: Cell {
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemBackground

        maximumContentSizeCategory = .extraExtraExtraLarge
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
