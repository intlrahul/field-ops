//
//  DashboardScreen.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

struct DashboardScreen: View {
    private let summary = [
        "Assigned count": "10",
        "In-progress count": "13",
        "Completed count": "9",
    ]
    private let columns = [
        GridItem(.adaptive(minimum: 90), spacing: 16)
    ]
    var body: some View {

        List {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Hello, Technician!")
                        .font(.title2.bold())

                    Text("Here’s your inspection overview.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(summary.keys.sorted(), id: \.self) { key in
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .padding(10)
                                .background(
                                    Color.blue.opacity(0.1),
                                    in: RoundedRectangle(cornerRadius: 10)
                                )

                            Text(summary[key] ?? "0")
                                .font(.largeTitle.bold())
                                .monospacedDigit()
                                .foregroundStyle(.primary)

                            Text(key)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity,
                            alignment: .topLeading
                        )
                        .padding(16)
                        .background(
                            Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: 18)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18)
                                .strokeBorder(
                                    Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                    }
                }
            }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(
                EdgeInsets(top: 16, leading: 16, bottom: 20, trailing: 16)
            )

            Section {
                ForEach(Inspection.samples) { inspection in
                    InspectionRow(inspection: inspection)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } header: {
                Text("Your inspections")
                    .font(.title2.bold())
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("Account")
            }
        }

    }

}

#Preview {
    NavigationStack {
        DashboardScreen()
    }
}
