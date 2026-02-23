# Project Status: Pulseboard Platform

## Last Updated
2026-02-23

## Current Phase
**SaaS Implementation Phase 4 Complete** - Webhooks & alerts system with webhook management, alert rules, threshold evaluation, and notifications.

## Overall Progress

| Epic | Status | Progress |
|------|--------|----------|
| 01 - Platform Foundation | Complete | 100% |
| 02 - Auth & Org Model | Complete | 100% |
| 03 - Data Model & Project Mgmt | Complete | 100% |
| 04 - Ingestion API & Processing | Complete | 100% |
| 05 - Flutter SDK | Complete | 100% |
| 06 - Analytics Dashboards | Complete | 100% |
| 07 - Compliance & Governance | Complete | 100% |
| 08 - Billing Placeholder | Complete | 100% |
| 09 - Quality & CI/CD | Complete | 100% |
| 10 - Onboarding & Dashboard | Complete | 100% |
| SaaS Phase 1 - Bug Fixes | Complete | 100% |
| SaaS Phase 2 - Spark Billing | Complete | 100% |
| SaaS Phase 3 - Marketing Pages | Complete | 100% |
| SaaS Phase 4 - Webhooks & Alerts | Complete | 100% |

## Recent Changes

### 2026-02-23 (Bugfix: Sessionizer duration_ms causing event rejection)
- **Root Cause** — `Sessionizer::updateSession()` computed `duration_ms` via `Carbon::diffInMilliseconds()` which returns a float. PostgreSQL rejected the float for the integer column, causing a silent exception that rolled back the event. All events after the first in a batch (which creates the session) triggered `updateSession()` and were rejected.
- **Fix** — Cast `duration_ms` to `(int) abs(...)` in `Sessionizer.php:114-115`. This ensures the value is always a non-negative integer.
- **Impact** — Previously only ~4 of 9 events per batch were accepted (1st event + user_properties + traces which skip sessionization). Now all 9/9 accepted.
- **Reprocessed** — Cleared dedup cache and reprocessed all 3 existing PHP SDK test batches. All now show 9 accepted, 0 rejected.
- **Test** — Added "processes multiple events in a single batch with shared session" test to `ProcessIngestBatchTest.php` verifying 5 events in one batch all get accepted and share one session with integer `duration_ms >= 0`.
- All ingestion tests pass: **71 passed** (151 assertions)

### 2026-02-23 (Project Edit/Delete & Admin Nav Links)
- **Project Delete** — Added full project deletion to ProjectSettings Livewire component with confirmation modal. User must type the project name to confirm. Soft-deletes the project and redirects to projects index. Only visible to users with `delete` policy permission (team owners and admins).
- **Project Edit Enhancements** — Added field labels, validation error display for name and platform fields.
- **Admin Nav Links** — Created `x-admin-nav-links` Blade component showing Filament, Horizon, and Pulse links in the user dropdown for admin users. Included in both `app-top-bar` and `project-top-bar`.
- **Tests** — 10 new tests: ProjectSettingsTest (8 tests: renders, update name, update platform, name required, danger zone visibility, delete confirmation mismatch, successful delete with soft-delete verification, non-owner cannot see danger zone), AppTopBarTest (2 tests: admin sees links, non-admin doesn't).
- Full test suite: **580 passed**, 1 skipped, 0 failures (1487 assertions)

### 2026-02-23 (Dashboard Navigation Redesign)
- **New Components** — Created `x-nav-tab` (reusable tab with icon slot, active state, border-b indicator) and `x-mobile-nav-drawer` (hamburger button + Alpine.js slide-down drawer for mobile).
- **App Top Bar Redesign** — Added Heroicons to Dashboard, Projects tabs. Added Billing tab linking to team settings. Integrated mobile hamburger drawer with all nav items + account links (Profile, API Tokens, Team Settings, Log Out). User dropdown hidden on mobile (replaced by drawer).
- **Project Top Bar Redesign** — Grouped 9 tabs into primary (Dashboard, Events, Sessions, Crashes, Performance) and "More" dropdown (Compliance, Webhooks, Alerts, Settings). Added Heroicons to all tabs. "More" dropdown highlights when any secondary tab is active. Project switcher now visible on md+ (was lg+). Mobile drawer shows project switcher at top, all 9 tabs as a list, All Projects link, and account links.
- **Consistent Design** — Both bars use the same `x-mobile-nav-drawer` and `x-nav-tab` components. Consistent spacing, transitions, dark mode styling, and `relative` positioning for drawer panels.
- **Tests** — 12 new tests across 2 files: AppTopBarTest (5 tests: tabs, mobile menu, user dropdown, dark mode, billing link), ProjectTopBarTest (6 tests: primary tabs, more dropdown, project switcher, mobile menu, active state, all projects link).
- Full test suite: **570 passed**, 1 skipped, 0 failures (1458 assertions)

### 2026-02-23 (SaaS Phase 4: Webhooks & Alerts System)
- **Migrations** — Created `webhooks` (team_id, url, encrypted secret, events JSON, active), `webhook_deliveries` (webhook_id, event_type, payload, response_code, response_body, attempts, delivered_at), `alert_rules` (project_id, name, metric, operator, threshold, webhook_id, notification_channels, active, last_triggered_at). Added `slack_webhook_url` to teams.
- **Enums** — Created `WebhookEventType` (crash.new/resolved, alert.threshold, export.ready, deletion.complete), `AlertMetric` (crash_count, error_rate, p95_cold_start, event_volume, crash_free_rate), `AlertOperator` (>, <, >=, <=, ==).
- **Models** — Created `Webhook` (encrypted secret, events array, subscribesTo method), `WebhookDelivery` (isSuccessful helper), `AlertRule` (enum casts, evaluate method with operator matching). Added `webhooks()` relation to Team, `alertRules()` relation to Project.
- **Factories** — Created WebhookFactory, WebhookDeliveryFactory, AlertRuleFactory with inactive/failed states.
- **WebhookService** — `dispatch()` finds matching active webhooks for event type and queues SendWebhook jobs. `generateSignature()` HMAC-SHA256. `testDelivery()` synchronous test with HTTP client.
- **SendWebhook Job** — Queued on `compliance` queue, 3 tries with [10, 60, 300]s backoff. Posts with `X-Pulseboard-Signature` and `X-Pulseboard-Event` headers. Logs delivery result.
- **AlertEvaluator** — Evaluates all active rules per project. `getMetricValue()` computes crash_count, error_rate, p95_cold_start, event_volume, crash_free_rate from DB. `handleTriggered()` dispatches webhooks and sends AlertTriggeredNotification.
- **AlertTriggeredNotification** — Mail + Slack channels. Includes alert name, metric, threshold, current value, project link.
- **CheckAlertThresholds Command** — `alerts:check-thresholds` scheduled hourly. Evaluates all projects with active alert rules.
- **Livewire Components** — `WebhookManager` (CRUD webhooks, test delivery, toggle active, delivery log). `AlertRuleManager` (CRUD alert rules with metric/operator/threshold, webhook binding, notification channels).
- **Routes** — Added `/projects/{project}/webhooks` and `/projects/{project}/alerts` under project scope. Added Webhooks and Alerts tabs to project top bar navigation.
- **Tests** — 36 new tests across 8 files: WebhookServiceTest (6), SendWebhookJobTest (2), AlertEvaluatorTest (5), CheckAlertThresholdsCommandTest (3), WebhookManagerTest (6), AlertRuleManagerTest (5), WebhookModelTest (3), AlertRuleModelTest (6).
- Full test suite: **559 passed**, 1 skipped, 0 failures (1423 assertions)

### 2026-02-23 (SaaS Phase 3: Public Marketing Pages)
- **Marketing Layout** — Created shared `layouts/marketing.blade.php` with sticky nav (Features, Pricing, Contact, Terms, Privacy, Login/Register), GDPR/EU trust badges in footer, dark mode support. Created `MarketingLayout` view component class.
- **Landing Page** — Rewrote `welcome.blade.php` to use marketing layout. Hero section ("Privacy-first analytics for mobile apps"), 6 feature highlight cards, plan preview grid (Free/Pro/Enterprise), EU trust badges (GDPR, EU Data Residency, Flutter-First SDK).
- **Pricing Page** — Created `/pricing` with 4 plan cards (Free/Trial/Pro/Enterprise) with feature lists and CTAs. Full feature comparison table with all plan limits.
- **Features Page** — Created `/features` with 6 alternating feature sections: Event Analytics, Session Tracking, Crash Reporting, Performance Tracing, GDPR Compliance, Team Collaboration. Gradient illustration placeholders. CTA banner.
- **Contact Page** — Created `/contact` with email/sales cards, company info (Germany, EU, Hetzner, GDPR).
- **Terms & Privacy** — Created GDPR-focused markdown files (`resources/markdown/terms-of-service.md`, `privacy-policy.md`). Updated `terms.blade.php` and `policy.blade.php` to use marketing layout. Terms cover: EU jurisdiction, data retention by plan, data minimization. Privacy covers: data controller, sub-processors, DSAR 30-day SLA, data residency, security measures.
- **Routes** — Added named routes: `marketing.home`, `marketing.pricing`, `marketing.features`, `marketing.contact`.
- **Tests** — 23 new tests across 6 files: WelcomePageTest (5), PricingPageTest (4), FeaturesPageTest (4), ContactPageTest (4), TermsPageTest (3), PrivacyPageTest (3).
- Full test suite: **523 passed**, 1 skipped, 0 failures (1354 assertions)

### 2026-02-23 (Dashboard Improvements — Top Bar Only)
- **Dashboard Aggregate Overview** — Updated dashboard route to pass team projects (with `withCount('environments')`) and member count. Dashboard now shows stat cards (Total Projects, Team Members) and recent projects grid (up to 6) when projects exist; empty state preserved when no projects.
- Navigation uses **top bar only** (no sidebar). Layouts unchanged from original top-bar approach.
- Files modified: `dashboard.blade.php`, `routes/web.php`
- Full test suite: **475 passed**, 1 skipped, 0 failures (1252 assertions)

### 2026-02-23 (Plan 10: Onboarding Flow & Dashboard Redesign)
- **Phase 1: Database & Model** — Added `onboarding_completed_at`, `onboarding_step`, `getting_started_dismissed_at` columns to projects table. Updated Project model with fillable, casts, and helper methods (`hasCompletedOnboarding()`, `hasReceivedData()`, `isGettingStartedDismissed()`). Added `completed()` factory state.
- **Phase 2: SdkSnippetService** — Extracted SDK snippet logic from ProjectKeyManager into shared `SdkSnippetService` with `getFrameworks()`, `getInstallCommand()`, `getConfigSnippet()` methods supporting flutter, react_native, javascript, php, laravel frameworks. Refactored ProjectKeyManager to use the service.
- **Phase 3: Onboarding Wizard** — Created `OnboardingWizard` Livewire component with 4-step flow: framework selection → install command → configure with DSN → verify first event. Auto-generates write key for production environment. Uses `wire:poll.3s` on verify step. Skip option marks onboarding complete. Updated `ProjectCreate` to redirect to onboarding instead of settings.
- **Phase 4: Dashboard Enhancements** — Added `getRecentEvents()` and `getTopCrashGroups()` to MetricsService. Created `RecentEventsFeed` (wire:poll.10s), `TopCrashes`, and `GettingStartedChecklist` Livewire components with Blade views. Updated `stat-card` with optional `previousValue` prop. Updated dashboard layout with new bottom row (recent events + top crashes) and getting started checklist at top.
- **Phase 5: Smart Routing** — ProjectDashboard redirects to onboarding for new projects. Shows `<x-waiting-for-data>` component when no events/users exist. Created reusable waiting-for-data Blade component with pulsing animation, DSN display, and link to revisit onboarding.
- **Phase 6: Tests** — 26 new tests across 6 files: OnboardingWizardTest (9), RecentEventsFeedTest (3), TopCrashesTest (3), GettingStartedChecklistTest (4), updated ProjectDashboardTest (7), updated ProjectModelTest (10). Updated E2E test to handle onboarding redirect.
- Full test suite: **475 passed**, 1 skipped, 0 failures (1252 assertions)

### 2026-02-23 (Plan 09: Quality & CI/CD)
- **Phase 1: Test Organization** — Moved ~30 root-level feature tests into logical subdirectories: Auth/ (11), Teams/ (8), Api/ (4), Foundation/ (4), Models/ (5), Authorization/ (2), Admin/ (4). Zero breakage.
- **Phase 2: Test Configuration** — Updated Pest.php to extend TestCase into Contract and E2E directories. Added Contract and E2E test suites to phpunit.xml.
- **Phase 3: GitHub Actions CI** — Created `.github/workflows/ci.yml` with two parallel jobs:
  - `laravel-tests`: Ubuntu + PHP 8.4 + PostgreSQL 16 + Redis 7, Composer + Node 20 build, Pest + Pint checks
  - `flutter-tests`: Flutter stable, pub get, analyze, test
- **Phase 4: Contract Tests** — Created `tests/Contract/IngestPayloadV1Test.php` (8 tests): validates 202 response structure, per-event-type schema compliance (event/crash/trace/user_properties), invalid schema_version 422, missing required fields 422 with structured errors, mixed event types in single batch.
- **Phase 5: Contract Tests** — Created `tests/Contract/QueryResponseTest.php` (6 tests): metrics KPI numeric values, paginated events with data/meta/links, event item required keys, crash groups structure, trace percentiles structure, auth requirement.
- **Phase 6: E2E Smoke Test** — Created `tests/E2E/OnboardingFlowTest.php` (1 comprehensive test): register user → personal team auto-created → create project via API (3 environments) → generate write key → POST ingest batch (202) → ProcessIngestBatch sync → verify events persisted, sessions created, daily aggregates updated → Livewire dashboard renders.
- Full test suite: 449 passed, 1 skipped, 0 failures (15 new tests added)

### 2026-02-23 (Plan 08: Billing Placeholder)
- Added plans table (Free/Trial/Pro/Enterprise) and team_subscriptions table; migration-seeded plans, backfill migration for existing teams.
- Created Plan and TeamSubscription models; Team.subscription() HasOne; TeamObserver creates Free subscription on team create.
- EntitlementService: getPlanForTeam, getLimits, getCurrentUsage, isWithinLimits, isApproachingLimits (events from DailyAggregate, members/projects counts).
- Team settings: tabbed layout (General, Members, Billing, Danger zone); Billing tab with Livewire BillingManager (current plan, usage, plan comparison table, trial countdown, Upgrade placeholder link).
- Upgrade CTA component shown on app dashboard and project dashboard when isApproachingLimits (≥80%); links to team billing tab.
- CheckEntitlement middleware (entitlement:projects) on projects.create; AddTeamMember action checks team_members limit and throws AuthorizationException when at limit.
- Gate advancedRetention for Pro/Enterprise plans (AppServiceProvider).
- Tests: EntitlementServiceTest (10), TeamBillingTest (2), EntitlementMiddlewareTest (5). No Spark coupling; no payment provider.

### 2026-02-23 (Filament Admin Resources Blueprint)
- Implemented Filament Blueprint adding seven admin resources to the Admin panel: Devices, Teams, Projects, CrashReports, Traces, ConsentRecords, DataBreachIncidents.
- All resources use admin-only policies (DevicePolicy, CrashReportPolicy, TracePolicy, ConsentRecordPolicy, DataBreachIncidentPolicy); TeamPolicy and ProjectPolicy updated to allow admins to view/update/delete any team or project.
- Navigation groups and sort order: User Management (1), Organization – Teams (2), Projects (3), Environments & devices – Devices (4), Crash & performance – Crash Reports (5), Traces (6), Consent & compliance – Consent Records (7), Data Breach Incidents (8).
- Relation managers: TeamResource – ProjectsRelationManager, DataBreachIncidentsRelationManager; ProjectResource – EnvironmentsRelationManager (columns: name, retention_days_raw, pii_mode, created_at).
- Enums Platform, ConsentType, BreachSeverity implement Filament HasLabel; BreachSeverity implements HasColor for badges.
- ConsentRecord create: unique validation for (environment_id, app_user_id, consent_type); created_at set in mutateFormDataBeforeCreate (model has $timestamps = false).
- Tests: FilamentAdminResourcesTest (29 tests) – non-admin 403 on list/create for all resources, admin list access, CRUD for Team/Project/DataBreachIncident/ConsentRecord, filters (team_id, severity), relation managers (Projects, DataBreachIncidents on Team).

### 2026-02-23 (Filament Admin User Management)
- Implemented Filament Blueprint for admin-only user management (plan: Admin User Management Filament Blueprint).
- Admin panel set as default; path `/admin`; access restricted via `User::canAccessPanel()` (is_admin).
- UserResource: list/create/edit/view with form (name, email, password, is_admin, email_verified_at), table with filters (is_admin, email_verified), infolist on view page; navigation group "User Management", global search on name/email.
- Relation managers: Teams (attach/detach, pivot role, no create), SocialAccounts (view + revoke), Tokens (view + revoke).
- UserPolicy: all abilities require `$user->isAdmin()`; policy used by Filament for resource authorization.
- UserStatsWidget: dashboard stats for total users, verified users, admins.
- Tests: FilamentUserResourceTest (16 tests) for panel/resource auth, CRUD, validation, relation managers; Queue::fake() used to avoid welcome-email view errors in tests.

### 2026-02-23 (Plan 01 Implementation)
- Switched database from SQLite to PostgreSQL 16 (installed via Homebrew)
- Configured Redis queues with predis client (installed Redis 7 via Homebrew)
- Configured Horizon with 3 supervisor queues: default, ingest, compliance
- Updated Horizon gate to restrict access to team owners/admins
- Updated composer dev script to use Horizon instead of queue:listen
- Created 5 Pennant feature flags: SdkReactNative, DashboardPerformance, DashboardBeta, ExportsEnabled, RetentionAdvanced
- Registered Feature::discover() in AppServiceProvider
- Added base API rate limiting (60/min) in AppServiceProvider
- Custom Tailwind config: primary/secondary/accent/semantic colors, Inter + JetBrains Mono fonts, dark mode class strategy
- Custom sidebar-based layout replacing stock Jetstream top-nav
- Created Blade components: sidebar-nav, top-bar, stat-card, page-header, empty-state
- Created DarkModeToggle Livewire component with localStorage persistence and FOUC prevention
- Updated dashboard with Pulseboard branding and "Create your first project" empty state
- APP_NAME set to Pulseboard, LOG_STACK to daily, CACHE_STORE to redis
- Updated phpunit.xml for PostgreSQL test database
- Wrote 11 foundation tests: DB connectivity, table listing, Pennant flags, Horizon access
- Full test suite: 54 passed, 1 skipped, 0 failures

- Documentation updated: extensible SocialAuthController pattern (generic redirect/callback, config-driven providers)
- Documentation updated: Hetzner Cloud Germany + Laravel Forge hosting details added to CLAUDE.md, AGENTS.md, STATUS.md
- Project analyzed and deep-dived
- 9 detailed plans created in `Docs/Plans/`
- 9 task breakdown files created in `Docs/Tasks/`
- CLAUDE.md and AGENTS.md written with comprehensive AI instructions
- STATUS.md created for change tracking
- Existing state: Laravel 12 + Jetstream scaffold (fresh install)
- Flutter SDK directory is empty (not started)

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-23 | No Laravel Passport | Use Sanctum for all API token needs; simpler, already installed |
| 2026-02-23 | EU-first privacy model | Primary market is European; GDPR-first, privacy-by-default |
| 2026-02-23 | PostgreSQL over SQLite | Production-ready, supports jsonb, GIN indexes for analytics |
| 2026-02-23 | Use Laravel Spark for billing | Spark already installed; use for payment processing instead of custom billing models |
| 2026-02-23 | Hetzner Cloud Germany + Laravel Forge | EU data residency for GDPR compliance; Forge for managed deployments, SSL, daemons |
| 2026-02-23 | PostgreSQL 16 + Redis 7 on Hetzner | Co-located with app servers in Germany; no cross-border data transfers |
| 2026-02-23 | Ubuntu 24.04 LTS | LTS for stability; Forge-supported |
| 2026-02-23 | Extensible SocialAuthController pattern | Generic redirect/callback with config-driven provider list instead of per-provider methods |
| 2026-02-23 | Sentry-like DSN for SDK | Single config string replaces writeKey + endpoint + environment; easier onboarding |
| 2026-02-23 | Renamed to "Pulseboard" | Full rebrand from "App Analytics"; Flutter package stays `app_analytics` |

## Blockers
- None currently

### 2026-02-23 (Plan 02 Implementation)
- Installed laravel/socialite and configured GitHub + Google providers in config/services.php
- Created SocialAccount model with UUIDs, encrypted tokens, user relationship
- Created social_accounts migration with unique (provider, provider_id) constraint
- Created SocialAccountFactory with github() and google() states
- Created SocialProvider enum (GitHub, Google)
- Built extensible SocialAuthController with generic redirect/callback for any configured provider
- Made password nullable on users table (social-only users don't need passwords)
- Enabled MustVerifyEmail on User model; social users auto-verified on creation
- Added socialAccounts() HasMany relationship to User model
- Registered social auth routes with whereIn constraint on configured providers
- Expanded Jetstream permissions: project:create/read/update/delete, event:ingest/read, export:create
- Added viewer role (read-only) to Jetstream roles
- Created social-login-buttons Blade component with GitHub/Google SVG icons
- Added social login buttons to login and register views
- Wrote 14 new tests: social auth flows, model encryption, UUID keys, unique constraints, email verification, Sanctum permissions
- Full test suite: 68 passed, 1 skipped, 0 failures

### 2026-02-23 (Plan 03 Implementation)
- Created 14 domain enums: Platform, KeyType, PiiMode, UserIdHashing, EventType, BatchStatus, ExportType, DeletionScope, PlanType, SubscriptionStatus, LawfulBasis, ConsentType, DsarStatus, DataRegion
- Created 11 migrations for core domain tables: projects, environments, project_keys, app_users, devices, analytics_sessions, events (with GIN index on properties), crash_reports, traces, data_export_jobs, data_deletion_requests
- Created migration to make user password nullable (for social-only users)
- All tables use UUID primary keys, privacy-by-default settings (strict PII, IP truncation, SHA-256 hashing, EU region)
- Created 11 Eloquent models with relationships, enum casts, HasUuids, SoftDeletes (Project)
- ProjectKey model with static generate() (prefixed tokens, SHA-256 hashing, DSN generation), findByToken(), revoke(), markSeen(), scopeActive()
- AppUser model with applyPropertyOperation() for set/set_once/increment/unset on jsonb properties
- AnalyticsSession uses custom table name to avoid conflict with Laravel sessions
- Event model with GIN-indexed jsonb properties and scopes: byName, inDateRange, forUser, forSession
- CrashReport and Trace models with fingerprint/duration scopes
- DataDeletionRequest with isOverdue() for 30-day GDPR SLA tracking
- Created factories for all 11 models with realistic data and state methods
- ProjectObserver auto-creates 3 environments (production, staging, development) on project creation
- ProjectPolicy with team-scoped authorization (owner for delete, admin for update, member for view)
- Added AuthorizesRequests trait to base Controller
- Built Project Management API with 3 controllers (ProjectController, EnvironmentController, ProjectKeyController)
- 11 API routes under /api/v1 with Sanctum auth: full CRUD for projects, environment settings, key generation/revocation
- 4 Form Requests with validation rules
- 3 API Resources (ProjectResource, EnvironmentResource, ProjectKeyResource with display-once plain_token + DSN)
- Built 5 Livewire components: ProjectList, ProjectCreate, ProjectSettings, EnvironmentSettings, ProjectKeyManager
- ProjectKeyManager with create modal (shows plain token + DSN once), copy-to-clipboard, and revoke confirmation
- Added "Projects" link to sidebar navigation
- Registered 3 web routes for project management pages
- Wrote 128 new tests: enum validation (70), model relationships (12), ProjectKey generation (12), AppUser properties (6), Project CRUD API (7), Environment API (4), ProjectKey API (6), authorization (5), model tests (6)
- Full test suite: 196 passed, 1 skipped, 0 failures

### 2026-02-23 (Plan 04 Implementation)
- Created IngestBatch migration, model, and factory with BatchStatus enum and markProcessing/markProcessed/markFailed methods
- Created AuthenticateProjectKey middleware: Bearer token auth via SHA-256 hashed ProjectKey lookup, 401/403 responses, attaches environment/project to request
- Registered `auth.project_key` middleware alias in bootstrap/app.php
- Configured ingest rate limiter (120/min per environment) in AppServiceProvider
- Created IngestBatchRequest form request with comprehensive validation: schema_version, app/device/user context, per-event type-specific rules (event, crash, trace, user_properties), structured JSON error responses
- Created IngestController with batch() endpoint: idempotency key support, creates IngestBatch, dispatches ProcessIngestBatch job, returns 202
- Added `POST /api/v1/ingest/batch` route with auth.project_key + throttle:ingest middleware
- Created 6 ingestion service classes:
  - EventNormalizer: UTC timestamp normalization, future/past clamping, UUID validation, string trimming
  - Deduplicator: Cache-based event deduplication (environment + event_id)
  - Sessionizer: Session resolution by explicit key or inference (device + user + 30min gap)
  - PiiFilter: Property filtering (strict/permissive modes, denylist, auto-detection), IP truncation, user ID hashing (SHA-256/HMAC/None)
  - UserPropertyApplicator: set/set_once/increment/unset operations on AppUser jsonb properties
  - AggregateUpdater: Daily aggregate upserts for event counts, active users, crashes, cold starts
- Created ProcessIngestBatch job: queue-based processing with 3 retries, backoff [10, 60, 300], 120s timeout, DB savepoints per event for PostgreSQL compatibility
- Created DailyAggregate migration, model, and factory with unique composite index
- Created UpdateDailyAggregates artisan command scheduled daily at 02:30
- Wrote 61 new tests across 7 test files: AuthenticateProjectKey (6), IngestBatchValidation (15), IngestController (4), ProcessIngestBatch (8), EventNormalizer (8), PiiFilter (11), UserPropertyApplicator (9)
- Full test suite: 257 passed, 1 skipped, 0 failures

### 2026-02-23 (Plan 05 Implementation)
- Created Flutter SDK package `app_analytics` in `Source Code/flutter-sdk/`
- Package setup: pubspec.yaml (7 deps, 3 dev deps), strict analysis_options.yaml, barrel file
- Created 3 utility classes: IdGenerator (UUID/idempotency keys), Clock (testable abstraction), SdkLogger (debug logging)
- Created AnalyticsConfig with full DSN parsing (`https://<key>@<host>/<project>/<env>`), validation, and configurable defaults
- Created 10 data models matching API schema exactly:
  - AnalyticsEvent, AppInfo, DeviceInfoModel, UserInfo, Breadcrumb
  - CrashReport + CrashException, TraceEvent + TraceData
  - UserPropertiesEvent + UserPropertyOp, BatchPayload, BatchResponse
- All models have toJson()/fromJson() with proper null handling
- Created 6 service classes:
  - AnalyticsHttpClient: POST to /api/v1/ingest/batch with Bearer auth, SDK headers, idempotency key, response handling (202/422/429/5xx)
  - BatchProcessor: In-memory queue, auto-flush at threshold, timer-based flush, sampling, consent/opt-out, retry with exponential backoff, connectivity listener
  - SessionManager: WidgetsBindingObserver, auto session_start/session_end, 5-min resume timeout
  - CrashHandler: FlutterError.onError + PlatformDispatcher.instance.onError, breadcrumb buffer, fingerprint generation
  - DeviceInfoProvider: device_info_plus + package_info_plus, cached results
  - Persistence: JSON file storage via path_provider, load/save/clear, max event limit
- Created AppAnalytics singleton client with static API:
  - initialize(), track(), identify(), setUserProperty/Once/Increment/Unset()
  - startTrace() returning Trace handle with putAttribute()/stop()
  - flush(), reset(), optOut()/optIn(), grantConsent()/revokeConsent()
  - addBreadcrumb(), shutdown()
  - Persists anonymous_id via SharedPreferences
- Created example app with buttons for all SDK methods
- Wrote 64 tests across 7 test files:
  - config_test: 10 DSN parsing tests (valid, port, http, errors, defaults, custom values)
  - models_test: 18 serialization round-trip tests for all models
  - http_client_test: 6 tests (202/422/429/500/network error/idempotency key)
  - batch_processor_test: 6 tests (auto-flush, explicit flush, empty, opt-out, consent, sampling)
  - session_manager_test: 5 tests (start, stop, resume within timeout, timeout exceeded, idempotent)
  - crash_handler_test: 3 tests (breadcrumb limit, clear, install/uninstall)
  - persistence_test: 5 tests (empty, round-trip, append, trim, clear)
  - analytics_client_test: 7 integration tests (init, track, identify, user props, opt-out, schema, reset)
- `flutter analyze` passes with 0 issues
- `flutter test` passes all 64 tests

### 2026-02-23 (Plan 06 Implementation)
- Installed Chart.js via npm; exposed as `window.Chart` in app.js
- Created MetricsService with 9 methods: getKpis, getPreviousPeriodKpis, getDailyActiveUsers, getEventVolume, getTopEvents, getCrashFreeRateTrend, getEventNames, getTracePercentiles, getTraceVersionBreakdown
- MetricsService uses 5-minute caching, PostgreSQL `PERCENTILE_CONT()` for trace percentiles, `BOOL_OR()` for crash grouping
- Created reusable Blade components: timeseries-chart, bar-chart, stack-trace-viewer, data-table
- Created DateRangePicker Livewire component with presets (7d/14d/30d/90d), static parseDateRange() helper
- Created EnvironmentSwitcher Livewire component with session persistence
- Built project-scoped layout (`layouts/project.blade.php`) with sidebar navigation
- Created ShareProjectWithView middleware for passing route-bound Project to layout views
- Created 5 dashboard Livewire components:
  - ProjectDashboard: KPI cards, DAU chart, event volume, top events bar chart, crash-free rate trend
  - EventExplorer: Name autocomplete, filters, paginated results, event detail modal
  - CrashExplorer: Fingerprint grouping, fatal/version filters, detail view with stack trace and breadcrumbs
  - PerformanceExplorer: Trace percentile display, drill-down with histogram and version breakdown
  - SessionsExplorer: Session list with detail view and event timeline
- Created 4 analytics API controllers: MetricsController, EventsController, CrashesController, TracesController
- Created 4 Form Request classes for API validation
- Registered project-scoped web routes with ShareProjectWithView middleware
- Registered 4 API analytics routes under /api/v1/analytics
- Fixed EnvironmentFactory to generate unique short names (avoids ProjectObserver conflict)
- Fixed TeamFactory to use `fake()->words()` instead of `$this->faker->company()` (Faker provider issue)
- Moved MetricsServiceTest from Unit to Feature (requires Laravel app bootstrap for factories)
- Wrote 29 new tests across 6 test files:
  - MetricsServiceTest: 7 unit tests (KPIs, crash-free rate, top events, event names, DAU, event volume, trace percentiles)
  - MetricsApiTest: 7 API tests (overview, validation, events search, name filtering, crashes, traces, auth)
  - ProjectDashboardTest: 4 tests (renders, component, date range, environment change)
  - EventExplorerTest: 4 tests (renders, events display, name filtering, event detail)
  - CrashExplorerTest: 4 tests (renders, empty state, crash groups, detail view)
  - PerformanceExplorerTest: 3 tests (renders, trace percentiles, drill-down)
- Full test suite: 286 passed, 1 skipped, 0 failures

### 2026-02-23 (Queuing & Horizon Optimization)
- Queued team invitation emails (`Mail::queue()` instead of `Mail::send()`)
- Added caching to `MetricsService::getEventNames()` (120s TTL) and `getTraceVersionBreakdown()` (300s TTL)
- Created `PrecomputeMetrics` queued job to warm metric caches hourly for all environments
- Scheduled `horizon:snapshot` every 5 minutes for metrics graphs
- Scheduled hourly metric pre-computation with `withoutOverlapping()` to prevent queue flooding
- Optimized Horizon configuration for high-throughput analytics:
  - `fast_termination: true` for zero-downtime Forge deploys
  - Master memory limit raised to 128MB
  - Ingest supervisor: minProcesses=2, maxProcesses=10, balanceMaxShift=3, balanceCooldown=1s (fast auto-scale for burst SDK traffic)
  - Default supervisor: minProcesses=1, maxProcesses=5 (emails, notifications, metric pre-computation)
  - Compliance supervisor: minProcesses=1, maxProcesses=3, timeout=600s, simple balance (GDPR exports/deletions)
  - Wait time thresholds: ingest=30s (tighter), default=60s, compliance=120s
  - Trim: recent jobs 3h, failed jobs 7d
- Updated InviteTeamMember test to use `assertQueued()` instead of `assertSent()`
- Full test suite: 286 passed, 1 skipped, 0 failures

### 2026-02-23 (Plan 07 Implementation)
- **Phase 1: Audit Log System**
  - Created `audit_logs` migration with UUID PK, team_id/user_id FKs, action/resource/metadata/ip fields, immutable (no updated_at)
  - Created `AuditAction` enum with 16 compliance actions (consent, deletion, export, retention, breach, etc.)
  - Created `AuditLog` model with HasUuids, scopes: forTeam(), forAction(), forResource()
  - Created `AuditService` with static log() using direct DB::table()->insert() for speed, auto-resolves auth context, truncates IP via PiiFilter
  - Created `Auditable` trait for convenience audit() method
  - 7 tests: creation, IP truncation, scopes, immutability, unauthenticated context

- **Phase 2: Consent Management**
  - Created `consent_records` migration with unique (environment, app_user, consent_type) constraint, nullable app_user_id with nullOnDelete FK (preserves records after user deletion)
  - Created `ConsentRecord` model with HasUuids, active() scope
  - Created `ConsentRecordFactory` with revoked() and forType() states
  - Created `ConsentService`: grantConsent() (upsert + audit), revokeConsent() (+ audit), hasConsent() (indexed lookup), getConsentStatus()
  - Created `ConsentController` for POST /api/v1/ingest/consent (project_key auth)
  - Created `ConsentRequest` form request
  - Modified `ProcessIngestBatch`: pre-computes consent map per user, checks consent per event type (Analytics/CrashReporting/Performance), rejects events without consent when environment.consent_required=true
  - 6 ConsentService tests + 2 ProcessIngestBatch consent tests

- **Phase 3: Data Deletion Workflow (Art. 17)**
  - Created `DeletionService`: requestDeletion() creates DataDeletionRequest (30-day SLA), dispatches job, audit-logged
  - Created `ProcessDataDeletion` job (queue: compliance, tries: 3, timeout: 300, backoff: [30,120,600]):
    - FullDelete: chunked deletion (1000 rows + 50ms sleep) of events, crashes, traces, sessions, then AppUser. Consent records preserved via nullOnDelete FK.
    - Pseudonymize: replaces anonymous_id with pseudonymized_{uuid}, nulls user_id/hash/properties
    - Generates deletion certificate JSON at compliance/certificates/{id}.json
  - Created `ComplianceController` with 5 endpoints: requestErasure (POST 202), erasureStatus (GET), requestExport (POST 202), exportStatus (GET), downloadExport (GET with signed URL)
  - Created `ErasureRequest` and `AccessRequestRequest` form requests
  - Added compliance API routes under /api/v1/projects/{project}/compliance/
  - 6 tests: full erasure, pseudonymization, consent preservation, certificate, SLA, non-existent user

- **Phase 4: Data Export Workflow (Art. 15, 20)**
  - Created `ExportService`: requestExport() creates DataExportJob, dispatches job, audit-logged
  - Created `ProcessDataExport` job (queue: compliance, tries: 3, timeout: 600):
    - Streams user data via cursor() (no OOM): profile, events, sessions, crashes, traces, consent history
    - Builds structured JSON with metadata (processing purposes, retention info, GDPR Art. 15/20 compliance)
    - Creates ZIP at compliance/exports/{id}.zip
  - Download via 48h signed temporary URL, audit-logged on download
  - 5 tests: job dispatch, ZIP creation, data completeness, audit logging, non-existent user

- **Phase 5: Retention Enforcement**
  - Created `EnforceRetention` artisan command (compliance:enforce-retention {--dry-run}):
    - Per environment: deletes raw data (events, crashes, traces, sessions) older than retention_days_raw, aggregates older than retention_days_agg
    - Never deletes consent_records
    - Chunked deletion (1000 rows + 100ms sleep)
    - --dry-run mode counts without deleting
    - Audit-logged per environment with row counts
  - Scheduled daily at 02:00 UTC with withoutOverlapping()
  - 5 tests: old data deleted, recent preserved, consent never deleted, dry-run mode, audit logging

- **Phase 6: PII Settings UI**
  - Created `PiiSettings` Livewire component: per-environment form for PII mode, IP truncation, user ID hashing, lawful basis, consent required toggle, allowlist/denylist editors
  - Created Blade view at livewire/compliance/pii-settings.blade.php
  - Save is audit-logged with PiiSettingsUpdated action
  - Route: /projects/{project}/compliance/pii
  - 3 tests: renders, saves settings + audit log, environment switching

- **Phase 7: Data Breach Foundation**
  - Created `data_breach_incidents` migration with team FK, severity, affected_users_count, affected_environments (jsonb), discovered/reported/resolved timestamps
  - Created `BreachSeverity` enum: Low, Medium, High, Critical
  - Created `DataBreachIncident` model with HasUuids, unresolved() scope, team/reporter relationships
  - Created `DataBreachIncidentFactory` with resolved() state
  - 4 tests: creation, relationships, scopes, JSON environments

- **Phase 8: Compliance Dashboard**
  - Created `ComplianceDashboard` Livewire component: stats cards (pending/overdue deletions, pending exports, active breaches), consent summary per type, recent audit logs table, retention policy display, quick action links
  - Created Blade view at livewire/compliance/compliance-dashboard.blade.php
  - Route: /projects/{project}/compliance
  - Added "Compliance" nav item (shield-check icon) to sidebar before Settings
  - 3 tests: renders, shows stats, retention policies

- **Phase 9: Final Integration**
  - Added consentRecords() relationship to Environment model
  - Ran Pint formatter on all modified files
  - Full test suite: 327 passed, 1 skipped, 0 failures

**New files created:** 3 migrations, 2 enums, 5 models, 4 services, 2 jobs, 1 command, 3 controllers, 3 form requests, 1 factory, 2 Livewire components, 2 Blade views, 1 trait, 8 test files (~41 new tests)

### 2026-02-23 (Compliance Refactoring — Contracts, Context, Resources, Caching)
- **Contracts (Task #11):** Created 4 interfaces in `app/Contracts/Compliance/`: AuditServiceContract, ConsentServiceContract, DeletionServiceContract, ExportServiceContract. All services now implement their contracts. Bindings registered in AppServiceProvider.
- **Controllers updated:** ComplianceController and ConsentController type-hint contracts instead of concrete services. ProcessIngestBatch job also uses ConsentServiceContract.
- **Events & Listeners (Task #12):** Already fully implemented in prior session — 9+ domain events, 11+ listeners, DomainEventSubscriber, model observers all present.
- **Context facade (Task #13):** Enhanced AddRequestContext middleware to propagate user_id, team_id, ip_address alongside trace_id. AuditService falls back to Context values when auth/request context unavailable (e.g., in queued jobs). Context dehydration shares keys with queued jobs.
- **API Resources (Task #14):** Created 5 resources: AuditLogResource, ConsentRecordResource, DataDeletionRequestResource, DataExportJobResource, DataBreachIncidentResource. ComplianceController now returns Resources instead of manual JSON.
- **Caching (Task #15):** ConsentService.hasConsent() cached for 120s with automatic invalidation on grant/revoke. ComplianceDashboard stats cached for 60s (wrapping Concurrency::run).
- 10 new tests in ComplianceRefactoringTest: contract resolution, context propagation, consent caching, resource serialization, API endpoints with contracts, dashboard caching.
- Full test suite: 434 passed, 1 skipped, 0 failures


- Redesigned entire application UI to match the Pulseboard reference design (React/Tailwind prototype)
- **Design system updates:**
  - Added JetBrains Mono web font alongside Inter
  - Labels use `text-[10px] font-mono uppercase tracking-wider` with underscore_names
  - Page headings use `font-light tracking-tight` (not bold)
  - Stat cards have gradient hover lines, `text-3xl font-light` values, colored trend badges
  - Primary color: indigo (#6366f1), dark palette (#050505, #0a0a0a, #111, #222, #444, #666)
  - Cards: `rounded-lg` + `dark:shadow-none`, no `rounded-xl`
- **CSS additions:** `.btn-danger`, `.mono-label`, `.panel-header` utility classes
- **Components updated:** stat-card, page-header (subtitle prop), data-table (sticky headers), empty-state, project-top-bar (green dot + mono selector), stack-trace-viewer, upgrade-cta, dark-mode-toggle
- **Livewire views updated:** project-dashboard (mono chart headers, indigo lines, JetBrains Mono ticks), event-explorer (search icon, mono filter tags, type badges), sessions-explorer (mono headings), crash-explorer (card-based groups, rose exception names), performance-explorer (mono headings), date-range-picker (button group), environment-switcher (mono + uppercase)
- **Project management views updated:** project-list (mono badges), project-create (mono labels, full-width buttons), project-settings (mono headings), project-key-manager (full rewrite with mono table), environment-settings (data governance layout with toggles)
- **Compliance views updated:** compliance-dashboard (underscore headings, bordered items), pii-settings (toggle layout, mono labels)
- Updated ComplianceDashboardTest assertions for underscore-separated heading text
- npm build: success; pint: pass; tests: 424 passed, 1 skipped, 0 failures

## Next Steps
1. Manual verification of onboarding wizard and dashboard enhancements
2. Consider additional dashboard widgets (funnels, retention charts)
