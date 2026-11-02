# Validation checklist

Original creation environment had no Swift/Xcode tooling. FieldOps integration on 2026-11-02 verified 8 package tests, a successful iOS Simulator app build, and 4 app navigation integration tests. Interactive checks below still require manual verification.

On a Mac:
1. Run `swift test` at package root; resolve any diagnostics before integration.
2. Build PathRouterUI for iOS Simulator in Xcode (package platforms: iOS 17/macOS 14).
3. Register Dashboard, list, details and Account; internal /inspections/123 must construct list then details.
4. Back button and swipe-back must update router.path and reveal list then dashboard.
5. Test root and unknown paths; invalid routes must preserve current path.
6. Use `xcrun simctl openurl booted 'fieldops://inspections/123'` with app running, terminated, signed out, and restoring.
7. Login must resume pending details; rejected/unknown links must not create partial stacks.
8. Logout must clear path/pending; later login must not reopen old protected destinations.
9. Malformed IDs, untrusted domains, query/fragment and encoded slash must be rejected.
10. Verify concurrent incoming links use the latest pending destination and auth startup cannot overwrite later logout.

Additional automated Router state tests (Apple target) are recommended before production: pending link resume, rejection atomicity, push/canonical difference, duplicate prevention, logout clearing, and Back binding prefix enforcement.
