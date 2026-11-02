import SwiftUI
import Foundation

public enum DSSkeletonStyle { case card, statistics }

/// Noninteractive placeholders; real content replaces each independently loaded region.
public struct DSSkeleton: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var lineHeight = 16
    private let style: DSSkeletonStyle
    private let label: String

    public init(_ style: DSSkeletonStyle = .card, label: String = "Loading content") {
        self.style = style
        self.label = label
    }

    public var body: some View {
        Group {
            if reduceMotion || reduceTransparency {
                placeholders
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: scenePhase != .active)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                    placeholders.overlay {
                        GeometryReader { geometry in
                            LinearGradient(colors: [.clear, theme.colors.surface.opacity(0.8), .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: geometry.size.width * 0.6)
                                .offset(x: geometry.size.width * (phase * 1.6 - 0.6))
                        }
                        .mask(placeholders)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    @ViewBuilder private var placeholders: some View {
        switch style {
        case .card:
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    bar(fraction: 0.3)
                    bar(fraction: 0.85)
                    bar(fraction: 0.6)
                    bar(fraction: 0.4)
                }
            }
        case .statistics:
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                      ? [GridItem(.flexible())]
                      : [GridItem(.adaptive(minimum: DSMetrics.summaryColumnWidth))], spacing: DSSpacing.sm) {
                ForEach(0..<4) { _ in
                    DSCard {
                        VStack(alignment: .leading, spacing: DSSpacing.sm) {
                            bar(fraction: 0.3, height: DSMetrics.minimumTouchTarget)
                            bar(fraction: 0.45, height: lineHeight * 2)
                            bar(fraction: 0.75)
                        }
                    }
                }
            }
        }
    }

    private func bar(fraction: CGFloat, height: CGFloat? = nil) -> some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: DSSpacing.xxs)
                .fill(theme.colors.elevated)
                .frame(width: geometry.size.width * fraction)
        }
        .frame(height: height ?? lineHeight)
    }
}
