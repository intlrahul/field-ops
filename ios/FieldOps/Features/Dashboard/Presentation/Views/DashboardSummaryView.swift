import Prism
import SwiftUI

struct DashboardSummaryView: View {
    let statistics: InspectionStatistics
    let onSelect: (InspectionStatus?) -> Void

    var body: some View {
        DSStatGrid(items: [
            DSStatistic(id: "total", title: "Total", value: String(statistics.total), symbol: "tray.full"),
            DSStatistic(id: "assigned", title: "Assigned", value: String(statistics.assigned), symbol: InspectionStatus.assigned.symbol),
            DSStatistic(id: "in_progress", title: "In progress", value: String(statistics.inProgress), symbol: InspectionStatus.inProgress.symbol),
            DSStatistic(id: "completed", title: "Completed", value: String(statistics.completed), symbol: InspectionStatus.completed.symbol)
        ]) { id in
            onSelect(InspectionStatus(rawValue: id))
        }
    }
}
