//
//  WhereToWatchTableViewCell.swift
//  Rippple
//
//  Created by Kevin Cador on 27/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

import Receiver

struct ProviderType: Identifiable, Equatable, Hashable, Codable {
    var id: Int {
        return identifier ?? UUID().hashValue
    }

    static func == (lhs: ProviderType, rhs: ProviderType) -> Bool {
        return lhs.identifier == rhs.identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }

    var priority: Int?
    let logo: String?
    let identifier: Int?
    let name: String?
    var type: [String]?
}

final class WhereToWatchTableViewCell: UITableViewCell, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!

    private let disposeBag = DisposeBag()

    private var loading = true
    private var error = false
    private var empty: Bool {
        if loading == true { return false }
        if error == true { return false }
        return self.data.isEmpty
    }

    private func provider(in country: Country) -> Providers? {
        guard let result = self.result else { return nil }
        if let results = result.results {
            switch country {
            case .BE:
                if let provider = results.BE { return provider }
            case .US:
                if let provider = results.US { return provider }
            case .AR:
                if let provider = results.AR { return provider }
            case .AT:
                if let provider = results.AT { return provider }
            case .AU:
                if let provider = results.AU { return provider }
            case .BR:
                if let provider = results.BR { return provider }
            case .CA:
                if let provider = results.CA { return provider }
            case .CH:
                if let provider = results.CH { return provider }
            case .CL:
                if let provider = results.CL { return provider }
            case .CO:
                if let provider = results.CO { return provider }
            case .CZ:
                if let provider = results.CZ { return provider }
            case .DE:
                if let provider = results.DE { return provider }
            case .DK:
                if let provider = results.DK { return provider }
            case .EC:
                if let provider = results.EC { return provider }
            case .EE:
                if let provider = results.EE { return provider }
            case .ES:
                if let provider = results.ES { return provider }
            case .FI:
                if let provider = results.FI { return provider }
            case .FR:
                if let provider = results.FR { return provider }
            case .GB:
                if let provider = results.GB { return provider }
            case .GR:
                if let provider = results.GR { return provider }
            case .HU:
                if let provider = results.HU { return provider }
            case .ID:
                if let provider = results.ID { return provider }
            case .IE:
                if let provider = results.IE { return provider }
            case .IN:
                if let provider = results.IN { return provider }
            case .IT:
                if let provider = results.IT { return provider }
            case .JP:
                if let provider = results.JP { return provider }
            case .KR:
                if let provider = results.KR { return provider }
            case .LT:
                if let provider = results.LT { return provider }
            case .LV:
                if let provider = results.LV { return provider }
            case .MX:
                if let provider = results.MX { return provider }
            case .MY:
                if let provider = results.MY { return provider }
            case .NL:
                if let provider = results.NL { return provider }
            case .NO:
                if let provider = results.NO { return provider }
            case .NZ:
                if let provider = results.NZ { return provider }
            case .PE:
                if let provider = results.PE { return provider }
            case .PH:
                if let provider = results.PH { return provider }
            case .PL:
                if let provider = results.PL { return provider }
            case .PT:
                if let provider = results.PT { return provider }
            case .RO:
                if let provider = results.RO { return provider }
            case .RU:
                if let provider = results.RU { return provider }
            case .SE:
                if let provider = results.SE { return provider }
            case .SG:
                if let provider = results.SG { return provider }
            case .TH:
                if let provider = results.TH { return provider }
            case .TR:
                if let provider = results.TR { return provider }
            case .VE:
                if let provider = results.VE { return provider }
            case .ZA:
                if let provider = results.ZA { return provider }
            case .BG:
                if let provider = results.BG { return provider }
            case .BO:
                if let provider = results.BO { return provider }
            case .CR:
                if let provider = results.CR { return provider }
            case .GT:
                if let provider = results.GT { return provider }
            case .HK:
                if let provider = results.HK { return provider }
            case .HN:
                if let provider = results.HN { return provider }
            case .HR:
                if let provider = results.HR { return provider }
            case .IS:
                if let provider = results.IS { return provider }
            case .MD:
                if let provider = results.MD { return provider }
            case .PY:
                if let provider = results.PY { return provider }
            case .SK:
                if let provider = results.SK { return provider }
            case .TW:
                if let provider = results.TW { return provider }
            case .UY:
                if let provider = results.UY { return provider }
            case .AD:
                if let provider = results.AD { return provider }
            case .AE:
                if let provider = results.AE { return provider }
            case .AG:
                if let provider = results.AG { return provider }
            case .AL:
                if let provider = results.AL { return provider }
            case .AO:
                if let provider = results.AO { return provider }
            case .AZ:
                if let provider = results.AZ { return provider }
            case .BA:
                if let provider = results.BA { return provider }
            case .BB:
                if let provider = results.BB { return provider }
            case .BF:
                if let provider = results.BF { return provider }
            case .BH:
                if let provider = results.BH { return provider }
            case .BM:
                if let provider = results.BM { return provider }
            case .BS:
                if let provider = results.BS { return provider }
            case .BY:
                if let provider = results.BY { return provider }
            case .BZ:
                if let provider = results.BZ { return provider }
            case .CD:
                if let provider = results.CD { return provider }
            case .CI:
                if let provider = results.CI { return provider }
            case .CM:
                if let provider = results.CM { return provider }
            case .CU:
                if let provider = results.CU { return provider }
            case .CV:
                if let provider = results.CV { return provider }
            case .CY:
                if let provider = results.CY { return provider }
            case .DO:
                if let provider = results.DO { return provider }
            case .DZ:
                if let provider = results.DZ { return provider }
            case .EG:
                if let provider = results.UY { return provider }
            case .FJ:
                if let provider = results.FJ { return provider }
            case .GF:
                if let provider = results.GF { return provider }
            case .GH:
                if let provider = results.GH { return provider }
            case .GI:
                if let provider = results.GI { return provider }
            case .GP:
                if let provider = results.GP { return provider }
            case .GQ:
                if let provider = results.GQ { return provider }
            case .GY:
                if let provider = results.GY { return provider }
            case .IL:
                if let provider = results.IL { return provider }
            case .IQ:
                if let provider = results.IQ { return provider }
            case .JM:
                if let provider = results.JM { return provider }
            case .JO:
                if let provider = results.JO { return provider }
            case .KE:
                if let provider = results.KE { return provider }
            case .KW:
                if let provider = results.KW { return provider }
            case .LB:
                if let provider = results.LB { return provider }
            case .LC:
                if let provider = results.LC { return provider }
            case .LI:
                if let provider = results.LI { return provider }
            case .LU:
                if let provider = results.LU { return provider }
            case .LY:
                if let provider = results.LY { return provider }
            case .MA:
                if let provider = results.MA { return provider }
            case .MC:
                if let provider = results.MC { return provider }
            case .ME:
                if let provider = results.ME { return provider }
            case .MG:
                if let provider = results.MG { return provider }
            case .MK:
                if let provider = results.MK { return provider }
            case .ML:
                if let provider = results.ML { return provider }
            case .MT:
                if let provider = results.MT { return provider }
            case .MU:
                if let provider = results.MU { return provider }
            case .MW:
                if let provider = results.MW { return provider }
            case .MZ:
                if let provider = results.MZ { return provider }
            case .NE:
                if let provider = results.NE { return provider }
            case .NG:
                if let provider = results.NG { return provider }
            case .NI:
                if let provider = results.NI { return provider }
            case .OM:
                if let provider = results.OM { return provider }
            case .PA:
                if let provider = results.PA { return provider }
            case .PF:
                if let provider = results.PF { return provider }
            case .PG:
                if let provider = results.PG { return provider }
            case .PK:
                if let provider = results.PK { return provider }
            case .PS:
                if let provider = results.PS { return provider }
            case .QA:
                if let provider = results.QA { return provider }
            case .RS:
                if let provider = results.RS { return provider }
            case .SA:
                if let provider = results.SA { return provider }
            case .SC:
                if let provider = results.SC { return provider }
            case .SI:
                if let provider = results.SI { return provider }
            case .SM:
                if let provider = results.SM { return provider }
            case .SN:
                if let provider = results.SN { return provider }
            case .SV:
                if let provider = results.SV { return provider }
            case .TC:
                if let provider = results.TC { return provider }
            case .TD:
                if let provider = results.TD { return provider }
            case .TN:
                if let provider = results.TN { return provider }
            case .TT:
                if let provider = results.TT { return provider }
            case .TZ:
                if let provider = results.TZ { return provider }
            case .UA:
                if let provider = results.UA { return provider }
            case .UG:
                if let provider = results.UG { return provider }
            case .VA:
                if let provider = results.VA { return provider }
            case .XK:
                if let provider = results.XK { return provider }
            case .YE:
                if let provider = results.YE { return provider }
            case .ZM:
                if let provider = results.ZM { return provider }
            case .ZW:
                if let provider = results.ZW { return provider }
            }
        }
        return nil
    }

    private var link: URL? {
        if let providerInCountry = provider(in: CountryManager.userCountry) {
            if let linkString = providerInCountry.link {
                if let url = URL(string: linkString) {
                    return url
                }
            }
        }
        return nil
    }

    private var result: ProvidersResult? {
        didSet {
            if CountryManager.shared.disabled {
                isHidden = true
                return
            }
            var data = [ProviderType]()
            if let providerInCountry = provider(in: CountryManager.userCountry) {
                if let rent = providerInCountry.rent {
                    for provider in rent {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Rent")
                        } else {
                            data.append(ProviderType(priority: provider.priority,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Rent"]))
                        }
                    }
                }
                if let buy = providerInCountry.buy {
                    for provider in buy {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Buy")
                        } else {
                            data.append(ProviderType(priority: provider.priority,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Buy"]))
                        }
                    }
                }
                if let flatrate = providerInCountry.flatrate {
                    for provider in flatrate {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Stream")
                        } else {
                            data.append(ProviderType(priority: provider.priority ?? Int.max,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Stream"]))
                        }
                    }
                }
                if let free = providerInCountry.free {
                    for provider in free {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Free")
                        } else {
                            data.append(ProviderType(priority: provider.priority ?? Int.max,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Free"]))
                        }
                    }
                }
                if let ads = providerInCountry.ads {
                    for provider in ads {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Ads")
                        } else {
                            data.append(ProviderType(priority: provider.priority,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Ads"]))
                        }
                    }
                }
                if let none = providerInCountry.none {
                    for provider in none {
                        if let index = data.firstIndex(where: { type -> Bool in
                            return type.identifier == provider.identifier
                        }) {
                            data[index].priority = min(data[index].priority ?? Int.max, provider.priority ?? Int.max)
                            data[index].type?.append("Unknown")
                        } else {
                            data.append(ProviderType(priority: provider.priority,
                                                     logo: provider.logo,
                                                     identifier: provider.identifier,
                                                     name: provider.name,
                                                     type: ["Unknown"]))
                        }
                    }
                }
            }
            if CountryManager.shared.favoritesOnly {
                let favorites = CountryManager.shared.favoriteProviders
                data = data.filter({ provider in
                    favorites.contains(where: { $0 == provider })
                })
            }
            self.data = data.sorted { $0.computedPriority < $1.computedPriority }
            collectionView.reloadData()
        }
    }

    private var data = [ProviderType]()

    var media: MediaModel! {
        didSet {
            guard let media = media else { return }
            switch media {
            case .movie(let movie):
                loadMovie(movie: movie)
            case .show(let show):
                loadShow(show: show)
            case .episode(let episode, let show):
                load(show: show, season: episode.season)
            case .season(let season, let show):
                load(show: show, season: season.number)
            case .list:
                fatalError()
            case .showProgress(let show, let progress):
                if let nextEpisodeToWatch = progress.nextEpisodeToWatch {
                    load(show: show, season: nextEpisodeToWatch.season)
                } else {
                    loadShow(show: show)
                }
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        collectionView.allowsFocus = false

        collectionView.register(UINib(nibName: "WhereToWatchCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "where to watch")
        collectionView.register(UINib(nibName: "WhereToWatchHeaderCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "header")
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }

        onCountryChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            let result = self.result
            self.result = result
        }.disposed(by: disposeBag)

        minimumContentSizeCategory = .large
        maximumContentSizeCategory = .extraExtraLarge
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        return data.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "header", for: indexPath) as! WhereToWatchHeaderCollectionViewCell
            if loading {
                cell.info.text = "Loading..."
            } else if error {
                cell.info.text = "Oops, an error occurred!"
            } else if empty {
                cell.info.text = "JustWatch doesn't know yet."
            } else {
                cell.info.text = "Provided by JustWatch via TMDb."
            }
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "where to watch", for: indexPath) as! WhereToWatchCollectionViewCell

            cell.provider = data[indexPath.row]

            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let link = link else { return }
        if indexPath.section == 1 {
            UIApplication.shared.open(link,
                                      options: [:],
                                      completionHandler: nil)
        }
    }
}

extension WhereToWatchTableViewCell {
    private func loadShow(show: Show) {
        guard let tmdbId = show.identifiers.tmdb else {
            loading = false
            error = true
            collectionView.reloadData()
            return
        }
        loading = true
        error = false
        collectionView.reloadData()
        TmdbAPIProvider.provider.request(TmdbAPIService.showProviders(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map(ProvidersResult.self, using: TmdbAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = false
                        self.result = results
                    }
                } catch {
                    print("TmdbAPIService.showProviders Error: \(error)")
                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = true
                        self.collectionView.reloadData()
                    }
                }
            case let .failure(error):
                print("TmdbAPIService.showProviders Failure: \(error)")
                DispatchQueue.main.async {
                    self.loading = false
                    self.error = true
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func loadMovie(movie: Movie) {
        guard let tmdbId = movie.identifiers.tmdb else {
            loading = false
            error = true
            collectionView.reloadData()
            return
        }
        loading = true
        error = false
        collectionView.reloadData()
        TmdbAPIProvider.provider.request(TmdbAPIService.movieProviders(tmdbId), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map(ProvidersResult.self, using: TmdbAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = false
                        self.result = results
                    }
                } catch {
                    print("TmdbAPIService.movieProviders Error: \(error)")
                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = true
                        self.collectionView.reloadData()
                    }
                }
            case let .failure(error):
                print("TmdbAPIService.movieProviders Failure: \(error)")
                DispatchQueue.main.async {
                    self.loading = false
                    self.error = true
                    self.collectionView.reloadData()
                }
            }
        }
    }

    private func load(show: Show, season: Int) {
        guard let tmdbId = show.identifiers.tmdb else {
            loading = false
            error = true
            collectionView.reloadData()
            return
        }
        loading = true
        error = false
        collectionView.reloadData()
        TmdbAPIProvider.provider.request(TmdbAPIService.seasonProviders(tmdbId, season), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let results = try response.map(ProvidersResult.self, using: TmdbAPIProvider.decoder)

                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = false
                        self.result = results
                    }
                } catch {
                    print("TmdbAPIService.seasonProviders Error: \(error)")
                    DispatchQueue.main.async {
                        self.loading = false
                        self.error = true
                        self.collectionView.reloadData()
                    }
                }
            case let .failure(error):
                print("TmdbAPIService.seasonProviders Failure: \(error)")
                DispatchQueue.main.async {
                    self.loading = false
                    self.error = true
                    self.collectionView.reloadData()
                }
            }
        }
    }
}
