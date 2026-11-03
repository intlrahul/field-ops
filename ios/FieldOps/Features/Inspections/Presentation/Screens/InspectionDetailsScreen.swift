import Prism
import SwiftUI

struct InspectionDetailsScreen: View {
    @State private var viewModel: InspectionDetailViewModel

    init(viewModel: InspectionDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        DSScreen(onRefresh: { await viewModel.load() }) {
            if let error = viewModel.errorMessage {
                DSMessage(error, tone: .danger)
                DSButton(title: "Retry") { Task { await viewModel.load() } }
            }
            if viewModel.detail == nil && viewModel.errorMessage == nil {
                DSSkeleton(label: "Loading inspection details")
                DSSkeleton(label: "Loading checklist and readings")
                DSSkeleton(label: "Loading inspection notes")
            }
            if let detail = viewModel.detail {
                let inspection = detail.summary
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    DSBadge(
                        title: inspection.status.title,
                        tone: inspection.status.tone,
                        symbol: inspection.status.symbol
                    )
                    DSText(inspection.title, style: .title)
                    DSText(inspection.assetName, tone: .secondary)
                }
                if !viewModel.isLoading && viewModel.errorMessage == nil {
                    if inspection.status == .completed {
                        DSMessage("Completed inspections are read-only.", tone: .info)
                    } else if !InspectionAction.allCases.contains(where: { viewModel.allows($0) }) {
                        DSMessage("You can review this inspection. No work actions are available.", tone: .info)
                    }
                }
                DSSection("Inspection") {
                    DSCard {
                        VStack(spacing: DSSpacing.md) {
                            DSFieldRow(
                                title: "Asset",
                                value:
                                    "\(detail.assetTag) · \(inspection.assetName)",
                                symbol: "shippingbox"
                            )
                            if let location = detail.location {
                                DSFieldRow(
                                    title: "Location",
                                    value: location,
                                    symbol: "mappin"
                                )
                            }
                            DSDivider()
                            DSFieldRow(
                                title: "Due date",
                                value: inspection.dueDate?.formatted(
                                    date: .abbreviated,
                                    time: .omitted
                                ) ?? "No due date",
                                symbol: "calendar"
                            )
                            DSFieldRow(
                                title: "Inspection ID",
                                value: inspection.id,
                                symbol: "number"
                            )
                        }
                    }
                }
                DSSection("Checklist") {
                    ForEach(detail.checklist) { item in
                        DSCard {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                DSText(item.label, style: .subheading)
                                DSText(
                                    item.required ? "Required" : "Optional",
                                    style: .caption,
                                    tone: .secondary
                                )
                                DSBadge(
                                    title: item.result?.capitalized
                                        ?? "Unanswered",
                                    tone: item.result == "fail"
                                        ? .danger
                                        : (item.result == "pass"
                                            ? .success : .neutral)
                                )
                                if let note = item.failureNote {
                                    DSText(note, style: .callout)
                                }
                            }
                        }
                    }
                }
                DSSection("Readings") {
                    if detail.readings.isEmpty {
                        DSText("No readings required.", tone: .secondary)
                    }
                    ForEach(detail.readings) { reading in
                        DSCard {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                DSFieldRow(
                                    title: reading.label,
                                    value: reading.value.map {
                                        "\($0.formatted()) \(reading.unit)"
                                    } ?? "Not recorded"
                                )
                                DSText(
                                    reading.required ? "Required" : "Optional",
                                    style: .caption,
                                    tone: .secondary
                                )
                                DSText(
                                    "Range: \(reading.minValue.map { $0.formatted() } ?? "No minimum") – \(reading.maxValue.map { $0.formatted() } ?? "No maximum") \(reading.unit)",
                                    style: .caption,
                                    tone: .secondary
                                )
                                if reading.rangeStatus != "unrecorded" {
                                    DSBadge(
                                        title: reading.rangeStatus
                                            == "out_of_range"
                                            ? "Out of range" : "In range",
                                        tone: reading.rangeStatus
                                            == "out_of_range"
                                            ? .danger : .success
                                    )
                                }
                            }
                        }
                    }
                }
                DSSection("Notes") {
                    if detail.notes.isEmpty {
                        DSText("No notes yet.", tone: .secondary)
                    }
                    ForEach(detail.notes) { note in
                        DSCard {
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                DSText(note.text)
                                DSText(
                                    note.createdAt.formatted(
                                        date: .abbreviated,
                                        time: .shortened
                                    ),
                                    style: .caption,
                                    tone: .secondary
                                )
                            }
                        }
                    }
                }
            }
        }
        .task { if viewModel.detail == nil { await viewModel.load() } }
        .navigationTitle("Inspection details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InspectionDetailsScreen(
            viewModel: InspectionDetailViewModel(
                id: "inspection-001",
                getDetails: DefaultGetInspectionDetailsUseCase(repository: PreviewInspectionRepository())
            )
        )
    }.designTheme()
}
