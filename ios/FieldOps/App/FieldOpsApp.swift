//
//  FieldOpsApp.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

@main
struct FieldOpsApp: App {
    @State private var coordinator: AppCoordinator
    private let container: AppContainer

    init() {
        guard let baseURL = URL(string: "http://localhost:3000") else {
            fatalError("Invalid API base URL configuration")
        }

        let container = AppContainer(baseURL: baseURL)
        self.container = container

        _coordinator = State(
            initialValue: AppCoordinator(
                restoreSessionUseCase: container.authFactory.restoreSessionUseCase
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                coordinator: coordinator,
                container: container
            )
        }
    }
}
