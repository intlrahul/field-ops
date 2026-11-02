//
//  AccountScreen.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import SwiftUI

struct AccountScreen: View {
    @State private var viewModel: AccountViewModel
    @State private var showSignOutConfirmation = false

    private let onSignedOut: () -> Void

    init(
        viewModel: AccountViewModel,
        onSignedOut: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSignedOut = onSignedOut
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text(viewModel.user?.name ?? "Your account")
                        .font(.title2.bold())

                    if let email = viewModel.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)

            Section {
                VStack(alignment: .leading, spacing: 20) {
                    accountField(
                        title: "Full name",
                        value: viewModel.user?.name ?? "Not available",
                        symbol: "person"
                    )

                    Divider()

                    accountField(
                        title: "Email address",
                        value: viewModel.user?.email ?? "Not available",
                        symbol: "envelope"
                    )
                }
                .padding(20)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(
                            Color.primary.opacity(0.06),
                            lineWidth: 1
                        )
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 0,
                        leading: 0,
                        bottom: 0,
                        trailing: 0
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    HStack(spacing: 12) {
                        Label(
                            viewModel.isSigningOut
                                ? "Signing out…"
                                : "Sign out",
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )

                        Spacer()

                        if viewModel.isSigningOut {
                            ProgressView()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(viewModel.isSigningOut)
            } footer: {
                Text(
                    "You’ll need to sign in again to access your workspace."
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadUser()
        }
        .confirmationDialog(
            "Sign out of FieldOps?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                Task {
                    if await viewModel.signOut() {
                        onSignedOut()
                    }
                }
            }

            Button("Cancel", role: .cancel) {}
        }
    }

    private func accountField(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 44, height: 44)
                .background(
                    Color.accentColor.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
