import Foundation
import Observation

@MainActor @Observable
final class InspectionListViewModel {
    private let getCurrentUser: any GetCurrentUserUseCase
    private(set) var user: User?
    private(set) var accessError: String?
    private var authorizationChanged = false
    private(set) var isCheckingAccess = false
    var canReadInspections: Bool { user?.can(.inspectionsRead) == true }

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
        guard await checkAccess() else { return }
        await reloadAuthorizedContent()
    }

    private func reloadAuthorizedContent() async {
        async let list: Void = loadPage()
        async let totals: Void = fetchStatistics()
        _ = await (list, totals)
    }

    func loadStatistics() async {
        guard await checkAccess() else { return }
        if authorizationChanged { await reloadAuthorizedContent() }
        else { await fetchStatistics() }
    }

    private func checkAccess() async -> Bool {
        guard !isCheckingAccess else { return false }
        isCheckingAccess = true
        authorizationChanged = false
        accessError = nil
        defer { isCheckingAccess = false }
        do {
            let profile = try await getCurrentUser.execute()
            try Task.checkCancellation()
            if let previous = user,
               previous.id != profile.id || previous.organizationId != profile.organizationId
                || previous.roles != profile.roles || previous.capabilities != profile.capabilities {
                clearInspectionAccess()
                authorizationChanged = true
            }
            user = profile
            if canReadInspections { return true }
            accessError = "Inspection access is unavailable for your account."
        } catch {
            guard !Task.isCancelled else { return false }
            user = nil
            accessError = (error as? BackendError)?.message ?? "Unable to verify inspection access. Please try again."
        }
        clearInspectionAccess()
        return false
    }

    private func clearInspectionAccess() {
        user = nil
        filterRevision += 1
        inspections = []
        nextCursor = nil
        statistics = nil
        errorMessage = nil
        statisticsError = nil
        hasLoaded = false
        isLoading = false
        isLoadingStatistics = false
    }

    private func fetchStatistics() async {
        guard !isLoadingStatistics else { return }
        let revision = filterRevision
        isLoadingStatistics = true
        statisticsError = nil
        defer { if revision == filterRevision { isLoadingStatistics = false } }
        do {
            let response = try await getStatistics.execute()
            try Task.checkCancellation()
            guard revision == filterRevision, canReadInspections else { return }
            statistics = response
        } catch {
            guard !Task.isCancelled, revision == filterRevision else { return }
            if let rejection = error as? BackendError, ["FORBIDDEN", "UNAUTHORIZED"].contains(rejection.code) {
                clearInspectionAccess()
                accessError = rejection.message
                return
            }
            statistics = nil
            statisticsError = (error as? BackendError)?.message ?? "Unable to load inspection statistics. Please try again."
        }
    }

    init(getInspections: any GetInspectionsUseCase, getStatistics: any GetInspectionStatisticsUseCase, initialStatus: InspectionStatus? = nil, getCurrentUser: any GetCurrentUserUseCase) {
        self.getCurrentUser = getCurrentUser
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
        guard await checkAccess() else { return }
        if authorizationChanged { await reloadAuthorizedContent() }
        else { await loadPage(reset: reset || !hasLoaded) }
    }

    private func loadPage(reset: Bool = true) async {
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
            if let rejection = error as? BackendError, ["FORBIDDEN", "UNAUTHORIZED"].contains(rejection.code) {
                clearInspectionAccess()
                accessError = rejection.message
                return
            }
            errorMessage = (error as? BackendError)?.message ?? "Unable to load inspections. Please try again."
        }
    }
}
