//
//  OpenInSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 18/03/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import SwiftUI

import Receiver

struct OpenInSettingsView: View {
    @State private var customActions: [CustomOpenAction] = []
    @State private var builtInActions: [BuiltInOpenAction] = []

    @State private var editorState: EditorState?
    @State private var editMode: EditMode = .inactive
    @State private var pendingDeletionOffsets: IndexSet?
    @State private var isShowingDeleteConfirmation = false

    @Environment(\.dismiss) private var dismiss

    private let disposeBag = DisposeBag()

    private struct EditorState: Identifiable {
        let id = UUID()
        let action: CustomOpenAction
        let isNew: Bool
    }

    var body: some View {
        NavigationStack {
            SwiftUI.List {
                Section {
                    Text("Manage your \"Open In\" actions. You can create new custom actions that appear on movie, show, season, and episode detail screens. Each action uses a URL template with variables like \(OpenActionVariable.tmdbId.placeholder) or \(OpenActionVariable.title.placeholder).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Built-in Actions") {
                    ForEach(builtInActions.indices, id: \.self) { index in
                        let action = builtInActions[index]
                        builtInRow(for: action, isEnabled: $builtInActions[index].enabled)
                    }
                }

                Section {
                    ForEach(customActions) { action in
                        Button {
                            editorState = EditorState(action: action, isNew: false)
                        } label: {
                            customRow(for: action)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .contentShape(Rectangle())
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)

                    HStack(alignment: .center) {
                        Button {
                            editorState = EditorState(action: CustomOpenAction(name: "", urlTemplate: "", mediaTypes: []), isNew: true)
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("New Action")
                            }
                        }.buttonStyle(.bordered)
                    }
                } header: {
                    HStack {
                        Text("Custom Actions")
                        Spacer()
                        if !customActions.isEmpty {
                            Button(editMode.isEditing ? "Done" : "Edit") {
                                withAnimation {
                                    editMode = editMode.isEditing ? .inactive : .active
                                }
                            }.font(.callout)
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Open In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
            .onAppear {
                customActions = OpenActionManager.shared.customOpenActions
                builtInActions = BuiltInOpenAction.allCases
            }
            .task {
                onCustomOpenActionsChangedReceiver.listen { _ in
                    DispatchQueue.main.async {
                        self.customActions = OpenActionManager.shared.customOpenActions
                        self.builtInActions = BuiltInOpenAction.allCases
                    }
                }.disposed(by: disposeBag)

                onBuiltInOpenActionsChangedReceiver.listen { _ in
                    DispatchQueue.main.async {
                        self.customActions = OpenActionManager.shared.customOpenActions
                        self.builtInActions = BuiltInOpenAction.allCases
                    }
                }.disposed(by: disposeBag)
            }
            .onChange(of: customActions) { _, newValue in
                OpenActionManager.shared.customOpenActions = newValue
            }
            .environment(\.editMode, $editMode)
            .alert("Sure you want to Delete?", isPresented: $isShowingDeleteConfirmation, presenting: pendingDeletionOffsets) { offsets in
                Button("Delete", role: .destructive) {
                    customActions.remove(atOffsets: offsets)
                }
                Button("Cancel", role: .cancel) { }
            } message: { _ in
                Text("This will delete the custom \"Open In\" action. This cannot be undone.")
            }
            .sheet(item: $editorState) { state in
                OpenInItemEditView(action: state.action,
                                   isNew: state.isNew,
                                   onSave: { updated in
                    if state.isNew {
                        customActions.append(updated)
                        return
                    }
                    if let idx = customActions.firstIndex(where: { $0.id == updated.id }) {
                        customActions[idx] = updated
                    }
                }, onDelete: {
                    customActions.removeAll { $0.id == state.action.id }
                })
#if targetEnvironment(macCatalyst)
                .frame(minWidth: 620, minHeight: 720)
#endif
            }
        }
    }

    private func builtInRow(for action: BuiltInOpenAction, isEnabled: Binding<Bool>) -> some View {
        Toggle(isOn: isEnabled) {
            HStack(spacing: 12) {
                Image(systemName: action.systemImageName)
                    .font(.title2)
                    .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                    .frame(width: 32, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(action.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }.tint(Color(uiColor: UIColor(asset: .globalTint)))
            .toggleStyle(.switch)
    }

    private func customRow(for item: CustomOpenAction) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.systemImageName)
                .font(.title2)
                .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(item.urlTemplate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        pendingDeletionOffsets = offsets
        isShowingDeleteConfirmation = true
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        customActions.move(fromOffsets: source, toOffset: destination)
    }
}

// MARK: - Edit view

struct OpenInItemEditView: View {
    let action: CustomOpenAction
    let isNew: Bool
    let onSave: (CustomOpenAction) -> Void
    let onDelete: () -> Void

    @State private var name: String = ""
    @State private var urlTemplate: String = ""
    @State private var urlTemplateSelection: TextSelection?
    @State private var mediaTypes: Set<OpenActionMediaType> = []
    @State private var systemImageName: String = "arrow.up.forward"
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false

    private let suggestedSymbols = [
        "link", "safari", "arrow.up.forward", "play.circle.fill", "tv",
        "film", "rectangle.on.rectangle", "square.and.arrow.up", "play.tv", "arrow.down.circle"
    ]

    private let suggestedStrings = [
        "https://", "movie", "show", "series", "tv", "episode", "season", "search", "=", "&", "/", "?"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Open in...") {
                    TextField("Name", text: $name, prompt: Text("What?"))
                }

                Section("URL template") {
                    TextField("URL with variables", text: $urlTemplate, selection: $urlTemplateSelection, prompt: Text("How?"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    FlowLayout(spacing: 6) {
                        ForEach(suggestedStrings, id: \.self) { string in
                            Button(string) {
                                insertIntoUrlTemplate(string)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }

                    FlowLayout(spacing: 6) {
                        ForEach(OpenActionVariable.allCases) { variable in
                            Button(variable.placeholder) {
                                insertIntoUrlTemplate(variable.placeholder)
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }
                }

                Section("Show for") {
                    ForEach(OpenActionMediaType.allCases) { type in
                        Toggle(type.displayName,
                               isOn: Binding(get: { mediaTypes.contains(type) },
                                             set: { if $0 { mediaTypes.insert(type) } else { mediaTypes.remove(type) } })
                        ).tint(Color(uiColor: UIColor(asset: .globalTint)))
                            .toggleStyle(.switch)
                    }
                }

                Section("Icon") {
                    HStack(spacing: 12) {
                        Image(systemName: systemImageName)
                            .font(.title)
                            .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                            .frame(width: 44, height: 44)
                        TextField("SF Symbol name", text: $systemImageName, prompt: Text("Symbol name"))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    FlowLayout(spacing: 8) {
                        ForEach(suggestedSymbols, id: \.self) { symbol in
                            Button {
                                systemImageName = symbol
                            } label: {
                                Image(systemName: symbol)
                                    .frame(width: 24, height: 24)
                            }.buttonStyle(.bordered)
                                .frame(height: 36)
                        }
                    }
                }

                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            isShowingDeleteConfirmation = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete This Action")
                            }
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .confirm) {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedTemplate = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedName.isEmpty, !trimmedTemplate.isEmpty else { return }

                        let updated = CustomOpenAction(id: action.id,
                                                       name: trimmedName,
                                                       urlTemplate: trimmedTemplate,
                                                       mediaTypes: mediaTypes,
                                                       systemImageName: systemImageName.isEmpty ? "arrow.up.forward" : systemImageName)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                name = action.name
                urlTemplate = action.urlTemplate
                mediaTypes = action.mediaTypes
                systemImageName = action.systemImageName
            }
            .alert("Sure you want to Delete?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will delete the custom \"Open In\" action. This cannot be undone.")
            }
        }
    }

    private func insertIntoUrlTemplate(_ value: String) {
        guard let selection = urlTemplateSelection,
              case .selection(let range) = selection.indices else {
            urlTemplate.append(value)
            urlTemplateSelection = TextSelection(insertionPoint: urlTemplate.endIndex)
            return
        }

        let insertionStart = range.lowerBound
        urlTemplate.replaceSubrange(range, with: value)
        let insertedEnd = urlTemplate.index(insertionStart, offsetBy: value.count)
        urlTemplateSelection = TextSelection(insertionPoint: insertedEnd)
    }

}

// MARK: - Flow layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct Cache {
        var sizes: [CGSize] = []
        var arrangement: Arrangement?
    }

    struct Arrangement {
        let width: CGFloat
        let frames: [CGRect]
        let size: CGSize
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(sizes: subviews.map { $0.sizeThatFits(.unspecified) })
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        cache.sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        cache.arrangement = nil
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let arrangement = arrangement(for: proposal.width, subviews: subviews, cache: &cache)
        return arrangement.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        let arrangement = arrangement(for: bounds.width, subviews: subviews, cache: &cache)

        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrangement(for proposedWidth: CGFloat?, subviews: Subviews, cache: inout Cache) -> Arrangement {
        let width = normalizedWidth(for: proposedWidth, sizes: cache.sizes)

        if let arrangement = cache.arrangement, arrangement.width == width {
            return arrangement
        }

        let arrangement = makeArrangement(width: width, sizes: cache.sizes)
        cache.arrangement = arrangement
        return arrangement
    }

    private func normalizedWidth(for proposedWidth: CGFloat?, sizes: [CGSize]) -> CGFloat {
        guard let proposedWidth, proposedWidth.isFinite, proposedWidth > 0 else {
            let intrinsicWidth = sizes.reduce(0) { partial, size in
                partial + size.width
            }
            let totalSpacing = spacing * CGFloat(max(sizes.count - 1, 0))
            return max(intrinsicWidth + totalSpacing, sizes.map(\.width).max() ?? 0)
        }

        return max(proposedWidth, sizes.map(\.width).max() ?? 0)
    }

    private func makeArrangement(width: CGFloat, sizes: [CGSize]) -> Arrangement {
        var frames: [CGRect] = []
        frames.reserveCapacity(sizes.count)

        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var contentWidth: CGFloat = 0

        for size in sizes {
            let itemWidth = min(size.width, width)
            let itemHeight = size.height

            if x > 0, x + itemWidth > width {
                contentWidth = max(contentWidth, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(x: x, y: y, width: itemWidth, height: itemHeight))
            x += itemWidth + spacing
            rowHeight = max(rowHeight, itemHeight)
        }

        if !sizes.isEmpty {
            contentWidth = max(contentWidth, max(0, x - spacing))
        }

        let totalHeight = y + rowHeight
        return Arrangement(width: width, frames: frames, size: CGSize(width: contentWidth, height: totalHeight))
    }
}
