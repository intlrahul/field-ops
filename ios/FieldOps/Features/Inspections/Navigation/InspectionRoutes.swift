import PathRouter
import SwiftUI

@MainActor
enum InspectionRoutes {
    static let listPattern = "/inspection-lists/:status"

    static func listPath(status: InspectionStatus?) -> String {
        "/inspection-lists/\(status?.rawValue ?? "all")"
    }

    static let detailsPattern = "/inspections/:id"

    static func detailsPath(id: String) -> String {
        "/inspections/\(RoutePath.encodeSegment(id))"
    }

    static func registrations(getDetails: any GetInspectionDetailsUseCase, getInspections: any GetInspectionsUseCase, getStatistics: any GetInspectionStatisticsUseCase)
        -> [FeatureRoute]
    {
        [
            FeatureRoute(listPattern, parent: "/", validate: { parameters in
                guard let status = parameters["status"],
                      status == "all" || InspectionStatus(rawValue: status) != nil else {
                    throw RoutingError.invalidParameter("status")
                }
            }) { entry, _ in
                InspectionListScreen(viewModel: InspectionListViewModel(
                    getInspections: getInspections, getStatistics: getStatistics,
                    initialStatus: InspectionStatus(rawValue: entry.parameters["status"]!)
                ))
            },
            FeatureRoute(
                detailsPattern,
                parent: "/",
                validate: { parameters in
                    guard let id = parameters["id"],
                        !id.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    else {
                        throw RoutingError.invalidParameter("id")
                    }
                }
            ) { entry, _ in
                InspectionDetailsScreen(
                    viewModel: InspectionDetailViewModel(
                        id: entry.parameters["id"]!,
                        getDetails: getDetails
                    )
                )
            }
        ]
    }
}
