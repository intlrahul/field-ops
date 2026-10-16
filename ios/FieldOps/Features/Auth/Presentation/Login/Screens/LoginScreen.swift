//
//  LoginScreen.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import SwiftUI

struct LoginScreen: View {
    @State private var viewModel: LoginViewModel

    private let onSignedIn: () -> Void

    init(
        viewModel: LoginViewModel,
        onSignedIn: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSignedIn = onSignedIn
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 96))
                .foregroundStyle(.tint)

                .padding(.bottom, 12)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 20) {
                Text("Sign in to FieldOps")
                    .font(.title.bold())

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            TextField("you@example.com", text: $viewModel.email)
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .accessibilityLabel("Email")
                        }
                        .padding(16)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.subheadline.weight(.medium))

                        HStack(spacing: 12) {
                            Image(systemName: "lock")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                                .accessibilityHidden(true)

                            SecureField(
                                "Enter your password",
                                text: $viewModel.password
                            )
                            .textContentType(.password)
                            .submitLabel(.go)
                            .onSubmit {
                                signIn()
                            }
                            .accessibilityLabel("Password")
                        }
                        .padding(16)
                        .background(
                            Color(.secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(.separator), lineWidth: 0.5)
                        }
                    }
                }
                .textFieldStyle(.plain)
                .disabled(viewModel.isLoading)

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .accessibilityLabel("Sign-in error: \(message)")
                }

                Button(action: signIn) {
                    HStack(spacing: 10) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(
                            viewModel.isLoading
                                ? "Signing in…"
                                : "Sign in"
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }

            Spacer()
        }
        .textFieldStyle(.roundedBorder)
        .padding(24)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func signIn() {
        Task {
            if await viewModel.signIn() {
                onSignedIn()
            }
        }
    }
}

private struct PreviewSignInUseCase: SignInUseCase {
    func execute(email: String, password: String) async throws {
        try await Task.sleep(for: .seconds(1))
    }
}

#Preview {
    LoginScreen(
        viewModel: LoginViewModel(
            signInUseCase: PreviewSignInUseCase()
        ),
        onSignedIn: {
            print("Sign-in succeeded")
        }
    )
}
