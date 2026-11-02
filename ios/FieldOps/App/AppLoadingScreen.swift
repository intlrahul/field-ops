//
//  AppLoadingScreen.swift
//  FieldOps
//
//  Created by Rahul Singh on 19/10/26.
//

import SwiftUI

struct AppLoadingScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isScanning = false

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: 144, height: 144)

                VStack(alignment: .leading, spacing: 14) {
                    checklistLine(width: 48)
                    checklistLine(width: 36)
                    checklistLine(width: 42)
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(.systemBackground))
                        .shadow(
                            color: .black.opacity(0.06),
                            radius: 12,
                            y: 6
                        )
                }

                if !reduceMotion {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.accentColor,
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 100, height: 2)
                        .offset(y: isScanning ? 42 : -42)
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("FieldOps")
                    .font(.title.bold())

                Text("Preparing your workspace")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            guard !reduceMotion else { return }

            withAnimation(
                .easeInOut(duration: 1.6)
                    .repeatForever(autoreverses: true)
            ) {
                isScanning = true
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func checklistLine(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.accentColor)

            Capsule()
                .fill(Color.primary.opacity(0.12))
                .frame(width: width, height: 5)
        }
    }
}

#Preview {
    AppLoadingScreen()
}
