import SwiftUI
import Foundation

public enum DSLoadingSize {
    case compact, refresh, launch

    fileprivate var dimension: CGFloat {
        switch self {
        case .compact: 28
        case .refresh: 48
        case .launch: 144
        }
    }
}

/// Decorative checklist scan. Pair it with an accessible loading label.
public struct DSLoadingIndicator: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private let size: DSLoadingSize

    public init(size: DSLoadingSize = .launch) { self.size = size }

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
        .scaleEffect(size.dimension / 144)
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityHidden(true)
    }

    private func illustration(scanOffset: CGFloat?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(theme.colors.accentSurface)
            Group {
                if size == .compact {
                    Image(systemName: "checklist")
                        .font(.system(size: 68, weight: .semibold))
                        .foregroundStyle(theme.colors.accent)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        checklistLine(width: 48)
                        checklistLine(width: 36)
                        checklistLine(width: 42)
                    }
                }
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

public struct DSLoadingRow: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        HStack(spacing: DSSpacing.sm) {
            DSLoadingIndicator(size: .refresh)
            DSText(title, style: .callout, tone: .secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}
