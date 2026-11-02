/// The app-level feature-registration list. Add new features here.
@MainActor
enum AppRoutes {
    static func registrations(container: AppContainer) -> [FeatureRoute] {
        DashboardRoutes.registrations(
            getInspections: DefaultGetInspectionsUseCase(repository: container.inspectionRepository),
            getStatistics: DefaultGetInspectionStatisticsUseCase(repository: container.inspectionRepository)
        )
            + InspectionRoutes.registrations(
                getDetails: DefaultGetInspectionDetailsUseCase(repository: container.inspectionRepository), getInspections: DefaultGetInspectionsUseCase(repository: container.inspectionRepository), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: container.inspectionRepository)
            )
            + AccountRoutes.registrations(
                sessionProvider: container.sessionStore,
                signoutUseCase: container.authFactory.signoutUseCase()
            )
    }
}
