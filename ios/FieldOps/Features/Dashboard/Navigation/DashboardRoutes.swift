import SwiftUI

@MainActor
enum DashboardRoutes {
    static let path = "/"

    static func registrations(
        getInspections: any GetInspectionsUseCase,
        getStatistics: any GetInspectionStatisticsUseCase,
        getCurrentUser: any GetCurrentUserUseCase
    )
        -> [FeatureRoute]
    {
        [
            FeatureRoute(path) { _, _ in
                DashboardScreen(
                    viewModel: InspectionListViewModel(
                        getInspections: getInspections,
                        getStatistics: getStatistics, getCurrentUser: getCurrentUser
                    )
                )
            }
        ]
    }
}
