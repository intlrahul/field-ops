//
//  LoginViewModel.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Observation
import Foundation

@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""

    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let signInUseCase: any SignInUseCase

    init(signInUseCase: any SignInUseCase) {
        self.signInUseCase = signInUseCase
    }

    func signIn() async -> Bool {
        guard !isLoading else { return false }

        errorMessage = nil

        let email = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter your email and password."
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await signInUseCase.execute(
                email: email,
                password: password
            )

            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
