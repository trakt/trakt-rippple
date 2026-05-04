//
//  ShelfConfigView.swift
//  Rippple
//
//  Created by Kevin Cador on 02/09/2024.
//  Copyright © 2024 Trakt. All rights reserved.
//

import SwiftUI

import Receiver

private struct ShelfSortOption: Hashable {
    let id: String
    let label: String
}

private struct ShelfQueryValues {
    let ignoreWatched: Bool
    let sort: ShelfSortConfiguration
}

private let shelfSortByOptions: [ShelfSortOption] = [
    ShelfSortOption(id: "", label: "Default"),
    ShelfSortOption(id: "rank", label: "Rank"),
    ShelfSortOption(id: "added", label: "Added"),
    ShelfSortOption(id: "my_rating", label: "My Rating"),
    ShelfSortOption(id: "watched", label: "Watched"),
    ShelfSortOption(id: "title", label: "Title"),
    ShelfSortOption(id: "released", label: "Released"),
    ShelfSortOption(id: "runtime", label: "Runtime"),
    ShelfSortOption(id: "popularity", label: "Popularity"),
    ShelfSortOption(id: "random", label: "Random"),
    ShelfSortOption(id: "percentage", label: "Percentage"),
    ShelfSortOption(id: "imdb_rating", label: "IMDb Rating"),
    ShelfSortOption(id: "tmdb_rating", label: "TMDb Rating"),
    ShelfSortOption(id: "rt_tomatometer", label: "RT Tomatometer"),
    ShelfSortOption(id: "rt_audience", label: "RT Audience"),
    ShelfSortOption(id: "metascore", label: "Metascore"),
    ShelfSortOption(id: "votes", label: "Votes"),
    ShelfSortOption(id: "imdb_votes", label: "IMDb Votes"),
    ShelfSortOption(id: "tmdb_votes", label: "TMDb Votes")
]

private let shelfSortHowOptions = ["", "asc", "desc"]

private func shelfQueryValues(from query: String) -> ShelfQueryValues {
    let values = query.split(separator: "&").reduce(into: [String: String]()) { dict, part in
        let pieces = part.split(separator: "=", maxSplits: 1).map(String.init)
        guard let key = pieces.first?.lowercased() else { return }
        dict[key] = pieces.count > 1 ? pieces[1] : ""
    }
    let sortBy = values["sort_by"].flatMap { raw in
        shelfSortByOptions.contains(where: { $0.id == raw }) ? raw : nil
    } ?? ""
    let sortHow = values["sort_how"].flatMap { raw in
        shelfSortHowOptions.contains(raw) ? raw : nil
    } ?? ""
    return ShelfQueryValues(ignoreWatched: values["ignore_watched"] == "true",
                            sort: ShelfSortConfiguration(by: sortBy, how: sortHow))
}

private func updatedShelfQuery(from base: String,
                               ignoreWatched: Bool,
                               sort: ShelfSortConfiguration) -> String {
    var parts = base.split(separator: "&").map(String.init).filter {
        let part = $0.lowercased()
        return !part.hasPrefix("ignore_watched=") && !part.hasPrefix("sort_by=") && !part.hasPrefix("sort_how=")
    }
    if ignoreWatched {
        parts.append("ignore_watched=true")
    }
    if !sort.by.isEmpty && !sort.how.isEmpty {
        parts.append("sort_by=\(sort.by)")
        parts.append("sort_how=\(sort.how)")
    }
    return parts.joined(separator: "&")
}

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
                                    case "List":
                                        Text("List Style")
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
    @State private var sortBy = ""
    @State private var sortHow = ""
    @State private var buttonStyle: ShelfBrowseActionButtonStyle = .none

    private var previewModule: BrowseViewController.ModuleType {
        let updatedName = name
        let updatedQuery = updatedShelfQuery(from: row.filter.query,
                                             ignoreWatched: ignoreWatched,
                                             sort: ShelfSortConfiguration(by: sortBy,
                                                                          how: sortHow))
        let updatedFilter = SavedFilter(section: row.filter.section,
                                        name: updatedName,
                                        path: row.filter.path,
                                        query: updatedQuery,
                                        limit: row.filter.limit)
        let moduleId = selectedStyle
        return BrowseViewController.ModuleType(module: moduleId,
                                               filter: updatedFilter,
                                               buttonStyle: buttonStyle == .none ? nil : buttonStyle)
    }

    private var currentConfiguration: ShelfModuleEditConfiguration {
        ShelfModuleEditConfiguration(name: name,
                                     module: selectedStyle,
                                     ignoresWatched: ignoreWatched,
                                     sort: ShelfSortConfiguration(by: sortBy,
                                                                  how: sortHow),
                                     buttonStyle: buttonStyle)
    }

    private func persistCurrentConfiguration() {
        let updatedModule = previewModule
        ShelfManager.shared.edit(module: row, with: currentConfiguration)
        row = updatedModule
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
                    if selectedStyle == "L1" || selectedStyle == "L2" || selectedStyle == "L3" || selectedStyle == "T1" || selectedStyle == "C1" || selectedStyle == "G1" || selectedStyle == "List" {
                        Picker("Style", selection: $selectedStyle) {
                            Text("Standard").tag("L1")
                            Text("Bigger").tag("L2")
                            Text("Two Lines").tag("L3")
                            Text("Top").tag("T1")
                            Text("Carousel").tag("C1")
                            Text("Widget").tag("G1")
                            Text("List").tag("List")
                        }
                    }
                }
                if row.filter.canFilterWatched {
                    Toggle("Filter Watched", isOn: $ignoreWatched)
                        .tint(.accentColor)
                }
                if row.filter.canSort {
                    Picker("Sort by", selection: $sortBy) {
                        ForEach(shelfSortByOptions, id: \.self) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    Picker("Sort order", selection: $sortHow) {
                        ForEach(shelfSortHowOptions, id: \.self) { option in
                            Text(option == "" ? "Default" : (option == "asc" ? "Ascending" : "Descending")).tag(option)
                        }
                    }
                }
                if selectedStyle == "G1" || selectedStyle == "ToWatch" || selectedStyle == "List" {
                    Picker("Button", selection: $buttonStyle) {
                        ForEach(ShelfBrowseActionButtonStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: BrowseRowPreview.height(for: previewModule))
                    .padding(.top, 20)
                    .padding(.leading, -25)
            }
        }.listStyle(.insetGrouped)
            .headerProminence(.increased)
            .onAppear {
                name = row.filter.name
                selectedStyle = row.module
                let queryValues = shelfQueryValues(from: row.filter.query)
                ignoreWatched = queryValues.ignoreWatched
                sortBy = queryValues.sort.by
                sortHow = queryValues.sort.how
                buttonStyle = row.buttonStyle ?? .none
            }
            .onChange(of: sortBy) { _, newValue in
                if newValue.isEmpty {
                    if !sortHow.isEmpty {
                        sortHow = ""
                    }
                } else if sortHow.isEmpty {
                    sortHow = shelfSortHowOptions.first(where: { !$0.isEmpty }) ?? "asc"
                }
            }
            .onChange(of: sortHow) { _, newValue in
                if newValue.isEmpty {
                    if !sortBy.isEmpty {
                        sortBy = ""
                    }
                } else if sortBy.isEmpty {
                    sortBy = shelfSortByOptions.first(where: { !$0.id.isEmpty })?.id ?? "rank"
                }
            }
            .onChange(of: buttonStyle) {
                persistCurrentConfiguration()
            }
            .onDisappear {
                let originalQuery = shelfQueryValues(from: row.filter.query)
                let originalButtonStyle = row.buttonStyle ?? .none
                let queryChanged = ignoreWatched != originalQuery.ignoreWatched ||
                    sortBy != originalQuery.sort.by ||
                    sortHow != originalQuery.sort.how
                let rowChanged = name != row.filter.name ||
                    selectedStyle != row.module ||
                    buttonStyle != originalButtonStyle

                if rowChanged || queryChanged {
                    persistCurrentConfiguration()
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
    @State private var sortBy = ""
    @State private var sortHow = ""
    @State private var buttonStyle: ShelfBrowseActionButtonStyle = .none

    private var previewModule: BrowseViewController.ModuleType {
        let updatedName = debouncedName
        let updatedQuery = updatedShelfQuery(from: row.filter.query,
                                             ignoreWatched: ignoreWatched,
                                             sort: ShelfSortConfiguration(by: sortBy,
                                                                          how: sortHow))
        let updatedFilter = SavedFilter(section: row.filter.section,
                                        name: updatedName,
                                        path: row.filter.path,
                                        query: updatedQuery,
                                        limit: row.filter.limit)
        let moduleId = selectedStyle
        return BrowseViewController.ModuleType(module: moduleId,
                                               filter: updatedFilter,
                                               buttonStyle: buttonStyle == .none ? nil : buttonStyle)
    }

    private var currentConfiguration: ShelfModuleEditConfiguration {
        ShelfModuleEditConfiguration(name: name,
                                     module: selectedStyle,
                                     ignoresWatched: ignoreWatched,
                                     sort: ShelfSortConfiguration(by: sortBy,
                                                                  how: sortHow),
                                     buttonStyle: buttonStyle)
    }

    private func persistCurrentConfiguration() {
        let updatedModule = BrowseViewController.ModuleType(module: selectedStyle,
                                                           filter: SavedFilter(section: row.filter.section,
                                                                               name: name,
                                                                               path: row.filter.path,
                                                                               query: updatedShelfQuery(from: row.filter.query,
                                                                                                         ignoreWatched: ignoreWatched,
                                                                                                         sort: ShelfSortConfiguration(by: sortBy,
                                                                                                                                      how: sortHow)),
                                                                               limit: row.filter.limit),
                                                           buttonStyle: buttonStyle == .none ? nil : buttonStyle)
        ShelfManager.shared.edit(module: row, with: currentConfiguration)
        row = updatedModule
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
                        if selectedStyle == "L1" || selectedStyle == "L2" || selectedStyle == "L3" || selectedStyle == "T1" || selectedStyle == "C1" || selectedStyle == "G1" || selectedStyle == "List" {
                            Picker("Style", selection: $selectedStyle) {
                                Text("Standard").tag("L1")
                                Text("Bigger").tag("L2")
                                Text("Two Lines").tag("L3")
                                Text("Top").tag("T1")
                                Text("Carousel").tag("C1")
                                Text("Widget").tag("G1")
                                Text("List").tag("List")
                            }
                        }
                    }
                    if row.filter.canFilterWatched {
                        Toggle("Filter Watched", isOn: $ignoreWatched)
                            .tint(.accentColor)
                    }
                    if row.filter.canSort {
                        Picker("Sort by", selection: $sortBy) {
                            ForEach(shelfSortByOptions, id: \.self) { option in
                                Text(option.label).tag(option.id)
                            }
                        }
                        Picker("Sort order", selection: $sortHow) {
                            ForEach(shelfSortHowOptions, id: \.self) { option in
                                Text(option == "" ? "Default" : (option == "asc" ? "Ascending" : "Descending")).tag(option)
                            }
                        }
                    }
                    if selectedStyle == "G1" || selectedStyle == "ToWatch" || selectedStyle == "List" {
                        Picker("Button", selection: $buttonStyle) {
                            ForEach(ShelfBrowseActionButtonStyle.allCases, id: \.self) { style in
                                Text(style.label).tag(style)
                            }
                        }
                    }
                } footer: {
                    BrowseRowPreview(module: previewModule)
                        .frame(height: BrowseRowPreview.height(for: previewModule))
                        .padding(.top, 20)
                        .padding(.leading, -40)
                        .padding(.trailing, -40)
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
                            persistCurrentConfiguration()
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
            let queryValues = shelfQueryValues(from: row.filter.query)
            ignoreWatched = queryValues.ignoreWatched
            sortBy = queryValues.sort.by
            sortHow = queryValues.sort.how
            buttonStyle = row.buttonStyle ?? .none
        }
        .onChange(of: sortBy) { _, newValue in
            if newValue.isEmpty {
                if !sortHow.isEmpty {
                    sortHow = ""
                }
            } else if sortHow.isEmpty {
                sortHow = shelfSortHowOptions.first(where: { !$0.isEmpty }) ?? "asc"
            }
        }
        .onChange(of: sortHow) { _, newValue in
            if newValue.isEmpty {
                if !sortBy.isEmpty {
                    sortBy = ""
                }
            } else if sortBy.isEmpty {
                sortBy = shelfSortByOptions.first(where: { !$0.id.isEmpty })?.id ?? "rank"
            }
        }
        .onChange(of: buttonStyle) {
            persistCurrentConfiguration()
        }
    }
}

struct BrowseRowPreview: UIViewControllerRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    var module: BrowseViewController.ModuleType

    static func height(for module: BrowseViewController.ModuleType) -> CGFloat {
        let contentHeight: CGFloat = switch module.module {
        case "L1":
            150
        case "L2", "L3":
            250
        case "T1":
            200
        case "C1":
            198
        case "G1":
            220
        case "List":
            240
        case "ToWatch", "History":
            171
        default:
            220
        }

        return contentHeight + 50 // 50 to be safe
    }

    func makeUIViewController(context: Context) -> BrowseViewController {
        let viewController = BrowseViewController()
        viewController.view.isUserInteractionEnabled = false
        viewController.view.clipsToBounds = true
        viewController.tableView.isScrollEnabled = false
        viewController.tableView.separatorStyle = .none
        viewController.view.backgroundColor = .clear
        viewController.tableView.backgroundColor = .clear
        applyAppearance(to: viewController)
        viewController.model = modelString(for: module)
        return viewController
    }

    func updateUIViewController(_ uiViewController: BrowseViewController, context: Context) {
        applyAppearance(to: uiViewController)
        uiViewController.model = modelString(for: module)
    }

    private func applyAppearance(to viewController: BrowseViewController) {
        viewController.overrideUserInterfaceStyle = resolvedUserInterfaceStyle
        viewController.view.overrideUserInterfaceStyle = resolvedUserInterfaceStyle
        viewController.tableView.overrideUserInterfaceStyle = resolvedUserInterfaceStyle
    }

    private var resolvedUserInterfaceStyle: UIUserInterfaceStyle {
        switch colorScheme {
        case .dark:
            return .dark
        case .light:
            return .light
        @unknown default:
            return .unspecified
        }
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
