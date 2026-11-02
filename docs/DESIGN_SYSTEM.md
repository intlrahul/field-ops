# Prism — FieldOps design system

Status: implemented as the local Swift package Prism in ios/local_dependencies/Prism (Swift tools 6.0+, iOS 17+). The app links its Prism library product and imports Prism at call sites. This is the required styling boundary for app screens. It has been compiled for a generic iOS device; the user owns simulator and visual verification.

## Structure and ownership

- Foundations/DesignTokens.swift: spacing, radii, layout/touch-target metrics, motion.
- Foundations/DesignTypography.swift: semantic Dynamic Type fonts and DSText.
- Foundations/DesignTheme.swift: palette roles, appearance, tone mapping, environment theme, and root modifier.
- Components/: shared layouts, actions, inputs, feedback, content rows, and state views.
- Preview/PrismCatalog.swift: interactive Xcode preview gallery, without a shipping app route or API calls.
- Resources/Colors.xcassets/: 18 semantic colors, each with light, dark, increased-contrast light, and increased-contrast dark variants. AccentColor matches the brand accent for native controls.

The design system must not import models, view models, routers, repositories, or app composition. Features supply content/actions and map domain states to generic semantic tones in their presentation layer. InspectionStatus's tone mapping remains with InspectionRow, not inside the shared library.

## Package integration

Prism has no dependencies on FieldOps or other packages. Sources live in Sources/Prism; Package.swift processes Resources. Colors use Color(name, bundle: .module), so they work in the app and package previews without depending on the app asset catalog. Only the app's native AccentColor branding remains in the app catalog.

Components retain their DS-prefixed names and expose explicit public initializers. Add import Prism to UI files, apply .designTheme() at the app root, and compose public components. DSTheme.prism is the system-following default preset. DSTheme, DSColors, and DSTypography are Sendable value configurations with public customization APIs. Prism currently targets iOS; macOS support is not claimed because input controls use iOS keyboard APIs.

## Visual foundation

FieldOps uses a teal brand accent, neutral slate surfaces, rounded system headings, and system body text. No external font assets or dependencies are needed. Typography uses semantic SwiftUI text styles so fonts scale with Dynamic Type. Metrics use a 4/8/12/16/24/32/48 spacing scale; controls have a minimum 44-point hit target, with main controls at least 52 points before padding. Text is allowed to wrap rather than forced into fixed-height controls.

Typography roles: display, title, heading, subheading, body, bodyStrong, callout, caption, captionStrong, metric. Metrics use monospaced digits. Do not specify font sizes or weights ad hoc in features.

Color roles: canvas, surface, elevated, primaryText, secondaryText, border, accent, onAccent, onDanger, accentSurface, plus foreground/surface pairs for info, success, warning, and danger. Meaning is expressed through text/icons as well as color. There are no domain-specific inspection colors in the design system.

DSTheme supplies colors, typography, and DSAppearance (system/light/dark). FieldOpsApp applies .designTheme() once, outside loading/login/navigation so all app content is themed. The default follows system appearance. A parent can supply DSTheme(appearance: .dark) or customize the palette/heading design; this is configuration, not a persisted account setting. App appearance selection/persistence is not added by this slice.

## Shared components

| Need | Component |
| --- | --- |
| Scrollable page, bounded readable width, canvas | DSScreen |
| Section heading and grouped surface | DSSection, DSCard, DSDivider |
| Semantic typography | DSText |
| Primary, secondary, destructive actions | DSButton |
| Loading/disabled action | DSButton isLoading/isDisabled |
| Toolbar/icon action with label and minimum target | DSIconButton |
| Text/email/password input, focus/helper/error | DSInput |
| Status label or contextual message | DSBadge, DSMessage |
| Decorative icon/avatar tile | DSIconTile, DSBrandMark |
| Labeled read-only value | DSFieldRow |
| Summary count and responsive grid | DSStatCard, DSStatGrid, DSStatistic |
| Tappable card | DSNavigationCard |
| Loading/empty/unavailable content | DSLoadingIndicator, DSLoadingState, DSLoadingBackground, DSEmptyState |

DSLoadingState uses a static teal-to-slate-to-blue surface gradient, stronger corner glows, and contour rings with a dot grid that fades away behind the central content. DSLoadingBackground owns this decoration in Prism; AppLoadingScreen only supplies its text. Increase Contrast or Reduce Transparency switches the backdrop to the plain semantic canvas. The background adds no motion.

DSInput supports an optional FocusState<Bool>.Binding so screens can coordinate keyboard focus. Login moves from email submission to the password field. Secure inputs retain native SecureField behavior; the component does not log input or persist credentials. DSButton owns pressed/disabled/loading styling and prevents duplicate taps while loading. The remaining business-level guards in view models are retained.

## Required authoring convention

1. Compose screens from shared components and native SwiftUI layout primitives (VStack/HStack/Group/etc.). Content and domain/navigation decisions stay in the feature.
2. Use DSText roles, DS tones, and spacing/metrics tokens. Do not add raw Color values, literal corner radii, font sizes, repeated borders, or custom button/field styling to feature screens.
3. Add a new reusable visual pattern to ios/local_dependencies/Prism/Sources/Prism/Components when needed by real UI. Do not create a wrapper for every native SwiftUI primitive or add speculative controls.
4. Keep native navigation bars, alerts, confirmation dialogs, text selection, and keyboard behavior. These system surfaces intentionally remain native; they inherit appearance/tint and accessibility rather than being replaced with custom overlays.
5. Resolve app actions through existing callbacks/feature navigation. The theme environment does not expose AppCoordinator/AppContainer or change the official route-registration convention.
6. Update the catalog and this guide when changing a shared component API or token role.
7. Recheck affected colors and the user's manual accessibility matrix before declaring visual/accessibility verification complete.

Keep private decorative/layout decisions inside the design system. Content strings and semantic SF Symbol choices may be supplied by features. Caller-owned strings can be localized before passing them to components; a localization rollout is not part of this slice.

## Applied screens

Login, Account, Dashboard, inspection details, and app loading now use the shared components. Repeated field/card/button styling has been removed from feature files. DashboardSummaryView now counts the actual existing sample inspections rather than showing unrelated hardcoded totals. Samples remain local; no API integration or business workflow was added. The original checklist scan illustration is retained as Prism’s DSLoadingIndicator, used by DSLoadingState. It uses theme colors, pauses when the scene is inactive, and becomes a static checklist under Reduce Motion. Button loading now uses the compact checklist scanner.

## Verification and limits

Run the non-simulator palette check:

```sh
python3 scripts/check_design_system.py
```

It validates all four variants for every semantic color, 4.5:1 contrast for 56 text/background combinations, and 3:1 contrast for four control-border/surface combinations. It checks sRGB token values, not screenshots, composited pressed effects, arbitrary custom themes, or every possible text placement. Do not treat it as a complete accessibility audit.

Generic-device compile (does not run the app or tests):

```sh
xcodebuild -project ios/FieldOps.xcodeproj -scheme FieldOps \
  -destination 'generic/platform=iOS' -configuration Debug \
  -derivedDataPath /private/tmp/fieldops-design-system-build \
  CODE_SIGNING_ALLOWED=NO build
```

No simulator or simulator tests were run for this design-system work, per the user's preference. No screenshot-based QA is claimed.

The user can open PrismCatalog's Light, Dark, and Accessibility previews and verify:

- Small and largest accessibility text sizes, long labels, and portrait/landscape on a small phone.
- Appearance changes and Increase Contrast using Xcode/device settings (contrast/reduced-motion environment values are read-only, not manually assigned in previews).
- VoiceOver labels/order, secure input, focus handoff, keyboard dismissal, disabled/loading actions, and status messages.
- Reduce Motion: custom button feedback animation is disabled; the checklist loading scan becomes static and button checklist loading also becomes static.
- Login keyboard reachability, scrollability, navigation back/deep-link behavior, Account confirmation and sign-out callbacks.

Large-text grids collapse to one column at accessibility sizes. Decorative symbols are hidden from VoiceOver; actionable icons carry explicit labels. Actual behavior/layout still requires the manual checks above. New controls (sheets, toggles, selectors, complex tables), a persistent theme picker, custom fonts, and additional brand themes should be added when a product screen needs them.

## App wordmark

Use FieldOpsLogo() wherever the app name is presented as branding; FieldOpsLogo(compact: true) fits navigation bars. The app-owned wrapper in Core/Branding supplies the name once to Prism's public DSWordmark. Prism owns the scalable vector F/check symbol, rounded heavy two-tone lettering, spacing, semantic colors, Dynamic Type, and a combined accessibility label. No bitmap logo or external font is required. Loading, login, and dashboard now share this branding. Keep plain strings for confirmation-dialog copy and navigation titles used by system back navigation.

DSLoadingState also accepts a heading view builder for branded loading, while its existing title-string initializer remains available for ordinary states. Preview both wordmark sizes in PrismCatalog and check the largest text sizes on-device; no screenshot verification is claimed.

## Responsive welcome illustration

DSWelcomeIllustration(symbol:) supplies decorative vector artwork using semantic colors and a caller-selected symbol. It maintains its aspect ratio while growing with available width and is hidden from VoiceOver. Login uses the readable screen width (up to 680 points) for the illustration, while keeping its form at 440 points. The scroll view preserves access on small phones, landscape, Split View, and with the keyboard visible. Artwork dimensions describe a scalable drawing, not text sizing. Review phone and iPad layouts manually; no simulator execution or screenshot QA is claimed.

Button height includes content padding: apply padding before the minimum-height frame in DSActionStyle. Ordinary single-line buttons are 52 points tall rather than 68; larger text and wrapped labels can expand naturally.

## Content loading placeholders

DSSkeleton(.card) and DSSkeleton(.statistics) provide shared noninteractive shimmer placeholders. They use semantic surfaces, scale line heights with Dynamic Type, and expose a caller-supplied loading label to VoiceOver rather than placeholder children. Reduce Motion or Reduce Transparency disables shimmer; animation pauses when the scene is inactive. The catalog includes both layouts. Inspection list/statistics render independently as their requests resolve, and details use card placeholders until their single detail response arrives. Keep existing content visible during refresh; do not replace it with a full-screen loader. Session restoration retains its existing app-boundary loading screen.

DSStatGrid optionally accepts selectedID and onSelect. With an action it renders native buttons, an accent selection outline, and the selected accessibility trait; without one it remains read-only. Features map the string IDs to domain filters. PrismCatalog demonstrates selection.


## Sized loading and refresh

DSLoadingIndicator(size:) supports .launch (144 points, default), .refresh (48), and .compact (28). Compact artwork simplifies the checklist so it remains legible. DSLoadingRow supplies refresh-size artwork with scalable loading text and a combined accessibility label. All sizes respect Reduce Motion and scene activity. These fixed decorative sizes do not change with Dynamic Type; labels still scale.

DSScreen(onRefresh:) uses native SwiftUI .refreshable for reliable pull recognition and release behavior. The system owns its pull indicator; a 48-point checklist row appears in content while refreshing. Concurrent refresh actions are ignored until the async action finishes. Native refresh awaits the full async action, and a named accessibility Refresh action provides an alternative through a view-owned task. Dashboard/details use this API and retain existing content; initial skeletons remain. DSButton uses the compact scanner. Manual device verification is required for pull/release, scrolling, short/empty lists, VoiceOver, and dark/light appearance; only generic-device compilation was performed.
