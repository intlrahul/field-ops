import Alamofire
import Foundation
import Testing

@testable import FieldOps

private final class LogoutURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest
    { request }
    override func stopLoading() {}

    override func startLoading() {
        let authenticated =
            request.value(forHTTPHeaderField: "Authorization")
            == "Bearer test-access-token"
        let publicCall = request.url?.path == "/public"
        let valid =
            publicCall
            ? request.value(forHTTPHeaderField: "Authorization") == nil
            : authenticated && request.httpMethod == "POST"
                && request.httpBody == nil && request.httpBodyStream == nil
        let status = valid ? 204 : 401
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        client?.urlProtocol(
            self,
            didReceive: response,
            cacheStoragePolicy: .notAllowed
        )
        if !valid {
            client?.urlProtocol(
                self,
                didLoad: Data(
                    "{\"error\":{\"code\":\"UNAUTHORIZED\",\"message\":\"Authentication required\"}}"
                        .utf8
                )
            )
        }
        client?.urlProtocolDidFinishLoading(self)
    }
}

@MainActor
private final class TestSession: SessionProvider, SessionWriter {
    private var stored: FieldOps.Session?
    init(token: String = "test-access-token") {
        stored = FieldOps.Session(
            user: User(
                id: "test-user",
                name: "Technician",
                email: "technician@fieldops.test"
            ),
            credentials: Credentials(
                tokenType: "Bearer",
                accessToken: token,
                refreshToken: "test-refresh-token",
                accessTokenExpiresAt: .distantFuture,
                sessionExpiresAt: .distantFuture
            )
        )
    }
    func restoreSession() async throws {}
    func credentials() async -> Credentials? { stored?.credentials }
    func currentUser() async -> User? { stored?.user }
    func accessToken() async -> String? { stored?.credentials.accessToken }
    func saveSession(_ session: FieldOps.Session) async throws {
        stored = session
    }
    func clearSession() async throws { stored = nil }
}

@MainActor
struct SignoutTests {
    private func client(provider: TestSession) -> AlamofireAPIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [LogoutURLProtocol.self]
        return AlamofireAPIClient(
            baseURL: URL(string: "https://test.local")!,
            accessTokenProvider: provider,
            session: Alamofire.Session(configuration: configuration)
        )
    }

    @Test func signoutSendsBearerWithoutBodyAndAcceptsEmpty204() async throws {
        let provider = TestSession()
        let repository = RemoteAuthRepository(
            apiClient: client(provider: provider)
        )
        let useCase = DefaultSignoutUseCase(
            authRepository: repository,
            sessionWriter: provider,
            sessionProvider: provider
        )
        try await useCase.execute()
        #expect(await provider.credentials() == nil)
    }

    @Test func rejectedSignoutPreservesLocalSessionAndReturnsBackendError()
        async
    {
        let provider = TestSession(token: "expired-test-token")
        let repository = RemoteAuthRepository(
            apiClient: client(provider: provider)
        )
        let useCase = DefaultSignoutUseCase(
            authRepository: repository,
            sessionWriter: provider,
            sessionProvider: provider
        )
        do {
            try await useCase.execute()
            Issue.record("Expected unauthorized signout")
        } catch let error as BackendError {
            #expect(error.code == "UNAUTHORIZED")
        } catch { Issue.record("Unexpected error: \(error)") }
        #expect(await provider.credentials() != nil)
    }

    @Test func publicRequestsDoNotSendStoredCredentials() async throws {
        let provider = TestSession()
        try await client(provider: provider).postWithoutResponse(
            path: "public",
            requiresAuthentication: false
        )
    }

    @Test func authenticatedRequestWithoutLocalTokenFailsBeforeSending()
        async throws
    {
        let provider = TestSession()
        try await provider.clearSession()
        await #expect(throws: SessionError.self) {
            try await client(provider: provider).postWithoutResponse(
                path: "auth/logout",
                requiresAuthentication: true
            )
        }
    }
}
