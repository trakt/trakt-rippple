//
//  TransactionsView.swift
//  Rippple
//
//  Created by Kevin Cador on 08/10/2025.
//  Copyright © Trakt. All rights reserved.
//

import Foundation
import StoreKit
import SwiftUI

struct TransactionsView: View {
    @State private var transactions: [StoreKit.Transaction] = []
    @State private var isLoading = true
    @State private var header = ""
    @State private var unverifiedTransactionIDs: [UInt64] = []

    private enum Filter: String, CaseIterable, Identifiable {
        case activePurchased = "Active"
        case all = "All"
        var id: Self {
            self
        }
    }

    @State private var selectedFilter: Filter = .activePurchased

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading transactions...")
                } else if transactions.isEmpty {
                    ContentUnavailableView("No Transactions",
                                           systemImage: "cart.badge.minus",
                                           description: Text("Couldn't find any past transactions for Rippple."))
                } else {
                    VStack(spacing: 12) {
                        RipppleList {
                            if !header.isEmpty {
                                Section {
                                    Text(header)
                                }
                            }

                            Picker("Filter", selection: $selectedFilter) {
                                Text(Filter.activePurchased.rawValue).tag(Filter.activePurchased)
                                Text(Filter.all.rawValue).tag(Filter.all)
                            }.pickerStyle(.segmented)

                            ForEach(filteredTransactions) { txn in
                                Section {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(productName(from: txn)).font(.headline)
                                            Spacer()
                                            Text(statusText(for: txn)).font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        HStack {
                                            HStack(spacing: 2) {
                                                Image(systemName: "calendar")
                                                Text(txn.purchaseDate.formatted(date: .abbreviated, time: .shortened))
                                            }
                                            Spacer()
                                            if let expiry = txn.expirationDate, expiry > Date() {
                                                HStack(spacing: 2) {
                                                    if unverifiedTransactionIDs.contains(txn.id) {
                                                        Image(systemName: "exclamationmark.shield")
                                                    }
                                                    Text("→ Expires " + expiry.formatted(date: .abbreviated, time: .omitted))
                                                }
                                            }
                                        }.font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        copyTransactionToClipboard(txn)
                                    }
                                }
                            }
                        }
                        .listSectionSpacing(8)
                    }
                }
            }.navigationTitle("Transactions History")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
        }.task {
            isLoading = true
            await loadTransactions()
            isLoading = false
        }
    }

    private var filteredTransactions: [StoreKit.Transaction] {
        switch selectedFilter {
        case .all:
            return transactions
        case .activePurchased:
            return transactions.filter { txn in
                // Exclude revoked
                if txn.revocationDate != nil { return false }
                // If it has an expiration, include only if not expired
                if let expiration = txn.expirationDate {
                    return expiration >= Date()
                }
                // Non-expiring purchases are included
                return true
            }
        }
    }
}

extension TransactionsView {
    private func loadTransactions() async {
        if PurchaseManager.shared.isSandboxed {
            header = "You are currently running a test version of Rippple. Transactions here are not \"real\". Your App Store transactions will not be reflected here."
        }
        var all: [StoreKit.Transaction] = []
        for await result in Transaction.all {
            switch result {
            case .verified(let txn):
                all.append(txn)
            case .unverified(let txn, _):
                unverifiedTransactionIDs.append(txn.id)
                all.append(txn)
            }
        }
        all.sort { $0.purchaseDate > $1.purchaseDate }
        transactions = all
    }

    private func productName(from txn: StoreKit.Transaction) -> String {
        switch txn.productID {
        case "tv.trakt.rippple.vip.1m":
            return "Trakt VIP (monthly)"
        default:
            return txn.productID
        }
    }

    private func statusText(for txn: StoreKit.Transaction) -> String {
        if txn.revocationDate != nil {
            return "Revoked"
        }
        if let expiration = txn.expirationDate {
            if expiration < Date() {
                return "Expired"
            } else {
                return "Active"
            }
        }
        return "Purchased"
    }

    private func transactionDebugInfo(for txn: StoreKit.Transaction) -> String {
        var lines: [String] = []
        lines.append("id: \(txn.id)")
        lines.append("productId: \(txn.productID)")
        lines.append("status: \(statusText(for: txn))")
        lines.append("environment: \(txn.environment)")
        lines.append("purchaseDate: \(txn.purchaseDate)")
        if let expiration = txn.expirationDate {
            lines.append("expirationDate: \(expiration)")
        }
        if let revocationDate = txn.revocationDate {
            lines.append("revocationDate: \(revocationDate)")
        }
        lines.append("jsonRepresentation: \(String(data: txn.jsonRepresentation, encoding: .utf8) ?? "")")
        return lines.joined(separator: "\n")
    }

    private func copyTransactionToClipboard(_ txn: StoreKit.Transaction) {
        UIPasteboard.general.string = transactionDebugInfo(for: txn)
        SwiftMessages.show(message: "Copy to clipboard", style: .content)
    }
}
