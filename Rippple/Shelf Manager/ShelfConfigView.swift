//
//  ShelfConfigView.swift
//  Rippple
//
//  Created by Kevin Cador on 02/09/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI

import Receiver

struct ShelfConfigView: View {
    @State var shelf = ShelfManager.shared.shelfModules

    @Environment(\.dismiss) var dismiss

    @StateObject fileprivate var router = NavigationManager()

    @State private var showingSheet = false

    private let disposeBag = DisposeBag()

    var body: some View {
        NavigationStack(path: $router.navPath) {
            ZStack(alignment: .bottom) {
                SwiftUI.List {
                    Section {
                        ForEach(shelf, id: \.self) { row in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(row.filter.name)
                                        .lineLimit(1)
                                    switch row.module {
                                    case "L1":
                                        Text("Standard Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "L2":
                                        Text("Bigger Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "L3":
                                        Text("Two Lines Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "T1":
                                        Text("Top Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "C1":
                                        Text("Carousel Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "G1":
                                        Text("Widget Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "ToWatch":
                                        Text("To Watch Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    case "In Review":
                                        Text("In Review")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    default:
                                        Text("Custom Style")
                                            .foregroundStyle(.secondary)
                                            .font(.caption)
                                    }
                                }.layoutPriority(1)
                                Button {
                                    router.navigate(to: .details(row))
                                } label: {
                                    EmptyView()
                                }
                            }
                        }.onMove { source, destination in
                            ShelfManager.shared.move(from: source, to: destination)
                        }.onDelete { indexSet in
                            ShelfManager.shared.delete(at: indexSet)
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            if shelf.isEmpty {
                                Text("Add Rows to Your Shelf")
                                    .font(.largeTitle)
                                    .bold()
                                Text("You'll then be able to customize and reorder them how you want.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Customize & Reorder")
                                    .font(.largeTitle)
                                    .bold()
                                Text("Customize, reorder, add or delete rows to personalize your shelf.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }.padding(.bottom)
                            .padding(.trailing, 50)
                    }
                }.listStyle(.grouped)
                    .headerProminence(.increased)
                    .contentMargins(.bottom, 100, for: .scrollContent)
                Button {
                    showingSheet.toggle()
                } label: {
                    Label("Add Rows", systemImage: "plus")
                        .padding([.trailing, .leading], 50)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(UIColor(asset: .globalTint).isLight == true ? .black : .white)
                }.buttonStyle(.glassProminent)
                    .controlSize(.extraLarge)
                    .buttonBorderShape(.capsule)
                    .padding(.bottom)
            }.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationDestination(for: NavigationManager.Destination.self) { destination in
                switch destination {
                case .details(let row):
                    ShelfRowConfigView(row: row)
                }
            }
            .sheet(isPresented: $showingSheet) {
                SheetView()
            }
            .onAppear {
                onShelfChangedReceiver.listen { _ in
                    self.shelf = ShelfManager.shared.shelfModules
                }.disposed(by: disposeBag)
            }
        }
    }
}

struct ShelfRowConfigView: View {
    @State var row: BrowseViewController.ModuleType

    @State private var name = ""
    @State private var selectedStyle = ""
    @State private var ignoreWatched = false

    private var previewModule: BrowseViewController.ModuleType {
        let updatedName = name
        let updatedQuery = updatedQuery(from: row.filter.query, ignoreWatched: ignoreWatched)
        let updatedFilter = SavedFilter(section: row.filter.section,
                                        name: updatedName,
                                        path: row.filter.path,
                                        query: updatedQuery,
                                        limit: row.filter.limit)
        let moduleId = selectedStyle
        return BrowseViewController.ModuleType(module: moduleId, filter: updatedFilter)
    }

    private func updatedQuery(from base: String, ignoreWatched: Bool) -> String {
        var parts = base.split(separator: "&").map(String.init).filter { !$0.lowercased().hasPrefix("ignore_watched=") }
        if ignoreWatched {
            parts.append("ignore_watched=true")
        }
        return parts.joined(separator: "&")
    }

    var body: some View {
        SwiftUI.List {
            Section {
                if row.filter.section != "in_review" {
                    TextField("Name", text: $name)
                }
                if row.filter.section == "episodes_to_watch" || row.filter.section == "pinned_to_watch" || row.filter.section == "unpinned_to_watch" {
                    Picker("Style", selection: $selectedStyle) {
                        Text("To Watch").tag("ToWatch")
                        Text("Widget").tag("G1")
                    }
                } else {
                    if selectedStyle == "L1" || selectedStyle == "L2" || selectedStyle == "L3" || selectedStyle == "T1" || selectedStyle == "C1" || selectedStyle == "G1" {
                        Picker("Style", selection: $selectedStyle) {
                            Text("Standard").tag("L1")
                            Text("Bigger").tag("L2")
                            Text("Two Lines").tag("L3")
                            Text("Top").tag("T1")
                            Text("Carousel").tag("C1")
                            Text("Widget").tag("G1")
                        }
                    }
                }
                if row.filter.canFilterWatched {
                    Toggle("Filter Watched", isOn: $ignoreWatched)
                        .tint(.accentColor)
                }
            } header: {
                VStack(alignment: .leading) {
                    Text("Customize")
                        .font(.largeTitle)
                        .bold()
                    Text("Personalize this item on your Shelf.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }.padding(.bottom)
                    .padding(.trailing, 50)
            } footer: {
                BrowseRowPreview(module: previewModule)
                    .frame(height: 320)
                    .padding(.top, 20)
                    .padding(.leading, -25)
            }
        }.listStyle(.insetGrouped)
            .headerProminence(.increased)
            .onAppear {
                name = row.filter.name
                selectedStyle = row.module
                ignoreWatched = row.filter.query.contains("ignore_watched=true")
            }
            .onDisappear {
                if name != row.filter.name || selectedStyle != row.module || ignoreWatched != row.filter.query.contains("ignore_watched=true") {
                    ShelfManager.shared.edit(module: row, with: name, and: selectedStyle, ignoringWatched: ignoreWatched)
                }
            }
    }
}

struct ShelfRowQuickConfigView: View {
    @Environment(\.dismiss) var dismiss

    @State var row: BrowseViewController.ModuleType

    @State private var name = ""
    @State private var debouncedName = ""
    @State private var selectedStyle = ""
    @State private var ignoreWatched = false

    private var previewModule: BrowseViewController.ModuleType {
        let updatedName = debouncedName
        let updatedQuery = updatedQuery(from: row.filter.query, ignoreWatched: ignoreWatched)
        let updatedFilter = SavedFilter(section: row.filter.section,
                                        name: updatedName,
                                        path: row.filter.path,
                                        query: updatedQuery,
                                        limit: row.filter.limit)
        let moduleId = selectedStyle
        return BrowseViewController.ModuleType(module: moduleId, filter: updatedFilter)
    }

    private func updatedQuery(from base: String, ignoreWatched: Bool) -> String {
        var parts = base.split(separator: "&").map(String.init).filter { !$0.lowercased().hasPrefix("ignore_watched=") }
        if ignoreWatched {
            parts.append("ignore_watched=true")
        }
        return parts.joined(separator: "&")
    }

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                Section {
                    TextField("Name", text: $name)
                        .task(id: $name.wrappedValue) {
                            try? await Task.sleep(for: .seconds(1.0))
                            guard !Task.isCancelled else { return }
                            debouncedName = name
                        }
                    if row.filter.section == "episodes_to_watch" || row.filter.section == "pinned_to_watch" || row.filter.section == "unpinned_to_watch" {
                        Picker("Style", selection: $selectedStyle) {
                            Text("To Watch").tag("ToWatch")
                            Text("Widget").tag("G1")
                        }
                    } else {
                        if selectedStyle == "L1" || selectedStyle == "L2" || selectedStyle == "L3" || selectedStyle == "T1" || selectedStyle == "C1" || selectedStyle == "G1" {
                            Picker("Style", selection: $selectedStyle) {
                                Text("Standard").tag("L1")
                                Text("Bigger").tag("L2")
                                Text("Two Lines").tag("L3")
                                Text("Top").tag("T1")
                                Text("Carousel").tag("C1")
                                Text("Widget").tag("G1")
                            }
                        }
                    }
                    if row.filter.canFilterWatched {
                        Toggle("Filter Watched", isOn: $ignoreWatched)
                            .tint(.accentColor)
                    }
                } footer: {
                    BrowseRowPreview(module: previewModule)
                        .frame(height: 320)
                        .padding(.top, 20)
                        .padding(.leading, -25)
                }
            }.listStyle(.insetGrouped)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .confirm) {
                            ShelfManager.shared.edit(module: row, with: name, and: selectedStyle, ignoringWatched: ignoreWatched)
                            dismiss()
                        }
                    }
                }.navigationTitle("Customize")
                .navigationSubtitle("Personalize this item on your Shelf")
                .navigationBarTitleDisplayMode(.inline)
        }.onAppear {
            name = row.filter.name
            debouncedName = row.filter.name
            selectedStyle = row.module
            ignoreWatched = row.filter.query.contains("ignore_watched=true")
        }
    }
}

struct BrowseRowPreview: UIViewControllerRepresentable {
    var module: BrowseViewController.ModuleType

    func makeUIViewController(context: Context) -> BrowseViewController {
        let vc = BrowseViewController()
        vc.view.isUserInteractionEnabled = false
        vc.view.clipsToBounds = false
        vc.tableView.isScrollEnabled = false
        vc.tableView.separatorStyle = .none
        vc.model = modelString(for: module)
        return vc
    }

    func updateUIViewController(_ uiViewController: BrowseViewController, context: Context) {
        uiViewController.model = modelString(for: module)
    }

    private func modelString(for module: BrowseViewController.ModuleType) -> String {
        let header = BrowseViewController.ModuleType(module: "Preview",
                                                     filter: SavedFilter(section: "",
                                                                         name: "",
                                                                         path: "",
                                                                         query: "",
                                                                         limit: nil))
        let encoder = JSONEncoder()
        guard let headerData = try? encoder.encode(header),
              let moduleData = try? encoder.encode(module),
              let headerString = String(data: headerData, encoding: .utf8),
              let moduleString = String(data: moduleData, encoding: .utf8) else {
            return ""
        }
        return "\(headerString)\n\(moduleString)"
    }
}

private final class NavigationManager: ObservableObject {

    public enum Destination: Codable, Hashable {
        case details(BrowseViewController.ModuleType)
    }

    @Published var navPath = NavigationPath()

    func navigate(to destination: Destination) {
        navPath.append(destination)
    }

    func navigateBack() {
        navPath.removeLast()
    }

    func navigateToRoot() {
        navPath.removeLast(navPath.count)
    }
}

struct SheetView: View {
    @Environment(\.dismiss) var dismiss

    @State var lists = ListsManager.shared.lists
    @State var savedFilters = [SavedFilter]()
    @State var showsSmartSearches = SmartSearch.smartSearches(for: .show)
    @State var moviesSmartSearches = SmartSearch.smartSearches(for: .movie)
    @State var collaborations = CollaborationsManager.shared.collaborations
    @State var likedLists = [List]()

    private let disposeBag = DisposeBag()

    @State private var refreshView = false

    private let watchlist = SavedFilter(section: "watchlist",
                                        name: "Watchlist",
                                        path: "/sync/watchlist",
                                        query: "",
                                        limit: 250)
    private let favorites = SavedFilter(section: "favorites",
                                        name: "Favorites",
                                        path: "/sync/favorites",
                                        query: "",
                                        limit: 250)

    //  { "module": "ToWatch", "filter": { "section": "episodes_to_watch", "name": "Up Next", "path": "", "query": "" } }
    private let toWatch = SavedFilter(section: "episodes_to_watch",
                                        name: "Up Next",
                                        path: "",
                                        query: "",
                                        limit: nil)
    private let moviesToWatch = SavedFilter(section: "movies_to_watch",
                                            name: "Movies To Watch",
                                            path: "",
                                            query: "",
                                            limit: nil)
    private let pinnedToWatch = SavedFilter(section: "pinned_to_watch",
                                      name: "Pinned Up Next",
                                      path: "",
                                      query: "",
                                      limit: nil)
    private let unpinnedToWatch = SavedFilter(section: "unpinned_to_watch",
                                      name: "Up Next",
                                      path: "",
                                      query: "",
                                      limit: nil)
    //  { "module": "History", "filter": { "section": "History", "name": "History", "path": "", "query": "" } }
    private let history = SavedFilter(section: "History",
                                        name: "History",
                                        path: "history",
                                        query: "",
                                        limit: nil)

    // { "module": "Comments", "filter": { "section": "comments", "name": "Comments", "path": "", "query": "" } }
    private let comments = SavedFilter(section: "comments",
                                       name: "Comments",
                                       path: "",
                                       query: "",
                                       limit: nil)

    // { "module": "In Review", "filter": { "section": "in_review", "name": "In Review", "path": "", "query": "" } }
    private let inReview = SavedFilter(section: "in_review",
                                       name: "Rewind: Go Back in Time",
                                       path: "",
                                       query: "",
                                       limit: nil)

    // { "module": "Services", "filter": { "section": "services", "name": "Streaming On", "path": "", "query": "" } }
    private let streamingOn = SavedFilter(section: "services",
                                       name: "Streaming On",
                                       path: "",
                                       query: "",
                                       limit: nil)

    // { "module": "L2", "filter": { "section": "shows", "name": "TV Shows Recommendations", "path": "/recommendations/shows", "query": "" } }
    private let tvRecommendations = SavedFilter(section: "shows",
                                       name: "TV Shows Recommendations",
                                       path: "/recommendations/shows",
                                       query: "",
                                       limit: nil)

    // { "module": "L2", "filter": { "section": "movies", "name": "Movies Recommendations", "path": "/recommendations/movies", "query": "" } }
    private let moviesRecommendations = SavedFilter(section: "movies",
                                       name: "Movies Recommendations",
                                       path: "/recommendations/movies",
                                       query: "",
                                       limit: nil)

    // { "module": "Genres", "filter": { "section": "genres-movies", "name": "By Genres", "path": "", "query": "" } }
    private let movieGenres = SavedFilter(section: "genres-movies",
                                       name: "Movies By Genres",
                                       path: "",
                                       query: "",
                                       limit: nil)

    // { "module": "Genres", "filter": { "section": "genres-shows", "name": "By Genres", "path": "", "query": "" } }
    private let tvGenres = SavedFilter(section: "genres-shows",
                                       name: "TV Shows By Genres",
                                       path: "",
                                       query: "",
                                       limit: nil)

    // { "module": "C1", "filter": { "section": "movies,shows", "name": "", "path": "/all/trending", "query": "" } }
    private let allTrending = SavedFilter(section: "movies,shows",
                                       name: "Trending TV Shows & Movies",
                                       path: "/all/trending",
                                       query: "",
                                       limit: nil)

    private let watchedMovies = SavedFilter(section: "WatchedItem",
                                          name: "Watched Movies",
                                          path: "/users/me/watched/movies",
                                          query: "",
                                          limit: nil)
    private let watchedShows = SavedFilter(section: "WatchedItem",
                                            name: "Watched TV Shows",
                                            path: "/users/me/watched/shows",
                                            query: "",
                                            limit: nil)

    private let droppedShows = SavedFilter(section: "DroppedShows",
                                           name: "Dropped TV Shows",
                                           path: "",
                                           query: "",
                                           limit: nil)
    private let pinnedShows = SavedFilter(section: "PinnedShows",
                                           name: "Pinned TV Shows",
                                           path: "",
                                           query: "",
                                           limit: nil)
    private let pinnedMovies = SavedFilter(section: "PinnedMovies",
                                           name: "Pinned Movies",
                                           path: "",
                                           query: "",
                                           limit: nil)
    private let completedShows = SavedFilter(section: "CompletedShows",
                                          name: "Completed TV Shows",
                                          path: "",
                                          query: "",
                                          limit: nil)

    private let collectedMovies = SavedFilter(section: "movies",
                                          name: "Movie Library",
                                          path: "/users/me/collection/movies",
                                          query: "",
                                          limit: nil)
    private let collectedShows = SavedFilter(section: "shows",
                                            name: "TV Show Library",
                                            path: "/users/me/collection/shows",
                                            query: "",
                                            limit: nil)

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                Section {
                    HStack {
                        if watchlist.isShelved {
                            Button {
                                watchlist.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                watchlist.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Watchlist")
                            .lineLimit(1)
                    }
                    HStack {
                        if favorites.isShelved {
                            Button {
                                favorites.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                favorites.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Favorites")
                            .lineLimit(1)
                    }
                    HStack {
                        if collectedMovies.isShelved {
                            Button {
                                collectedMovies.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                collectedMovies.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Movie Library")
                            .lineLimit(1)
                    }
                    HStack {
                        if collectedShows.isShelved {
                            Button {
                                collectedShows.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                collectedShows.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("TV Show Library")
                            .lineLimit(1)
                    }
                    HStack {
                        if watchedMovies.isShelved {
                            Button {
                                watchedMovies.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                watchedMovies.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Watched Movies")
                            .lineLimit(1)
                    }
                    HStack {
                        if watchedShows.isShelved {
                            Button {
                                watchedShows.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                watchedShows.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Watched TV Shows")
                            .lineLimit(1)
                    }
                    HStack {
                        if history.isShelved {
                            Button {
                                history.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                history.shelf(onTop: false, module: "History")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Watch History")
                            .lineLimit(1)
                    }
                } header: {
                    VStack(alignment: .leading) {
                        Text("Add Rows")
                            .font(.largeTitle)
                            .bold()
                        Text("Add lists, saved filters, smart searches and more to personalize your shelf.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.bottom)
                    }.padding(.trailing, 50)
                }

                Section {
                    HStack {
                        if toWatch.isShelved {
                            Button {
                                toWatch.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                toWatch.shelf(onTop: false, module: "ToWatch")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Episodes To Watch - All")
                            .lineLimit(1)
                    }
                    HStack {
                        if pinnedToWatch.isShelved {
                            Button {
                                pinnedToWatch.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                pinnedToWatch.shelf(onTop: false, module: "ToWatch")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Episodes To Watch - Pinned")
                            .lineLimit(1)
                    }
                    HStack {
                        if unpinnedToWatch.isShelved {
                            Button {
                                unpinnedToWatch.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                unpinnedToWatch.shelf(onTop: false, module: "ToWatch")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Episodes To Watch - Not Pinned")
                            .lineLimit(1)
                    }
                    HStack {
                        if pinnedShows.isShelved {
                            Button {
                                pinnedShows.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                pinnedShows.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Pinned TV Shows")
                            .lineLimit(1)
                    }
                    HStack {
                        if completedShows.isShelved {
                            Button {
                                completedShows.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                completedShows.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Completed TV Shows")
                            .lineLimit(1)
                    }
                    HStack {
                        if droppedShows.isShelved {
                            Button {
                                droppedShows.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                droppedShows.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Dropped TV Shows")
                            .lineLimit(1)
                    }
                } header: {
                    VStack(alignment: .leading) {
                        Text("TV Tracking")
                            .font(.callout)
                    }
                }

                Section {
                    HStack {
                        if moviesToWatch.isShelved {
                            Button {
                                moviesToWatch.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                moviesToWatch.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Movies To Watch")
                            .lineLimit(1)
                    }
                    HStack {
                        if pinnedMovies.isShelved {
                            Button {
                                pinnedMovies.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                pinnedMovies.shelf(onTop: false)
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Pinned Movies")
                            .lineLimit(1)
                    }
                } header: {
                    VStack(alignment: .leading) {
                        Text("Movie Tracking")
                            .font(.callout)
                    }
                }

                Section {
                    HStack {
                        if allTrending.isShelved {
                            Button {
                                allTrending.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                allTrending.shelf(onTop: false, module: "C1")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Trending TV Shows and Movies")
                            .lineLimit(1)
                    }

                    HStack {
                        if streamingOn.isShelved {
                            Button {
                                streamingOn.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                streamingOn.shelf(onTop: false, module: "Services")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Streaming On")
                            .lineLimit(1)
                    }

                    HStack {
                        if comments.isShelved {
                            Button {
                                comments.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                comments.shelf(onTop: false, module: "Comments")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Comments")
                            .lineLimit(1)
                    }

                    HStack {
                        if tvRecommendations.isShelved {
                            Button {
                                tvRecommendations.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                tvRecommendations.shelf(onTop: false, module: "L2")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("TV Shows Recommendations")
                            .lineLimit(1)
                    }

                    HStack {
                        if moviesRecommendations.isShelved {
                            Button {
                                moviesRecommendations.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                moviesRecommendations.shelf(onTop: false, module: "L2")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Movies Recommendations")
                            .lineLimit(1)
                    }

                    HStack {
                        if tvGenres.isShelved {
                            Button {
                                tvGenres.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                tvGenres.shelf(onTop: false, module: "Genres")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("TV Shows by Genres")
                            .lineLimit(1)
                    }

                    HStack {
                        if movieGenres.isShelved {
                            Button {
                                movieGenres.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                movieGenres.shelf(onTop: false, module: "Genres")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Movies by Genres")
                            .lineLimit(1)
                    }

                    HStack {
                        if inReview.isShelved {
                            Button {
                                inReview.unshelf()
                            } label: {
                                Label("Shelved", systemImage: "checkmark.circle.fill")
                            }.labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        } else {
                            Button {
                                inReview.shelf(onTop: false, module: "In Review")
                            } label: {
                                Label("Unshelved", systemImage: "circle")
                            }.tint(.secondary)
                                .labelStyle(.iconOnly)
                                .font(.title2)
                                .id(refreshView)
                        }
                        Text("Rewind: Your Stats")
                            .lineLimit(1)
                    }
                } header: {
                    VStack(alignment: .leading) {
                        Text("More to Explore")
                            .font(.callout)
                    }
                }

                if !savedFilters.isEmpty {
                    Section {
                        ForEach(savedFilters, id: \.self) { savedFilter in
                            HStack {
                                if savedFilter.isShelved {
                                    Button {
                                        savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(savedFilter.name)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("Saved Filters on Trakt")
                                .font(.callout)
                        }
                    }
                }

                if !showsSmartSearches.isEmpty {
                    Section {
                        ForEach(showsSmartSearches, id: \.self) { smartSearch in
                            HStack {
                                if smartSearch.savedFilter.isShelved {
                                    Button {
                                        smartSearch.savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        smartSearch.savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(smartSearch.name ?? "A Smart Search")
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("TV Shows Smart Searches")
                                .font(.callout)
                        }
                    }
                }

                if !moviesSmartSearches.isEmpty {
                    Section {
                        ForEach(moviesSmartSearches, id: \.self) { smartSearch in
                            HStack {
                                if smartSearch.savedFilter.isShelved {
                                    Button {
                                        smartSearch.savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        smartSearch.savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(smartSearch.name ?? "A Smart Search")
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("Movies Smart Searches")
                                .font(.callout)
                        }
                    }
                }

                if !lists.isEmpty {
                    Section {
                        ForEach(lists, id: \.self) { list in
                            HStack {
                                if list.savedFilter.isShelved {
                                    Button {
                                        list.savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        list.savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(list.name)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("Your Lists")
                                .font(.callout)
                        }
                    }
                }

                if !likedLists.isEmpty {
                    Section {
                        ForEach(likedLists, id: \.self) { likedList in
                            HStack {
                                if likedList.savedFilter.isShelved {
                                    Button {
                                        likedList.savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        likedList.savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(likedList.name)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("Liked Lists")
                                .font(.callout)
                        }
                    }
                }

                if !collaborations.isEmpty {
                    Section {
                        ForEach(collaborations, id: \.self) { collaboration in
                            HStack {
                                if collaboration.savedFilter.isShelved {
                                    Button {
                                        collaboration.savedFilter.unshelf()
                                    } label: {
                                        Label("Shelved", systemImage: "checkmark.circle.fill")
                                    }.labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                } else {
                                    Button {
                                        collaboration.savedFilter.shelf(onTop: false)
                                    } label: {
                                        Label("Unshelved", systemImage: "circle")
                                    }.tint(.secondary)
                                        .labelStyle(.iconOnly)
                                        .font(.title2)
                                        .id(refreshView)
                                }
                                Text(collaboration.name)
                                    .lineLimit(1)
                            }
                        }
                    } header: {
                        VStack(alignment: .leading) {
                            Text("Collaborations")
                                .font(.callout)
                        }
                    }
                }
            }.listStyle(.grouped)
                .headerProminence(.increased)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .close) {
                            dismiss()
                        }
                    }
                }
        }.onAppear {
            onSavedFiltersChangedReceiver.listen { savedFilters in
                self.savedFilters = savedFilters
            }.disposed(by: disposeBag)

            onShowSmartSearchChangedReceiver.listen { _ in
                self.showsSmartSearches = SmartSearch.smartSearches(for: .show)
            }.disposed(by: disposeBag)

            onMovieSmartSearchChangedReceiver.listen { _ in
                self.moviesSmartSearches = SmartSearch.smartSearches(for: .movie)
            }.disposed(by: disposeBag)

            onCustomListsChangedReceiver.hotOnly().listen { _ in
                self.lists = ListsManager.shared.lists
            }.disposed(by: disposeBag)

            onShelfChangedReceiver.hotOnly().listen { _ in
                self.refreshView.toggle()
            }.disposed(by: disposeBag)

            onCollaborationsChangedReceiver.hotOnly().listen { _ in
                self.collaborations = CollaborationsManager.shared.collaborations
            }.disposed(by: disposeBag)

            onLikedListsChangedReceiver.listen { likedLists in
                self.likedLists = likedLists
            }.disposed(by: disposeBag)
        }
    }
}

#Preview {
    ShelfConfigView()
}
