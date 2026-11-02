import SwiftUI

public enum DSButtonVariant { case primary, secondary, destructive }

private struct DSActionStyle: ButtonStyle {
    @Environment(\.designTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let variant: DSButtonVariant

    private var foreground: Color {
        guard isEnabled else { return theme.colors.secondaryText }
        switch variant {
        case .primary: return theme.colors.onAccent
        case .secondary: return theme.colors.accent
        case .destructive: return theme.colors.onDanger
        }
    }

    private var background: Color {
        guard isEnabled else { return theme.colors.elevated }
        switch variant {
        case .primary: return theme.colors.accent
        case .secondary: return theme.colors.accentSurface
        case .destructive: return theme.colors.danger
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.font(.bodyStrong))
            .foregroundStyle(foreground)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DSSpacing.md)
            .padding(.vertical, DSSpacing.xs)
            .frame(maxWidth: .infinity, minHeight: DSMetrics.controlHeight)
            .background(background, in: RoundedRectangle(cornerRadius: DSRadius.control))
            .overlay {
                if configuration.isPressed {
                    RoundedRectangle(cornerRadius: DSRadius.control)
                        .fill(theme.colors.primaryText.opacity(0.12))
                }
            }
            .animation(reduceMotion ? nil : DSMotion.feedback, value: configuration.isPressed)
    }
}

public struct DSButton: View {
    @Environment(\.designTheme) private var theme
    let title: String
    var symbol: String? = nil
    var variant: DSButtonVariant = .primary
    var isLoading = false
    var loadingTitle: String? = nil
    var isDisabled = false
    let action: () -> Void

    public init(title: String, symbol: String? = nil, variant: DSButtonVariant = .primary,
                isLoading: Bool = false, loadingTitle: String? = nil, isDisabled: Bool = false,
                action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.variant = variant
        self.isLoading = isLoading; self.loadingTitle = loadingTitle; self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button(role: variant == .destructive ? .destructive : nil, action: action) {
            HStack(spacing: DSSpacing.xs) {
                if isLoading {
                    ProgressView().tint(theme.colors.secondaryText).accessibilityHidden(true)
                } else if let symbol {
                    Image(systemName: symbol).accessibilityHidden(true)
                }
                Text(isLoading ? (loadingTitle ?? title) : title)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .buttonStyle(DSActionStyle(variant: variant))
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(isLoading ? (loadingTitle ?? title) : title)
        .accessibilityValue(isLoading ? "In progress" : "")
    }
}

public struct DSIconButton: View {
    @Environment(\.designTheme) private var theme
    let title: String
    let symbol: String
    let action: () -> Void

    public init(title: String, symbol: String, action: @escaping () -> Void) {
        self.title = title; self.symbol = symbol; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(theme.typography.font(.subheading))
                .foregroundStyle(theme.colors.accent)
                .frame(minWidth: DSMetrics.minimumTouchTarget, minHeight: DSMetrics.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

public enum DSInputKind { case text, email, password }

public struct DSInput: View {
    @Environment(\.designTheme) private var theme
    @FocusState private var isFocused: Bool
    let title: String
    let placeholder: String
    @Binding var text: String
    var kind: DSInputKind = .text
    var symbol: String? = nil
    var helper: String? = nil
    var error: String? = nil
    var focus: FocusState<Bool>.Binding? = nil
    var onSubmit: () -> Void = {}

    public init(title: String, placeholder: String, text: Binding<String>, kind: DSInputKind = .text,
                symbol: String? = nil, helper: String? = nil, error: String? = nil,
                focus: FocusState<Bool>.Binding? = nil, onSubmit: @escaping () -> Void = {}) {
        self.title = title; self.placeholder = placeholder; self._text = text; self.kind = kind
        self.symbol = symbol; self.helper = helper; self.error = error; self.focus = focus; self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            DSText(title, style: .subheading).accessibilityHidden(true)
            HStack(spacing: DSSpacing.sm) {
                if let symbol {
                    Image(systemName: symbol).foregroundStyle(theme.colors.secondaryText)
                        .accessibilityHidden(true)
                }
                Group {
                    if kind == .password {
                        SecureField(placeholder, text: $text).textContentType(.password)
                    } else {
                        TextField(placeholder, text: $text)
                            .textContentType(kind == .email ? .username : nil)
                            .keyboardType(kind == .email ? .emailAddress : .default)
                            .textInputAutocapitalization(kind == .email ? .never : .sentences)
                            .autocorrectionDisabled(kind == .email)
                    }
                }
                .font(theme.typography.font(.body))
                .foregroundStyle(theme.colors.primaryText)
                .tint(theme.colors.accent)
                .textFieldStyle(.plain)
                .focused(focus ?? $isFocused)
                .submitLabel(kind == .password ? .go : .next)
                .onSubmit(onSubmit)
                .accessibilityLabel(title)
                .accessibilityHint(error ?? helper ?? "")
            }
            .padding(DSSpacing.md)
            .frame(minHeight: DSMetrics.controlHeight)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: DSRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.control)
                    .strokeBorder(error != nil ? theme.colors.danger : ((focus?.wrappedValue ?? isFocused) ? theme.colors.accent : theme.colors.border),
                                  lineWidth: DSMetrics.borderWidth)
            }
            if let error { DSMessage(error, tone: .danger) }
            else if let helper { DSText(helper, style: .caption, tone: .secondary) }
        }
    }
}
