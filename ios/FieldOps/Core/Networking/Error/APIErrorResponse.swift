//
//  APIErrorResponse.swift
//  FieldOps
//
//  Created by Rahul Singh on 16/10/26.
//

nonisolated struct APIErrorResponse: Decodable, Sendable {
    let error: ErrorDetails

    struct ErrorDetails: Decodable, Sendable {
        let code: String
        let message: String
    }
}
