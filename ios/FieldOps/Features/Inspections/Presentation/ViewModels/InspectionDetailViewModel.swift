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

    func allows(_ action: InspectionAction) -> Bool {
        !isLoading && errorMessage == nil && detail?.allows(action) == true
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
            if let rejection = error as? BackendError,
               ["FORBIDDEN", "UNAUTHORIZED", "NOT_FOUND"].contains(rejection.code) { detail = nil }
            errorMessage = (error as? BackendError)?.message ?? "Unable to load this inspection. Please try again."
        }
    }
}
