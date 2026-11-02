import Prism
import SwiftUI

struct LoginScreen: View {
    @FocusState private var passwordFocused: Bool
    @State private var viewModel: LoginViewModel
    private let onSignedIn: () -> Void

    init(viewModel: LoginViewModel, onSignedIn: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSignedIn = onSignedIn
    }

    var body: some View {
        DSScreen {
            DSWelcomeIllustration(symbol: "checkmark.shield.fill")
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    FieldOpsLogo()
                    DSText("Sign in to your workspace", style: .title)
                    DSText("Your inspections, equipment, and field work in one place.", tone: .secondary)
                }
                DSInput(title: "Email", placeholder: "you@example.com", text: $viewModel.email,
                        kind: .email, symbol: "envelope", onSubmit: { passwordFocused = true })
                    .disabled(viewModel.isLoading)
                DSInput(title: "Password", placeholder: "Enter your password", text: $viewModel.password,
                        kind: .password, symbol: "lock", focus: $passwordFocused, onSubmit: signIn)
                    .disabled(viewModel.isLoading)
                if let message = viewModel.errorMessage { DSMessage(message, tone: .danger) }
                DSButton(title: "Sign in", isLoading: viewModel.isLoading, loadingTitle: "Signing in…", action: signIn)
            }
            .frame(maxWidth: DSMetrics.formWidth)
            .frame(maxWidth: .infinity)
        }
    }

    private func signIn() {
        Task {
            if await viewModel.signIn() { onSignedIn() }
        }
    }
}

private struct PreviewSignInUseCase: SignInUseCase {
    func execute(email: String, password: String) async throws {}
}

#Preview {
    LoginScreen(viewModel: LoginViewModel(signInUseCase: PreviewSignInUseCase()), onSignedIn: {})
        .designTheme()
}
