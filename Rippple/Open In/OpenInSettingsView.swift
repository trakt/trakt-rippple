//
//  OpenInSettingsView.swift
//  Rippple
//
//  Created by Kevin Cador on 18/03/2026.
//  Copyright © 2026 Trakt. All rights reserved.
//

import Receiver
import SFSymbols
import SwiftUI

struct OpenInSettingsView: View {
    enum PresentationStyle {
        case modal
        case pushed
    }

    let presentationStyle: PresentationStyle

    @State private var customActions: [CustomOpenAction] = []
    @State private var openActionItems: [OpenActionItem] = []

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

    init(presentationStyle: PresentationStyle = .modal) {
        self.presentationStyle = presentationStyle
    }

    var body: some View {
        if presentationStyle == .modal {
            NavigationStack {
                content
            }
        } else {
            content
        }
    }

    private var availableBuiltInActions: [BuiltInOpenAction] {
        let selectedBuiltInActions = Set(openActionItems.compactMap(\.builtInAction))
        return BuiltInOpenAction.allCases.filter { !selectedBuiltInActions.contains($0) }
    }

    private var content: some View {
        SwiftUI.List {
            Section {
                Text("Manage your \"Open In\" actions. Reorder built-in and custom actions for movie, show, season, and episode detail screens. Custom actions use a URL template with variables like \(OpenActionVariable.tmdbId.placeholder) or \(OpenActionVariable.title.placeholder).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !availableBuiltInActions.isEmpty {
                Section("Built-in Actions") {
                    ForEach(availableBuiltInActions) { action in
                        availableBuiltInRow(for: action)
                    }
                }
            }

            Section {
                ForEach(openActionItems) { item in
                    actionRow(for: item)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)

                HStack(alignment: .center) {
                    Button {
                        editorState = EditorState(action: CustomOpenAction(name: "",
                                                                           urlTemplate: "",
                                                                           mediaTypes: Set(OpenActionMediaType.allCases)),
                                                  isNew: true)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("New Action")
                        }
                    }.buttonStyle(.bordered)
                }
            } header: {
                HStack {
                    Text("Actions")
                    Spacer()
                    if !openActionItems.isEmpty {
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
            if presentationStyle == .modal {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            reloadActions()
        }
        .task {
            onCustomOpenActionsChangedReceiver.listen { _ in
                DispatchQueue.main.async {
                    self.reloadActions()
                }
            }.disposed(by: disposeBag)

            onBuiltInOpenActionsChangedReceiver.listen { _ in
                DispatchQueue.main.async {
                    self.reloadActions()
                }
            }.disposed(by: disposeBag)
        }
        .environment(\.editMode, $editMode)
        .alert("Sure you want to Delete?", isPresented: $isShowingDeleteConfirmation, presenting: pendingDeletionOffsets) { offsets in
            Button("Delete", role: .destructive) {
                removeActionItems(at: offsets, shouldDeleteCustomActions: true)
                pendingDeletionOffsets = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeletionOffsets = nil
            }
        } message: { offsets in
            Text(deleteConfirmationMessage(for: offsets))
        }
        .sheet(item: $editorState) { state in
            OpenInItemEditView(action: state.action,
                               isNew: state.isNew,
                               onSave: { updated in
                                   saveCustomAction(updated, isNew: state.isNew)
                               }, onDelete: {
                                   deleteCustomAction(id: state.action.id)
                               })
            #if targetEnvironment(macCatalyst)
                               .frame(minWidth: 620, minHeight: 720)
            #endif
        }
    }

    @ViewBuilder
    private func actionRow(for item: OpenActionItem) -> some View {
        if let builtInAction = item.builtInAction {
            builtInRow(for: builtInAction)
        } else if let customAction = customAction(for: item) {
            Button {
                editorState = EditorState(action: customAction, isNew: false)
            } label: {
                customRow(for: customAction)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
    }

    private func availableBuiltInRow(for action: BuiltInOpenAction) -> some View {
        HStack(spacing: 12) {
            builtInRow(for: action)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 12)
            Button {
                addBuiltInAction(action)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    private func builtInRow(for action: BuiltInOpenAction) -> some View {
        openActionRow(title: action.title,
                      subtitle: action.subtitle,
                      systemImageName: action.systemImageName)
    }

    private func customRow(for item: CustomOpenAction) -> some View {
        openActionRow(title: item.name,
                      subtitle: item.urlTemplate,
                      systemImageName: item.systemImageName)
    }

    private func openActionRow(title: String, subtitle: String, systemImageName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImageName)
                .font(.title2)
                .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                .frame(width: 32, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = actionItems(at: offsets)
        guard !items.isEmpty else { return }

        if items.contains(where: { $0.customActionID != nil }) {
            pendingDeletionOffsets = offsets
            isShowingDeleteConfirmation = true
            return
        }

        removeActionItems(at: offsets, shouldDeleteCustomActions: false)
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        openActionItems.move(fromOffsets: source, toOffset: destination)
        saveOpenActionItems()
    }

    private func addBuiltInAction(_ action: BuiltInOpenAction) {
        let item = OpenActionItem(builtInAction: action)
        guard !openActionItems.contains(item) else { return }
        openActionItems.append(item)
        saveOpenActionItems()
    }

    private func saveCustomAction(_ action: CustomOpenAction, isNew: Bool) {
        if isNew {
            customActions.append(action)
            openActionItems.append(OpenActionItem(customActionID: action.id))
            saveCustomActions()
            saveOpenActionItems()
            return
        }

        if let idx = customActions.firstIndex(where: { $0.id == action.id }) {
            customActions[idx] = action
            saveCustomActions()
        }
    }

    private func deleteCustomAction(id: UUID) {
        performWithoutListAnimation {
            customActions.removeAll { $0.id == id }
            openActionItems.removeAll { $0.customActionID == id }
            saveCustomActions()
            saveOpenActionItems()
        }
    }

    private func removeActionItems(at offsets: IndexSet, shouldDeleteCustomActions: Bool) {
        performWithoutListAnimation {
            let removedItems = actionItems(at: offsets)
            let removedCustomActionIDs = Set(removedItems.compactMap(\.customActionID))

            if shouldDeleteCustomActions, !removedCustomActionIDs.isEmpty {
                customActions.removeAll { removedCustomActionIDs.contains($0.id) }
                saveCustomActions()
            }

            openActionItems.remove(atOffsets: offsets)
            saveOpenActionItems()
        }
    }

    private func performWithoutListAnimation(_ updates: () -> Void) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            updates()
        }
    }

    private func actionItems(at offsets: IndexSet) -> [OpenActionItem] {
        offsets.compactMap { index in
            guard openActionItems.indices.contains(index) else { return nil }
            return openActionItems[index]
        }
    }

    private func customAction(for item: OpenActionItem) -> CustomOpenAction? {
        guard let customActionID = item.customActionID else { return nil }
        return customActions.first { $0.id == customActionID }
    }

    private func deleteConfirmationMessage(for offsets: IndexSet?) -> String {
        guard let offsets else {
            return "This cannot be undone."
        }

        let items = actionItems(at: offsets)
        let includesBuiltInAction = items.contains { $0.builtInAction != nil }
        let includesCustomAction = items.contains { $0.customActionID != nil }

        if includesBuiltInAction, includesCustomAction {
            return "This will remove the built-in action from the list and delete the custom action. Custom actions cannot be restored."
        }

        return "This will delete the custom \"Open In\" action. This cannot be undone."
    }

    private func reloadActions() {
        customActions = OpenActionManager.shared.customOpenActions
        openActionItems = OpenActionManager.shared.openActionItems
    }

    private func saveCustomActions() {
        OpenActionManager.shared.customOpenActions = customActions
    }

    private func saveOpenActionItems() {
        OpenActionManager.shared.openActionItems = openActionItems
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
    @State private var isShowingSymbolPicker = false
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingDeleteConfirmation = false

    private let suggestedStrings = [
        "https://", "movie", "show", "series", "tv", "episode", "season", "search", "=", "&", "/", "?", "%20", "s"
    ]

    private var optionalSystemImageNameBinding: Binding<String?> {
        Binding<String?>(
            get: { systemImageName },
            set: { newValue in
                guard let newValue, !newValue.isEmpty else { return }
                systemImageName = newValue
            }
        )
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedURLTemplate: String {
        urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var urlTemplateValidationMessage: String? {
        OpenActionURLTemplateValidator.validationMessage(for: trimmedURLTemplate)
    }

    private var shouldShowURLTemplateValidationMessage: Bool {
        !trimmedURLTemplate.isEmpty && urlTemplateValidationMessage != nil
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && urlTemplateValidationMessage == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        TextField("Name", text: $name, prompt: Text("What?"))
                        Button {
                            isShowingSymbolPicker = true
                        } label: {
                            Image(systemName: systemImageName)
                                .font(.title3)
                                .foregroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                                .frame(width: 32, height: 32)
                        }.buttonStyle(.plain)
                            .sfSymbolPicker(isPresented: $isShowingSymbolPicker, selection: optionalSystemImageNameBinding)
                            .sfSymbolPickerForegroundStyle(Color(uiColor: UIColor(asset: .globalTint)))
                    }
                } header: {
                    Text("Open in...")
                } footer: {
                    Text("Give your action a name and choose Symbol to help identify it in the Open In list.")
                }

                Section {
                    TextField("URL with variables", text: $urlTemplate, selection: $urlTemplateSelection, prompt: Text("How?"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .textContentType(.URL)

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
                } header: {
                    Text("URL template")
                } footer: {
                    if shouldShowURLTemplateValidationMessage,
                       let urlTemplateValidationMessage {
                        Text(urlTemplateValidationMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Show for") {
                    ForEach(OpenActionMediaType.allCases) { type in
                        Toggle(type.displayName,
                               isOn: Binding(get: { mediaTypes.contains(type) },
                                             set: { if $0 { mediaTypes.insert(type) } else { mediaTypes.remove(type) } }))
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
                        guard canSave else { return }

                        let updated = CustomOpenAction(id: action.id,
                                                       name: trimmedName,
                                                       urlTemplate: trimmedURLTemplate,
                                                       mediaTypes: mediaTypes,
                                                       systemImageName: systemImageName.isEmpty ? "arrow.up.forward" : systemImageName)
                        onSave(updated)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                name = action.name
                urlTemplate = action.urlTemplate
                mediaTypes = action.mediaTypes
                systemImageName = action.systemImageName
            }
            .onChange(of: systemImageName) { _, _ in
                if isShowingSymbolPicker {
                    isShowingSymbolPicker = false
                }
            }
            .alert("Sure you want to Delete?", isPresented: $isShowingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
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

private enum OpenActionURLTemplateValidator {
    static func validationMessage(for template: String) -> String? {
        guard !template.isEmpty else {
            return "Enter a URL template."
        }

        guard template.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else {
            return "URLs cannot contain spaces. Use %20 for fixed spaces."
        }

        if let placeholderValidationMessage = validatePlaceholders(in: template) {
            return placeholderValidationMessage
        }

        let sampleResolvedTemplate = sampleResolvedTemplate(for: template)
        guard let components = URLComponents(string: sampleResolvedTemplate),
              let scheme = components.scheme,
              !scheme.isEmpty else {
            return "Add a URL scheme like https:// or an app scheme."
        }

        guard URL(string: sampleResolvedTemplate)?.scheme != nil else {
            return "Enter a valid URL template."
        }

        if ["http", "https"].contains(scheme.lowercased()),
           components.host?.isEmpty ?? true {
            return "HTTP URLs need a host, like example.com."
        }

        let hasDestination = components.host?.isEmpty == false ||
            components.path.isEmpty == false ||
            components.query?.isEmpty == false
        guard hasDestination else {
            return "Add a host or path after the URL scheme."
        }

        return nil
    }

    private static func validatePlaceholders(in template: String) -> String? {
        let validVariableNames = Set(OpenActionVariable.allCases.map(\.rawValue))
        var index = template.startIndex

        while index < template.endIndex {
            switch template[index] {
            case "{":
                let variableStart = template.index(after: index)
                guard let closingBraceIndex = template[variableStart...].firstIndex(of: "}") else {
                    return "Close the variable placeholder with }."
                }

                let variableName = String(template[variableStart..<closingBraceIndex])
                guard validVariableNames.contains(variableName) else {
                    if variableName.isEmpty {
                        return "Remove the empty variable placeholder."
                    }
                    return "Unknown variable {\(variableName)}. Use one of the variable chips."
                }

                index = template.index(after: closingBraceIndex)
            case "}":
                return "Remove the unmatched closing brace."
            default:
                index = template.index(after: index)
            }
        }

        return nil
    }

    private static func sampleResolvedTemplate(for template: String) -> String {
        var resolvedTemplate = template
        for variable in OpenActionVariable.allCases {
            resolvedTemplate = resolvedTemplate.replacingOccurrences(of: variable.placeholder,
                                                                     with: sampleValue(for: variable))
        }
        return resolvedTemplate
    }

    private static func sampleValue(for variable: OpenActionVariable) -> String {
        switch variable {
        case .title:
            return "Sample%20Title"
        case .showTitle:
            return "Sample%20Show"
        case .slug:
            return "sample-title"
        case .traktId, .tmdbId, .showTmdbId, .showTraktId, .year, .season, .episode:
            return "123"
        case .imdbId, .showImdbId:
            return "tt1234567"
        }
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
