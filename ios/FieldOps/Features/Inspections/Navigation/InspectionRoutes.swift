import SwiftUI
import PathRouter

@MainActor
enum InspectionRoutes {
    static let detailsPattern = "/inspections/:id"

    static func detailsPath(id: String) -> String {
        "/inspections/\(RoutePath.encodeSegment(id))"
    }

    static func registrations() -> [FeatureRoute] {
        [FeatureRoute(detailsPattern, parent: "/", validate: { parameters in
            guard let id = parameters["id"], !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RoutingError.invalidParameter("id")
            }
        }) { entry, _ in
            InspectionDetailsScreen(
                inspection: Inspection.samples.first { $0.id == entry.parameters["id"] }
            )
        }]
    }
}
