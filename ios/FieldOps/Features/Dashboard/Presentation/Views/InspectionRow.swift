//
//  InspectionRow.swift
//  FieldOps
//
//  Created by Rahul Singh on 18/10/26.
//

import SwiftUI

struct InspectionRow: View {
    let inspection: Inspection

    private var statusColor: Color {
        switch inspection.status {
        case .assigned: .blue
        case .inProgress: .orange
        case .completed: .green
        }
    }

    private var isOverdue: Bool {
        inspection.status != .completed &&
        inspection.dueDate < .now
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(inspection.status.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    statusColor.opacity(0.12),
                    in: Capsule()
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(inspection.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Label(inspection.assetName, systemImage: "shippingbox")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack(spacing: 6) {
                Image(systemName: "calendar")

                Text(isOverdue ? "Overdue ·" : "Due")

                Text(inspection.dueDate, format: .dateTime.day().month().year())
            }
            .font(.caption)
            .foregroundStyle(isOverdue ? Color.red : Color.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}
