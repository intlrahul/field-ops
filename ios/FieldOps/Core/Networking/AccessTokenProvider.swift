//
//  AccessTokenProvider.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol AccessTokenProvider: Sendable {
    func accessToken() async -> String?
}
