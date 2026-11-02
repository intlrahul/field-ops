import Prism
import SwiftUI

extension InspectionStatus {
    var tone: DSTone {
        switch self {
        case .assigned: .info
        case .inProgress: .warning
        case .completed: .success
        }
    }

    var symbol: String {
        switch self {
        case .assigned: "clipboard"
        case .inProgress: "clock"
        case .completed: "checkmark.circle"
        }
    }
}

/// Feature content; the shared navigation card owns surface and interaction styling.
struct InspectionRow: View {
    let inspection: Inspection

    private var isOverdue: Bool {
        inspection.status != .completed
            && inspection.dueDate.map { $0 < .now } == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSBadge(
                title: inspection.status.title,
                tone: inspection.status.tone,
                symbol: inspection.status.symbol
            )
            DSText(inspection.title, style: .subheading)
            DSText(inspection.assetName, style: .callout, tone: .secondary)
            DSDivider()
            let date = inspection.dueDate?.formatted(
                date: .abbreviated,
                time: .omitted
            )
            if let date, isOverdue {
                DSBadge(
                    title: "Overdue · \(date)",
                    tone: .danger,
                    symbol: "calendar.badge.exclamationmark"
                )
            } else if let date {
                DSText("Due \(date)", style: .caption, tone: .secondary)
            } else {
                DSText("No due date", style: .caption, tone: .secondary)
            }
        }
    }
}
