import Foundation
import Observation

@MainActor @Observable
final class InspectionDetailViewModel {
    private let getDetails: any GetInspectionDetailsUseCase
    let id: String
    private(set) var detail: InspectionDetail?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    init(id: String, getDetails: any GetInspectionDetailsUseCase) {
        self.id = id
        self.getDetails = getDetails
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await getDetails.execute(id: id)
            try Task.checkCancellation()
            detail = response
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = (error as? BackendError)?.message ?? "Unable to load this inspection. Please try again."
        }
    }
}
