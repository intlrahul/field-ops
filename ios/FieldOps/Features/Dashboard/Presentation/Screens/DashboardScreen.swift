import PathRouterUI
import Prism
import SwiftUI

struct DashboardScreen: View {
    @Environment(Router.self) private var router
    @State private var viewModel: InspectionListViewModel

    init(viewModel: InspectionListViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    @State private var navigationError: String?

    var body: some View {
        DSScreen(onRefresh: { await viewModel.refresh() }) {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                DSText("Your workspace", style: .captionStrong, tone: .accent)
                DSText("Inspection overview", style: .title)
                DSText(
                    "Review assigned work and keep your inspections moving.",
                    tone: .secondary
                )
            }
            if viewModel.canReadInspections {
                DSSection("Inspection statistics") {
                    if let statistics = viewModel.statistics {
                        DashboardSummaryView(statistics: statistics) { status in
                            navigate(to: InspectionRoutes.listPath(status: status))
                        }
                    }
                    if viewModel.statistics == nil && viewModel.statisticsError == nil {
                        DSSkeleton(.statistics, label: "Loading inspection statistics")
                    }
                    if viewModel.isLoadingStatistics && viewModel.statistics != nil {
                        DSLoadingRow("Updating statistics…")
                    }
                    if let error = viewModel.statisticsError {
                        DSMessage(error, tone: .danger)
                        DSButton(title: "Retry statistics") {
                            Task { await viewModel.loadStatistics() }
                        }
                    }
                }
                if let error = viewModel.errorMessage {
                    DSMessage(error, tone: .danger)
                    DSButton(title: "Retry") { Task { await viewModel.load() } }
                }
                if viewModel.hasLoaded && viewModel.inspections.isEmpty {
                    DSEmptyState(
                        title: "No inspections",
                        message: "There are no inspections available to your account."
                    )
                }
                DSSection("All inspections") {
                    if !viewModel.hasLoaded && viewModel.errorMessage == nil {
                        DSSkeleton(label: "Loading inspections")
                        DSSkeleton(label: "Loading more inspections")
                    }
                    LazyVStack(spacing: DSSpacing.sm) {
                        ForEach(viewModel.inspections) { inspection in
                            DSNavigationCard(action: {
                                navigate(
                                    to: InspectionRoutes.detailsPath(
                                        id: inspection.id
                                    )
                                )
                            }) {
                                InspectionRow(inspection: inspection)
                            }
                        }
                    }
                }
                if viewModel.nextCursor != nil {
                    DSButton(title: "Load more", isLoading: viewModel.isLoading) {
                        Task { await viewModel.load(reset: false) }
                    }
                }
            } else if let error = viewModel.accessError {
                DSMessage(error, tone: .warning)
                DSButton(title: "Retry access") {
                    Task { await viewModel.refresh() }
                }
            } else {
                DSSkeleton(label: "Checking inspection access")
            }
        }
        .task { if !viewModel.hasLoaded || viewModel.statistics == nil { await viewModel.refresh() } }
        .navigationTitle("FieldOps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                FieldOpsLogo(compact: true)
            }
            ToolbarItem(placement: .topBarTrailing) {
                DSIconButton(title: "Account", symbol: "person.crop.circle") {
                    navigate(to: AccountRoutes.path)
                }
            }
        }
        .alert(
            "Unable to navigate",
            isPresented: Binding(
                get: { navigationError != nil },
                set: { if !$0 { navigationError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { navigationError = nil }
        } message: {
            Text(navigationError ?? "")
        }
    }

    private func navigate(to path: String) {
        do { try router.navigate(to: path, mode: .push) } catch {
            navigationError = "This destination is currently unavailable."
        }
    }
}

#Preview {
    let screens = try! ScreenRegistry(
        screens: [
            ScreenRoute(DashboardRoutes.path) { _ in
                DashboardScreen(
                    viewModel: InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: PreviewInspectionRepository()), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: PreviewInspectionRepository()), getCurrentUser: PreviewCurrentUserUseCase())
                )
            },
            ScreenRoute(AccountRoutes.path, parent: DashboardRoutes.path) { _ in
                Text("Account preview")
            },
        ]
            + InspectionRoutes.registrations(getDetails: DefaultGetInspectionDetailsUseCase(repository: PreviewInspectionRepository()), getInspections: DefaultGetInspectionsUseCase(repository: PreviewInspectionRepository()), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: PreviewInspectionRepository()), getCurrentUser: PreviewCurrentUserUseCase()).map { $0.screen(actions: NavigationActions(onSignedOut: {})) }
    )
    let router = screens.makeRouter(authentication: .signedIn)
    try! RouterStack(router: router, screens: screens).designTheme()
}
