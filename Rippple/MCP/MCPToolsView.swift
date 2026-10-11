#if targetEnvironment(macCatalyst)
import Receiver
import SwiftUI

struct MCPToolsView: View {
    @State private var tools = MCPServerManager.shared.availableTools
    @State private var search = ""
    @State private var disposeBag = DisposeBag()

    private var filteredTools: [MCPOpenAPICatalog.Operation] {
        guard !search.isEmpty else { return tools }
        return tools.filter {
            $0.name.localizedStandardContains(search)
                || $0.path.localizedStandardContains(search)
                || $0.method.localizedStandardContains(search)
                || ($0.definition["summary"] as? String ?? "").localizedStandardContains(search)
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "get": return .green
        case "post": return .blue
        case "delete": return .red
        case "put": return .orange
        case "patch": return .purple
        case "head": return .teal
        case "options": return .indigo
        default: return .secondary
        }
    }

    var body: some View {
        RipppleList {
            if filteredTools.isEmpty {
                Text(search.isEmpty ? "No tools available" : "No matching tools")
                    .foregroundStyle(.secondary)
            }
            ForEach(filteredTools, id: \.name) { tool in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(tool.method.uppercased())
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(methodColor(tool.method))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(methodColor(tool.method).opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    Text(tool.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }.padding(.vertical, 2)
            }
        }.navigationTitle("MCP tools")
            .searchable(text: $search, prompt: "Find a tool or route")
            .onAppear {
                tools = MCPServerManager.shared.availableTools
                MCPServerManager.shared.onChangeReceiver.listen { _ in
                    tools = MCPServerManager.shared.availableTools
                }.disposed(by: disposeBag)
            }
            .onDisappear { disposeBag = DisposeBag() }
    }
}
#endif
