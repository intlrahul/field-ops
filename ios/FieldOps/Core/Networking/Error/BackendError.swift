//
//  BackendError.swift
//  FieldOps
//
//  Created by Rahul Singh on 16/10/26.
//

import Foundation

nonisolated struct BackendError: LocalizedError, Sendable {
    let code: String
    let message: String

    var errorDescription: String? { message }
}
