//
//  RemoteAuthRepository.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

struct RemoteAuthRepository: AuthRepository {
    
    private let apiClient: any APIClient

    init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> Session {
        try await Task.sleep(for: .seconds(4))
        let response: AuthResponseDTO = try await apiClient.post(
            path: "auth/login",
            body: LoginRequestDTO(
                email: email,
                password: password
            ),
            requiresAuthentication: false
        )

        return try response.toDomain()
    }
    
    func refreshSession(refreshToken: String) async throws -> Session {
        let response: AuthResponseDTO = try await apiClient.post(
            path: "auth/refresh",
            body: RefreshTokenRequestDTO(refreshToken: refreshToken),
            requiresAuthentication: false
        )

        return try response.toDomain()
    }
    
    func signOut() async throws {
        try await apiClient.postWithoutResponse(
            path: "auth/logout",
            requiresAuthentication: true
        )
    }
}
