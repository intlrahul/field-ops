import Foundation
import Observation

@MainActor @Observable
final class InspectionListViewModel {
    private let getInspections: any GetInspectionsUseCase
    private let getStatistics: any GetInspectionStatisticsUseCase
    private var filterRevision = 0
    private(set) var selectedStatus: InspectionStatus?
    private(set) var inspections: [Inspection] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?

    private(set) var statistics: InspectionStatistics?
    private(set) var isLoadingStatistics = false
    private(set) var statisticsError: String?

    func refresh() async {
        async let list: Void = load()
        async let totals: Void = loadStatistics()
        _ = await (list, totals)
    }

    func loadStatistics() async {
        guard !isLoadingStatistics else { return }
        isLoadingStatistics = true
        statisticsError = nil
        defer { isLoadingStatistics = false }
        do {
            let response = try await getStatistics.execute()
            try Task.checkCancellation()
            statistics = response
        } catch {
            guard !Task.isCancelled else { return }
            statistics = nil
            statisticsError = (error as? BackendError)?.message ?? "Unable to load inspection statistics. Please try again."
        }
    }

    init(getInspections: any GetInspectionsUseCase, getStatistics: any GetInspectionStatisticsUseCase, initialStatus: InspectionStatus? = nil) {
        self.getInspections = getInspections
        self.getStatistics = getStatistics
        self.selectedStatus = initialStatus
    }

    func selectStatus(_ status: InspectionStatus?) async {
        guard status != selectedStatus else { return }
        selectedStatus = status
        filterRevision += 1
        // Older requests may finish, but cannot publish into this filter's state.
        isLoading = false
        hasLoaded = false
        inspections = []
        nextCursor = nil
        errorMessage = nil
        await load()
    }

    func load(reset: Bool = true) async {
        guard !isLoading, reset || nextCursor != nil else { return }
        let revision = filterRevision
        isLoading = true
        errorMessage = nil
        defer { if revision == filterRevision { isLoading = false } }
        do {
            let page = try await getInspections.execute(cursor: reset ? nil : nextCursor, status: selectedStatus)
            try Task.checkCancellation()
            guard revision == filterRevision else { return }
            var combined = reset ? [] : inspections
            for item in page.items {
                if let index = combined.firstIndex(where: { $0.id == item.id }) { combined[index] = item }
                else { combined.append(item) }
            }
            inspections = combined
            nextCursor = page.nextCursor
            hasLoaded = true
        } catch {
            guard !Task.isCancelled else { return }
            guard revision == filterRevision else { return }
            errorMessage = (error as? BackendError)?.message ?? "Unable to load inspections. Please try again."
        }
    }
}
