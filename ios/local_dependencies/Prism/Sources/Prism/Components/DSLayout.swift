import SwiftUI

public struct DSScreen<Content: View>: View {
    @Environment(\.designTheme) private var theme
    private let maxWidth: CGFloat
    private let content: Content
    private let onRefresh: (() async -> Void)?
    @State private var isRefreshing = false
    @State private var refreshGeneration = 0

    public init(maxWidth: CGFloat = DSMetrics.readableWidth, onRefresh: (() async -> Void)? = nil,
                @ViewBuilder content: () -> Content) {
        self.maxWidth = maxWidth
        self.onRefresh = onRefresh
        self.content = content()
    }

    public var body: some View {
        Group {
            if onRefresh != nil {
                scrollContent.refreshable { await performRefresh() }
            } else {
                scrollContent
            }
        }
        .accessibilityActions {
            if onRefresh != nil {
                Button("Refresh") {
                    guard !isRefreshing else { return }
                    refreshGeneration += 1
                }
            }
        }
        .task(id: refreshGeneration) {
            guard refreshGeneration > 0 else { return }
            await performRefresh()
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isRefreshing {
                    DSLoadingRow("Refreshing…").padding(.top, DSSpacing.sm)
                }
                VStack(alignment: .leading, spacing: DSSpacing.lg) { content }
                    .frame(maxWidth: maxWidth, alignment: .leading)
                    .padding(DSSpacing.lg)
                    .frame(maxWidth: .infinity)
            }
        }
        .scrollBounceBehavior(.always)
        .scrollDismissesKeyboard(.interactively)
        .background(theme.colors.canvas.ignoresSafeArea())
    }

    private func performRefresh() async {
        guard let onRefresh, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await onRefresh()
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
