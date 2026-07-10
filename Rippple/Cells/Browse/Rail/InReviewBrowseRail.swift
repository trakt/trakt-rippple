//
//  InReviewBrowseRail.swift
//
//
//  Created by Kevin Cador on 29/10/2025.
//

import LRUCache
import SwiftUI
import UIKit

private enum InReviewCardConstants {
    static let size = CGSize(width: 200, height: 280)
}

enum InReviewBrowseCache {
    struct Stats {
        let totalWatches: Int
        let totalMinutes: Int
    }

    private struct Entry {
        let stats: Stats
        let expirationDate: Date
    }

    private static let lifetime: TimeInterval = 2 * 60
    private static let cache = LRUCache<String, Entry>(countLimit: 10)

    static func stats(slug: String, year: Int, month: Int? = nil) -> Stats? {
        let key = key(slug: slug, year: year, month: month)
        guard let entry = cache.value(forKey: key) else { return nil }
        guard entry.expirationDate > Date() else {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.stats
    }

    static func store(_ stats: Stats, slug: String, year: Int, month: Int? = nil) {
        let entry = Entry(stats: stats,
                          expirationDate: Date().addingTimeInterval(lifetime))
        cache.setValue(entry, forKey: key(slug: slug, year: year, month: month))
    }

    static func removeAll() {
        cache.removeAll()
    }

    private static func key(slug: String, year: Int, month: Int?) -> String {
        return "\(slug):\(year):\(month ?? 0)"
    }
}

private extension View {
    func inReviewCardFrame() -> some View {
        frame(width: InReviewCardConstants.size.width, height: InReviewCardConstants.size.height)
    }
}

struct MeshGradientView: View {
    @State var positions: [SIMD2<Float>] = [
        .init(x: 0, y: 0), .init(x: 0.2, y: 0), .init(x: 1, y: 0),
        .init(x: 0, y: 0.7), .init(x: 0.1, y: 0.5), .init(x: 1, y: 0.2),
        .init(x: 0, y: 1), .init(x: 0.9, y: 1), .init(x: 1, y: 1)
    ]

    var colors: [Color] = [.purple, .pink, .purple,
                           .blue, .indigo, .purple,
                           .purple, .teal, .indigo].shuffled()

    var updateDistance: Float = 0.2

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: positions,
            colors: colors
        ).onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever()) {
                shufflePositions()
            }
        }
    }

    private func shufflePositions() {
        positions[1] = randomizePosition(
            currentPosition: positions[1],
            xRange: (min: 0.2, max: 0.9),
            yRange: (min: 0, max: 0)
        )

        positions[3] = randomizePosition(
            currentPosition: positions[3],
            xRange: (min: 0, max: 0),
            yRange: (min: 0.2, max: 0.8)
        )

        positions[4] = randomizePosition(
            currentPosition: positions[4],
            xRange: (min: 0.3, max: 0.8),
            yRange: (min: 0.3, max: 0.8)
        )

        positions[5] = randomizePosition(
            currentPosition: positions[5],
            xRange: (min: 1, max: 1),
            yRange: (min: 0.1, max: 0.9)
        )

        positions[7] = randomizePosition(
            currentPosition: positions[7],
            xRange: (min: 0.1, max: 0.9),
            yRange: (min: 1, max: 1)
        )
    }

    private func randomizePosition(currentPosition: SIMD2<Float>,
                                   xRange: (min: Float, max: Float),
                                   yRange: (min: Float, max: Float)) -> SIMD2<Float> {
        let newX = if Bool.random() {
            min(currentPosition.x + updateDistance, xRange.max)
        } else {
            max(currentPosition.x - updateDistance, xRange.min)
        }

        let newY = if Bool.random() {
            min(currentPosition.y + updateDistance, yRange.max)
        } else {
            max(currentPosition.y - updateDistance, yRange.min)
        }

        return .init(x: newX, y: newY)
    }
}

struct MonthInReviewCard: View {
    var year: Int
    var month: Int

    @State private var isLoading = true
    @State private var errorText: String?
    @State private var totalWatches: Int = 0
    @State private var totalMinutes: Int = 0

    private var titleText: String {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let calendar = Calendar.current
        let date = calendar.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    private var footerText: String {
        if isLoading { return "Loading...\n " }
        if let errorText { return errorText }
        return "\(totalWatches) plays\n\(formatMinutes(totalMinutes)) watching"
    }

    private func formatMinutes(_ minutesTotal: Int) -> String {
        let hours = minutesTotal / 60
        let minutes = minutesTotal % 60
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: -10) {
                Text(titleText)
                    .font(.system(size: 60).lowercaseSmallCaps())
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("In Review")
                    .font(.system(size: 25).lowercaseSmallCaps())
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            HStack(alignment: .bottom) {
                Text(footerText)
                    .font(.system(size: 14))
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
            }
        }.padding(12)
            .inReviewCardFrame()
            .background {
                MeshGradientView()
                    .clipShape(RoundedRectangle(cornerRadius: ViewRadius.large.rawValue,
                                                style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: ViewRadius.large.rawValue, style: .continuous)
                            .stroke(Color(UIColor.tertiarySystemFill),
                                    lineWidth: 1)
                    }
            }
            .onTapGesture {
                UIApplication.shared.openStats(mode: .mir(user: UserManager.shared.currentUser!,
                                                          month: month,
                                                          year: year))
            }
            .task {
                await fetchMIR()
            }
    }

    private let slug: String = {
        if let user = UserManager.shared.currentUser { return user.slug }
        return "me"
    }()

    private func fetchMIR() async {
        if let stats = InReviewBrowseCache.stats(slug: slug, year: year, month: month) {
            await MainActor.run {
                self.totalWatches = stats.totalWatches
                self.totalMinutes = stats.totalMinutes
                self.isLoading = false
                self.errorText = nil
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorText = nil
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let cancellable = TraktAPIProvider.provider.request(.mir(slug: slug, year: self.year, month: self.month),
                                                                callbackQueue: .global(qos: .userInitiated)) { result in
                _Concurrency.Task {
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()
                            // Decode the same model used by MirTableViewCell
                            let stats = try response.map(IRUserStats.self, using: TraktAPIProvider.decoder).stats.all
                            let cachedStats = InReviewBrowseCache.Stats(totalWatches: stats.playCounts.total,
                                                                        totalMinutes: stats.minutes.total)
                            InReviewBrowseCache.store(cachedStats, slug: slug, year: year, month: month)
                            await MainActor.run {
                                self.totalWatches = cachedStats.totalWatches
                                self.totalMinutes = cachedStats.totalMinutes
                                self.isLoading = false
                                self.errorText = nil
                            }
                        } catch {
                            await MainActor.run {
                                self.errorText = "Monthly stats with clear visualizations!"
                                self.isLoading = false
                            }
                        }
                    case .failure:
                        await MainActor.run {
                            self.errorText = "Monthly stats with clear visualizations!"
                            self.isLoading = false
                        }
                    }
                    continuation.resume()
                }
            }
            // Keep the request alive for the duration of the continuation
            _ = cancellable
        }
    }
}

struct AllTimeReviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: -10) {
                VStack(alignment: .leading, spacing: -20) {
                    Text("All")
                        .font(.system(size: 60).lowercaseSmallCaps())
                        .bold()
                        .fontDesign(.rounded)
                        .foregroundStyle(.black)
                    Text("Time")
                        .font(.system(size: 60).lowercaseSmallCaps())
                        .bold()
                        .fontDesign(.rounded)
                        .foregroundStyle(.black)
                }
                Text("Stats")
                    .font(.system(size: 25).lowercaseSmallCaps())
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.black)
            }
            HStack(alignment: .bottom) {
                Text("Your stats across years, all in one view!")
                    .font(.system(size: 14))
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
            }
        }.padding(12)
            .inReviewCardFrame()
            .background {
                MeshGradientView(colors: [.white, .white, .white,
                                          .white, .white, .white,
                                          .red, .pink, .purple],
                                 updateDistance: 0.01)
                    .clipShape(RoundedRectangle(cornerRadius: ViewRadius.large.rawValue,
                                                style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: ViewRadius.large.rawValue, style: .continuous)
                            .stroke(Color(UIColor.tertiarySystemFill),
                                    lineWidth: 1)
                    }
            }
            .onTapGesture {
                UIApplication.shared.openStats(mode: .all(user: UserManager.shared.currentUser!))
            }
    }
}

struct YearInReviewCard: View {
    var year: Int

    @State private var isLoading = true
    @State private var errorText: String?
    @State private var totalWatches: Int = 0
    @State private var totalMinutes: Int = 0

    private let slug: String = {
        if let user = UserManager.shared.currentUser { return user.slug }
        return "me"
    }()

    private var footerText: String {
        if isLoading { return "Loading...\n " }
        if let errorText { return errorText }
        return "\(totalWatches) plays\n\(formatMinutes(totalMinutes)) watching"
    }

    private func formatMinutes(_ minutesTotal: Int) -> String {
        let hours = minutesTotal / 60
        let minutes = minutesTotal % 60
        if hours > 0 {
            if minutes > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(hours)h"
            }
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            VStack(alignment: .leading, spacing: -10) {
                Text("‘\(String(year).suffix(2))")
                    .font(.system(size: 60).lowercaseSmallCaps())
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                Text("In Review")
                    .font(.system(size: 25).lowercaseSmallCaps())
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
            }
            HStack(alignment: .bottom) {
                Text(footerText)
                    .font(.system(size: 14))
                    .bold()
                    .fontDesign(.rounded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
            }
        }.padding(12)
            .inReviewCardFrame()
            .background {
                MeshGradientView(colors: [.orange, .pink, .purple,
                                          .mint, .teal, .blue,
                                          .purple, .cyan, .indigo].shuffled())
                    .clipShape(RoundedRectangle(cornerRadius: ViewRadius.large.rawValue,
                                                style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: ViewRadius.large.rawValue, style: .continuous)
                            .stroke(Color(UIColor.tertiarySystemFill),
                                    lineWidth: 1)
                    }
            }
            .onTapGesture {
                UIApplication.shared.openStats(mode: .yir(user: UserManager.shared.currentUser!, year: year))
            }
            .task {
                await fetchYIR()
            }
    }

    private func fetchYIR() async {
        if let stats = InReviewBrowseCache.stats(slug: slug, year: year) {
            await MainActor.run {
                self.totalWatches = stats.totalWatches
                self.totalMinutes = stats.totalMinutes
                self.isLoading = false
                self.errorText = nil
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorText = nil
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let cancellable = TraktAPIProvider.provider.request(.yir(slug: slug, year: self.year),
                                                                callbackQueue: .global(qos: .userInitiated)) { result in
                _Concurrency.Task {
                    switch result {
                    case .success(let moyaResponse):
                        do {
                            let response = try moyaResponse.filterSuccessfulStatusCodes()
                            let stats = try response.map(IRUserStats.self, using: TraktAPIProvider.decoder).stats.all
                            let cachedStats = InReviewBrowseCache.Stats(totalWatches: stats.playCounts.total,
                                                                        totalMinutes: stats.minutes.total)
                            InReviewBrowseCache.store(cachedStats, slug: slug, year: year)
                            await MainActor.run {
                                self.totalWatches = cachedStats.totalWatches
                                self.totalMinutes = cachedStats.totalMinutes
                                self.isLoading = false
                                self.errorText = nil
                            }
                        } catch {
                            await MainActor.run {
                                self.errorText = "Detailed stats for every year you've been a member!"
                                self.isLoading = false
                            }
                        }
                    case .failure:
                        await MainActor.run {
                            self.errorText = "Detailed stats for every year you've been a member!"
                            self.isLoading = false
                        }
                    }
                    continuation.resume()
                }
            }
            // Keep the request alive for the duration of the continuation
            _ = cancellable
        }
    }
}

struct InReviewView: View {
    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var lastYear: Int {
        currentYear - 1
    }

    private var last4Months: [YearMonth] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<4).compactMap { offset in
            guard let date = calendar.date(byAdding: .month, value: -offset, to: now) else { return nil }
            return YearMonth(date)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rewind: Go Back in Time")
                .font(.headline)
                .padding(.horizontal, 8)
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    AllTimeReviewCard()
                    YearInReviewCard(year: currentYear)
                    YearInReviewCard(year: lastYear)
                    ForEach(last4Months) { ym in
                        MonthInReviewCard(year: ym.year, month: ym.month)
                    }
                }
            }
            .scrollIndicators(.never)
            .scrollClipDisabled()
        }
    }
}

private struct YearMonth: Hashable, Identifiable {
    var id: Int {
        year + month
    }

    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        precondition((1...12).contains(month), "Month must be between 1 and 12")
        self.year = year
        self.month = month
    }

    init(_ date: Date, calendar: Calendar = .current) {
        let comps = calendar.dateComponents([.year, .month], from: date)
        self.init(year: comps.year ?? 1, month: comps.month ?? 1)
    }
}
