/// The app-level feature-registration list. Add new features here.
@MainActor
enum AppRoutes {
    static func registrations(container: AppContainer) -> [FeatureRoute] {
        DashboardRoutes.registrations()
            + InspectionRoutes.registrations()
            + AccountRoutes.registrations(
                sessionProvider: container.sessionStore,
                signoutUseCase: container.authFactory.signoutUseCase()
            )
    }
}
