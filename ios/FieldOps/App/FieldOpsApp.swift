//
//  FieldOpsApp.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

@main
struct FieldOpsApp: App {
    @State private var coordinator = AppCoordinator()
    private let container: AppContainer

    init() {
        guard let baseURL = URL(string: "http://localhost:3000") else {
            fatalError("Invalid API base URL configuration")
        }

        container = AppContainer(baseURL: baseURL)
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(coordinator: coordinator, container: container)
        }
    }
}
