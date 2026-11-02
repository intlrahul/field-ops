import Prism
import SwiftUI
import PathRouterUI

struct DashboardScreen: View {
    @Environment(Router.self) private var router
    @State private var navigationError: String?

    var body: some View {
        DSScreen {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                DSText("Your workspace", style: .captionStrong, tone: .accent)
                DSText("Inspection overview", style: .title)
                DSText("Review assigned work and keep your inspections moving.", tone: .secondary)
            }
            DashboardSummaryView(inspections: Inspection.samples)
            DSSection("Your inspections") {
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(Inspection.samples) { inspection in
                        DSNavigationCard(action: {
                            navigate(to: InspectionRoutes.detailsPath(id: inspection.id))
                        }) {
                            InspectionRow(inspection: inspection)
                        }
                    }
                }
            }
        }
        .navigationTitle("FieldOps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FieldOpsLogo(compact: true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                DSIconButton(title: "Account", symbol: "person.crop.circle") { navigate(to: AccountRoutes.path) }
            }
        }
        .alert("Unable to navigate", isPresented: Binding(
            get: { navigationError != nil }, set: { if !$0 { navigationError = nil } }
        )) {
            Button("OK", role: .cancel) { navigationError = nil }
        } message: { Text(navigationError ?? "") }
    }

    private func navigate(to path: String) {
        do { try router.navigate(to: path, mode: .push) }
        catch { navigationError = "This destination is currently unavailable." }
    }
}

#Preview {
    let screens = try! ScreenRegistry(screens: [
        ScreenRoute(DashboardRoutes.path) { _ in DashboardScreen() },
        ScreenRoute(AccountRoutes.path, parent: DashboardRoutes.path) { _ in Text("Account preview") }
    ] + InspectionRoutes.registrations().map { $0.screen(actions: NavigationActions(onSignedOut: {})) })
    let router = screens.makeRouter(authentication: .signedIn)
    try! RouterStack(router: router, screens: screens).designTheme()
}
