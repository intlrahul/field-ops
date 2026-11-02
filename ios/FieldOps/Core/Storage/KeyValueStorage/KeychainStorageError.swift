//
//  KeychainStorageError.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import Foundation
import Security

nonisolated enum KeychainStorageError: LocalizedError, Sendable {
    case status(OSStatus)
    case unexpectedResult

    var errorDescription: String? {
        switch self {
        case .status(let status):
            let message = SecCopyErrorMessageString(status, nil)
                as String?

            return message ?? "Keychain operation failed (\(status))."

        case .unexpectedResult:
            return "Keychain returned an unexpected value."
        }
    }
}
