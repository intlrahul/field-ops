import SwiftUI

/// Resolution-independent welcome artwork that grows with its container.
public struct DSWelcomeIllustration: View {
    @Environment(\.designTheme) private var theme
    private let symbol: String

    public init(symbol: String) { self.symbol = symbol }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Circle()
                    .fill(theme.colors.accentSurface)
                    .frame(width: 190, height: 190)
                    .offset(x: -55, y: 5)
                Circle()
                    .stroke(theme.colors.accent.opacity(0.25), lineWidth: 1)
                    .frame(width: 210, height: 210)
                    .offset(x: -55, y: 5)
                RoundedRectangle(cornerRadius: 18)
                    .fill(theme.colors.infoSurface)
                    .frame(width: 95, height: 100)
                    .rotationEffect(.degrees(12))
                    .offset(x: 115, y: 20)
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(theme.colors.info)
                    .offset(x: 128, y: -5)
                VStack(alignment: .leading, spacing: 15) {
                    Image(systemName: symbol)
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                    ForEach(0..<3) { index in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(theme.colors.accent)
                            Capsule()
                                .fill(theme.colors.border.opacity(0.6))
                                .frame(width: index == 1 ? 55 : 80, height: 6)
                        }
                        .font(.system(size: 16))
                    }
                }
                .padding(22)
                .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.colors.border, lineWidth: 1)
                }
                .rotationEffect(.degrees(-6))
                .offset(x: -15)
                Image(systemName: "sparkle")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.colors.accent)
                    .offset(x: -140, y: -70)
            }
            .frame(width: 400, height: 240)
            .scaleEffect(min(geometry.size.width / 400, geometry.size.height / 240))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .aspectRatio(400 / 240, contentMode: .fit)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
