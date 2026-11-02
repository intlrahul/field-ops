import SwiftUI

public enum DSAppearance: String, CaseIterable, Sendable {
    case system, light, dark

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

public enum DSTone: String, CaseIterable, Sendable {
    case neutral, info, success, warning, danger

    public var symbol: String {
        switch self {
        case .neutral: "circle"
        case .info: "info.circle.fill"
        case .success: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .danger: "exclamationmark.circle.fill"
        }
    }
}

/// Semantic colors backed by Any/Dark and increased-contrast asset variants.
public struct DSColors: Sendable {
    public var canvas = Color("DSCanvas", bundle: .module)
    public var surface = Color("DSSurface", bundle: .module)
    public var elevated = Color("DSElevated", bundle: .module)
    public var primaryText = Color("DSTextPrimary", bundle: .module)
    public var secondaryText = Color("DSTextSecondary", bundle: .module)
    public var border = Color("DSBorder", bundle: .module)
    public var accent = Color("DSAccent", bundle: .module)
    public var onAccent = Color("DSOnAccent", bundle: .module)
    public var onDanger = Color("DSOnDanger", bundle: .module)
    public var accentSurface = Color("DSAccentSurface", bundle: .module)
    public var info = Color("DSInfo", bundle: .module)
    public var infoSurface = Color("DSInfoSurface", bundle: .module)
    public var success = Color("DSSuccess", bundle: .module)
    public var successSurface = Color("DSSuccessSurface", bundle: .module)
    public var warning = Color("DSWarning", bundle: .module)
    public var warningSurface = Color("DSWarningSurface", bundle: .module)
    public var danger = Color("DSDanger", bundle: .module)
    public var dangerSurface = Color("DSDangerSurface", bundle: .module)

    public init() {}

    public func foreground(_ tone: DSTone) -> Color {
        switch tone {
        case .neutral: secondaryText
        case .info: info
        case .success: success
        case .warning: warning
        case .danger: danger
        }
    }

    public func background(_ tone: DSTone) -> Color {
        switch tone {
        case .neutral: elevated
        case .info: infoSurface
        case .success: successSurface
        case .warning: warningSurface
        case .danger: dangerSurface
        }
    }
}

public struct DSTheme: Sendable {
    public var colors = DSColors()
    public var typography = DSTypography()
    public var appearance: DSAppearance = .system
    public init(colors: DSColors = DSColors(), typography: DSTypography = DSTypography(), appearance: DSAppearance = .system) {
        self.colors = colors
        self.typography = typography
        self.appearance = appearance
    }

    public static let prism = DSTheme()
}

extension EnvironmentValues {
    @Entry public var designTheme = DSTheme.prism
}

extension View {
    /// Apply once at app root; previews can override it locally.
    public func designTheme(_ theme: DSTheme = .prism) -> some View {
        environment(\.designTheme, theme)
            .tint(theme.colors.accent)
            .font(theme.typography.font(.body))
            .foregroundStyle(theme.colors.primaryText)
            .preferredColorScheme(theme.appearance.colorScheme)
    }
}
