//
//  AppCoordinator.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

enum AppFlow {
    case restoringSession
    case signedOut
    case signedIn
}

import Observation

@MainActor
@Observable
final class AppCoordinator {
    private(set) var flow: AppFlow = .restoringSession

    private let restoreSessionUseCase: any RestoreSessionUseCase

    init(restoreSessionUseCase: any RestoreSessionUseCase) {
        self.restoreSessionUseCase = restoreSessionUseCase
    }

    func start() async {
        do {
            let result = try await restoreSessionUseCase.execute()
            try Task.checkCancellation()

            switch result {
            case .authenticated:
                flow = .signedIn

            case .signedOut:
                flow = .signedOut
            }
        } catch is CancellationError {
            // This needs to be handled more gracefully
            flow = .signedOut
        } catch {
            // Show retry button with logout button.
            flow = .signedOut
        }
    }

    func didSignIn() {
        flow = .signedIn
    }

    func didSignOut() {
        flow = .signedOut
    }
}
