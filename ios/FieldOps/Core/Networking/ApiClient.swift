//
//  ApiClient.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Alamofire
import Foundation

protocol APIClient: Sendable {
    func get<Response: Decodable & Sendable>(
        path: String,
        requiresAuthentication: Bool
    ) async throws -> Response

    func post<Body: Encodable & Sendable, Response: Decodable & Sendable>(
        path: String,
        body: Body,
        requiresAuthentication: Bool
    ) async throws -> Response
}

struct AlamofireAPIClient: APIClient {
    private let baseURL: URL
    private let accessTokenProvider: any AccessTokenProvider

    init(
        baseURL: URL,
        accessTokenProvider: any AccessTokenProvider
    ) {
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
    }

    func get<Response>(path: String, requiresAuthentication: Bool) async throws
        -> Response where Response: Decodable, Response: Sendable
    {
        try await AF.request(
            baseURL.appendingPathComponent(path),
            method: .get
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(Response.self)
        .value
    }

    func post<Body, Response>(
        path: String,
        body: Body,
        requiresAuthentication: Bool
    ) async throws -> Response
    where
        Body: Encodable, Body: Sendable, Response: Decodable, Response: Sendable
    {
        let response = await AF.request(
            baseURL.appendingPathComponent(path),
            method: .post,
            parameters: body,
            encoder: JSONParameterEncoder.default
        )
        .validate(statusCode: 200..<300)
        .serializingDecodable(Response.self)
        .response
        
        switch response.result {
        case .success(let value):
            return value

        case .failure(let error):
            print("HTTP status:", response.response?.statusCode as Any)

            if let data = response.data,
                let message = String(data: data, encoding: .utf8)
            {
                print("Error response:", message)
            }
            
            if let status = response.response?.statusCode,
               !(200..<300).contains(status),
               let data = response.data,
               let payload = try? JSONDecoder().decode(
                   APIErrorResponse.self,
                   from: data
               ) {
                throw BackendError(
                    code: payload.error.code,
                    message: payload.error.message
                )
            }

            throw error
        }
    }
}
