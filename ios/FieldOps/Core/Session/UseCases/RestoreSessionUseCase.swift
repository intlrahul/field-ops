//
//  RestoreSessionUseCase.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

nonisolated enum SessionRestorationResult: Sendable {
    case authenticated
    case signedOut
}

protocol RestoreSessionUseCase: Sendable {
    func execute() async throws -> SessionRestorationResult
}
