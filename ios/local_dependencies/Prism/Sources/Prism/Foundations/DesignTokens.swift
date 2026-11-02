import SwiftUI

public enum DSSpacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

public enum DSRadius {
    public static let control: CGFloat = 12
    public static let card: CGFloat = 20
}

public enum DSMetrics {
    public static let minimumTouchTarget: CGFloat = 44
    public static let controlHeight: CGFloat = 52
    public static let readableWidth: CGFloat = 680
    public static let formWidth: CGFloat = 440
    public static let summaryColumnWidth: CGFloat = 140
    public static let borderWidth: CGFloat = 1
    public static let brandMarkSize: CGFloat = 88
    public static let brandMarkMaximumSize: CGFloat = 160
}

public enum DSMotion {
    public static let feedback = Animation.easeOut(duration: 0.15)
}
