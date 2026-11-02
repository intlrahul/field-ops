import SwiftUI

/// Scalable vector branding with a field/check monogram and two-part lettering.
public struct DSWordmark: View {
    @Environment(\.designTheme) private var theme
    @ScaledMetric(relativeTo: .title) private var regularSymbolSize = 40
    @ScaledMetric(relativeTo: .headline) private var compactSymbolSize = 26
    private let name: String
    private let accentName: String
    private let compact: Bool

    public init(_ name: String, accentName: String, compact: Bool = false) {
        self.name = name
        self.accentName = accentName
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? DSSpacing.xs : DSSpacing.sm) {
            FieldCheckMark()
                .stroke(theme.colors.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .padding(compact ? 5 : 8)
                .frame(width: compact ? compactSymbolSize : regularSymbolSize,
                       height: compact ? compactSymbolSize : regularSymbolSize)
                .background(theme.colors.accentSurface,
                            in: RoundedRectangle(cornerRadius: DSRadius.control))
            (
                Text(name).foregroundStyle(theme.colors.primaryText)
                + Text(accentName).foregroundStyle(theme.colors.accent)
            )
            .font(.system(compact ? .headline : .largeTitle, design: .rounded, weight: .heavy))
            .tracking(compact ? -0.5 : -1.2)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name + accentName)
    }
}

private struct FieldCheckMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // An open F with a check rising out of its lower arm.
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.85))
        path.addLine(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.width * 0.85, y: rect.height * 0.15))
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.48))
        path.addLine(to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.48))
        path.move(to: CGPoint(x: rect.width * 0.40, y: rect.height * 0.72))
        path.addLine(to: CGPoint(x: rect.width * 0.57, y: rect.height * 0.88))
        path.addLine(to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.48))
        return path
    }
}
