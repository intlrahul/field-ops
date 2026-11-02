//
//  AppRootView.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI
import PathRouterUI

struct AppRootView: View {
    let coordinator: AppCoordinator
    let container: AppContainer
    let signedInStack: RouterStack

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
                signedInStack
            case .restoringSession:
                AppLoadingScreen()
            }
        }.task {
            await coordinator.start()
        }
        .onOpenURL { url in
            coordinator.handleURL(url)
        }
    }
}
