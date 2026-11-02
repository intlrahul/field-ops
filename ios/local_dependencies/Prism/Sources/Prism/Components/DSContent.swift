import SwiftUI

public struct DSBadge: View {
    @Environment(\.designTheme) private var theme
    let title: String
    var tone: DSTone = .neutral
    var symbol: String? = nil

    public init(title: String, tone: DSTone = .neutral, symbol: String? = nil) {
        self.title = title; self.tone = tone; self.symbol = symbol
    }

    public var body: some View {
        Label(title, systemImage: symbol ?? tone.symbol)
            .font(theme.typography.font(.captionStrong))
            .foregroundStyle(theme.colors.foreground(tone))
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(theme.colors.background(tone), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }
}

public struct DSMessage: View {
    @Environment(\.designTheme) private var theme
    let message: String
    var tone: DSTone = .info

    public init(_ message: String, tone: DSTone = .info) { self.message = message; self.tone = tone }

    public var body: some View {
        Label {
            Text(message).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: tone.symbol).accessibilityHidden(true)
        }
        .font(theme.typography.font(.callout))
        .foregroundStyle(theme.colors.foreground(tone))
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.background(tone), in: RoundedRectangle(cornerRadius: DSRadius.control))
        .accessibilityElement(children: .combine)
    }
}

public struct DSIconTile: View {
    @Environment(\.designTheme) private var theme
    let symbol: String
    @ScaledMetric(relativeTo: .body) private var size = DSMetrics.minimumTouchTarget

    public init(symbol: String) { self.symbol = symbol }

    public var body: some View {
        Image(systemName: symbol)
            .font(theme.typography.font(.subheading))
            .foregroundStyle(theme.colors.accent)
            .frame(width: size, height: size)
            .background(theme.colors.accentSurface, in: RoundedRectangle(cornerRadius: DSRadius.control))
            .accessibilityHidden(true)
    }
}

public struct DSBrandMark: View {
    @Environment(\.designTheme) private var theme
    var symbol = "checkmark.shield.fill"
    @ScaledMetric(relativeTo: .largeTitle) private var size = DSMetrics.brandMarkSize

    public init(symbol: String = "checkmark.shield.fill") { self.symbol = symbol }

    public var body: some View {
        Image(systemName: symbol)
            .font(theme.typography.font(.display))
            .foregroundStyle(theme.colors.accent)
            .frame(width: min(size, DSMetrics.brandMarkMaximumSize), height: min(size, DSMetrics.brandMarkMaximumSize))
            .background(theme.colors.accentSurface, in: RoundedRectangle(cornerRadius: DSRadius.card))
            .accessibilityHidden(true)
    }
}

public struct DSFieldRow: View {
    let title: String
    let value: String
    var symbol: String? = nil

    public init(title: String, value: String, symbol: String? = nil) {
        self.title = title; self.value = value; self.symbol = symbol
    }

    public var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            if let symbol { DSIconTile(symbol: symbol) }
            VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                DSText(title, style: .captionStrong, tone: .secondary)
                DSText(value, style: .bodyStrong).textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

public struct DSStatCard: View {
    let title: String
    let value: String
    let symbol: String

    public init(title: String, value: String, symbol: String) {
        self.title = title; self.value = value; self.symbol = symbol
    }

    public var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                DSIconTile(symbol: symbol)
                DSText(value, style: .metric)
                DSText(title, style: .captionStrong, tone: .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

public struct DSLoadingState<Heading: View>: View {
    private let heading: Heading
    var message: String? = nil

    public init(title: String, message: String? = nil) where Heading == DSText {
        self.heading = DSText(title, style: .heading)
        self.message = message
    }

    public init(message: String? = nil, @ViewBuilder heading: () -> Heading) {
        self.heading = heading()
        self.message = message
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xl) {
            DSLoadingIndicator()
            heading
            if let message { DSText(message, style: .callout, tone: .secondary) }
        }
        .multilineTextAlignment(.center)
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { DSLoadingBackground() }
        .accessibilityElement(children: .combine)
        .accessibilityValue("Loading")
    }
}

public struct DSEmptyState: View {
    let title: String
    let message: String
    var symbol = "tray"

    public init(title: String, message: String, symbol: String = "tray") {
        self.title = title; self.message = message; self.symbol = symbol
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            DSBrandMark(symbol: symbol)
            DSText(title, style: .heading)
            DSText(message, style: .body, tone: .secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
        .accessibilityElement(children: .combine)
    }
}

public struct DSStatistic: Identifiable {
    public let id: String
    let title: String
    let value: String
    let symbol: String

    public init(id: String, title: String, value: String, symbol: String) {
        self.id = id; self.title = title; self.value = value; self.symbol = symbol
    }

}

public struct DSStatGrid: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let items: [DSStatistic]

    private let selectedID: String?
    private let onSelect: ((String) -> Void)?

    public init(items: [DSStatistic], selectedID: String? = nil, onSelect: ((String) -> Void)? = nil) {
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                  ? [GridItem(.flexible())]
                  : [GridItem(.adaptive(minimum: DSMetrics.summaryColumnWidth))], spacing: DSSpacing.sm) {
            ForEach(items) { item in
                if let onSelect {
                    Button { onSelect(item.id) } label: {
                        DSStatCard(title: item.title, value: item.value, symbol: item.symbol)
                            .overlay {
                                if selectedID == item.id {
                                    RoundedRectangle(cornerRadius: DSRadius.card)
                                        .strokeBorder(theme.colors.accent, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(item.title): \(item.value)")
                    .accessibilityHint("Show matching items")
                    .accessibilityAddTraits(selectedID == item.id ? .isSelected : [])
                } else {
                    DSStatCard(title: item.title, value: item.value, symbol: item.symbol)
                }
            }
        }
    }
}

public struct DSNavigationCard<Content: View>: View {
    @Environment(\.designTheme) private var theme
    private let action: () -> Void
    private let content: Content

    public init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Button(action: action) {
            DSCard {
                HStack(alignment: .center, spacing: DSSpacing.sm) {
                    content.frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(theme.typography.font(.captionStrong))
                        .foregroundStyle(theme.colors.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: DSMetrics.minimumTouchTarget)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
