import Foundation

public enum RoutingError: Error, Equatable, Sendable {
    case invalidPath(String)
    case invalidRegistration(String)
    case unknownRoute(String)
    case ambiguousRoute(String)
    case invalidParameter(String)
    case untrustedURL
}

public struct RouteEntry: Hashable, Sendable {
    public let pattern: String
    public let parameters: [String: String]
    public let path: String
}

public struct RouteDefinition: Sendable {
    public let pattern: String
    public let parent: String?
    public let requiresAuthentication: Bool
    let validate: @Sendable ([String: String]) throws -> Void

    public init(
        _ pattern: String,
        parent: String? = nil,
        requiresAuthentication: Bool = true,
        validate: @escaping @Sendable ([String: String]) throws -> Void = { _ in }
    ) {
        self.pattern = pattern
        self.parent = parent
        self.requiresAuthentication = requiresAuthentication
        self.validate = validate
    }
}

public struct ResolvedRoute: Sendable {
    /// Root included; the SwiftUI adapter removes it from the pushed path.
    public let entries: [RouteEntry]
    public let requiresAuthentication: Bool
}

/// Strict paths: no query strings, fragments, repeated slashes, or trailing slash.
/// Percent-encoded values are decoded once; encoded slashes and dot segments are rejected.
public enum RoutePath {
    public static func segments(_ path: String) throws -> [String] {
        guard path.hasPrefix("/"), !path.contains("?"), !path.contains("#") else {
            throw RoutingError.invalidPath(path)
        }
        if path == "/" { return [] }
        let parts = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false)
        return try parts.map { part in
            guard !part.isEmpty, let value = String(part).removingPercentEncoding,
                  !value.isEmpty, value != ".", value != "..",
                  !value.contains("/"), !value.contains("\\"),
                  !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
                throw RoutingError.invalidPath(path)
            }
            return value
        }
    }

    public static func encodeSegment(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")) ?? ""
    }
}

public struct RouteRegistry: Sendable {
    public let rootPattern: String
    private let definitions: [String: RouteDefinition]

    public init(root: String = "/", routes: [RouteDefinition]) throws {
        var table: [String: RouteDefinition] = [:]
        var shapes = Set<String>()
        for route in routes {
            let parts = try RoutePath.segments(route.pattern)
            var names = Set<String>()
            for part in parts where part.hasPrefix(":") {
                let name = String(part.dropFirst())
                guard !name.isEmpty, names.insert(name).inserted else {
                    throw RoutingError.invalidRegistration(route.pattern)
                }
            }
            let shape = parts.map { $0.hasPrefix(":") ? ":" : $0 }.joined(separator: "/")
            guard table[route.pattern] == nil, shapes.insert(shape).inserted else {
                throw RoutingError.invalidRegistration(route.pattern)
            }
            table[route.pattern] = route
        }
        guard let rootRoute = table[root], rootRoute.parent == nil,
              try RoutePath.segments(root).allSatisfy({ !$0.hasPrefix(":") }) else {
            throw RoutingError.invalidRegistration(root)
        }
        for route in routes where route.pattern != root {
            var visited = Set<String>()
            var current = route
            let available = Set(try RoutePath.segments(route.pattern).filter { $0.hasPrefix(":") })
            while current.pattern != root {
                guard visited.insert(current.pattern).inserted,
                      let parent = current.parent, let next = table[parent] else {
                    throw RoutingError.invalidRegistration(route.pattern)
                }
                let needed = Set(try RoutePath.segments(next.pattern).filter { $0.hasPrefix(":") })
                guard needed.isSubset(of: available) else {
                    throw RoutingError.invalidRegistration(route.pattern)
                }
                current = next
            }
        }
        self.rootPattern = root
        self.definitions = table
    }

    public func resolve(_ path: String) throws -> ResolvedRoute {
        let values = try RoutePath.segments(path)
        var matches: [(RouteDefinition, [String: String], Int)] = []
        for definition in definitions.values {
            let pattern = try RoutePath.segments(definition.pattern)
            guard pattern.count == values.count else { continue }
            var parameters: [String: String] = [:]
            var score = 0
            var matchesPattern = true
            for (part, value) in zip(pattern, values) {
                if part.hasPrefix(":") { parameters[String(part.dropFirst())] = value }
                else if part == value { score += 1 }
                else { matchesPattern = false; break }
            }
            if matchesPattern { matches.append((definition, parameters, score)) }
        }
        guard let highest = matches.map({ $0.2 }).max() else {
            throw RoutingError.unknownRoute(path)
        }
        let winners = matches.filter { $0.2 == highest }
        guard winners.count == 1, let winner = winners.first else {
            throw RoutingError.ambiguousRoute(path)
        }
        var chain: [RouteEntry] = []
        var protected = false
        var current: RouteDefinition? = winner.0
        while let definition = current {
            let parts = try RoutePath.segments(definition.pattern)
            let names = parts.filter { $0.hasPrefix(":") }.map { String($0.dropFirst()) }
            let parameters = winner.1.filter { names.contains($0.key) }
            try definition.validate(parameters)
            let concrete = try parts.map { part -> String in
                if part.hasPrefix(":") {
                    guard let value = parameters[String(part.dropFirst())] else {
                        throw RoutingError.invalidRegistration(definition.pattern)
                    }
                    return RoutePath.encodeSegment(value)
                }
                return RoutePath.encodeSegment(part)
            }
            chain.insert(RouteEntry(pattern: definition.pattern, parameters: parameters,
                                    path: "/" + concrete.joined(separator: "/")), at: 0)
            protected = protected || definition.requiresAuthentication
            current = definition.parent.flatMap { definitions[$0] }
        }
        return ResolvedRoute(entries: chain, requiresAuthentication: protected)
    }
}
