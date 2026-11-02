import SwiftUI

public enum DSTextStyle: String, CaseIterable, Sendable {
    case display, title, heading, subheading, body, bodyStrong, callout, caption, captionStrong, metric
}

public struct DSTypography: Sendable {
    public var headingDesign: Font.Design = .rounded
    public var bodyDesign: Font.Design = .default

    public init(headingDesign: Font.Design = .rounded, bodyDesign: Font.Design = .default) {
        self.headingDesign = headingDesign
        self.bodyDesign = bodyDesign
    }

    public func font(_ style: DSTextStyle) -> Font {
        switch style {
        case .display: .system(.largeTitle, design: headingDesign, weight: .bold)
        case .title: .system(.title, design: headingDesign, weight: .bold)
        case .heading: .system(.title2, design: headingDesign, weight: .bold)
        case .subheading: .system(.headline, design: bodyDesign, weight: .semibold)
        case .body: .system(.body, design: bodyDesign)
        case .bodyStrong: .system(.body, design: bodyDesign, weight: .semibold)
        case .callout: .system(.callout, design: bodyDesign)
        case .caption: .system(.caption, design: bodyDesign)
        case .captionStrong: .system(.caption, design: bodyDesign, weight: .semibold)
        case .metric: .system(.largeTitle, design: headingDesign, weight: .bold).monospacedDigit()
        }
    }
}

public enum DSTextTone { case primary, secondary, accent }

public struct DSText: View {
    @Environment(\.designTheme) private var theme
    let value: String
    var style: DSTextStyle = .body
    var tone: DSTextTone = .primary

    public init(_ value: String, style: DSTextStyle = .body, tone: DSTextTone = .primary) {
        self.value = value
        self.style = style
        self.tone = tone
    }

    private var color: Color {
        switch tone {
        case .primary: theme.colors.primaryText
        case .secondary: theme.colors.secondaryText
        case .accent: theme.colors.accent
        }
    }

    public var body: some View {
        Text(value)
            .font(theme.typography.font(style))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
