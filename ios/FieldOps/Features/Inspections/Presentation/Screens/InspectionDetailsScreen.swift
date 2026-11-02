import Prism
import SwiftUI

struct InspectionDetailsScreen: View {
    let inspection: Inspection?

    var body: some View {
        DSScreen {
            if let inspection {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    DSBadge(title: inspection.status.title, tone: inspection.status.tone, symbol: inspection.status.symbol)
                    DSText(inspection.title, style: .title)
                    DSText(inspection.assetName, tone: .secondary)
                }
                DSSection("Inspection") {
                    DSCard {
                        VStack(spacing: DSSpacing.md) {
                            DSFieldRow(title: "Asset", value: inspection.assetName, symbol: "shippingbox")
                            DSDivider()
                            DSFieldRow(title: "Due date", value: inspection.dueDate.formatted(date: .abbreviated, time: .omitted), symbol: "calendar")
                            DSDivider()
                            DSFieldRow(title: "Inspection ID", value: inspection.id, symbol: "number")
                        }
                    }
                }
            } else {
                DSEmptyState(title: "Inspection not found",
                             message: "This inspection is not available in the current sample data.",
                             symbol: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle("Inspection details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { InspectionDetailsScreen(inspection: Inspection.samples.first) }.designTheme()
}
