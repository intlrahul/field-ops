//
//  AccountViewModel.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import Observation

@MainActor
@Observable
final class AccountViewModel {
    private(set) var user: User?
    private(set) var isSigningOut = false
    private(set) var errorMessage: String?

    private let sessionProvider: any SessionProvider
    private let signoutUseCase: any SignoutUseCase

    init(
        sessionProvider: any SessionProvider,
        signoutUseCase: any SignoutUseCase
    ) {
        self.sessionProvider = sessionProvider
        self.signoutUseCase = signoutUseCase
    }

    func loadUser() async {
        user = await sessionProvider.currentUser()
    }

    func signOut() async -> Bool {
        guard !isSigningOut else { return false }

        isSigningOut = true
        errorMessage = nil
        defer { isSigningOut = false }

        do {
            try await signoutUseCase.execute()
            user = nil
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = "Unable to sign out. Please try again."
            return false
        }
    }
}
