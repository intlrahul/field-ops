import Foundation

public struct DeepLinkConfiguration: Sendable {
    private let customScheme: String
    private let universalLinkHosts: Set<String>

    public init(customScheme: String, universalLinkHosts: Set<String> = []) {
        self.customScheme = customScheme.lowercased()
        self.universalLinkHosts = Set(universalLinkHosts.map { $0.lowercased() })
    }

    /// Supports fieldops:///inspections/123 and fieldops://inspections/123.
    /// HTTPS links require an explicitly trusted host. Queries/fragments are unsupported in v1.
    public func path(from url: URL) throws -> String {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.port == nil,
              parts.query == nil, parts.fragment == nil,
              let scheme = parts.scheme?.lowercased() else {
            throw RoutingError.untrustedURL
        }
        let path: String
        if scheme == customScheme {
            let host = parts.percentEncodedHost ?? ""
            path = (host.isEmpty ? "" : "/" + host) + parts.percentEncodedPath
        } else if scheme == "https", let host = parts.host?.lowercased(),
                  universalLinkHosts.contains(host) {
            path = parts.percentEncodedPath
        } else { throw RoutingError.untrustedURL }
        let result = path.isEmpty ? "/" : path
        _ = try RoutePath.segments(result)
        return result
    }
}
