import SwiftUI

struct InspectionDetailsScreen: View {
    let inspection: Inspection?

    var body: some View {
        Group {
            if let inspection {
                Form {
                    Section("Inspection") {
                        LabeledContent("Title", value: inspection.title)
                        LabeledContent("Asset", value: inspection.assetName)
                        LabeledContent("Status", value: inspection.status.title)
                        LabeledContent("Due date") {
                            Text(inspection.dueDate, format: .dateTime.day().month().year())
                        }
                        LabeledContent("ID", value: inspection.id)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Inspection not found",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("This inspection is not available in the current sample data.")
                )
            }
        }
        .navigationTitle("Inspection details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InspectionDetailsScreen(inspection: Inspection.samples.first)
    }
}
