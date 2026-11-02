// Integration sketch: copy/adapt into FieldOps, not part of the library target.
import SwiftUI
import PathRouter
import PathRouterUI

@MainActor
func fieldOpsScreens() throws -> ScreenRegistry {
    try ScreenRegistry(screens: [
        ScreenRoute("/") { _ in DashboardExample() },
        ScreenRoute("/account", parent: "/") { _ in
            Text("Replace with AccountScreen from your factory")
        },
        ScreenRoute("/inspections", parent: "/") { _ in
            Text("Replace with InspectionListScreen")
        },
        ScreenRoute("/inspections/:id", parent: "/inspections", validate: { parameters in
            guard let id = parameters["id"], !id.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw RoutingError.invalidParameter("id")
            }
        }) { entry in
            Text("Inspection: \(entry.parameters["id"] ?? "")")
        }
    ])
}

struct DashboardExample: View {
    @Environment(Router.self) private var router
    @State private var errorMessage: String?

    var body: some View {
        List {
            Button("Account") { navigate("/account") }
            Button("Inspection 123") { navigate("/inspections/123") }
            if let errorMessage { Text(errorMessage) }
        }
        .navigationTitle("Dashboard")
    }

    private func navigate(_ path: String) {
        do { try router.navigate(to: path) }
        catch { errorMessage = "This destination is unavailable." }
    }
}

// At app composition time:
// let screens = try fieldOpsScreens()
// let router = screens.makeRouter()
// let stack = try RouterStack(router: router, screens: screens)
// Retain all three; never recreate the router in body.
//
// In AppRootView, keep your existing restoring/login/signed-in flow switch.
// signed-in branch: stack
// Root-level .onOpenURL (MUST also exist while login/restoration is showing):
// router.open(url, configuration: DeepLinkConfiguration(customScheme: "fieldops"))
//
// After session restoration:
// router.setAuthentication(.signedIn) or .signedOut
// After login and session save:
// router.setAuthentication(.signedIn)  // resumes pending deep link
// coordinator.didSignIn()            // shows the signed-in stack
// After successful local logout:
// router.resetForSignOut()
// coordinator.didSignOut()
//
// If coordinator controls flow, its restoration/login/logout transition methods
// should make these router calls together. Router does not validate credentials.
