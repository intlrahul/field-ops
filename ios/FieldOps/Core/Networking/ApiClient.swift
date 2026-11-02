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
    
    func postWithoutResponse(
        path: String,
        requiresAuthentication: Bool
    ) async throws 
}

struct AlamofireAPIClient: APIClient {
    private let session: Alamofire.Session
    private let baseURL: URL
    private let accessTokenProvider: any AccessTokenProvider

    init(
        baseURL: URL,
        accessTokenProvider: any AccessTokenProvider,
        session: Alamofire.Session = .default
    ) {
        self.session = session
        self.baseURL = baseURL
        self.accessTokenProvider = accessTokenProvider
    }

    func get<Response>(path: String, requiresAuthentication: Bool) async throws
        -> Response where Response: Decodable, Response: Sendable
    {
        let headers = try await headers(requiresAuthentication: requiresAuthentication)
        guard let relative = URLComponents(string: path),
              var url = URLComponents(url: baseURL.appendingPathComponent(relative.path), resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        url.queryItems = relative.queryItems
        guard let requestURL = url.url else { throw URLError(.badURL) }
        let response = await session.request(requestURL, method: .get, headers: headers)
            .validate(statusCode: 200..<300)
            .serializingDecodable(Response.self)
            .response
        switch response.result {
        case .success(let value): return value
        case .failure(let error):
            if let data = response.data,
               let payload = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw BackendError(code: payload.error.code, message: payload.error.message)
            }
            throw error
        }
    }

    func post<Body, Response>(
        path: String,
        body: Body,
        requiresAuthentication: Bool
    ) async throws -> Response
    where
        Body: Encodable, Body: Sendable, Response: Decodable, Response: Sendable
    {
        let headers = try await headers(requiresAuthentication: requiresAuthentication)
        let response = await session.request(
            baseURL.appendingPathComponent(path),
            method: .post,
            parameters: body,
            encoder: JSONParameterEncoder.default,
            headers: headers
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
    
    func postWithoutResponse(
        path: String,
        requiresAuthentication: Bool
    ) async throws {
        let headers = try await headers(requiresAuthentication: requiresAuthentication)
        let response = await session.request(
            baseURL.appendingPathComponent(path),
            method: .post,
            headers: headers
        )
        .validate(statusCode: 200..<300)
        .serializingData()
        .response

        switch response.result {
        case .success:
            return

        case .failure(let error):
            if let data = response.data,
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

    private func headers(requiresAuthentication: Bool) async throws -> HTTPHeaders {
        guard requiresAuthentication else { return [:] }
        guard let token = await accessTokenProvider.accessToken(), !token.isEmpty else {
            throw SessionError.noSession
        }
        return [.authorization(bearerToken: token)]
    }

}
