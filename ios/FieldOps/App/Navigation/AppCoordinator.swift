import Observation
import Foundation
import PathRouter
import PathRouterUI

enum AppFlow {
    case restoringSession
    case signedOut
    case signedIn
}

@MainActor
@Observable
final class AppCoordinator {
    private(set) var flow: AppFlow = .restoringSession
    let router: Router

    private let restoreSessionUseCase: any RestoreSessionUseCase
    private let links = DeepLinkConfiguration(customScheme: "fieldops")
    private var restorationRunning = false
    private var transitionRevision = 0

    init(restoreSessionUseCase: any RestoreSessionUseCase, router: Router) {
        self.restoreSessionUseCase = restoreSessionUseCase
        self.router = router
    }

    func start() async {
        guard flow == .restoringSession, !restorationRunning else { return }
        restorationRunning = true
        let revision = transitionRevision
        defer { restorationRunning = false }

        do {
            let result = try await restoreSessionUseCase.execute()
            try Task.checkCancellation()
            guard transitionRevision == revision, flow == .restoringSession else { return }
            switch result {
            case .authenticated:
                didSignIn()
            case .signedOut:
                showSignIn()
            }
        } catch is CancellationError {
            // A replacement root task can retry restoration without discarding a link.
            return
        } catch {
            guard !Task.isCancelled, transitionRevision == revision, flow == .restoringSession else { return }
            // Restoration error/retry UI remains a separate concern.
            showSignIn()
        }
    }

    func didSignIn() {
        transitionRevision += 1
        router.setAuthentication(.signedIn)
        flow = .signedIn
    }

    func didSignOut() {
        transitionRevision += 1
        router.resetForSignOut()
        flow = .signedOut
    }

    func handleURL(_ url: URL) {
        router.open(url, configuration: links)
    }

    private func showSignIn() {
        transitionRevision += 1
        // Unlike logout, startup without a session must preserve a pending link.
        router.setAuthentication(.signedOut)
        flow = .signedOut
    }
}
