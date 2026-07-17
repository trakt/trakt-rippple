//
//  PurchaseManager.swift
//  Rippple
//
//  Created by Kevin Cador on 26/12/2017.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import Receiver
import StoreKit

final class PurchaseManager {
    private let disposeBag = DisposeBag()

    var appEnvironement: AppStore.Environment?

    private init() {
        traktVIPProduct = UserDefaults.standard.string(forKey: "PurchaseManager.product.traktVIP")
        onPurchasedChangedTransmitter.broadcast(purchased)

        refresh()

        onVIPChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            onPurchasedChangedTransmitter.broadcast(self.purchased)
        }.disposed(by: disposeBag)
    }

    static let shared = PurchaseManager()

    private var taskHandle: Task<Void, Error>?

    func setup() {
        taskHandle = listenForTransactions()
    }

    func refresh() {
        Task {
            for await result in Transaction.all {
                guard case .verified(let transaction) = result else { continue }
                if transaction.environment == .sandbox || transaction.environment == .xcode {
                    isSandboxed = true
                    break
                }
            }
            var transactionsCount = 0
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                updatePurchasedIdentifiers(transaction)
                transactionsCount += 1
            }
            if transactionsCount == 0 {
                traktVIPProduct = nil
                onPurchasedChangedTransmitter.broadcast(purchased)
            }
        }
    }

    func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions which didn't come from a direct call to `purchase()`.
            for await result in Transaction.updates {
                switch result {
                case .unverified: continue
                case .verified(let transaction):
                    if transaction.environment == .sandbox || transaction.environment == .xcode {
                        self.isSandboxed = true
                    }
                    self.updatePurchasedIdentifiers(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    let (onPurchasedChangedTransmitter, onPurchasedChangedReceiver) = Receiver<Bool>.make(with: .cold)

    var isSandboxed = false

    var purchased: Bool {
        if UserManager.shared.isCurrentVIP {
            return true
        }
        // This means the user just purchased VIP and Trakt settings aren't updated yet
        if traktVIPProduct != nil {
            return true
        }

        return false
    }

    private var traktVIPProduct: String? {
        didSet {
            DispatchQueue.main.async {
                guard let currentProduct = self.traktVIPProduct else {
                    UserDefaults.standard.removeObject(forKey: "PurchaseManager.product.traktVIP")
                    UserDefaults.standard.synchronize()
                    return
                }
                UserDefaults.standard.set(currentProduct, forKey: "PurchaseManager.product.traktVIP")
                UserDefaults.standard.synchronize()
                if currentProduct != oldValue {
                    SwiftMessages.show(message: "✨ Thank you ✨")
                }
            }
        }
    }

    var traktVIPIAP: Bool {
        guard let currentProduct = traktVIPProduct else { return false }
        return currentProduct == "tv.trakt.rippple.vip.1m"
    }

    func purchase(product: Product, completion: @escaping (_ error: Error?) -> Void) {
        print("💰 Purchasing \(product.id)")
        Task {
            do {
                let result = try await product.purchase()

                switch result {
                case .success(let verification):
                    switch verification {
                    case .unverified: break
                    case .verified(let transaction):
                        if transaction.environment == .sandbox || transaction.environment == .xcode {
                            isSandboxed = true
                        }
                        updatePurchasedIdentifiers(transaction)
                        await transaction.finish()
                        DispatchQueue.main.async {
                            completion(nil)
                        }
                    }
                case .userCancelled:
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "Purchase Cancelled")
                        completion(nil)
                    }
                case .pending:
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "Purchase Pending")
                        completion(nil)
                    }
                @unknown default:
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    let alertController = UIAlertController(title: "Purchase Error",
                                                            message: "An error occurred with your purchase: \(error.localizedDescription)",
                                                            preferredStyle: .alert)

                    let cancel = UIAlertAction(title: "Okay", style: .cancel)
                    alertController.addAction(cancel)

                    AppManager.shared.present(viewController: alertController, animated: true)

                    completion(error)
                }
            }
        }
    }

    private func updatePurchasedIdentifiers(_ transaction: Transaction) {
        if transaction.revocationDate == nil {
            if let expirationDate = transaction.expirationDate, expirationDate < Date.now {
                traktVIPProduct = nil
            } else {
                traktVIPProduct = transaction.productID
                verifyWithTrakt(transaction: transaction)
            }
        } else {
            traktVIPProduct = nil
        }

        onPurchasedChangedTransmitter.broadcast(purchased)
    }

    private func verifyWithTrakt(transaction: Transaction) {
        if transaction.environment == .xcode {
            print("IAP verify with Trakt will always fail in Xcode testing")
            return
        }
        guard let userId = UserManager.shared.currentUser?.identifiers.trakt else {
            print("IAP can't be verified with Trakt without a Trakt user ID")
            return
        }

        if transaction.environment == .sandbox {
            // Enable to test in-app purchase on the Sandbox
            /*
             TraktAPIProvider.debug_provider.request(.verifySandboxIAP(transactionId: transaction.id,
                                                                       userId: userId),
                                               callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                 switch result {
                 case .success(let response):
                     if response.statusCode == 204 {
                         print("IAP verification successful")
                         DispatchQueue.main.async {
                             SwiftMessages.show(message: "🧪 IAP /verify successful")
                         }
                     } else {
                         print("IAP verification failed: status code \(response.statusCode)")
                         DispatchQueue.main.async {
                             SwiftMessages.show(message: "🧪 IAP /verify failed (\(response.statusCode))!", style: .standout)
                         }
                     }
                 case .failure(let error):
                     print("IAP verification error: \(error)")
                     DispatchQueue.main.async {
                         SwiftMessages.show(message: "🧪 IAP /verify error!", style: .error(error))
                     }
                 }
             }
              */
        } else {
            TraktAPIProvider.provider.request(.verifyIAP(transactionId: transaction.id,
                                                         userId: userId),
                                              callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let response):
                    if response.statusCode == 200 {
                        print("IAP verification successful")
                    } else {
                        print("IAP verification failed: status code \(response.statusCode)")
                    }
                case .failure(let error):
                    print("IAP verification error: \(error)")
                }
            }
        }
    }
}
