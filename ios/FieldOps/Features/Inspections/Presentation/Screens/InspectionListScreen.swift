import PathRouterUI
import Prism
import SwiftUI

struct InspectionListScreen: View {
    @Environment(Router.self) private var router
    @State private var viewModel: InspectionListViewModel
    @State private var navigationError: String?

    init(viewModel: InspectionListViewModel) { _viewModel = State(initialValue: viewModel) }

    private var title: String {
        viewModel.selectedStatus.map { "\($0.title) inspections" } ?? "All inspections"
    }

    var body: some View {
        DSScreen(onRefresh: { await viewModel.load() }) {
            DSText(title, style: .title)
            if viewModel.canReadInspections {
                if let error = viewModel.errorMessage {
                    DSMessage(error, tone: .danger)
                    DSButton(title: "Retry") { Task { await viewModel.load() } }
                }
                if !viewModel.hasLoaded && viewModel.errorMessage == nil {
                    DSSkeleton(label: "Loading inspections")
                    DSSkeleton(label: "Loading more inspections")
                }
                if viewModel.hasLoaded && viewModel.inspections.isEmpty {
                    DSEmptyState(title: "No inspections", message: "There are no inspections matching this status.")
                }
                LazyVStack(spacing: DSSpacing.sm) {
                    ForEach(viewModel.inspections) { inspection in
                        DSNavigationCard(action: { open(inspection) }) {
                            InspectionRow(inspection: inspection)
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
                    Task { await viewModel.load() }
                }
            } else {
                DSSkeleton(label: "Checking inspection access")
            }
        }
        .task { if !viewModel.hasLoaded { await viewModel.load() } }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to navigate", isPresented: Binding(
            get: { navigationError != nil }, set: { if !$0 { navigationError = nil } }
        )) {
            Button("OK", role: .cancel) { navigationError = nil }
        } message: { Text(navigationError ?? "") }
    }

    private func open(_ inspection: Inspection) {
        do { try router.navigate(to: InspectionRoutes.detailsPath(id: inspection.id), mode: .push) }
        catch { navigationError = "This inspection is currently unavailable." }
    }
}
