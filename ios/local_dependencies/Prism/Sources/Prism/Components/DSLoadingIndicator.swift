import SwiftUI
import Foundation

/// Decorative checklist scan. Pair it with an accessible loading label.
public struct DSLoadingIndicator: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        Group {
            if reduceMotion {
                illustration(scanOffset: nil)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate * 2 * .pi / 3.2
                    illustration(scanOffset: 42 * sin(phase))
                }
            }
        }
        .frame(width: 144, height: 144)
        .accessibilityHidden(true)
    }

    private func illustration(scanOffset: CGFloat?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(theme.colors.accentSurface)
            VStack(alignment: .leading, spacing: 14) {
                checklistLine(width: 48)
                checklistLine(width: 36)
                checklistLine(width: 42)
            }
            .padding(20)
            .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(theme.colors.border, lineWidth: DSMetrics.borderWidth)
            }
            if let scanOffset {
                Capsule()
                    .fill(LinearGradient(colors: [.clear, theme.colors.accent, .clear],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 100, height: 2)
                    .offset(y: scanOffset)
            }
        }
    }

    private func checklistLine(width: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 16)) // Fixed-size decorative artwork; loading text still scales.
                .foregroundStyle(theme.colors.accent)
            Capsule().fill(theme.colors.border).frame(width: width, height: 5)
        }
    }
}
