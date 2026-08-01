//
//  PurchaseConfirmationView.swift
//  Rippple
//
//  Created by Kevin Cador on 11/01/2025.
//  Copyright © Trakt. All rights reserved.
//

import Receiver
import StoreKit
import SwiftUI
import UIKit

struct PurchaseConfirmationView: View {
    @Environment(\.openURL) var openURL

    enum PurchaseConfirmationOptions: Int {
        case monthly = 0
        case traktVIP = 1
    }

    @Environment(\.dismiss) var dismiss

    @State private var chosenOption = PurchaseConfirmationOptions.monthly

    private let productManager = ProductManager.shared
    private let monthlySubscription = ProductManager.shared.monthlySubscription!

    @State private var showOverlay = false

    @State private var didOpenVIPLink = false
    @State private var showVIPAlert = false

    @State private var restoreErrorMessage = ""
    @State private var showRestoreError = false

    private let disposeBag = DisposeBag()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack {
                        VStack(alignment: .leading) {
                            Text("Upgrade to VIP")
                                .font(.largeTitle)
                                .bold()
                            Text("Get smarter tracking and deeper insights. VIP helps power Trakt and unlocks features built for people who really care about what they watch.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }.padding(.trailing, 50)
                        Spacer(minLength: 20)

                        PurchaseOptionView(chosen: chosenOption == .monthly,
                                           title: "Pay Monthly",
                                           subtitle: """
                                           + Expanded Limits
                                           + Advanced Stats
                                           + Your To Watch
                                           + Your Shelf
                                           + Smarter Searches
                                           + Smarter Rewatching
                                           + Support Trakt & Rippple
                                           """,
                                           price: monthlySubscription.displayPrice).onTapGesture {
                            chosenOption = .monthly
                        }

                        PurchaseOptionView(chosen: chosenOption == .traktVIP,
                                           title: "More Options",
                                           subtitle: "Same perks, with more ways to support independent media tracking.",
                                           price: "↗").onTapGesture {
                            chosenOption = .traktVIP
                        }
                        Spacer(minLength: 18)
                        HStack {
                            Button {
                                Task {
                                    do {
                                        try await AppStore.sync()
                                        PurchaseManager.shared.refresh()
                                    } catch {
                                        restoreErrorMessage = error.localizedDescription
                                        showRestoreError = true
                                    }
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.caption)
                                    .underline()
                            }.buttonStyle(.plain)
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button {
                                Task {
                                    await AppManager.shared.presentOfferCodeRedeemSheet()
                                }
                            } label: {
                                Text("Redeem Code")
                                    .font(.caption)
                                    .underline()
                            }.buttonStyle(.plain)
                            Spacer()
                        }.padding(.horizontal)
                        Spacer(minLength: 110)
                    }.padding(.horizontal)
                }
                Button {
                    showOverlay = true
                    if chosenOption == .monthly {
                        PurchaseManager.shared.purchase(product: monthlySubscription) { _ in
                            showOverlay = false
                        }
                    } else if chosenOption == .traktVIP {
                        openURL(URL(string: "https://app.trakt.tv/vip")!)
                        showOverlay = false
                        didOpenVIPLink = true
                    }
                } label: {
                    Text(showOverlay ? "Loading..." : "Confirm")
                        .padding([.trailing, .leading], 50)
                        .bold()
                        .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                }.buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.capsule)
                    .padding(.bottom)
            }.toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }.overlay {
                if showOverlay {
                    Color.black
                        .opacity(0.3)
                        .ignoresSafeArea()
                }
            }
        }.onAppear {
            PurchaseManager.shared.onPurchasedChangedReceiver.skipRepeats().hotOnly().listen { purchased in
                if purchased == false { return }
                DispatchQueue.main.async {
                    dismiss()
                }
            }.disposed(by: disposeBag)
        }.onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            if didOpenVIPLink {
                didOpenVIPLink = false
                showVIPAlert.toggle()
            }
        }.alert(isPresented: $showVIPAlert) {
            Alert(title: Text("Trakt VIP yet?"),
                  message: Text("It looks like you’ve opened Trakt to activate your VIP subscription, but we’re not sure if it’s been updated yet. VIP activation may take some time. You might need to come back later to see your VIP benefits in Rippple."),
                  dismissButton: .default(Text("Got it!"), action: {
                      dismiss()
                  }))
        }.alert("Restore Failed", isPresented: $showRestoreError, actions: {
            Button("Okay", role: .cancel) {}
        }, message: {
            Text(restoreErrorMessage)
        })
    }
}

struct PurchaseOptionView: View {
    @Environment(\.colorScheme) var colorScheme

    var chosen: Bool
    var title: LocalizedStringKey
    var subtitle: LocalizedStringKey
    var price: String

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                if chosen {
                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white, Color(UIColor(asset: .globalTint)))
                } else {
                    Image(systemName: "circle")
                        .resizable()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(.title3)
                    .bold()
            }.padding()
        }.background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground))
            .cornerRadius(15)
            .overlay {
                RoundedRectangle(cornerRadius: 15)
                    .stroke(chosen ? .primary : .secondary,
                            lineWidth: 0.7)
            }
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    PurchaseConfirmationView()
}
