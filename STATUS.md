# Project Status: Pulseboard Platform

## Last Updated
2026-02-23

## Current Phase
**Phase 5: Flutter SDK Complete** - Full Flutter analytics SDK implemented with DSN parsing, event tracking, crash reporting, performance tracing, session management, and offline support.

## Overall Progress

| Epic | Status | Progress |
|------|--------|----------|
| 01 - Platform Foundation | Complete | 100% |
| 02 - Auth & Org Model | Complete | 100% |
| 03 - Data Model & Project Mgmt | Complete | 100% |
| 04 - Ingestion API & Processing | Complete | 100% |
| 05 - Flutter SDK | Complete | 100% |
| 06 - Analytics Dashboards | Not Started | 0% |
| 07 - Compliance & Governance | Not Started | 0% |
| 08 - Billing Placeholder | Not Started | 0% |
| 09 - Quality & CI/CD | Not Started | 0% |

## Recent Changes

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

## Next Steps
1. Begin Plan 06: Analytics Dashboards
2. Then Plan 07: Compliance & Governance
