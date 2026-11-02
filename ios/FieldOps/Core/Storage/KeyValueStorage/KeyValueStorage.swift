//
//  KeyValueStorage.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import Foundation

protocol KeyValueStorage: Sendable {
    func save(key: String, value: Data) async throws
    func get(key: String) async throws -> Data?
    func clear(key: String) async throws
}

