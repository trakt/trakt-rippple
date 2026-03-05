//
//  SeasonsRatingsLegendViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 09/01/2022.
//  Copyright © 2022 Trakt. All rights reserved.
//

import UIKit

final class SeasonsRatingsLegendViewController: UITableViewController {

    var media: MediaModel! {
        didSet {
            if media.show == nil { fatalError("Not okay") }
            tableView.reloadData()
        }
    }
    var seasons: [Season]? {
        didSet {
            tableView.reloadData()
        }
    }

    @IBOutlet var ratingChartLabels: [UILabel]!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let sheet = navigationController?.sheetPresentationController {
            sheet.detents = [.medium()]
        }

        for ratingChartLabel in ratingChartLabels {
            ratingChartLabel.layer.cornerRadius = ViewRadius.medium.rawValue
            ratingChartLabel.layer.cornerCurve = .continuous
            ratingChartLabel.clipsToBounds = true
            ratingChartLabel.layer.borderColor = ratingChartLabel.backgroundColor?.darker().cgColor
            ratingChartLabel.layer.borderWidth = 0.5
            ratingChartLabel.maximumContentSizeCategory = .extraExtraExtraLarge
        }
    }

    @IBAction func done(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            guard let seasons = seasons else { return nil }
            var episodesCount = 0
            var ratingsCount = 0

            for season in seasons {
                guard let episodes = season.episodes else { continue }
                for episode in episodes where episode.firstAired != nil && episode.firstAired! < Date.now {
                    episodesCount += 1
                    ratingsCount += episode.votes ?? 0
                }
            }
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            if let firstEpisode = seasons.first?.episodes?.first?.firstAired, let lastEpisode = seasons.last?.episodes?.last?.firstAired {
                return "Based on \(numberFormatter.string(from: NSNumber(value: ratingsCount))!) rating\(ratingsCount > 1 ? "s": "") on a total of \(numberFormatter.string(from: NSNumber(value: episodesCount))!) episode\(episodesCount > 1 ? "s": "") that aired from \(Calendar.current.dateComponents([.year], from: firstEpisode).year!) to \(Calendar.current.dateComponents([.year], from: lastEpisode).year!)."
            }
            return "Based on \(numberFormatter.string(from: NSNumber(value: ratingsCount))!) rating\(ratingsCount > 1 ? "s": "") on a total of \(numberFormatter.string(from: NSNumber(value: episodesCount))!) episode\(episodesCount > 1 ? "s": "")."
        }
        return nil
    }
}
