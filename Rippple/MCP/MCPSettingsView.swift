#if targetEnvironment(macCatalyst)
import Receiver
import SwiftUI
import UIKit

@MainActor
private final class WeakNavigationController {
    weak var value: UINavigationController?

    init(_ value: UINavigationController?) {
        self.value = value
    }
}

struct MCPSettingsView: View {
    private let navigationController: WeakNavigationController
    private let samplePrompts = [
        "What have I watched recently? Summarize my last 10 watched movies and episodes.",
        "What should I watch tonight? Recommend 5 unwatched movies from my watchlist based on my ratings and recent history.",
        "Which shows am I falling behind on? Rank them by the number of aired episodes I haven't watched.",
        "Give me a year-in-review for my Trakt activity so far, with totals, favorites, and viewing trends.",
        "What's coming up on my calendar over the next 14 days? Group it by day.",
        "Show me the 10 movies that have been sitting in my watchlist the longest.",
        "Which highly rated movies in my watchlist are under two hours long?",
        "Compare my movie and TV watching over the last 90 days.",
        "Which genres and shows have I rated most highly?",
        "Find five popular shows I haven't watched that match my favorite genres.",
        "Suggest a private Trakt list based on my recent favorites, then ask before creating it."
    ]

    @State private var snapshot = MCPServerManager.shared.snapshot
    @State private var disposeBag = DisposeBag()

    init(navigationController: UINavigationController?) {
        self.navigationController = WeakNavigationController(navigationController)
    }

    private var statusColor: Color {
        switch snapshot.state {
        case .listening: return snapshot.clientConnected ? .green : .yellow
        case .starting, .waiting: return .yellow
        case .failed: return .red
        case .stopped: return .gray
        }
    }

    private var statusDescription: String {
        if snapshot.state == .listening {
            return snapshot.clientConnected ? "Client connected" : "Listening"
        }
        return snapshot.state.rawValue
    }

    var body: some View {
        RipppleForm {
            Section {
                LabeledContent("Enable MCP") {
                    Toggle("Enable MCP", isOn: Binding(get: { snapshot.enabled }, set: { MCPServerManager.shared.setEnabled($0) }))
                        .labelsHidden()
                        .padding(.trailing, 0)
                }
                LabeledContent("Status") {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                        .help(statusDescription)
                        .accessibilityLabel(statusDescription)
                }
                Button(action: showTools) {
                    HStack {
                        Text("MCP Tools")
                        Spacer()
                        Text(String(snapshot.toolCount)).foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                if snapshot.enabled {
                    Button {
                        copyToClipboard(MCPServerManager.shared.connectionURL)
                    } label: {
                        HStack {
                            Text("MCP URL")
                            Spacer()
                            Text(MCPServerManager.shared.displayURL).foregroundStyle(.secondary)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityHint("Copy MCP URL to clipboard")
                    LabeledContent("Require Key") {
                        Toggle("", isOn: Binding(get: { snapshot.accessKeyEnabled }, set: { MCPServerManager.shared.setAccessKeyEnabled($0) }))
                            .labelsHidden()
                    }
                    if snapshot.accessKeyEnabled {
                        HStack {
                            Button {
                                copyToClipboard(MCPServerManager.shared.displayAccessKey)
                            } label: {
                                HStack {
                                    Text("Key")
                                    Spacer()
                                    Text(MCPServerManager.shared.displayAccessKey).foregroundStyle(.secondary)
                                }.contentShape(Rectangle())
                            }.buttonStyle(.plain)
                                .accessibilityHint("Copy MCP key to clipboard")
                            Button {
                                do {
                                    try MCPServerManager.shared.rotateKey()
                                    SwiftMessages.show(message: "Key rotated.", style: .content)
                                } catch {
                                    SwiftMessages.show(message: "Could not rotate the MCP key", style: .error(error))
                                }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }.buttonStyle(.borderless)
                                .help("Rotate key")
                                .accessibilityLabel("Rotate MCP key")
                        }
                    }
                    Button(action: showConsole) {
                        HStack {
                            Text("Console")
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }

            if snapshot.enabled {
                Section("Copy Setup Prompt") {
                    Button {
                        copyToClipboard(MCPServerManager.shared.setupPrompt)
                    } label: {
                        Text(MCPServerManager.shared.setupPrompt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical)
                    }.buttonStyle(.plain)
                        .accessibilityHint("Copy prompt to clipboard")
                }

                Section("Copy Sample Prompts") {
                    ForEach(samplePrompts, id: \.self) { prompt in
                        Button {
                            copyToClipboard(prompt)
                        } label: {
                            Text(prompt)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .padding(.vertical)
                        }.buttonStyle(.plain)
                            .accessibilityHint("Copy prompt to clipboard")
                    }
                }
            }
        }.contentMargins(.top, 6, for: .scrollContent)
            .navigationTitle("Local MCP Server")
            .onAppear {
                snapshot = MCPServerManager.shared.snapshot
                MCPServerManager.shared.onChangeReceiver.listen { value in
                    snapshot = value
                }.disposed(by: disposeBag)
            }
            .onDisappear { disposeBag = DisposeBag() }
    }

    private func copyToClipboard(_ value: String) {
        UIPasteboard.general.setItems([[UIPasteboard.typeAutomatic: value]], options: [.localOnly: true])
        SwiftMessages.show(message: "Copied to clipboard", style: .content)
    }

    private func showTools() {
        let controller = RipppleHostingController(rootView: MCPToolsView())
        controller.title = "MCP tools"
        navigationController.value?.pushViewController(controller, animated: true)
    }

    private func showConsole() {
        navigationController.value?.pushViewController(MCPConsoleViewController(), animated: true)
    }
}
#endif
