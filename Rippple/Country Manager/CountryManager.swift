//
//  CountryManager.swift
//  Rippple
//
//  Created by Kevin Cador on 30/01/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import Foundation

enum Country: String, CaseIterable, Identifiable {
    var id: String {
        return self.rawValue
    }

    case AD
    case AE
    case AG
    case AL
    case AO
    case AR
    case AT
    case AU
    case AZ
    case BA
    case BB
    case BE
    case BF
    case BG
    case BH
    case BM
    case BO
    case BR
    case BS
    case BY
    case BZ
    case CA
    case CD
    case CH
    case CI
    case CL
    case CM
    case CO
    case CR
    case CU
    case CV
    case CY
    case CZ
    case DE
    case DK
    case DO
    case DZ
    case EC
    case EE
    case EG
    case ES
    case FI
    case FJ
    case FR
    case GB
    case GF
    case GH
    case GI
    case GP
    case GQ
    case GR
    case GT
    case GY
    case HK
    case HN
    case HR
    case HU
    case ID
    case IE
    case IL
    case IN
    case IQ
    case IS
    case IT
    case JM
    case JO
    case JP
    case KE
    case KR
    case KW
    case LB
    case LC
    case LI
    case LT
    case LU
    case LV
    case LY
    case MA
    case MC
    case MD
    case ME
    case MG
    case MK
    case ML
    case MT
    case MU
    case MW
    case MX
    case MY
    case MZ
    case NE
    case NG
    case NI
    case NL
    case NO
    case NZ
    case OM
    case PA
    case PE
    case PF
    case PG
    case PH
    case PK
    case PL
    case PS
    case PT
    case PY
    case QA
    case RO
    case RS
    case RU
    case SA
    case SC
    case SE
    case SG
    case SI
    case SK
    case SM
    case SN
    case SV
    case TC
    case TD
    case TH
    case TN
    case TR
    case TT
    case TW
    case TZ
    case UA
    case UG
    case US
    case UY
    case VA
    case VE
    case XK
    case YE
    case ZA
    case ZM
    case ZW

    var localizedCountry: String {
        return Locale.current.localizedString(forRegionCode: self.rawValue) ?? "Unknown"
    }
}

import Receiver

let (onCountryChangedTransmitter, onCountryChangedReceiver) = Receiver<Country>.make(with: .hot)

final class CountryManager {

    private init() {
        disabled = UserDefaults.standard.bool(forKey: "CountryManager.disabled")
        favoritesOnly = UserDefaults.standard.bool(forKey: "CountryManager.favoritesOnly")
        if let data = UserDefaults.standard.data(forKey: "CountryManager.favoriteProviders.\(CountryManager.userCountry.rawValue)"),
            let array = try? PropertyListDecoder().decode([ProviderType].self, from: data) {
            favoriteProviders = array
        } else {
            favoriteProviders = [ProviderType]()
        }
        displayInLists = UserDefaults.standard.bool(forKey: "CountryManager.displayInLists")
    }

    static let shared = CountryManager()

    var disabled: Bool {
        didSet {
            UserDefaults.standard.set(disabled, forKey: "CountryManager.disabled")
            UserDefaults.standard.synchronize()
            onCountryChangedTransmitter.broadcast(CountryManager.userCountry)
        }
    }

    var displayInLists: Bool {
        didSet {
            UserDefaults.standard.set(displayInLists, forKey: "CountryManager.displayInLists")
            UserDefaults.standard.synchronize()
            onCountryChangedTransmitter.broadcast(CountryManager.userCountry)
        }
    }

    var favoritesOnly: Bool {
        didSet {
            UserDefaults.standard.set(favoritesOnly, forKey: "CountryManager.favoritesOnly")
            UserDefaults.standard.synchronize()
            onCountryChangedTransmitter.broadcast(CountryManager.userCountry)
        }
    }

    static var userCountry: Country {
        if let storedCountry = UserDefaults.standard.object(forKey: "CountryManager.userCountry") as? String {
            return Country(rawValue: storedCountry) ?? .US
        }
        if let localCountry = Locale.current.language.region?.identifier { return Country(rawValue: localCountry) ?? .US }
        return .US // default to US
    }

    func storeCountryChoosenByUser(country: String) {
        UserDefaults.standard.setValue(country, forKey: "CountryManager.userCountry")
        UserDefaults.standard.synchronize()
        if let data = UserDefaults.standard.data(forKey: "CountryManager.favoriteProviders.\(CountryManager.userCountry.rawValue)"),
            let array = try? PropertyListDecoder().decode([ProviderType].self, from: data) {
            favoriteProviders = array
        } else {
            favoriteProviders = [ProviderType]()
        }
        onCountryChangedTransmitter.broadcast(CountryManager.userCountry)
    }

    var favoriteProviders: [ProviderType] {
        didSet {
            UserDefaults.standard.set(try? PropertyListEncoder().encode(favoriteProviders), forKey: "CountryManager.favoriteProviders.\(CountryManager.userCountry.rawValue)")
            UserDefaults.standard.synchronize()
            onCountryChangedTransmitter.broadcast(CountryManager.userCountry)
        }
    }

    var localizedCountries: [String] {
        var localizedCountries = [String]()
        for country in Country.allCases {
            if let localizedCountry = Locale.current.localizedString(forRegionCode: country.rawValue) {
                localizedCountries.append(localizedCountry)
            }
        }
        return localizedCountries
    }

    var localizedUserCountry: String {
        return Locale.current.localizedString(forRegionCode: CountryManager.userCountry.rawValue) ?? "Unknown"
    }
}

extension ProviderType {
    var computedPriority: Int {
        var priority = priority ?? Int.max
        if type?.contains(where: { $0 == "Stream" }) == true {
            priority -= 10000
        }
        if type?.contains(where: { $0 == "Free"}) == true {
            priority -= 20000
        }
        if let index = CountryManager.shared.favoriteProviders.firstIndex(where: { $0 == self }) {
            priority -= 100000 + index
        }
        return priority
    }
}
