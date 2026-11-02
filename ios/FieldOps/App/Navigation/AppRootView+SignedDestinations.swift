//
//  AppRootView+SignedDestinations.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import SwiftUI

enum SignedRoute: Hashable {
    case account
}

extension AppRootView {
    @ViewBuilder
    func signedInDestination(for route: SignedRoute) -> some View {
        switch route {
        case .account:
            AccountScreen(
                viewModel: container.accountFactory.accountViewModel(),
                onSignedOut: {
                    coordinator.didSignOut()
                }
            )
        }
    }
}
