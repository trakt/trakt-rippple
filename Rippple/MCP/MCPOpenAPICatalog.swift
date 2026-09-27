import Foundation

#if targetEnvironment(macCatalyst)
struct MCPOpenAPICatalog {
    struct Operation {
        let name: String
        let path: String
        let method: String
        let definition: [String: Any]
        let inputSchema: [String: Any]
        let parameters: [[String: Any]]

        var isAuthentication: Bool {
            path.hasPrefix("/oauth")
        }

        var tool: [String: Any] {
            let readOnly = method == "get" || method == "head"
            return ["name": name,
                    "title": definition["summary"] as? String ?? name,
                    "description": "\(method.uppercased()) \(path)\n\(definition["description"] as? String ?? "")\nReturns status, response body, pagination and rate-limit headers. Request one page at a time.",
                    "inputSchema": inputSchema,
                    "annotations": ["readOnlyHint": readOnly,
                                    "destructiveHint": !readOnly,
                                    "idempotentHint": readOnly,
                                    "openWorldHint": true]]
        }

        func request(arguments: [String: Any]) throws -> (path: String, query: [String: Any], body: Any?) {
            try MCPOpenAPICatalog.validate(arguments, schema: inputSchema, location: "arguments")
            let pathArguments = arguments["path"] as? [String: Any] ?? [:]
            var resolvedPath = path
            for parameter in parameters where parameter["in"] as? String == "path" {
                guard let name = parameter["name"] as? String,
                      let value = pathArguments[name] else { continue }
                let text = String(describing: value)
                guard text != ".", text != "..",
                      let encoded = text.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: "-._~"))) else {
                    throw MCPError.invalid("Invalid path parameter.")
                }
                resolvedPath = resolvedPath.replacingOccurrences(of: "{\(name)}", with: encoded)
            }
            guard !resolvedPath.contains("{"), !resolvedPath.contains("}") else {
                throw MCPError.invalid("Missing path parameters.")
            }
            return (resolvedPath, arguments["query"] as? [String: Any] ?? [:], arguments["body"])
        }
    }

    let operations: [Operation]

    init(data: Data) throws {
        guard data.count <= 16 * 1024 * 1024,
              let document = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              (document["openapi"] as? String)?.hasPrefix("3.") == true,
              let paths = document["paths"] as? [String: [String: Any]] else {
            throw MCPError.invalid("Invalid OpenAPI document.")
        }
        var result = [Operation]()
        var names = Set<String>()
        let orderedOperations = try MCPOpenAPICatalog.operationOrder(in: data)
        for (path, method) in orderedOperations {
            guard path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("?"), !path.contains("#") else {
                throw MCPError.invalid("Invalid OpenAPI path.")
            }
            let item = paths[path] ?? [:]
            guard let raw = item[method] as? [String: Any],
                  let definition = try MCPOpenAPICatalog.resolve(raw, document: document) as? [String: Any] else {
                throw MCPError.invalid("Invalid OpenAPI operation.")
            }
            // Authentication belongs to SessionManager and must never be exposed as an MCP tool.
            guard !path.hasPrefix("/oauth") else { continue }
            guard let name = definition["operationId"] as? String,
                  name.range(of: "^[a-zA-Z0-9_-]{1,128}$", options: .regularExpression) != nil,
                  names.insert(name).inserted else {
                throw MCPError.invalid("Missing or duplicate operation ID.")
            }
            let inherited = try MCPOpenAPICatalog.resolve(item["parameters"] ?? [], document: document) as? [[String: Any]] ?? []
            let own = definition["parameters"] as? [[String: Any]] ?? []
            let parameters = inherited.filter { inherited in
                !own.contains { $0["name"] as? String == inherited["name"] as? String && $0["in"] as? String == inherited["in"] as? String }
            } + own
            var properties = [String: Any]()
            var required = [String]()
            for location in ["path", "query"] {
                var fields = [String: Any]()
                var requiredFields = [String]()
                for parameter in parameters where parameter["in"] as? String == location {
                    guard let name = parameter["name"] as? String else { continue }
                    var schema = parameter["schema"] as? [String: Any] ?? [:]
                    if let description = parameter["description"] { schema["description"] = description }
                    fields[name] = schema
                    if parameter["required"] as? Bool == true { requiredFields.append(name) }
                }
                if !fields.isEmpty {
                    properties[location] = ["type": "object", "properties": fields, "required": requiredFields, "additionalProperties": false]
                    if !requiredFields.isEmpty { required.append(location) }
                }
            }
            if let body = definition["requestBody"] as? [String: Any],
               let content = body["content"] as? [String: Any],
               let json = content["application/json"] as? [String: Any] {
                properties["body"] = json["schema"] ?? ["type": "object"]
                if body["required"] as? Bool == true { required.append("body") }
            }
            let schema: [String: Any] = ["type": "object", "properties": properties, "required": required, "additionalProperties": false]
            result.append(Operation(name: name, path: path, method: method, definition: definition, inputSchema: schema, parameters: parameters))
        }
        guard !result.isEmpty else { throw MCPError.invalid("OpenAPI contains no tools.") }
        operations = result
    }

    private static func operationOrder(in data: Data) throws -> [(path: String, method: String)] {
        var cursor = JSONOrderCursor(data: data)
        let root = try cursor.objectMembers()
        guard let pathsRange = root.first(where: { $0.key == "paths" })?.value else {
            throw MCPError.invalid("OpenAPI contains no paths object.")
        }
        cursor.index = pathsRange.lowerBound
        let pathMembers = try cursor.objectMembers()
        let methods = Set(["get", "post", "put", "patch", "delete", "head", "options"])
        var result = [(path: String, method: String)]()
        for pathMember in pathMembers {
            cursor.index = pathMember.value.lowerBound
            for methodMember in try cursor.objectMembers() where methods.contains(methodMember.key) {
                result.append((pathMember.key, methodMember.key))
            }
        }
        return result
    }

    private static func resolve(_ value: Any, document: [String: Any], references: Set<String> = []) throws -> Any {
        if let array = value as? [Any] {
            return try array.map { try resolve($0, document: document, references: references) }
        }
        guard var object = value as? [String: Any] else { return value }
        if let reference = object.removeValue(forKey: "$ref") as? String {
            guard reference.hasPrefix("#/"), !references.contains(reference) else {
                throw MCPError.invalid("Unsupported or recursive OpenAPI reference: \(reference)")
            }
            var target: Any = document
            for part in reference.dropFirst(2).components(separatedBy: "/") {
                let key = part.replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
                guard let next = (target as? [String: Any])?[key] else { throw MCPError.invalid("Unresolved OpenAPI reference.") }
                target = next
            }
            guard let resolved = try resolve(target, document: document, references: references.union([reference])) as? [String: Any] else {
                throw MCPError.invalid("Invalid OpenAPI reference.")
            }
            object = resolved.merging(object) { _, new in new }
        }
        var result = try object.mapValues { try resolve($0, document: document, references: references) }
        if result.removeValue(forKey: "nullable") as? Bool == true, let type = result["type"] as? String {
            result["type"] = [type, "null"]
        }
        return result
    }

    private static func validate(_ value: Any, schema: [String: Any], location: String) throws {
        let types = schema["type"] as? [String] ?? (schema["type"] as? String).map { [$0] } ?? []
        if value is NSNull {
            guard types.isEmpty || types.contains("null") else { throw MCPError.invalid("\(location) cannot be null.") }
            return
        }
        if let object = value as? [String: Any] {
            guard types.isEmpty || types.contains("object") else { throw MCPError.invalid("\(location) has the wrong type.") }
            let properties = schema["properties"] as? [String: [String: Any]] ?? [:]
            for key in schema["required"] as? [String] ?? [] where object[key] == nil {
                throw MCPError.invalid("Missing \(location).\(key).")
            }
            for (key, child) in object {
                if let childSchema = properties[key] { try validate(child, schema: childSchema, location: "\(location).\(key)") }
                else if schema["additionalProperties"] as? Bool == false { throw MCPError.invalid("Unknown \(location).\(key).") }
            }
        } else if let array = value as? [Any] {
            guard types.isEmpty || types.contains("array") else { throw MCPError.invalid("\(location) must not be an array.") }
            if let items = schema["items"] as? [String: Any] {
                for child in array {
                    try validate(child, schema: items, location: location)
                }
            }
        } else if !types.isEmpty {
            let valid: Bool
            if let number = value as? NSNumber {
                let isBool = CFGetTypeID(number) == CFBooleanGetTypeID()
                valid = isBool ? types.contains("boolean") : types.contains("number") || (types.contains("integer") && number.doubleValue.rounded() == number.doubleValue)
            } else { valid = value is String && types.contains("string") }
            guard valid else { throw MCPError.invalid("\(location) has the wrong type.") }
        }
        if let allowed = schema["enum"] as? [Any], !allowed.contains(where: { NSDictionary(dictionary: ["v": $0]).isEqual(to: ["v": value]) }) {
            throw MCPError.invalid("\(location) is not an allowed value.")
        }
    }
}

private struct JSONOrderCursor {
    let data: Data
    var index = 0

    mutating func objectMembers() throws -> [(key: String, value: Range<Int>)] {
        skipWhitespace()
        try consume(ascii: 123)
        skipWhitespace()
        var members = [(key: String, value: Range<Int>)]()
        if consumeIf(ascii: 125) { return members }
        while true {
            let key = try string()
            skipWhitespace()
            try consume(ascii: 58)
            skipWhitespace()
            let start = index
            try skipValue()
            members.append((key, start..<index))
            skipWhitespace()
            if consumeIf(ascii: 125) { return members }
            try consume(ascii: 44)
            skipWhitespace()
        }
    }

    private mutating func string() throws -> String {
        guard index < data.count, data[index] == 34 else { throw MCPError.invalid("Invalid JSON string.") }
        let start = index
        index += 1
        var escaped = false
        while index < data.count {
            let byte = data[index]
            index += 1
            if escaped { escaped = false }
            else if byte == 92 { escaped = true }
            else if byte == 34 {
                return try JSONDecoder().decode(String.self, from: Data(data[start..<index]))
            }
        }
        throw MCPError.invalid("Unterminated JSON string.")
    }

    private mutating func skipValue() throws {
        skipWhitespace()
        guard index < data.count else { throw MCPError.invalid("Missing JSON value.") }
        switch data[index] {
        case 34:
            _ = try string()
        case 123:
            _ = try objectMembers()
        case 91:
            index += 1
            skipWhitespace()
            if consumeIf(ascii: 93) { return }
            while true {
                try skipValue()
                skipWhitespace()
                if consumeIf(ascii: 93) { return }
                try consume(ascii: 44)
                skipWhitespace()
            }
        default:
            let start = index
            while index < data.count, ![9, 10, 13, 32, 44, 93, 125].contains(data[index]) {
                index += 1
            }
            guard index > start else { throw MCPError.invalid("Invalid JSON value.") }
        }
    }

    private mutating func skipWhitespace() {
        while index < data.count, [9, 10, 13, 32].contains(data[index]) {
            index += 1
        }
    }

    private mutating func consume(ascii: UInt8) throws {
        guard consumeIf(ascii: ascii) else { throw MCPError.invalid("Invalid JSON structure.") }
    }

    private mutating func consumeIf(ascii: UInt8) -> Bool {
        guard index < data.count, data[index] == ascii else { return false }
        index += 1
        return true
    }
}

enum MCPError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}
#endif
