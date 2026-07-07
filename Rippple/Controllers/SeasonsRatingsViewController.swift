//
//  SeasonsRatingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/12/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Receiver
import UIKit

final class SeasonsRatingsViewController: UIViewController {
    // Filters
    @IBOutlet var filterButtonItem: UIBarButtonItem!
    @IBOutlet var gridContainerView: UIView!

    private var currentFilter = SeasonsRatingsFilter.trakt {
        didSet {
            UserDefaults.standard.set(currentFilter.rawValue, forKey: "SeasonsRatingsViewController.currentFilter")
            UserDefaults.standard.synchronize()

            applyCurrentFilter()
            reloadGridData()
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
    private var gridView: SeasonsRatingsGridView?

    var media: MediaModel! {
        didSet {
            if media.show == nil { fatalError("Not okay") }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [navigationItem.rightBarButtonItems!.first!,
                                              .flexibleSpace(),
                                              navigationItem.rightBarButtonItems!.last!]

        configureGridView()

        if let filter = SeasonsRatingsFilter(rawValue: UserDefaults.standard.integer(forKey: "SeasonsRatingsViewController.currentFilter")) {
            currentFilter = filter
        } else {
            applyCurrentFilter()
        }

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
                    self.reloadGridData()
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
                self.reloadGridData()
            }
        }
    }

    private var seasons: [Season]? {
        didSet {
            reloadGridData()
            scrollToInitialMedia()
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

    private func configureGridView() {
        let gridView = SeasonsRatingsGridView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.delegate = self

        gridContainerView.addSubview(gridView)

        NSLayoutConstraint.activate([
            gridView.leadingAnchor.constraint(equalTo: gridContainerView.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: gridContainerView.trailingAnchor),
            gridView.topAnchor.constraint(equalTo: gridContainerView.topAnchor),
            gridView.bottomAnchor.constraint(equalTo: gridContainerView.bottomAnchor)
        ])

        self.gridView = gridView
        tabBarController?.setContentScrollView(gridView.primaryScrollView)
    }

    private func applyCurrentFilter() {
        navigationItem.style = .browser

        filterButtonItem.image = UIImage(systemName: "line.horizontal.3.decrease")
        switch currentFilter {
        case .trakt:
            navigationItem.title = "Trakt Ratings"
        case .yours:
            navigationItem.title = "Your Ratings"
        }
    }

    private func reloadGridData() {
        guard isViewLoaded else { return }
        gridView?.adapter = makeGridAdapter()
    }

    private func makeGridAdapter() -> SeasonsRatingsGridAdapter? {
        guard let show = media.show,
              let seasons = seasons else { return nil }

        return SeasonsRatingsGridAdapter(show: show,
                                         seasons: seasons,
                                         filter: currentFilter,
                                         progress: progress)
    }

    private func scrollToInitialMedia() {
        guard isViewLoaded else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let gridView = self.gridView else { return }

            if case .episode(let episode, _) = self.media {
                gridView.scrollToSeason(number: episode.season,
                                        episodeNumber: episode.number,
                                        animated: true)
            }

            if case .season(let season, _) = self.media {
                gridView.scrollToSeason(number: season.number,
                                        episodeNumber: nil,
                                        animated: true)
            }
        }
    }
}

extension SeasonsRatingsViewController: SeasonsRatingsGridViewDelegate {
    func seasonsRatingsGridView(_ gridView: SeasonsRatingsGridView,
                                didSelect episode: Episode) {
        performSegue(withIdentifier: "media", sender: episode.mediaModel(given: media.show!))
    }

    func seasonsRatingsGridView(_ gridView: SeasonsRatingsGridView,
                                contextMenuConfigurationFor episode: Episode,
                                indexPath: IndexPath) -> UIContextMenuConfiguration? {
        guard let show = media.show else { return nil }
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
}
