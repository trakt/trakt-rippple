//
//  TrailersView.swift
//  Trailers
//
//  Created by Kevin Cador on 30/05/2024.
//

import SwiftUI
import YouTubePlayerKit

struct TrailersView: View {
    @Environment(\.colorScheme) private var colorScheme

    var mediaModel: MediaModel

    @State private var videos = [Video]()

    @State private var lastRefreshDate: Date?
    @State private var error: Error?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                if let error = error {
                    VStack(alignment: .center, spacing: 10) {
                        // Image ?
                        Text(error.localizedDescription)
                            .multilineTextAlignment(.center)
                        Button {
                            withAnimation {
                                self.error = nil
                            } completion: {
                                Task {
                                    await refreshData()
                                }
                            }
                        } label: {
                            HStack {
                                Text("Retry")
                                Image(systemName: "arrow.clockwise").fontWeight(.heavy)
                            }
                        }.tint(Color(UIColor(asset: .globalTint)))
                    }.frame(maxWidth: .infinity)
                        .padding(.top, 100)
                        .padding()
                } else if videos.isEmpty {
                    if lastRefreshDate == nil {
                        VStack(alignment: .center, spacing: 10) {
                            // Image for loading
                            Text("Loading...")
                                .multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity)
                            .padding(.top, 100)
                            .padding()
                    } else {
                        VStack(alignment: .center, spacing: 10) {
                            // Image for empty
                            Text("No Video Available Yet!")
                                .multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity)
                            .padding(.top, 100)
                            .padding()
                    }
                } else {
                    ForEach($videos, id: \.self) { $video in
                        ZStack {
                            if colorScheme == .dark {
                                RoundedRectangle(cornerRadius: ViewRadius.large.rawValue)
                                    .fill(Color(UIColor.secondarySystemBackground))
                                    .stroke(Color(UIColor.clear), lineWidth: 0.0)
                            } else {
                                RoundedRectangle(cornerRadius: ViewRadius.large.rawValue)
                                    .fill(Color(UIColor.systemBackground))
                                    .stroke(Color(UIColor.lightGray.lighter().withAlphaComponent(0.5)), lineWidth: 0.3)
                                    .shadow(color: Color(UIColor.lightGray.lighter().withAlphaComponent(0.8)),
                                            radius: 3)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                YouTubePlayerView(YouTubePlayer(
                                    source: .init(url: video.url),
                                    parameters: .init(autoPlay: false),
                                    configuration: .init(
                                        fullscreenMode: .system,
                                        allowsInlineMediaPlayback: true
                                    )
                                )) { state in
                                    switch state {
                                    case .idle:
                                        ProgressView()
                                            .tint(Color(UIColor(asset: .globalTint)))
                                    case .ready:
                                        EmptyView()
                                    case .error:
                                        EmptyView()
                                    }
                                }.frame(maxWidth: .infinity)
                                    .aspectRatio(16 / 9, contentMode: .fill)
                                    .cornerRadius(ViewRadius.large.rawValue)
                                    .padding([.top, .trailing, .leading], 6)
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(video.title)
                                            .font(.callout)
                                            .fontWeight(.bold)
                                        Spacer(minLength: 8)
                                        ShareLink(item: video.url) {
                                            Image(systemName: "square.and.arrow.up")
                                                .symbolRenderingMode(.hierarchical)
                                                .foregroundStyle(Color(UIColor(asset: .globalTint)))
                                                .fontWeight(.bold)
                                        }.buttonStyle(.plain)
                                    }
                                    video.metaText
                                        .font(.callout.uppercaseSmallCaps())
                                        .foregroundStyle(.secondary)
                                }.onTapGesture {
                                    UIApplication.shared.open(video.url)
                                }.padding(10)
                                    .padding([.leading, .trailing], 4)
                            }
                        }
                        Spacer(minLength: 2)
                    }
                }
            }.padding(12)
        }.navigationBarTitleDisplayMode(.inline)
            .task {
                await refreshData()
            }
    }

    private func refreshData() async {
        do {
            switch mediaModel {
            case .movie(let movie):
                let type = TraktObjectType.movie(movieId: movie.identifiers.trakt!)
                videos = try await fetchVideos(for: .videos(type: type)).filter { $0.site == "youtube" }
            case .show(let show):
                let type = TraktObjectType.show(showId: show.identifiers.trakt!)
                videos = try await fetchVideos(for: .videos(type: type)).filter { $0.site == "youtube" }
            case .season(let season, let show):
                let type = TraktObjectType.season(showId: show.identifiers.trakt!,
                                                  season: season.number)
                videos = try await fetchVideos(for: .videos(type: type)).filter { $0.site == "youtube" }
            case .episode(let episode, let show):
                let type = TraktObjectType.episode(showId: show.identifiers.trakt!,
                                                   season: episode.season,
                                                   episode: episode.number)
                videos = try await fetchVideos(for: .videos(type: type)).filter { $0.site == "youtube" }
            default:
                fatalError("Media type not supported")
            }
            lastRefreshDate = .now
        } catch {
            withAnimation {
                self.error = error
            }
        }
    }

    private func fetchVideos(for service: TraktAPIService) async throws -> [Video] {
        return try await withCheckedThrowingContinuation { continuation in
            TraktAPIProvider.provider.request(service, callbackQueue: DispatchQueue.global(qos: .userInitiated)) { result in
                switch result {
                case .success(let moyaResponse):
                    do {
                        let response = try moyaResponse.filterSuccessfulStatusCodes()
                        let videos = try response.map([Video].self, using: TraktAPIProvider.decoder)
                        continuation.resume(returning: videos)
                    } catch {
                        continuation.resume(throwing: error)
                        print("Videos call error: \(error)")
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                    print("Videos call error: \(error)")
                }
            }
        }
    }
}

extension Video {
    var metaText: Text {
        if let type = type, let size = size, let publishedDate = publishedDate {
            return Text("\(type) · \(Text(size, format: .number.grouping(.never)))p · \(Text(publishedDate, style: .date))")
        } else if let type = type, let size = size {
            return Text("\(type) · \(Text(size, format: .number.grouping(.never)))p")
        } else if let type = type, let publishedDate = publishedDate {
            return Text("\(type) · \(Text(publishedDate, style: .date))")
        } else if let size = size, let publishedDate = publishedDate {
            return Text("\(Text(size, format: .number.grouping(.never)))p · \(Text(publishedDate, style: .date))")
        } else if let type = type {
            return Text("\(type)")
        } else if let size = size {
            return Text("\(Text(size, format: .number.grouping(.never)))p")
        } else if let publishedDate = publishedDate {
            return Text("\(Text(publishedDate, style: .date))")
        } else {
            return Text("")
        }
    }
}
