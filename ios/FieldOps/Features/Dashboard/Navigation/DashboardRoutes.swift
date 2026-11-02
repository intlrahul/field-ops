import SwiftUI

@MainActor
enum DashboardRoutes {
    static let path = "/"

    static func registrations() -> [FeatureRoute] {
        [FeatureRoute(path) { _, _ in DashboardScreen() }]
    }
}
