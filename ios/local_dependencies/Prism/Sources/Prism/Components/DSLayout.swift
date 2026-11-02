import SwiftUI

public struct DSScreen<Content: View>: View {
    @Environment(\.designTheme) private var theme
    private let maxWidth: CGFloat
    private let content: Content

    public init(maxWidth: CGFloat = DSMetrics.readableWidth, @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) { content }
                .frame(maxWidth: maxWidth, alignment: .leading)
                .padding(DSSpacing.lg)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.colors.canvas.ignoresSafeArea())
    }
}

public struct DSCard<Content: View>: View {
    @Environment(\.designTheme) private var theme
    private let content: Content

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DSSpacing.md)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.card)
                    .strokeBorder(theme.colors.border, lineWidth: DSMetrics.borderWidth)
            }
    }
}

public struct DSSection<Content: View>: View {
    let title: String
    private let content: Content

    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            DSText(title, style: .heading).accessibilityAddTraits(.isHeader)
            content
        }
    }
}

public struct DSDivider: View {
    @Environment(\.designTheme) private var theme
    public init() {}

    public var body: some View {
        Rectangle().fill(theme.colors.border)
            .frame(height: DSMetrics.borderWidth)
            .accessibilityHidden(true)
    }
}
