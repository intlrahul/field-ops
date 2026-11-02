import Foundation
import Testing
@testable import PathRouter

private func registry() throws -> RouteRegistry {
    try RouteRegistry(routes: [
        .init("/"),
        .init("/account", parent: "/"),
        .init("/inspections", parent: "/"),
        .init("/inspections/:id", parent: "/inspections", validate: {
            guard $0["id"]?.allSatisfy(\.isNumber) == true else {
                throw RoutingError.invalidParameter("id")
            }
        }),
        .init("/inspections/new", parent: "/inspections")
    ])
}

@Test func buildsParentStack() throws {
    let result = try registry().resolve("/inspections/123")
    #expect(result.entries.map(\.path) == ["/", "/inspections", "/inspections/123"])
    #expect(result.entries.last?.parameters["id"] == "123")
}

@Test func staticRouteWins() throws {
    #expect(try registry().resolve("/inspections/new").entries.last?.pattern == "/inspections/new")
}

@Test func invalidParameterRejected() throws {
    #expect(throws: RoutingError.invalidParameter("id")) {
        try registry().resolve("/inspections/abc")
    }
}

@Test func malformedPathsRejected() throws {
    for path in ["inspections", "/inspections//123", "/inspections/%2F", "/../account", "/account?x=1"] {
        #expect(throws: (any Error).self) { try registry().resolve(path) }
    }
}

@Test func equivalentPatternsRejected() {
    #expect(throws: (any Error).self) {
        try RouteRegistry(routes: [.init("/"), .init("/:id", parent: "/"), .init("/:name", parent: "/")])
    }
}

@Test func parentCyclesRejected() {
    #expect(throws: (any Error).self) {
        try RouteRegistry(routes: [.init("/"), .init("/a", parent: "/b"), .init("/b", parent: "/a")])
    }
}

@Test func tiedMatchesRejected() throws {
    let routes = try RouteRegistry(routes: [.init("/"), .init("/a/:x", parent: "/"), .init("/:x/b", parent: "/")])
    #expect(throws: RoutingError.ambiguousRoute("/a/b")) { try routes.resolve("/a/b") }
}

@Test func linksHaveSharedResolution() throws {
    let config = DeepLinkConfiguration(customScheme: "fieldops", universalLinkHosts: ["example.com"])
    for raw in ["fieldops://inspections/123", "fieldops:///inspections/123", "https://example.com/inspections/123"] {
        let path = try config.path(from: #require(URL(string: raw)))
        #expect(try registry().resolve(path).entries.last?.parameters["id"] == "123")
    }
    #expect(throws: RoutingError.untrustedURL) {
        try config.path(from: #require(URL(string: "https://evil.example/inspections/123")))
    }
}
