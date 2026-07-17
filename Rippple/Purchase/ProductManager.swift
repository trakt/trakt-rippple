//
//  ProductManager.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import StoreKit

final class ProductManager {
    enum State {
        case loading
        case error
        case content
    }

    private init() {}

    static let shared = ProductManager()

    let (onProductChangedTransmitter, onProductChangedReceiver) = Receiver<State>.make(with: .warm(upTo: 1))

    var loading = false {
        didSet {
            if loading {
                onProductChangedTransmitter.broadcast(.loading)
            }
        }
    }

    var error: Error? {
        didSet {
            if error != nil {
                onProductChangedTransmitter.broadcast(.error)
            }
        }
    }

    var isEligibleForFreeTrial = false

    func reloadProducts() {
        products = nil
        error = nil
        loading = true
        isEligibleForFreeTrial = false

        Task {
            await retrieveProductsInfo()
        }
    }

    private var products: [Product]? {
        didSet {
            if products != nil {
                onProductChangedTransmitter.broadcast(.content)
            }
        }
    }

    var monthlySubscription: Product? {
        guard let products = products else { return nil }
        for product in products where product.id == "tv.trakt.rippple.vip.1m" {
            return product
        }
        return nil
    }

    var monthlyPrice: String {
        guard let product = monthlySubscription else { return "" }
        return "\(product.displayPrice) a month"
    }

    var freeTrial: String? {
        guard let product = monthlySubscription else { return nil }
        if let introductoryOffer = product.subscription?.introductoryOffer {
            switch introductoryOffer.period.unit {
            case .day:
                if introductoryOffer.period.value <= 1 {
                    return "\(introductoryOffer.period.value) day"
                } else {
                    return "\(introductoryOffer.period.value) days"
                }
            case .week:
                if introductoryOffer.period.value <= 1 {
                    return "\(introductoryOffer.period.value) week"
                } else {
                    return "\(introductoryOffer.period.value) weeks"
                }
            case .month:
                if introductoryOffer.period.value <= 1 {
                    return "\(introductoryOffer.period.value) month"
                } else {
                    return "\(introductoryOffer.period.value) months"
                }
            case .year:
                if introductoryOffer.period.value <= 1 {
                    return "\(introductoryOffer.period.value) year"
                } else {
                    return "\(introductoryOffer.period.value) years"
                }
            @unknown default:
                return "Some time"
            }
        }
        return nil
    }

    @MainActor
    private func retrieveProductsInfo() async {
        do {
            products = try await Product.products(for: ["tv.trakt.rippple.vip.1m"])
            error = nil
            loading = false
            Task {
                self.isEligibleForFreeTrial = await monthlySubscription?.subscription?.isEligibleForIntroOffer ?? false
            }
        } catch {
            print("Purchase Manager Error: \(error)")
            self.error = error
            loading = false
            isEligibleForFreeTrial = false
        }
    }
}
