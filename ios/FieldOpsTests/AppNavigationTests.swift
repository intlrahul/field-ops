import SwiftUI
import Testing
import PathRouter
import PathRouterUI
@testable import FieldOps

private nonisolated struct FixedRestoration: RestoreSessionUseCase {
    let result: SessionRestorationResult
    func execute() async throws -> SessionRestorationResult { result }
}

private actor DelayedRestoration: RestoreSessionUseCase {
    private var continuation: CheckedContinuation<SessionRestorationResult, Never>?

    func execute() async throws -> SessionRestorationResult {
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilStarted() async {
        while continuation == nil { await Task.yield() }
    }

    func finish() {
        continuation?.resume(returning: .authenticated)
        continuation = nil
    }
}

@MainActor
struct AppNavigationTests {
    private func coordinator(restoration: any RestoreSessionUseCase) throws -> AppCoordinator {
        let screens = try ScreenRegistry(screens: [
            ScreenRoute(DashboardRoutes.path) { _ in Text("Dashboard") },
            ScreenRoute(AccountRoutes.path, parent: DashboardRoutes.path) { _ in Text("Account") }
        ])
        return AppCoordinator(restoreSessionUseCase: restoration, router: screens.makeRouter())
    }

    @Test func restorationResumesPendingDeepLink() async throws {
        let coordinator = try coordinator(restoration: FixedRestoration(result: .authenticated))
        coordinator.handleURL(try #require(URL(string: "fieldops://account")))
        #expect(coordinator.router.path.isEmpty)
        await coordinator.start()
        #expect(coordinator.flow == .signedIn)
        #expect(coordinator.router.path.map(\.path) == [AccountRoutes.path])
        await coordinator.start()
        #expect(coordinator.router.path.map(\.path) == [AccountRoutes.path])
    }

    @Test func loginPreservesPendingLinkButLogoutDiscardsIt() async throws {
        let coordinator = try coordinator(restoration: FixedRestoration(result: .signedOut))
        coordinator.handleURL(try #require(URL(string: "fieldops://account")))
        await coordinator.start()
        #expect(coordinator.flow == .signedOut)
        #expect(coordinator.router.needsSignIn)
        coordinator.didSignIn()
        #expect(coordinator.router.path.map(\.path) == [AccountRoutes.path])
        coordinator.didSignOut()
        #expect(coordinator.router.path.isEmpty)
        coordinator.didSignIn()
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func unknownLinksPreserveHistoryAndBackReturnsToRoot() throws {
        let coordinator = try coordinator(restoration: FixedRestoration(result: .signedOut))
        coordinator.didSignIn()
        try coordinator.router.navigate(to: AccountRoutes.path, mode: .push)
        coordinator.handleURL(try #require(URL(string: "fieldops://unknown")))
        #expect(coordinator.router.path.map(\.path) == [AccountRoutes.path])
        #expect(coordinator.router.lastError != nil)
        coordinator.router.acceptSystemPath([])
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func lateRestorationCannotUndoLogout() async throws {
        let restoration = DelayedRestoration()
        let coordinator = try coordinator(restoration: restoration)
        let task = Task { await coordinator.start() }
        await restoration.waitUntilStarted()
        coordinator.didSignOut()
        await restoration.finish()
        await task.value
        #expect(coordinator.flow == .signedOut)
        #expect(coordinator.router.path.isEmpty)
    }

    @Test func inspectionDeepLinkResumesAboveDashboardAfterLogin() async throws {
        let registrations = DashboardRoutes.registrations() + InspectionRoutes.registrations()
        let registry = try RouteRegistry(routes: registrations.map(\.definition))
        let router = Router(registry: registry)
        let coordinator = AppCoordinator(
            restoreSessionUseCase: FixedRestoration(result: .signedOut), router: router
        )
        let inspection = try #require(Inspection.samples.first)
        let path = InspectionRoutes.detailsPath(id: inspection.id)
        coordinator.handleURL(try #require(URL(string: "fieldops://" + path.dropFirst())))
        await coordinator.start()
        #expect(coordinator.flow == .signedOut)
        coordinator.didSignIn()
        #expect(router.path.map(\.path) == [path])
        #expect(router.path.first?.parameters["id"] == inspection.id)
        #expect(try registry.resolve(path).entries.map(\.path) == [DashboardRoutes.path, path])
        router.back()
        #expect(router.path.isEmpty)
    }

    @Test func inspectionPathsEncodeSegmentsAndRejectMalformedParameters() throws {
        let registrations = DashboardRoutes.registrations() + InspectionRoutes.registrations()
        let registry = try RouteRegistry(routes: registrations.map(\.definition))
        let path = InspectionRoutes.detailsPath(id: "sample with space")
        #expect(path == "/inspections/sample%20with%20space")
        #expect(try registry.resolve(path).entries.last?.parameters["id"] == "sample with space")
        #expect(throws: RoutingError.self) { try registry.resolve("/inspections/%20") }
        #expect(throws: RoutingError.self) { try registry.resolve("/inspections/bad%2Fid") }
    }

}
