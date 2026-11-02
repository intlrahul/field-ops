import Prism
import SwiftUI

/// The single app-owned spelling and configuration for the Prism wordmark.
struct FieldOpsLogo: View {
    var compact = false

    var body: some View {
        DSWordmark("Field", accentName: "Ops", compact: compact)
    }
}
