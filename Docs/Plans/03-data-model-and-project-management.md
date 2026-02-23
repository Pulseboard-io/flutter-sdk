# Plan 03: Data Model & Project Management

## Objective
Build the core multi-tenant data model: Projects, Environments, ProjectKeys, AppUsers, Devices, Sessions, Events, CrashReports, Traces. Create the project management UI and API.

## Current State
- Only Jetstream default models exist (User, Team, Membership, TeamInvitation)
- No analytics-specific database tables
- No project management UI or API

## Target State
- Full domain model hierarchy: Team -> Project -> Environment -> ProjectKey
- Telemetry entities: AppUser, Device, Session, Event, CrashReport, Trace
- Project CRUD UI (Livewire) within team context
- Environment management per project
- ProjectKey generation, rotation, and revocation
- Data governance knobs per environment (PII mode, retention settings)

## Implementation Steps

### 3.1 Core Domain Migrations (PostgreSQL, UUID PKs)

**`projects` table:**
- `id (uuid pk)`, `team_id (fk teams)`, `name`, `platform_primary (enum: flutter, react_native, other)`, `created_at`, `updated_at`
- Index: `(team_id, created_at)`

**`environments` table:**
- `id (uuid pk)`, `project_id (fk projects)`, `name (string: prod/staging/dev)`, `retention_days_raw (int, default 90)`, `retention_days_agg (int, default 395)`, `pii_mode (enum: strict/permissive)`, `ip_truncation (bool, default true)`, `user_id_hashing (enum: none/sha256/hmac)`, `created_at`, `updated_at`
- Unique index: `(project_id, name)`

**`project_keys` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `key_type (enum: write/read)`, `token (string, plain for display once)`, `token_hash (string)`, `label (string, nullable)`, `revoked_at (timestamp, nullable)`, `last_seen_at (timestamp, nullable)`, `created_at`, `updated_at`
- Index: `(environment_id, key_type)`, `(token_hash) unique`

**`app_users` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `anonymous_id (string)`, `user_id (string, nullable)`, `user_id_hash (string, nullable)`, `properties (jsonb, default {})`, `first_seen_at`, `last_seen_at`, `created_at`, `updated_at`
- Unique index: `(environment_id, anonymous_id)`
- Index: `(environment_id, user_id_hash)`

**`devices` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `device_id (string)`, `platform (string)`, `os_version (string, nullable)`, `model (string, nullable)`, `first_seen_at`, `last_seen_at`, `created_at`, `updated_at`
- Unique index: `(environment_id, device_id)`

**`sessions` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `session_key (string)`, `app_user_id (fk app_users)`, `device_id (fk devices)`, `started_at`, `ended_at (nullable)`, `duration_ms (int, nullable)`, `event_count (int, default 0)`, `created_at`, `updated_at`
- Index: `(environment_id, started_at desc)`, `(environment_id, app_user_id, started_at desc)`

**`events` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `event_id (uuid, from client)`, `type (enum: event/user_properties/crash/trace)`, `name (string, nullable)`, `timestamp`, `session_id (fk sessions, nullable)`, `app_user_id (fk app_users, nullable)`, `device_id (fk devices, nullable)`, `properties (jsonb, default {})`, `schema_version (string)`, `app_version (string, nullable)`, `build_number (string, nullable)`, `created_at`
- Indexes:
  - `(environment_id, timestamp desc)`
  - `(environment_id, name, timestamp desc)`
  - `(environment_id, app_user_id, timestamp desc)`
  - GIN `(properties)` for ad-hoc property filters

**`crash_reports` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `event_id (uuid)`, `fingerprint (string)`, `fatal (bool)`, `exception_type (string)`, `message (text)`, `stacktrace (text)`, `breadcrumbs (jsonb)`, `app_version (string)`, `build_number (string, nullable)`, `app_user_id (fk, nullable)`, `device_id (fk, nullable)`, `session_id (fk, nullable)`, `timestamp`, `created_at`
- Index: `(environment_id, fingerprint, timestamp desc)`, `(environment_id, timestamp desc)`

**`traces` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `trace_id (string)`, `name (string)`, `duration_ms (int)`, `timestamp`, `attributes (jsonb)`, `app_version (string)`, `build_number (string, nullable)`, `app_user_id (fk, nullable)`, `device_id (fk, nullable)`, `session_id (fk, nullable)`, `created_at`
- Index: `(environment_id, name, timestamp desc)`, `(environment_id, duration_ms desc)`

**`billing_subscriptions` table (placeholder):**
- `id (uuid pk)`, `team_id (fk teams)`, `plan (enum: free/trial/pro/enterprise)`, `status (enum: active/trialing/canceled/expired)`, `trial_ends_at (nullable)`, `current_period_start`, `current_period_end`, `created_at`, `updated_at`

**`data_export_jobs` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `requested_by (fk users)`, `type (enum: user_export/full_export)`, `target_user_id (string, nullable)`, `status (enum: pending/processing/completed/failed)`, `file_path (string, nullable)`, `completed_at (nullable)`, `created_at`, `updated_at`

**`data_deletion_requests` table:**
- `id (uuid pk)`, `environment_id (fk environments)`, `requested_by (fk users)`, `target_user_id (string)`, `scope (enum: full_delete/pseudonymize)`, `status (enum: pending/processing/completed/failed)`, `completed_at (nullable)`, `created_at`, `updated_at`

### 3.2 Eloquent Models with Relationships
- Create all models with proper relationships, casts, factories, and policies
- Use `HasUuids` trait on all models
- Implement `Team->projects()`, `Project->environments()`, `Environment->projectKeys()`, etc.
- Create Enums: `Platform`, `KeyType`, `PiiMode`, `UserIdHashing`, `EventType`, `ExportType`, `DeletionScope`, `PlanType`, `SubscriptionStatus`

### 3.3 Project Management API (Sanctum/Passport protected)
- `ProjectController`: index, store, show, update, destroy
- `EnvironmentController`: index, store, show, update, destroy (nested under project)
- `ProjectKeyController`: index, store, show (reveal once with full DSN), revoke (nested under environment)
  - When a key is created, the response includes the full DSN: `https://<token>@<app-host>/<project-id>/<environment-name>`
  - The DSN is displayed once to the user and cannot be retrieved again (the plain token is not stored)
- Form Requests for all endpoints
- Eloquent API Resources for all responses
- Policy authorization (team members only)

### 3.4 Project Management UI (Livewire)
- Project list page within team context
- Create/edit project form (name, platform)
- Project detail page with environment tabs
- Environment settings (retention, PII mode, hashing)
- ProjectKey management (generate, copy DSN, revoke)
  - When generating a key, show the full DSN string: `https://<key>@<host>/<project-id>/<environment>`
  - Provide a "Copy DSN" button for easy clipboard copy
- Project onboarding wizard (triggered after team creation)

## Dependencies
- Plan 01 (Platform Foundation) - PostgreSQL + Redis must be configured

## Testing Requirements
- Unit tests for all model relationships
- Unit tests for all enums
- Feature tests for Project CRUD (create, read, update, delete with authorization)
- Feature tests for Environment CRUD
- Feature tests for ProjectKey generation, display-once, and revocation
- Factory-based seeding for all new models

## Estimated Effort
4-6 person-weeks

## Files to Create
- 12+ migration files
- 12+ model files in `app/Models/`
- 8+ enum files in `app/Enums/`
- 3+ controller files in `app/Http/Controllers/`
- 6+ Form Request files in `app/Http/Requests/`
- 6+ API Resource files in `app/Http/Resources/`
- 3+ Policy files in `app/Policies/`
- 12+ Factory files in `database/factories/`
- Livewire components for project management UI
- Blade views for project pages
- 20+ test files
