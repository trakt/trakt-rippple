//
//  SharingView.swift
//  Rippple
//
//  Created by Kevin Cador on 30/07/2024.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI
import UIKit

struct SharingView: View {
    @State private var enableText: Bool = true
    @State private var enableURL: Bool = true
    @State private var enableImage: Bool = true

    @State private var selectedTextFormat: String = "Look what I found on Rippple: Deadpool & Wolverine"
    private let textFormats = ["Look what I found on Rippple: Deadpool & Wolverine", "Look what I found: Deadpool & Wolverine", "I'm currently watching Deadpool & Wolverine", "Should we watch Deadpool & Wolverine?"]

    @State private var selectedURLService: String = "Trakt"
    private let URLServices = ["Trakt", "Rippple", "TMDb", "IMDb"]

    @State private var selectedImageType: String = "Poster"
    private let imageTypes = ["Poster", "Backdrop without Title", "Backdrop with Title"]

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                RipppleForm {
                    Section {
                        Toggle(isOn: $enableText) {
                            Text("Include Text")
                        }
                        if enableText {
                            Picker("Format", selection: $selectedTextFormat) {
                                ForEach(textFormats, id: \.self) { format in
                                    Text(format).tag(format)
                                }
                            }.pickerStyle(.navigationLink)
                        }
                    } header: {
                        Text("Text")
                    } footer: {
                        if enableText {
                            Text("Look what I found on Ripple: Deadpool & Wolverine")
                        }
                    }

                    Section {
                        Toggle(isOn: $enableURL) {
                            Text("Include URL")
                        }
                        if enableURL {
                            Picker("Service", selection: $selectedURLService) {
                                ForEach(URLServices, id: \.self) { service in
                                    Text(service).tag(service)
                                }
                            }.pickerStyle(.segmented)
                        }
                    } header: {
                        Text("URL")
                    } footer: {
                        if enableURL {
                            Text(verbatim: "https://app.trakt.tv/movies/deadpool-wolverine-2024")
                        }
                    }

                    Section("Image") {
                        Toggle(isOn: $enableImage) {
                            Text("Include Image")
                        }
                        if enableImage {
                            HStack(alignment: .top) {
                                AsyncImage(url: URL(string: "https://image.tmdb.org/t/p/original/8cdWjvZQUExUUTzyp4t6EDMubfO.jpg")!) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .cornerRadius(10)
                                        .padding([.bottom], 5)
                                } placeholder: {
                                    EmptyView()
                                }.frame(height: 200)
                            }
                        }
                    }
                }.listSectionSpacing(.compact)

                Button {
                    guard let sharedURL = URL(string: "https://ripppleapp.com") else { return }
                    let activityViewController = UIActivityViewController(activityItems: [sharedURL, "This is just a test"], applicationActivities: nil)
                    UIApplication.shared.present(activityViewController)
                } label: {
                    VStack(spacing: 1) {
                        Text("Share")
                            .font(.headline)
                    }.padding([.trailing, .leading], 10)
                }.padding()
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .shadow(radius: 5)
            }.navigationTitle("Share")
        }.tint(.purple)
    }
}

#Preview {
    SharingView()
}
