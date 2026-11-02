//
//  Inspection.swift
//  FieldOps
//
//  Created by Rahul Singh on 18/10/26.
//

import Foundation

nonisolated enum InspectionStatus: String, CaseIterable, Sendable {
    case assigned
    case inProgress
    case completed

    var title: String {
        switch self {
        case .assigned: "Assigned"
        case .inProgress: "In progress"
        case .completed: "Completed"
        }
    }
}

nonisolated struct Inspection: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let assetName: String
    let status: InspectionStatus
    let dueDate: Date
}

extension Inspection {
    static let samples: [Inspection] = [
        Inspection(
            id: "inspection-001",
            title: "Monthly generator inspection",
            assetName: "Generator A",
            status: .assigned,
            dueDate: .now.addingTimeInterval(86_400)
        ),
        Inspection(
            id: "inspection-002",
            title: "Check cooling performance",
            assetName: "HVAC Unit 02",
            status: .inProgress,
            dueDate: .now.addingTimeInterval(172_800)
        ),
        Inspection(
            id: "inspection-003",
            title: "Inspect emergency lighting",
            assetName: "Emergency Lights — Block B",
            status: .completed,
            dueDate: .now.addingTimeInterval(-86_400)
        ),
        Inspection(
            id: "inspection-004",
            title: "Check pressure and leakage",
            assetName: "Water Pump 03",
            status: .assigned,
            dueDate: .now.addingTimeInterval(-172_800)
        ),
        Inspection(
            id: "inspection-005",
            title: "Quarterly fire safety inspection",
            assetName: "Fire Extinguisher — Floor 2",
            status: .assigned,
            dueDate: .now.addingTimeInterval(259_200)
        ),
        Inspection(
            id: "inspection-006",
            title: "Inspect electrical connections",
            assetName: "Electrical Panel C",
            status: .inProgress,
            dueDate: .now.addingTimeInterval(86_400)
        ),
        Inspection(
            id: "inspection-007",
            title: "Verify battery backup",
            assetName: "UPS — Server Room",
            status: .completed,
            dueDate: .now.addingTimeInterval(-259_200)
        ),
        Inspection(
            id: "inspection-008",
            title: "Check belt tension and vibration",
            assetName: "Conveyor Belt 01",
            status: .assigned,
            dueDate: .now.addingTimeInterval(345_600)
        ),
        Inspection(
            id: "inspection-009",
            title: "Inspect lubrication and oil level",
            assetName: "Air Compressor 02",
            status: .inProgress,
            dueDate: .now.addingTimeInterval(-86_400)
        ),
        Inspection(
            id: "inspection-010",
            title: "Routine elevator safety check",
            assetName: "Elevator — Block A",
            status: .completed,
            dueDate: .now.addingTimeInterval(-345_600)
        )
    ]
}
