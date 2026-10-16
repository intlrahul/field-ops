//
//  AppRootView.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

struct AppRootView: View {
    let coordinator: AppCoordinator
    let container: AppContainer

    var body: some View {
        Group {
            switch coordinator.flow {
            case .signedOut:
                LoginScreen(
                    viewModel: container.loginViewModel(),
                    onSignedIn: {
                        coordinator.didSignIn()
                    }
                )

            case .signedIn:
                NavigationStack {
                    DashboardScreen()
                }
            case .restoringSession:
                ProgressView("Restoring session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.task {
            await coordinator.start()
        }
    }
}
