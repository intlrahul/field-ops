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
                    viewModel: container.authFactory.loginViewModel(),
                    onSignedIn: {
                        coordinator.didSignIn()
                    }
                )

            case .signedIn:
                NavigationStack {
                    DashboardScreen()
                        .navigationDestination(for: SignedRoute.self) { route in
                            signedInDestination(for: route)
                        }
                }
            case .restoringSession:
                AppLoadingScreen()

            }
        }.task {
            await coordinator.start()
        }
    }
}
