import Prism
import SwiftUI

@main
struct FieldOpsApp: App {
    @State private var composition: AppComposition

    init() {
        guard let baseURL = URL(string: "http://localhost:3000") else {
            fatalError("Invalid API base URL configuration")
        }
        do {
            _composition = State(initialValue: try AppComposition(baseURL: baseURL))
        } catch {
            preconditionFailure("Invalid app composition: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(
                coordinator: composition.coordinator,
                container: composition.container,
                signedInStack: composition.navigation.stack
            )
            .designTheme()
        }
    }
}
