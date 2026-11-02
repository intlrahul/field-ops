import Prism
import SwiftUI

struct DashboardSummaryView: View {
    let inspections: [Inspection]

    var body: some View {
        DSStatGrid(items: InspectionStatus.allCases.map { status in
            DSStatistic(id: status.rawValue, title: status.title,
                        value: String(inspections.filter { $0.status == status }.count), symbol: status.symbol)
        })
    }
}
