import Foundation
import Testing

@testable import FieldOps

private actor PagedInspectionRepository: InspectionRepository {
    private var cursors: [String?] = []
    private var statuses: [InspectionStatus?] = []
    private var shouldFail = false

    func statistics() async throws -> InspectionStatistics {
        if shouldFail { throw BackendError(code: "UNAVAILABLE", message: "Statistics unavailable.") }
        return InspectionStatistics(total: 50, assigned: 20, inProgress: 15, completed: 15)
    }

    func list(cursor: String?, status: InspectionStatus?) async throws -> InspectionPage {
        cursors.append(cursor)
        statuses.append(status)
        if shouldFail {
            throw BackendError(
                code: "UNAVAILABLE",
                message: "Service unavailable."
            )
        }
        return InspectionPage(
            items: Array(Inspection.samples.prefix(cursor == nil ? 1 : 2)),
            nextCursor: cursor == nil ? "page-two" : nil
        )
    }

    func detail(id: String) async throws -> InspectionDetail {
        throw BackendError(code: "NOT_FOUND", message: "Inspection not found.")
    }

    func fail() { shouldFail = true }
    func recover() { shouldFail = false }
    func requestedStatuses() -> [InspectionStatus?] { statuses }
    func requestedCursors() -> [String?] { cursors }
}

@MainActor
struct InspectionIntegrationTests {
    @Test func statusFilterResetsCursorAndPersistsAcrossPagination() async {
        let repository = PagedInspectionRepository()
        let model = InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: repository), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository), getCurrentUser: PreviewCurrentUserUseCase())
        await model.refresh()
        await model.load(reset: false)
        await model.selectStatus(.inProgress)
        await model.load(reset: false)
        await model.selectStatus(nil)
        let cursors = await repository.requestedCursors()
        let statuses = await repository.requestedStatuses()
        #expect(cursors == [nil, "page-two", nil, "page-two", nil])
        #expect(statuses == [nil, nil, .inProgress, .inProgress, nil])
        #expect(model.statistics?.total == 50)
    }

    @Test func statisticsRemainIndependentOfLoadedPages() async {
        let model = InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: PagedInspectionRepository()), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: PagedInspectionRepository()), getCurrentUser: PreviewCurrentUserUseCase())
        await model.refresh()
        #expect(model.inspections.count == 1)
        #expect(model.statistics == InspectionStatistics(total: 50, assigned: 20, inProgress: 15, completed: 15))
        await model.load(reset: false)
        #expect(model.inspections.count == 2)
        #expect(model.statistics?.total == 50)
    }

    @Test func statisticsFailureDoesNotSubstituteListCountsAndCanRetry() async {
        let repository = PagedInspectionRepository()
        let model = InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: repository), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository), getCurrentUser: PreviewCurrentUserUseCase())
        await model.refresh()
        await repository.fail()
        await model.loadStatistics()
        #expect(model.statistics == nil)
        #expect(model.statisticsError == "Statistics unavailable.")
        #expect(model.inspections.count == 1)
        #expect(!model.isLoadingStatistics)
        await repository.recover()
        await model.loadStatistics()
        #expect(model.statistics?.total == 50)
        #expect(model.statisticsError == nil)
    }

    @Test func mapsBackendStatusAndNullableDueDate() throws {
        let json = Data(
            """
            {"id":"inspection-id","title":"Pump check","status":"in_progress",
             "asset":{"assetTag":"PUMP-001","name":"Cooling pump","location":null},"dueAt":null}
            """.utf8
        )
        let inspection = try JSONDecoder().decode(
            InspectionSummaryDTO.self,
            from: json
        ).toDomain()
        #expect(inspection.status == .inProgress)
        #expect(inspection.dueDate == nil)
        #expect(inspection.assetName == "Cooling pump")
    }

    @Test func paginationDeduplicatesAndRefreshRestartsCursor() async {
        let repository = PagedInspectionRepository()
        let model = InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: repository), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository), getCurrentUser: PreviewCurrentUserUseCase())
        await model.load()
        await model.load(reset: false)
        #expect(model.inspections.count == 2)
        #expect(model.nextCursor == nil)
        await model.load()
        #expect(model.inspections.count == 1)
        let cursors = await repository.requestedCursors()
        #expect(cursors == [nil, "page-two", nil])
    }

    @Test func refreshFailurePreservesLoadedData() async {
        let repository = PagedInspectionRepository()
        let model = InspectionListViewModel(getInspections: DefaultGetInspectionsUseCase(repository: repository), getStatistics: DefaultGetInspectionStatisticsUseCase(repository: repository), getCurrentUser: PreviewCurrentUserUseCase())
        await model.load()
        await repository.fail()
        await model.load()
        #expect(model.inspections.count == 1)
        #expect(model.errorMessage == "Service unavailable.")
        #expect(!model.isLoading)
    }

    @Test func unavailableDetailShowsServerMessage() async {
        let model = InspectionDetailViewModel(
            id: "missing",
            getDetails: DefaultGetInspectionDetailsUseCase(repository: PagedInspectionRepository())
        )
        await model.load()
        #expect(model.detail == nil)
        #expect(model.errorMessage == "Inspection not found.")
    }
}
