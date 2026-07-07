//
//  DeepLinksView.swift
//  Rippple
//
//  Created by Kevin Cador on 06/01/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/*

 *Comments*
 ripl://comments/142442 -> Episode
 ripl://comments/161705 -> Season
 ripl://comments/157283 -> Show
 ripl://comments/160618 -> Movie
 ripl://comments/128216 -> List
 ripl://comments/140812 -> Reply

 *People, Shows, Movies, Users*
 ripl://people/quentin-krog -> Ok
 ripl://shows/star-trek-discovery -> Ok
 ripl://shows/star-trek-discovery/seasons/1/episodes/1 -> Ok
 ripl://movies/thor-ragnarok-2017 -> Ok
 ripl://users/kcador -> Ok

 *TMDb*
 ripl://tmdb/shows/97546 -> Ok
 ripl://tmdb/shows/97546/seasons/3 -> Ok
 ripl://tmdb/shows/97546/seasons/3/episodes/2 -> Ok
 ripl://tmdb/people/58224 -> Ok
 ripl://tmdb/movies/502356 -> Ok

 *Rippple*
 ripl:// -> Just open Rippple
 ripl://whatsnew -> Ok
 ripl://settings/notifications -> Ok

 *Search*
 ripl://search/[query]

 */

private struct DeeplinkInfo: Hashable {
    let title: String
    let subtitle: String
    let url: String
    let deeplink: String

    static var navigationDatasource: [DeeplinkInfo] {
        return [DeeplinkInfo(title: "Search",
                             subtitle: "Open the search screen and put the focus on the search field. If you give it a _query_, the search field will be populated with that text.",
                             url: "`ripl://search/_query_`",
                             deeplink: "ripl://search/Pulp Fiction"),
                DeeplinkInfo(title: "Episodes To Watch",
                             subtitle: "Open your Episodes To Watch.",
                             url: "`ripl://towatch/episodes`",
                             deeplink: "ripl://towatch/episodes"),
                DeeplinkInfo(title: "Movies To Watch",
                             subtitle: "Open your Movies To Watch.",
                             url: "`ripl://towatch/movies`",
                             deeplink: "ripl://towatch/movies"),
                DeeplinkInfo(title: "History",
                             subtitle: "Open your History.",
                             url: "`ripl://history`",
                             deeplink: "ripl://history"),
                DeeplinkInfo(title: "Calendar",
                             subtitle: "Open the Calendar.",
                             url: "`ripl://calendar`",
                             deeplink: "ripl://calendar")]
    }

    static var contentDatasource: [DeeplinkInfo] {
        return [DeeplinkInfo(title: "Movie",
                             subtitle: "Open a movie. Supports _id_ or _slug_.",
                             url: "`ripl://movies/_slug_`",
                             deeplink: "ripl://movies/the-matrix-1999"),
                DeeplinkInfo(title: "Show",
                             subtitle: "Open a TV show. Supports _id_ or _slug_.",
                             url: "`ripl://shows/_slug_`",
                             deeplink: "ripl://trakt/shows/rick-and-morty"),
                DeeplinkInfo(title: "Season",
                             subtitle: "Open the list of all episodes for the show scrolled on the specified season's _number_. Supports TV shows _id_ or _slug_.",
                             url: "`ripl://shows/_slug_/seasons/_number_`",
                             deeplink: "ripl://shows/breaking-bad/seasons/2"),
                DeeplinkInfo(title: "Episode",
                             subtitle: "Open an episode on the specified season's and episode's _number_. Supports TV shows _id_ or _slug_",
                             url: "`ripl://shows/_slug_/seasons/_number_/episodes/_number_`",
                             deeplink: "ripl://shows/the-office/seasons/4/episodes/3"),
                DeeplinkInfo(title: "People, Cast and Crew",
                             subtitle: "Open a people's view with cast and crew information. Supports _id_ or _slug_.",
                             url: "`ripl://people/_slug_`",
                             deeplink: "ripl://people/quentin-tarantino"),
                DeeplinkInfo(title: "Comment",
                             subtitle: "Open a specific comment and its replies with the given comment's Trakt _id_. Supports movie, TV show, season and episode comment's _id_. The comment can be a review, a shout and even a reply to another comment.",
                             url: "`ripl://comments/_id_`",
                             deeplink: "ripl://comments/327791"),
                DeeplinkInfo(title: "Trakt User",
                             subtitle: "Open a user profile giving the slugified username.",
                             url: "`ripl://users/_slug_`",
                             deeplink: "ripl://users/kcador"),
                DeeplinkInfo(title: "List",
                             subtitle: "Open a user's list. All you need is the _user_'s username slug (or 'me' if it's your list) and the _list_'s slug or id.",
                             url: "`ripl://users/_user_/lists/_list_`",
                             deeplink: "ripl://users/kcador/lists/highlights")]
    }

    static var tmdbDatasource: [DeeplinkInfo] {
        return [DeeplinkInfo(title: "Movie",
                             subtitle: "Open a movie. Supports TMDb _id_.",
                             url: "`ripl://tmdb/movies/_id_`",
                             deeplink: "ripl://tmdb/movies/502356"),
                DeeplinkInfo(title: "Show",
                             subtitle: "Open a TV show. Supports TMDb _id_.",
                             url: "`ripl://tmdb/shows/_id_`",
                             deeplink: "ripl://tmdb/shows/97546"),
                DeeplinkInfo(title: "Season",
                             subtitle: "Open the list of all episodes for the show scrolled on the specified season's _number_. Supports TMDb _id_.",
                             url: "`ripl://tmdb/shows/_id_/seasons/_number_`",
                             deeplink: "ripl://tmdb/shows/97546/seasons/3"),
                DeeplinkInfo(title: "Episode",
                             subtitle: "Open an episode on the specified season's and episode's _number_. Supports TMDb _id_",
                             url: "`ripl://tmdb/shows/_id_/seasons/_number_/episodes/_number_`",
                             deeplink: "ripl://tmdb/shows/97546/seasons/3/episodes/2"),
                DeeplinkInfo(title: "People, Cast and Crew",
                             subtitle: "Open a people's view with cast and crew information. Supports TMDb _id_.",
                             url: "`ripl://tmdb/people/_id_`",
                             deeplink: "ripl://tmdb/people/58224")]
    }
}

struct DeepLinksView: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        SwiftUI.List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(Image(systemName: "square.2.layers.3d")) About Deeplinks")
                        .font(.headline)
                    Text("""
                    Deeplinks are shortcuts urls that can take you directly to a specific part of the app when you tap them from a message, a website or from other apps like Shortcuts, Siri or other TV and movie trackers.
                    It saves time by skipping through the app's homepage and directly lands you where you need to be, making it easier to access content without navigating manually.
                    """).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(.vertical, 6)
            Section {
                ForEach(DeeplinkInfo.navigationDatasource, id: \.self) { deeplinkInfo in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(deeplinkInfo.title)
                            .font(.headline)
                        Text(.init(deeplinkInfo.subtitle))
                        Text(.init(deeplinkInfo.url))
                            .font(.subheadline)
                            .foregroundStyle(Color(UIColor(asset: .globalTint)))
                        HStack(alignment: .center, spacing: 5) {
                            Button {
                                openURL(URL(string: deeplinkInfo.deeplink)!)
                            } label: {
                                Text("Test it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                            Button {
                                UIPasteboard.general.string = deeplinkInfo.deeplink
                            } label: {
                                Text("Copy it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                }
            }.padding(.vertical, 6)
            Section {
                ForEach(DeeplinkInfo.contentDatasource, id: \.self) { deeplinkInfo in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(deeplinkInfo.title)
                            .font(.headline)
                        Text(.init(deeplinkInfo.subtitle))
                        Text(.init(deeplinkInfo.url))
                            .font(.subheadline)
                            .foregroundStyle(Color(UIColor(asset: .globalTint)))
                        HStack(alignment: .center, spacing: 5) {
                            Button {
                                openURL(URL(string: deeplinkInfo.deeplink)!)
                            } label: {
                                Text("Test it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                            Button {
                                UIPasteboard.general.string = deeplinkInfo.deeplink
                            } label: {
                                Text("Copy it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                }
            }.padding(.vertical, 6)
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Base URL")
                        .font(.headline)
                    Text("""
                    You can use \(Text("`ripl://`").font(.subheadline.bold())), \(Text("`ripl://trakt/`").font(.subheadline.bold())) or \(Text("`ripl://app.trakt.tv/`").font(.subheadline.bold())) as base URL for Rippple's deeplinks.
                    This means the following will work the same for movies, episodes, comments,...
                    """).font(.subheadline)
                    Text("`ripl://comments/_id_`")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor(asset: .globalTint)))
                    HStack(alignment: .center, spacing: 5) {
                        Button {
                            openURL(URL(string: "ripl://comments/327791")!)
                        } label: {
                            Text("Test it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                        Button {
                            UIPasteboard.general.string = "ripl://comments/327791"
                        } label: {
                            Text("Copy it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                    }
                    Text("`ripl://trakt/comments/_id_`")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor(asset: .globalTint)))
                    HStack(alignment: .center, spacing: 5) {
                        Button {
                            openURL(URL(string: "ripl://trakt/comments/327791")!)
                        } label: {
                            Text("Test it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                        Button {
                            UIPasteboard.general.string = "ripl://trakt/comments/327791"
                        } label: {
                            Text("Copy it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                    }
                    Text("`ripl://app.trakt.tv/comments/_id_`")
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor(asset: .globalTint)))
                    HStack(alignment: .center, spacing: 5) {
                        Button {
                            openURL(URL(string: "ripl://app.trakt.tv/comments/327791")!)
                        } label: {
                            Text("Test it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                        Button {
                            UIPasteboard.general.string = "ripl://app.trakt.tv/comments/327791"
                        } label: {
                            Text("Copy it")
                                .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                        }.buttonStyle(.borderedProminent)
                    }
                }
            }.padding(.vertical, 6)
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TMDb")
                        .font(.headline)
                    Text("""
                    If you are working with TMDb identifiers, you can use `ripl://tmdb/` to force Rippple to use TMDb as a source. This works with TV shows, seasons, episodes, movies and people. Won't work with comments and users.
                    """)
                }
                ForEach(DeeplinkInfo.tmdbDatasource, id: \.self) { deeplinkInfo in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(deeplinkInfo.title)
                            .font(.headline)
                        Text(.init(deeplinkInfo.subtitle))
                        Text(.init(deeplinkInfo.url))
                            .font(.subheadline)
                            .foregroundStyle(Color(UIColor(asset: .globalTint)))
                        HStack(alignment: .center, spacing: 5) {
                            Button {
                                openURL(URL(string: deeplinkInfo.deeplink)!)
                            } label: {
                                Text("Test it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                            Button {
                                UIPasteboard.general.string = deeplinkInfo.deeplink
                            } label: {
                                Text("Copy it")
                                    .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                            }.buttonStyle(.borderedProminent)
                        }
                    }
                }
            }.padding(.vertical, 6)
        }.listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
    }
}

#Preview {
    DeepLinksView()
}
