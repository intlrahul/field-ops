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

@MainActor
@Observable
final class AppCoordinator {
    private(set) var flow: AppFlow = .restoringSession

    func start() async {
        flow = .signedOut
    }

    func didSignIn() {
        flow = .signedIn
    }

    func didSignOut() {
        // Clear protected navigation state when we add it.
        flow = .signedOut
    }
}
