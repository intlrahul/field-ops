import SwiftUI

/// Preview-only gallery; it is not registered as an application route.
public struct PrismCatalog: View {
    @Environment(\.designTheme) private var theme
    @State private var appearance: DSAppearance
    @State private var selectedStatistic: String? = "assigned"
    @State private var email = ""
    @State private var password = ""

    public init(appearance: DSAppearance = .system) { _appearance = State(initialValue: appearance) }

    public var body: some View {
        DSScreen {
            DSText("Prism design system", style: .title)
            DSSection("Checklist loading sizes") {
                HStack(spacing: DSSpacing.lg) {
                    DSLoadingIndicator(size: .compact)
                    DSLoadingIndicator(size: .refresh)
                    DSLoadingIndicator(size: .launch)
                }
                DSLoadingRow("Refreshing…")
            }
            DSSection("Loading placeholders") {
                DSSkeleton(.statistics, label: "Loading statistics")
                DSSkeleton()
            }
            DSSection("Responsive welcome artwork") {
                DSWelcomeIllustration(symbol: "checkmark.shield.fill")
            }
            DSSection("Wordmark") {
                DSWordmark("Field", accentName: "Ops")
                DSWordmark("Field", accentName: "Ops", compact: true)
            }
            DSSection("Appearance") {
                Picker("Color scheme", selection: $appearance) {
                    ForEach(DSAppearance.allCases, id: \.self) { value in
                        Text(value.rawValue.capitalized).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
            DSSection("Typography") {
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        ForEach(DSTextStyle.allCases, id: \.self) { style in
                            DSText("\(style.rawValue) · Prism", style: style)
                        }
                    }
                }
            }
            DSSection("Semantic colors") {
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.sm) {
                        swatch("Canvas", color: theme.colors.canvas)
                        swatch("Surface", color: theme.colors.surface)
                        swatch("Elevated", color: theme.colors.elevated)
                        swatch("Accent", color: theme.colors.accent)
                        swatch("Primary text", color: theme.colors.primaryText)
                        swatch("Secondary text", color: theme.colors.secondaryText)
                        swatch("Border", color: theme.colors.border)
                    }
                }
            }
            DSSection("Actions") {
                DSButton(title: "Primary action", symbol: "checkmark") {}
                DSButton(title: "Secondary action", variant: .secondary) {}
                DSButton(title: "Destructive action", variant: .destructive) {}
                DSButton(title: "Disabled action", isDisabled: true) {}
                DSButton(title: "Submit", isLoading: true, loadingTitle: "Submitting…") {}
            }
            DSSection("Fields") {
                DSInput(title: "Email", placeholder: "you@example.com", text: $email, kind: .email,
                        symbol: "envelope", helper: "Use your workspace email.")
                DSInput(title: "Password", placeholder: "Enter password", text: $password, kind: .password,
                        symbol: "lock", error: "Example field validation message")
            }
            DSSection("Feedback and status") {
                ForEach(DSTone.allCases, id: \.self) { tone in
                    DSBadge(title: tone.rawValue.capitalized, tone: tone)
                    DSMessage("\(tone.rawValue.capitalized) message with enough text to demonstrate wrapping.", tone: tone)
                }
            }
            DSSection("Summary") {
                DSStatGrid(items: [
                    DSStatistic(id: "assigned", title: "Assigned", value: "12", symbol: "clipboard"),
                    DSStatistic(id: "completed", title: "Completed", value: "8", symbol: "checkmark.circle")
                ], selectedID: selectedStatistic) { selectedStatistic = $0 }
            }
            DSSection("Content") {
                DSCard {
                    DSFieldRow(title: "Asset", value: "Cooling pump · Plant A", symbol: "shippingbox")
                }
                DSNavigationCard(action: {}) {
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        DSText("An inspection", style: .subheading)
                        DSText("Reusable navigation card", tone: .secondary)
                    }
                }
                DSEmptyState(title: "No inspections", message: "Your assigned work will appear here.")
                DSLoadingState(title: "Loading", message: "Preparing your workspace")
            }
        }
        .designTheme(DSTheme(appearance: appearance))
    }

    private func swatch(_ title: String, color: Color) -> some View {
        HStack(spacing: DSSpacing.md) {
            RoundedRectangle(cornerRadius: DSRadius.control)
                .fill(color)
                .frame(width: DSMetrics.minimumTouchTarget, height: DSMetrics.minimumTouchTarget)
                .overlay {
                    RoundedRectangle(cornerRadius: DSRadius.control)
                        .strokeBorder(theme.colors.border, lineWidth: DSMetrics.borderWidth)
                }
                .accessibilityHidden(true)
            DSText(title, style: .bodyStrong)
        }
    }

}

#Preview("Light") { PrismCatalog(appearance: .light) }
#Preview("Dark") { PrismCatalog(appearance: .dark) }
#Preview("Accessibility") {
    PrismCatalog(appearance: .light)
        .environment(\.dynamicTypeSize, .accessibility3)
}
