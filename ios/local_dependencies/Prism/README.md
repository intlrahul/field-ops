# Prism

Local SwiftUI design-system package for FieldOps. Swift tools 6.0+, iOS 17+. No third-party dependencies. It currently targets iOS, not macOS.

## Use

Add this directory as a local Swift package and link the **Prism** library product. FieldOps already has this configured.

```swift
import SwiftUI
import Prism

struct ExampleScreen: View {
    var body: some View {
        DSScreen {
            DSText("Your workspace", style: .title)
            DSCard {
                DSFieldRow(title: "Asset", value: "Cooling pump", symbol: "shippingbox")
            }
            DSButton(title: "Continue") { /* caller owns the action */ }
        }
    }
}

// Apply once at the host's root:
// ExampleScreen().designTheme()
// ExampleScreen().designTheme(DSTheme(appearance: .dark))
```

The public API retains DS-prefixed names. The default preset is DSTheme.prism. Palette and typography are public value configurations; appearance follows the system unless overridden. Colors load from the package's processed resource bundle using Bundle.module.

## Contents

- Foundations: semantic colors, Dynamic Type typography, spacing/radii/metrics, motion, theme environment.
- Components: screens, sections/cards, buttons/icon actions, secure/text/email fields, badges/messages, field rows, summary grids, navigation cards, empty/loading states.
- Resources/Colors.xcassets: 18 roles, each with light/dark/increased-contrast variants.
- Preview/PrismCatalog.swift: Light, Dark, and Accessibility Xcode preview gallery. It is not registered as a shipping app route.

Keep features, domain types, networking, routing, and session state outside Prism. Build actual patterns needed by consumers; keep native alerts, navigation bars, and confirmation dialogs native.

## Verification

From the FieldOps repository root:

```sh
python3 scripts/check_design_system.py
xcodebuild -project ios/FieldOps.xcodeproj -scheme FieldOps \
  -destination 'generic/platform=iOS' -configuration Debug \
  -derivedDataPath /private/tmp/fieldops-prism-build \
  CODE_SIGNING_ALLOWED=NO build
```

Generic-device app/package compilation and 60 palette contrast checks have passed. No simulator, simulator tests, or preview rendering were run. The user owns visual, Dynamic Type, VoiceOver, Increase Contrast, and interaction verification. Host-platform `swift build` on macOS is not the validation path for this iOS-only package.

See ../../../docs/DESIGN_SYSTEM.md and ../../../docs/decisions/0006-shared-design-system.md for authoring rules and accessibility limits.
