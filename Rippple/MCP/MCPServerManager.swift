#if targetEnvironment(macCatalyst)
import Foundation
import Moya
import Receiver

final class MCPServerManager {
    static let shared = MCPServerManager()
    static let port: UInt16 = 52831
    static let endpoint = "http://127.0.0.1:\(MCPServerManager.port)/mcp"
    private static let clientActivityTimeout: TimeInterval = 90
    private static let versions = ["2025-11-25", "2025-06-18", "2025-03-26"]
    private static let enabledKey = "MCPServer.enabled"
    private static let accessKeyEnabledKey = "MCPServer.accessKeyEnabled"

    struct Snapshot {
        let enabled: Bool
        let accessKeyEnabled: Bool
        let running: Bool
        let clientConnected: Bool
        let activeConnectionCount: Int
        let state: MCPHTTPServer.State
        let toolCount: Int
        let console: String
        let verboseConsole: String
    }

    private let onChange = Receiver<Snapshot>.make(with: .hot)
    private let disposeBag = DisposeBag()
    var onChangeReceiver: Receiver<Snapshot> {
        onChange.1
    }

    private var server: MCPHTTPServer?
    private var catalog: MCPOpenAPICatalog?
    private var catalogRequest: Cancellable?
    private var requests = [String: Cancellable]()
    private var conciseLogs = [String]()
    private var verboseLogs = [String]()
    private var accessKey = ""
    private var clientActivityExpiration: Date?
    private var clientActivityWorkItem: DispatchWorkItem?
    private var generation = UUID()
    private var didSetup = false
    private var state = MCPHTTPServer.State.stopped
    private var running: Bool {
        state == .listening
    }

    private var enabled = UserDefaults.standard.bool(forKey: MCPServerManager.enabledKey)
    private var accessKeyEnabled = UserDefaults.standard.object(forKey: MCPServerManager.accessKeyEnabledKey) as? Bool ?? true
    private let formatter = ISO8601DateFormatter()

    private init() {}

    var snapshot: Snapshot {
        let clientConnected = clientActivityExpiration.map { $0 > Date() } ?? false
        return Snapshot(enabled: enabled, accessKeyEnabled: accessKeyEnabled, running: running, clientConnected: clientConnected, activeConnectionCount: clientConnected ? 1 : 0, state: state, toolCount: catalog?.operations.count ?? 0, console: conciseLogs.joined(separator: "\n"), verboseConsole: verboseLogs.joined(separator: "\n"))
    }

    var availableTools: [MCPOpenAPICatalog.Operation] {
        catalog?.operations ?? []
    }

    var connectionURL: String {
        guard accessKeyEnabled, !accessKey.isEmpty, var components = URLComponents(string: MCPServerManager.endpoint) else {
            return MCPServerManager.endpoint
        }
        components.queryItems = [URLQueryItem(name: "key", value: accessKey)]
        return components.string ?? MCPServerManager.endpoint
    }

    var displayURL: String {
        connectionURL.removingPercentEncoding ?? connectionURL
    }

    var displayAccessKey: String {
        accessKey
    }

    var setupPrompt: String {
        """
        Add Rippple as a local MCP server using Streamable HTTP.
        URL: \(displayURL)

        Use it to access my Trakt account while Rippple is running. Ask before making changes.
        """
    }

    func setup() {
        guard !didSetup else { return }
        didSetup = true
        onUserLoggedOutReceiver.listen { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                for request in self.requests.values {
                    request.cancel()
                }
                self.requests.removeAll()
                self.conciseLogs.removeAll()
                self.verboseLogs.removeAll()
                self.appendLog("Signed out of Trakt; requests cancelled and console cleared")
            }
        }.disposed(by: disposeBag)
        if enabled { start() }
        else { loadBundledCatalog() }
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        UserDefaults.standard.set(value, forKey: MCPServerManager.enabledKey)
        if value { start() }
        else { stop() }
    }

    func setAccessKeyEnabled(_ value: Bool) {
        guard accessKeyEnabled != value else { return }
        if value {
            do {
                accessKey = try KeychainStore.mcpAccessKey()
            } catch {
                appendLog("Could not enable the local access key: \(error.localizedDescription)")
                return
            }
        } else {
            accessKey = ""
        }
        accessKeyEnabled = value
        UserDefaults.standard.set(value, forKey: MCPServerManager.accessKeyEnabledKey)
        appendLog(value ? "Local access key enabled" : "Local access key disabled")
    }

    func rotateKey() throws {
        guard accessKeyEnabled else { return }
        accessKey = try KeychainStore.mcpAccessKey(rotate: true)
        if enabled { start() }
        appendLog("Local key rotated; reconnect clients using the new MCP URL")
    }

    func clearLogs() {
        conciseLogs.removeAll()
        verboseLogs.removeAll()
        publish()
    }

    func reload() {
        guard enabled else { return }
        start()
    }

    private func refreshCatalog() {
        guard enabled, catalogRequest == nil else { return }
        let currentGeneration = generation
        appendLog("OpenAPI: downloading official Trakt specification")
        catalogRequest = TraktAPIProvider.mcpProvider.request(.specification, callbackQueue: .global(qos: .utility)) { [weak self] result in
            let parsed = result.flatMap { response -> Result<MCPOpenAPICatalog, MoyaError> in
                do {
                    _ = try response.filterSuccessfulStatusCodes()
                    return try .success(MCPOpenAPICatalog(data: response.data))
                } catch { return .failure(.underlying(error, response)) }
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.generation == currentGeneration else { return }
                self.catalogRequest = nil
                switch parsed {
                case .success(let catalog):
                    self.catalog = catalog
                    self.appendLog("OpenAPI: loaded \(catalog.operations.count) tools from the live specification; reconnect clients to refresh their catalog")
                case .failure(let error):
                    self.appendLog("OpenAPI: \(self.safeText(error.localizedDescription)); retaining \(self.catalog?.operations.count ?? 0) bundled/current tools. Reload the server to try again.")
                }
            }
        }
    }

    private func start() {
        stop()
        enabled = true
        do {
            accessKey = accessKeyEnabled ? try KeychainStore.mcpAccessKey() : ""
            state = .starting
            let currentGeneration = generation
            let server = MCPHTTPServer(handler: { [weak self] request, completion in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.enabled, self.generation == currentGeneration else {
                        completion(MCPHTTPServer.Response(status: 503))
                        return
                    }
                    self.handle(request, completion: completion)
                }
            }, log: { [weak self] message in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.generation == currentGeneration else { return }
                    self.appendLog(message, verboseOnly: true)
                }
            })
            self.server = server
            try server.start(port: MCPServerManager.port) { [weak self] state, message in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.generation == currentGeneration else { return }
                    self.state = state
                    self.appendLog(message)
                }
            }
            loadBundledCatalog()
        } catch {
            state = .failed
            appendLog("Could not start MCP server: \(error.localizedDescription)")
        }
        publish()
    }

    private func loadBundledCatalog() {
        let currentGeneration = generation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let catalog = Bundle.main.url(forResource: "TraktOpenAPI", withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { try? MCPOpenAPICatalog(data: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.generation == currentGeneration else { return }
                self.catalog = catalog
                self.appendLog("OpenAPI: loaded \(catalog?.operations.count ?? 0) bundled tools")
                self.refreshCatalog()
            }
        }
    }

    private func stop() {
        generation = UUID()
        server?.stop()
        server = nil
        catalogRequest?.cancel()
        catalogRequest = nil
        for request in requests.values {
            request.cancel()
        }
        requests.removeAll()
        clientActivityWorkItem?.cancel()
        clientActivityWorkItem = nil
        clientActivityExpiration = nil
        state = .stopped
        appendLog("Server stopped; pending requests cancelled")
    }

    private func handle(_ request: MCPHTTPServer.Request, completion: @escaping (MCPHTTPServer.Response) -> Void) {
        guard request.headers["host"] == "127.0.0.1:\(MCPServerManager.port)" || request.headers["host"] == "localhost:\(MCPServerManager.port)" else {
            appendLog("Rejected Host header")
            completion(.init(status: 403)); return
        }
        if let origin = request.headers["origin"], origin != "http://127.0.0.1:\(MCPServerManager.port)", origin != "http://localhost:\(MCPServerManager.port)" {
            appendLog("Rejected browser Origin")
            completion(.init(status: 403)); return
        }
        if accessKeyEnabled, !request.hasAccessKey(accessKey) {
            appendLog("Rejected missing or invalid local access key")
            completion(.init(status: 401)); return
        }
        guard request.route == "/mcp" else { completion(.init(status: 404)); return }
        guard request.method == "POST" else { completion(.init(status: 405)); return }
        if let version = request.headers["mcp-protocol-version"], !MCPServerManager.versions.contains(version) {
            completion(.init(status: 400)); return
        }
        guard request.headers["content-type"]?.lowercased().hasPrefix("application/json") == true else {
            completion(.init(status: 415)); return
        }
        guard let accept = request.headers["accept"], accept.contains("application/json"), accept.contains("text/event-stream") else {
            completion(.init(status: 406)); return
        }
        guard let message = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            completion(rpcError(id: NSNull(), code: -32700, message: "Parse error")); return
        }
        let id = message["id"] ?? NSNull()
        guard message["jsonrpc"] as? String == "2.0", let method = message["method"] as? String,
              message["id"] == nil || id is String || (id is NSNumber && CFGetTypeID(id as CFTypeRef) != CFBooleanGetTypeID()) else {
            completion(rpcError(id: NSNull(), code: -32600, message: "Invalid request")); return
        }
        guard message["params"] == nil || message["params"] is [String: Any] else {
            completion(rpcError(id: id, code: -32602, message: "Parameters must be an object")); return
        }
        let params = message["params"] as? [String: Any] ?? [:]
        markClientActive()
        appendLog("RPC \(method) id=\(safeText(id)) params=\(safeText(params))", concise: "RPC \(method) id=\(safeText(id))")
        guard message["id"] != nil else {
            // No server-side sessions or background subscriptions are allocated.
            completion(.init(status: 202)); return
        }
        switch method {
        case "initialize":
            let requestedVersion = params["protocolVersion"] as? String ?? ""
            let version = MCPServerManager.versions.contains(requestedVersion) ? requestedVersion : MCPServerManager.versions[0]
            completion(rpcResult(id: id, result: ["protocolVersion": version,
                                                  "capabilities": ["tools": ["listChanged": false]],
                                                  "serverInfo": ["name": "Rippple", "version": "1.0"],
                                                  "instructions": "Use Rippple's signed-in Trakt account. OAuth is app-managed. Ask before writes. Respect pagination and Retry-After; do not automatically retry mutations."]))
        case "ping": completion(rpcResult(id: id, result: [:]))
        case "tools/list":
            guard let catalog = catalog else {
                completion(rpcError(id: id, code: -32603, message: "API specification is loading. Retry shortly.")); return
            }
            let cursor = params["cursor"] as? String ?? "0"
            guard let offset = Int(cursor), offset >= 0, offset < catalog.operations.count else {
                completion(rpcError(id: id, code: -32602, message: "Invalid tool cursor")); return
            }
            let end = min(offset + 40, catalog.operations.count)
            var result: [String: Any] = ["tools": catalog.operations[offset..<end].map(\.tool)]
            if end < catalog.operations.count { result["nextCursor"] = String(end) }
            completion(rpcResult(id: id, result: result))
        case "tools/call": callTool(id: id, params: params, completion: completion)
        default: completion(rpcError(id: id, code: -32601, message: "Method not found"))
        }
    }

    private func callTool(id: Any, params: [String: Any], completion: @escaping (MCPHTTPServer.Response) -> Void) {
        guard let name = params["name"] as? String,
              let operation = catalog?.operations.first(where: { $0.name == name }),
              !operation.isAuthentication else {
            completion(rpcError(id: id, code: -32602, message: "Unknown tool")); return
        }
        guard SessionManager.shared.isLoggedIn, TraktAPIProvider.source.token != nil else {
            completion(toolResult(id: id, payload: ["error": "Sign in to Trakt in Rippple first."], isError: true)); return
        }
        guard params["arguments"] == nil || params["arguments"] is [String: Any] else {
            completion(rpcError(id: id, code: -32602, message: "Tool arguments must be an object")); return
        }
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let target = try MCPAPIService(operation: operation, arguments: arguments)
            let requestID = UUID().uuidString
            let started = Date()
            let currentGeneration = generation
            let token = TraktAPIProvider.source.token
            appendLog("Trakt → \(operation.method.uppercased()) \(operation.path) • \(requestID) • \(safeText(arguments))", concise: "Trakt → \(operation.method.uppercased()) \(operation.path) • \(requestID)")
            requests[requestID] = TraktAPIProvider.mcpProvider.request(target, callbackQueue: .global(qos: .userInitiated)) { [weak self] result in
                var payload = [String: Any]()
                let isError: Bool
                switch result {
                case .success(let response):
                    isError = !(200...299).contains(response.statusCode)
                    payload["status"] = response.statusCode
                    let headers = response.response?.allHeaderFields ?? [:]
                    var metadata = [String: String]()
                    for (key, value) in headers {
                        let key = String(describing: key).lowercased()
                        if key.hasPrefix("x-pagination-"), !key.contains("token") { metadata[key] = String(describing: value) }
                        if ["retry-after", "x-ratelimit", "x-sort-by", "x-sort-how"].contains(key) { metadata[key] = String(describing: value) }
                    }
                    payload["headers"] = metadata
                    if response.data.count > 4 * 1024 * 1024 {
                        payload["error"] = "Response exceeds 4 MiB. Request a smaller page or less extended information."
                    } else {
                        payload["body"] = (try? JSONSerialization.jsonObject(with: response.data, options: .fragmentsAllowed)) ?? (response.data.isEmpty ? NSNull() : "Non-JSON response (\(response.data.count) bytes)" as Any)
                    }
                case .failure(let error):
                    isError = true
                    payload["details"] = error.localizedDescription
                    payload["error"] = "Trakt request failed or timed out. Check connectivity and the server console. A write may already have completed; verify before retrying."
                }
                let responsePayload = payload
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.generation == currentGeneration else { return }
                    self.requests.removeValue(forKey: requestID)
                    guard SessionManager.shared.isLoggedIn, TraktAPIProvider.source.token == token else {
                        self.appendLog("Discarded response after Trakt session changed • \(requestID)")
                        completion(self.toolResult(id: id, payload: ["error": "Trakt session changed during the request. Verify the result before retrying."], isError: true))
                        return
                    }
                    let duration = String(format: "%.0f", Date().timeIntervalSince(started) * 1000)
                    let result = responsePayload["status"].map { "HTTP \($0)" } ?? (isError ? "failed" : "completed")
                    self.appendLog("Trakt ← \(name) • \(duration) ms • \(requestID) • \(self.safeText(responsePayload))", concise: "Trakt ← \(name) • \(duration) ms • \(requestID) • \(result)")
                    completion(self.toolResult(id: id, payload: responsePayload, isError: isError || responsePayload["error"] != nil))
                }
            }
        } catch {
            appendLog("Tool rejected: \(error.localizedDescription)")
            completion(toolResult(id: id, payload: ["error": error.localizedDescription], isError: true))
        }
    }

    private func rpcResult(id: Any, result: [String: Any]) -> MCPHTTPServer.Response {
        .init(status: 200, json: ["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func rpcError(id: Any, code: Int, message: String) -> MCPHTTPServer.Response {
        .init(status: 200, json: ["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    private func toolResult(id: Any, payload: [String: Any], isError: Bool) -> MCPHTTPServer.Response {
        rpcResult(id: id, result: ["content": [["type": "text", "text": safeText(payload, limit: 4 * 1024 * 1024)]], "isError": isError])
    }

    private func safeText(_ value: Any, limit: Int = 6000) -> String {
        let redacted = redact(value)
        let data = try? JSONSerialization.data(withJSONObject: redacted, options: [.fragmentsAllowed, .sortedKeys])
        let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "[unavailable]"
        if text.count > limit { return String(text.prefix(limit)) + "… [truncated]" }
        return text
    }

    private func redact(_ value: Any) -> Any {
        if let object = value as? [String: Any] {
            return object.reduce(into: [String: Any]()) { result, pair in
                let key = pair.key.lowercased()
                if key.contains("token") || key.contains("secret") || key.contains("password") || ["authorization", "trakt-api-key", "client_id", "cookie", "key"].contains(key) {
                    result[pair.key] = "[redacted]"
                } else { result[pair.key] = redact(pair.value) }
            }
        }
        if let array = value as? [Any] { return array.map { redact($0) } }
        if var text = value as? String {
            let encodedKey = accessKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            for secret in [accessKey, encodedKey, encodedKey.lowercased(), TraktAPIConfiguration.clientId, TraktAPIConfiguration.secretId, TraktAPIProvider.source.token ?? "", SessionManager.shared.token?.refreshToken ?? ""] where !secret.isEmpty {
                text = text.replacingOccurrences(of: secret, with: "[redacted]")
            }
            return text
        }
        return value
    }

    private func appendLog(_ message: String, concise: String? = nil, verboseOnly: Bool = false) {
        let timestamp = formatter.string(from: Date())
        verboseLogs.append("\(timestamp) \(message)")
        if !verboseOnly {
            conciseLogs.append("\(timestamp) \(concise ?? message)")
        }
        if verboseLogs.count > 500 { verboseLogs.removeFirst(verboseLogs.count - 500) }
        if conciseLogs.count > 500 { conciseLogs.removeFirst(conciseLogs.count - 500) }
        publish()
    }

    private func markClientActive() {
        let wasConnected = snapshot.clientConnected
        let expiration = Date().addingTimeInterval(MCPServerManager.clientActivityTimeout)
        clientActivityExpiration = expiration
        clientActivityWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.clientActivityExpiration == expiration else { return }
            self.clientActivityExpiration = nil
            self.clientActivityWorkItem = nil
            self.appendLog("MCP client is no longer active")
        }
        clientActivityWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + MCPServerManager.clientActivityTimeout, execute: workItem)
        if !wasConnected {
            appendLog("MCP client connected")
        }
    }

    private func publish() {
        onChange.0.broadcast(snapshot)
    }
}
#endif
