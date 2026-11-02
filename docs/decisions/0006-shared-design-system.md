# ADR 0006: Shared semantic design system

Status: implemented foundation, 2026-11-02.

The user requested a comprehensive shared design system. Use ios/local_dependencies/Prism/Sources/Prism as the sole owner of app styling: semantic typography/palette/tokens, theme environment, reusable UI components, and a component preview catalog. Features retain content, domain state, view models, navigation, and callbacks. System navigation bars/dialogs remain native.

Use system fonts with Dynamic Type, semantic assets with four light/dark/contrast variants, a system-following default appearance, and explicit optional appearance overrides. Colors carry semantic intent; feature presentation maps domain statuses into generic tones. The shared library has no domain or routing dependencies.

Apply the same components to current Login, Account, Dashboard, inspection-details, and loading screens so the foundation is exercised rather than left unused. Do not add factories or view models just to style static content. A persistent theme-selection product feature is deferred.

Check token contrast with scripts/check_design_system.py and compile for a generic iOS device. The user owns simulator execution and visual/gesture/VoiceOver verification. No full accessibility compliance or screenshot validation is claimed. See ../DESIGN_SYSTEM.md for the component contract and adoption procedure.
