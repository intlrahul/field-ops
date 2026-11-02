import SwiftUI

/// A branded field-grid backdrop with a quiet center for loading content.
public struct DSLoadingBackground: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            let extent = max(geometry.size.width, geometry.size.height)

            ZStack {
                theme.colors.canvas

                if !reduceTransparency && contrast != .increased {
                    LinearGradient(
                        colors: [theme.colors.accentSurface, theme.colors.canvas,
                                 theme.colors.infoSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    RadialGradient(
                        colors: [theme.colors.accent.opacity(0.32), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: extent * 0.65
                    )
                    RadialGradient(
                        colors: [theme.colors.info.opacity(0.22), .clear],
                        center: .bottomTrailing,
                        startRadius: 0,
                        endRadius: extent * 0.65
                    )

                    Canvas { context, size in
                        let spacing = DSSpacing.xl
                        var dots = Path()
                        var contours = Path()
                        for scale in [0.55, 0.72, 0.89] {
                            let diameter = extent * scale
                            contours.addEllipse(in: CGRect(
                                x: -diameter * 0.5,
                                y: -diameter * 0.45,
                                width: diameter,
                                height: diameter
                            ))
                            contours.addEllipse(in: CGRect(
                                x: size.width - diameter * 0.45,
                                y: size.height - diameter * 0.5,
                                width: diameter,
                                height: diameter
                            ))
                        }
                        context.stroke(contours, with: .color(theme.colors.accent.opacity(0.20)), lineWidth: 1)
                        for x in stride(from: spacing / 2, to: size.width, by: spacing) {
                            for y in stride(from: spacing / 2, to: size.height, by: spacing) {
                                dots.addEllipse(in: CGRect(x: x, y: y, width: 2, height: 2))
                            }
                        }
                        context.fill(dots, with: .color(theme.colors.accent.opacity(0.23)))
                    }
                    .mask {
                        LinearGradient(
                            colors: [.white, .clear, .clear, .white],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview("Loading background") {
    DSLoadingState(title: "FieldOps", message: "Preparing your workspace")
        .designTheme()
}
