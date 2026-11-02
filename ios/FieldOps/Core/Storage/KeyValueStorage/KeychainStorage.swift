//
//  KeychainStorage.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import Foundation
import Security

actor KeychainStorage: KeyValueStorage {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func save(key: String, value: Data) throws {
        let query = baseQuery(key: key)

        let attributes: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String:
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )

        if status == errSecItemNotFound {
            var newItem = query
            newItem.merge(attributes) { _, new in new }

            let addStatus = SecItemAdd(
                newItem as CFDictionary,
                nil
            )

            guard addStatus == errSecSuccess else {
                throw KeychainStorageError.status(addStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainStorageError.status(status)
        }
    }

    func get(key: String) throws -> Data? {
        var query = baseQuery(key: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?

        let status = SecItemCopyMatching(
            query as CFDictionary,
            &result
        )

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainStorageError.status(status)
        }

        guard let data = result as? Data else {
            throw KeychainStorageError.unexpectedResult
        }

        return data
    }

    func clear(key: String) throws {
        let status = SecItemDelete(
            baseQuery(key: key) as CFDictionary
        )

        guard status == errSecSuccess ||
              status == errSecItemNotFound else {
            throw KeychainStorageError.status(status)
        }
    }

    private func baseQuery(key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecAttrSynchronizable as String: false
        ]
    }
}
