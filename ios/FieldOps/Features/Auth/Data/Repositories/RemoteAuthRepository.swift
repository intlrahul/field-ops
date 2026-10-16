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
        let response: LoginResponseDTO = try await apiClient.post(
            path: "auth/login",
            body: LoginRequestDTO(
                email: email,
                password: password
            ),
            requiresAuthentication: false
        )

        return try response.toDomain()
    }
}
