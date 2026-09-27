#if targetEnvironment(macCatalyst)
import Foundation
import Moya

struct MCPAPIService: AuthorizedTargetType {
    static let specificationURL = URL(string: "https://developer.trakt.tv/openapi.json")!

    let baseURL: URL
    let method: Moya.Method
    let task: Moya.Task
    let needsAuth: Bool
    let headers: [String: String]?
    var path: String {
        ""
    }

    var sampleData: Data {
        Data()
    }

    static var specification: MCPAPIService {
        MCPAPIService(baseURL: specificationURL, method: .get, task: .requestPlain, needsAuth: false, headers: ["Accept": "application/json"])
    }

    init(operation: MCPOpenAPICatalog.Operation, arguments: [String: Any]) throws {
        guard !operation.isAuthentication else {
            throw MCPError.invalid("Authentication endpoints are unavailable through MCP.")
        }
        let request = try operation.request(arguments: arguments)
        guard var url = URLComponents(string: TraktAPIConfiguration.baseURL), url.scheme == "https" else {
            throw MCPError.invalid("Invalid Trakt API URL.")
        }
        url.percentEncodedPath = (url.percentEncodedPath.hasSuffix("/") ? String(url.percentEncodedPath.dropLast()) : url.percentEncodedPath) + request.path
        var queryItems = [URLQueryItem]()
        for name in request.query.keys.sorted() {
            guard let value = request.query[name], !(value is NSNull) else { continue }
            if let array = value as? [Any] {
                // OpenAPI's default query style is form with explode=true.
                queryItems += array.map { URLQueryItem(name: name, value: MCPAPIService.queryString($0)) }
            } else {
                queryItems.append(URLQueryItem(name: name, value: MCPAPIService.queryString(value)))
            }
        }
        url.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let requestURL = url.url else {
            throw MCPError.invalid("Invalid API request.")
        }
        baseURL = requestURL
        method = Moya.Method(rawValue: operation.method.uppercased())
        if let body = request.body {
            task = try .requestData(JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed, .sortedKeys]))
        } else {
            task = .requestPlain
        }
        needsAuth = true
        headers = ["Content-Type": "application/json", "Accept": "application/json", "trakt-api-version": "2", "trakt-api-key": TraktAPIConfiguration.clientId]
    }

    private init(baseURL: URL, method: Moya.Method, task: Moya.Task, needsAuth: Bool, headers: [String: String]) {
        self.baseURL = baseURL
        self.method = method
        self.task = task
        self.needsAuth = needsAuth
        self.headers = headers
    }

    private static func queryString(_ value: Any) -> String {
        if let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            return number.boolValue ? "true" : "false"
        }
        return String(describing: value)
    }
}
#endif
