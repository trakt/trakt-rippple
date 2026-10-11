#if targetEnvironment(macCatalyst)
import Foundation
import Network

/// One JSON response per POST is a Streamable HTTP transport. GET/SSE is optional.
final class MCPHTTPServer {
    enum State: String {
        case stopped = "Stopped"
        case starting = "Starting"
        case listening = "Listening"
        case waiting = "Waiting"
        case failed = "Failed"
    }

    struct Request {
        let method: String
        let path: String
        let headers: [String: String]
        let body: Data

        private var components: URLComponents? {
            guard path.hasPrefix("/"), !path.hasPrefix("//"),
                  let components = URLComponents(string: path), components.fragment == nil else { return nil }
            return components
        }

        var route: String? {
            components?.path
        }

        func hasAccessKey(_ expected: String) -> Bool {
            let keys = components?.queryItems?.filter { $0.name == "key" } ?? []
            return !expected.isEmpty && keys.count == 1 && keys.first?.value == expected
        }
    }

    struct Response {
        let status: Int
        let body: Data

        init(status: Int, json: [String: Any]? = nil) {
            self.status = status
            body = json.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) } ?? Data()
        }
    }

    private let queue = DispatchQueue(label: "tv.trakt.rippple.mcp.http")
    private var listener: NWListener?
    private var connections = [UUID: NWConnection]()
    private let handler: (Request, @escaping (Response) -> Void) -> Void
    private let log: (String) -> Void

    init(handler: @escaping (Request, @escaping (Response) -> Void) -> Void, log: @escaping (String) -> Void) {
        self.handler = handler
        self.log = log
    }

    func start(port: UInt16, state: @escaping (State, String) -> Void) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: parameters)
        self.listener = listener
        listener.stateUpdateHandler = { status in
            switch status {
            case .ready: state(.listening, "Listening on 127.0.0.1:\(port)")
            case .failed(let error): state(.failed, "Server failed: \(error.localizedDescription)")
            case .waiting(let error): state(.waiting, "Waiting: \(error.localizedDescription)")
            default: break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self = self else { return }
            guard self.connections.count < 32 else { connection.cancel(); return }
            let id = UUID()
            self.connections[id] = connection
            connection.start(queue: self.queue)
            self.receive(connection, id: id, buffer: Data())
            self.queue.asyncAfter(deadline: .now() + 90) { [weak self] in
                guard let self = self, self.connections[id] != nil else { return }
                self.log("HTTP timeout \(id)")
                self.close(id)
            }
        }
        listener.start(queue: queue)
    }

    func stop() {
        queue.sync {
            self.listener?.cancel()
            self.listener = nil
            for connection in self.connections.values {
                connection.cancel()
            }
            self.connections.removeAll()
        }
    }

    private func close(_ id: UUID) {
        guard let connection = connections.removeValue(forKey: id) else { return }
        connection.cancel()
    }

    private func receive(_ connection: NWConnection, id: UUID, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, error in
            guard let self = self else { return }
            var buffer = buffer
            if let data = data { buffer.append(data) }
            guard buffer.count <= 1024 * 1024 else {
                self.send(Response(status: 413), connection: connection, id: id)
                return
            }
            do {
                if let request = try MCPHTTPServer.parse(buffer) {
                    self.log("HTTP \(request.method) \(request.route == "/mcp" ? "/mcp" : "[unknown path]") • \(request.body.count) bytes • \(id)")
                    self.handler(request) { [weak self] response in
                        guard let self = self else { return }
                        self.queue.async { [weak self] in
                            guard let self = self, self.connections[id] != nil else { return }
                            self.send(response, connection: connection, id: id)
                        }
                    }
                } else if error != nil || complete {
                    self.close(id)
                } else {
                    self.receive(connection, id: id, buffer: buffer)
                }
            } catch {
                self.log("Rejected malformed HTTP request • \(id)")
                self.send(Response(status: 400), connection: connection, id: id)
            }
        }
    }

    private func send(_ response: Response, connection: NWConnection, id: UUID) {
        log("HTTP \(response.status) • \(response.body.count) response bytes • \(id)")
        let reason = [200: "OK", 202: "Accepted", 400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed", 406: "Not Acceptable", 413: "Content Too Large", 415: "Unsupported Media Type", 503: "Service Unavailable"][response.status] ?? "Error"
        var header = "HTTP/1.1 \(response.status) \(reason)\r\nContent-Type: application/json\r\nContent-Length: \(response.body.count)\r\nConnection: close\r\nCache-Control: no-store\r\n"
        if response.status == 405 { header += "Allow: POST\r\n" }
        var data = Data((header + "\r\n").utf8)
        data.append(response.body)
        connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            guard let self = self else { return }
            self.close(id)
        })
    }

    static func parse(_ data: Data) throws -> Request? {
        guard let separator = data.range(of: Data("\r\n\r\n".utf8)) else {
            if data.count > 16 * 1024 { throw MCPError.invalid("HTTP headers too large.") }
            return nil
        }
        guard separator.lowerBound <= 16 * 1024,
              let head = String(data: data[..<separator.lowerBound], encoding: .utf8) else { throw MCPError.invalid("Invalid HTTP headers.") }
        let lines = head.components(separatedBy: "\r\n")
        let first = lines[0].components(separatedBy: " ")
        guard first.count == 3, first[2] == "HTTP/1.1" else { throw MCPError.invalid("Invalid HTTP request line.") }
        var headers = [String: String]()
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { throw MCPError.invalid("Invalid HTTP header.") }
            let key = line[..<colon].lowercased()
            guard headers[key] == nil else { throw MCPError.invalid("Duplicate HTTP header.") }
            headers[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        let bodyData = Data(data[separator.upperBound...])
        let body: Data
        if let transfer = headers["transfer-encoding"] {
            guard transfer.lowercased() == "chunked", headers["content-length"] == nil else { throw MCPError.invalid("Invalid transfer encoding.") }
            guard let decoded = try decodeChunks(bodyData) else { return nil }
            body = decoded
        } else {
            guard let count = Int(headers["content-length"] ?? "0"), count >= 0, count <= 1024 * 1024 else { throw MCPError.invalid("Invalid content length.") }
            guard bodyData.count >= count else { return nil }
            guard bodyData.count == count else { throw MCPError.invalid("Pipelining is unsupported.") }
            body = bodyData
        }
        return Request(method: first[0], path: first[1], headers: headers, body: body)
    }

    private static func decodeChunks(_ data: Data) throws -> Data? {
        var offset = 0
        var body = Data()
        let newline = Data("\r\n".utf8)
        while offset < data.count {
            guard let end = data.range(of: newline, in: offset..<data.count),
                  let line = String(data: data[offset..<end.lowerBound], encoding: .utf8) else { return nil }
            guard let size = Int(line.components(separatedBy: ";")[0], radix: 16), size >= 0, size <= 1024 * 1024 else { throw MCPError.invalid("Invalid chunk size.") }
            offset = end.upperBound
            guard data.count - offset >= size + 2 else { return nil }
            guard data[(offset + size)..<(offset + size + 2)] == newline else { throw MCPError.invalid("Invalid chunk ending.") }
            if size == 0 {
                guard offset + 2 == data.count else { throw MCPError.invalid("Unexpected chunk trailer.") }
                return body
            }
            body.append(data[offset..<(offset + size)])
            offset += size + 2
        }
        return nil
    }
}
#endif
