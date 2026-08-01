//
//  ImageCacheSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 13/03/2026.
//  Copyright © Trakt. All rights reserved.
//

import SwiftUI

struct ImageCacheSettingsView: View {
    @State private var selectedMode: ImagesManager.CacheMode = ImagesManager.shared.cacheMode
    @State private var stats: ImagesManager.CacheStats?

    var body: some View {
        Form {
            Section(header: Text("Disk Image Usage")) {
                if let stats = stats {
                    cacheSizeProgressRow(diskSize: stats.diskSize,
                                         diskLimit: stats.diskSizeLimit)
                } else {
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }

                Button("Refresh Stats") {
                    reloadStats()
                }
            }

            Section(header: Text("Cache Mode"),
                    footer: Text(selectedMode.description)
                        .font(.footnote)
                        .foregroundColor(.secondary)) {
                if let stats = stats {
                    Picker("Cache Mode", selection: $selectedMode) {
                        Text(ImagesManager.CacheMode.offlineFirst.name)
                            .tag(ImagesManager.CacheMode.offlineFirst)
                        Text(ImagesManager.CacheMode.balanced.name)
                            .tag(ImagesManager.CacheMode.balanced)
                        Text(ImagesManager.CacheMode.alwaysFresh.name)
                            .tag(ImagesManager.CacheMode.alwaysFresh)
                    }.pickerStyle(.segmented)

                    statRow(title: "Memory Expiration", value: stats.memoryExpirationDescription)
                    statRow(title: "Disk Expiration", value: stats.diskExpirationDescription)
                } else {
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            }
        }.navigationTitle("Image Cache")
            .onAppear {
                selectedMode = ImagesManager.shared.cacheMode
                reloadStats()
            }
            .onChange(of: selectedMode) { _, newValue in
                ImagesManager.shared.updateCacheMode(newValue)
                reloadStats()
            }
    }

    private func statRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func cacheSizeProgressRow(diskSize: UInt, diskLimit: UInt) -> some View {
        let limit = max(diskLimit, 1)
        let progress = min(Double(diskSize) / Double(limit), 1.0)
        let ratioText = "\(byteString(bytes: diskSize)) of \(byteString(bytes: diskLimit))"

        return VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .tint(.accentColor)
            HStack {
                Text(ratioText)
                    .foregroundColor(.secondary)
                Spacer()
                Text(String(format: "%.0f%%", progress * 100.0))
                    .foregroundColor(.secondary)
            }
        }.padding(.vertical, 4)
    }

    private func reloadStats() {
        ImagesManager.shared.loadCacheStats { stats in
            DispatchQueue.main.async {
                self.stats = stats
            }
        }
    }

    private func byteString(bytes: UInt) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
