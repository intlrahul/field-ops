nonisolated enum InspectionAction: String, CaseIterable, Sendable {
    case start
    case editAnswers = "edit_answers"
    case editReadings = "edit_readings"
    case addNote = "add_note"
    case complete
}

nonisolated struct InspectionCompletionBlocker: Sendable {
    let code: String
    let itemId: String
}
