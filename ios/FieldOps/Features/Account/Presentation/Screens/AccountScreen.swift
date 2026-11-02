import Prism
import SwiftUI

struct AccountScreen: View {
    @State private var viewModel: AccountViewModel
    @State private var showSignOutConfirmation = false
    private let onSignedOut: () -> Void

    init(viewModel: AccountViewModel, onSignedOut: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSignedOut = onSignedOut
    }

    var body: some View {
        DSScreen {
            VStack(spacing: DSSpacing.sm) {
                DSBrandMark(symbol: "person.crop.circle.fill")
                DSText(viewModel.user?.name ?? "Your account", style: .heading)
                if let email = viewModel.user?.email { DSText(email, tone: .secondary) }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            DSSection("Profile") {
                DSCard {
                    VStack(spacing: DSSpacing.md) {
                        DSFieldRow(title: "Full name", value: viewModel.user?.name ?? "Not available", symbol: "person")
                        DSDivider()
                        DSFieldRow(title: "Email address", value: viewModel.user?.email ?? "Not available", symbol: "envelope")
                    }
                }
            }
            DSButton(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right", variant: .destructive,
                     isLoading: viewModel.isSigningOut, loadingTitle: "Signing out…") {
                showSignOutConfirmation = true
            }
            DSText("You’ll need to sign in again to access your workspace.", style: .caption, tone: .secondary)
            if let message = viewModel.errorMessage { DSMessage(message, tone: .danger) }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadUser() }
        .confirmationDialog("Sign out of FieldOps?", isPresented: $showSignOutConfirmation, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    if await viewModel.signOut() { onSignedOut() }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
