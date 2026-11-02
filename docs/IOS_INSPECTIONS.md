# iOS inspection API integration

The dashboard and inspection details use authenticated GET /inspections , GET /inspections/{id}, and GET /inspections/statistics. This slice is read-only; start, checklist/result saves, readings, notes, completion, creation, offline persistence, and sync are not wired into the UI yet.

## Boundaries

Inspections owns the shared Inspection summary and detail domain types under Features/Inspections/Domain. Dashboard consumes these types. InspectionRepository defines list/detail reads; RemoteInspectionRepository owns API DTO decoding/mapping. DTOs remain separate from domain models. Nullable due dates and the backend in_progress spelling are supported. Date mapping accepts RFC 3339 with or without fractional seconds and rejects invalid dates.

AppContainer owns the repository using the existing authenticated APIClient. AppRoutes passes it explicitly to DashboardRoutes and InspectionRoutes. Their deferred builders construct view models retained in screen State. AppComposition, FieldOpsApp, AppNavigation, and AppCoordinator do not change. PreviewInspectionRepository is used explicitly by previews and navigation tests; production has no sample fallback.

APIClient GET now separates query parameters from the path so opaque list cursors are encoded correctly, and maps server error envelopes to BackendError. Authorization uses the current bearer token. Automatic refresh after 401 remains unimplemented; inspection reads do not change the established authentication lifecycle.

## UI behavior

The dashboard requests 20 inspections initially. Load more follows nextCursor, merges by ID, and replaces duplicate summaries. Pull-to-refresh restarts pagination. Dashboard totals come exclusively from GET /inspections/statistics. Total, Assigned, In progress, and Completed cover the full authorized dataset independently of loaded pages. Statistics and list requests run concurrently on initial load and pull-to-refresh. Statistics have separate loading/error/retry state; failed totals are hidden rather than replaced with list-derived counts. Load more changes the list only. Separate endpoint reads are not a shared database snapshot. Initial loading uses Prism shimmer placeholders per section. List and statistics appear independently as each request finishes, with empty/retry/error states replacing the corresponding placeholder. Existing content remains visible during refresh. A failed refresh preserves existing loaded data; Retry starts a fresh list request. Access is scoped by the server for the signed-in role.

Details fetch by ID independently of the loaded dashboard page, including deep links. They show asset snapshot/tag/location, optional due date, checklist results/failure notes, reading values/units/bounds/range status, and note text/time. Prism card placeholders appear during initial detail loading; the single detail response replaces them together. Pull-to-refresh reloads details while keeping prior content visible. Missing, forbidden, or expired-session reads show an error and Retry rather than sample content. Completed inspections are displayed read-only, as are other statuses in this slice.

## Manual verification

1. Start the backend with existing environment configuration. If needed, run npm run seed from backend/ to create the demo inspection; no database reset is necessary.
2. Sign in as the assigned technician. Confirm the dashboard shows the server inspection rather than the ten sample rows.
3. Tap it and confirm asset, checklist, readings, and notes match the server response. A null dueAt should show No due date.
4. Pull to refresh both screens. With more than 20 visible inspections, use Load more and check the statistics remain full totals (50 total, 20 assigned, 15 in progress, 15 completed for untouched demo data).
5. Stop the backend and refresh: show an error while retaining previously loaded content. Restart it and retry.
6. Open fieldops://inspections/REAL_BACKEND_UUID while signed in and through the signed-out login handoff. Check Back returns to Dashboard. The old inspection-001 sample link no longer resolves production data.
7. Use a nonexistent UUID or an inspection assigned to another technician. Verify no sample data appears. Expired credentials should show the authentication error.

Verification: generic-device app build and build-for-testing succeeded. Focused tests cover status/null-date decoding, cursor progression/deduplication/reset, preserving data after refresh failure, unavailable detail errors, statistics independent of loaded pages, and statistics failure/retry without partial-count fallback. Tests were compiled only, not executed, per user instruction. No simulator launched and no live backend called. Real-device/network/layout behavior remains manual.

## Statistics-card navigation

Tap Assigned, In progress, or Completed to push a separate InspectionListScreen, using GET /inspections?status=assigned|in_progress|completed. Total opens a separate unfiltered list. Dashboard list and overall totals remain unchanged. The feature-owned route /inspection-lists/:status accepts all, assigned, in_progress, completed, with Dashboard as explicit parent. For example: fieldops://inspection-lists/in_progress.

Each destination retains its own State-owned list view model initialized with the route status. It loads only inspection pages, with skeletons, empty/error/retry, native pull-to-refresh, and Load more preserving status. Tapping a row pushes existing details; Back returns to that list and then Dashboard. Existing detail deep links retain their Dashboard parent. No query parser or app-navigation screen switch was added. Navigation tests cover status validation and the list/detail back stack; they were compiled only, not executed. Manually check card taps, pagination, gestures, and cold-launch links.

## Required use-case boundary

Presentation view models depend on GetInspectionsUseCase, GetInspectionDetailsUseCase, and GetInspectionStatisticsUseCase under Inspections/Domain/UseCases. Default implementations receive InspectionRepository and expose execute operations; they contain no transport or UI state. AppRoutes constructs them from the shared repository and passes them explicitly to DashboardRoutes/InspectionRoutes, whose deferred builders create view models. View models retain loading, pagination, filter, and presentation error state. The flow is View → ViewModel → UseCase → Repository → APIClient. This supersedes the earlier direct repository injection into view models. Previews and focused tests compose the same use cases with sample/test repositories. No new forwarding factory is introduced.
