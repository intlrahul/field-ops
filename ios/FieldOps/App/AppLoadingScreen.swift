import Prism
import SwiftUI

struct AppLoadingScreen: View {
    var body: some View {
        DSLoadingState(message: "Preparing your workspace") {
            FieldOpsLogo()
        }
    }
}

#Preview {
    AppLoadingScreen().designTheme()
}
