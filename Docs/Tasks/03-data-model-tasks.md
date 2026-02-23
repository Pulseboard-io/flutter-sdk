# Tasks: Plan 03 - Data Model & Project Management

## References
- Plan: [03-data-model-and-project-management.md](../Plans/03-data-model-and-project-management.md)
- PRD: [PRD.md](../PRD.md) (lines 51-54, 293-358)

---

## Task 3.1: Create Enums
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Plan 01

### Steps
1. Create PHP enums in `app/Enums/`:
   - `Platform`: Flutter, ReactNative, Other
   - `KeyType`: Write, Read
   - `PiiMode`: Strict, Permissive
   - `UserIdHashing`: None, Sha256, Hmac
   - `EventType`: Event, UserProperties, Crash, Trace
   - `BatchStatus`: Received, Processing, Processed, Failed
   - `ExportType`: UserExport, FullExport
   - `DeletionScope`: FullDelete, Pseudonymize
   - `PlanType`: Free, Trial, Pro, Enterprise
   - `SubscriptionStatus`: Active, Trialing, Canceled, Expired
   - `LawfulBasis`: LegitimateInterest, Consent
   - `ConsentType`: Analytics, CrashReporting, Performance
2. Use string-backed enums for database storage
3. Follow TitleCase convention per CLAUDE.md guidelines

### Acceptance Criteria
- [ ] All enums created with correct values
- [ ] String-backed for database compatibility
- [ ] TitleCase naming convention followed

---

## Task 3.2: Create Projects Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 3.1

### Steps
1. Use `php artisan make:model Project -mf --no-interaction` to create model, migration, factory
2. Migration: `projects` table with `id (uuid pk)`, `team_id (fk teams)`, `name (string)`, `platform_primary (string, enum)`, `created_at`, `updated_at`
3. Add indexes: `(team_id, created_at)`
4. Model: `HasUuids` trait, `team()` BelongsTo, `environments()` HasMany
5. Cast `platform_primary` to `Platform` enum via `casts()` method
6. Factory: generate realistic project data
7. Create `ProjectPolicy` for authorization (team-scoped)

### Acceptance Criteria
- [ ] Migration runs against PostgreSQL
- [ ] Model with proper relationships and casts
- [ ] Factory generates valid data
- [ ] Policy restricts access to team members

---

## Task 3.3: Create Environments Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 3.2

### Steps
1. Create migration for `environments` table:
   - `id (uuid pk)`, `project_id (fk projects, cascade)`, `name (string)`, `retention_days_raw (int, default 90)`, `retention_days_agg (int, default 395)`, `pii_mode (string, default 'strict')`, `ip_truncation (bool, default true)`, `user_id_hashing (string, default 'sha256')`, `lawful_basis (string, default 'legitimate_interest')`, `consent_required (bool, default false)`, `data_region (string, default 'eu')`, `created_at`, `updated_at`
   - Unique index: `(project_id, name)`
2. Model: relationships, enum casts, `HasUuids`
3. Factory
4. Note: privacy-by-default values (strict PII, IP truncation ON, hashing ON, EU region)

### Acceptance Criteria
- [ ] Migration with privacy-by-default values
- [ ] Model with enum casts
- [ ] Factory generates valid environment data
- [ ] Default values enforce EU privacy standards

---

## Task 3.4: Create ProjectKeys Migration & Model
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Task 3.3

### Steps
1. Create migration for `project_keys` table:
   - `id (uuid pk)`, `environment_id (fk environments, cascade)`, `key_type (string)`, `token_prefix (string, 8 chars)`, `token_hash (string, unique)`, `label (string, nullable)`, `revoked_at (timestamp, nullable)`, `last_seen_at (timestamp, nullable)`, `created_at`, `updated_at`
2. Model with:
   - `environment()` BelongsTo
   - `HasUuids` trait
   - Static `generate(Environment $env, KeyType $type)` method that returns the plain token (only time it's visible)
   - `isRevoked()` helper
   - `markSeen()` helper (update last_seen_at)
3. Token generation: use `Str::random(48)` with prefix (`wk_` for write, `rk_` for read)
4. Store hash of token (SHA-256), never store plain text
5. DSN generation: when a key is created, also build and return the full DSN string
   - Format: `https://<plain_token>@<app_host>/<project_id>/<environment_name>`
   - Example: `https://wk_abc123...@pulseboard.example.com/proj_uuid/production`
   - The DSN is returned once at creation time alongside the plain token
6. Factory

### Acceptance Criteria
- [ ] Token generation creates prefixed, random tokens
- [ ] Only hash stored in database
- [ ] Plain token returned only at creation time
- [ ] Full DSN string returned at creation time (format: `https://<token>@<host>/<project-id>/<environment>`)
- [ ] Revocation works correctly
- [ ] Factory creates valid keys

---

## Task 3.5: Create AppUsers Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 3.3

### Steps
1. Create migration for `app_users` table per schema spec
2. Model with relationships, `HasUuids`, jsonb cast for `properties`
3. Factory
4. Methods: `applyPropertyOperation($op, $key, $value)` for set/set_once/increment/unset

### Acceptance Criteria
- [ ] Migration with unique constraints
- [ ] Property operations work correctly
- [ ] Factory generates valid data

---

## Task 3.6: Create Devices Migration & Model
**Priority:** Critical | **Estimate:** 1 hour | **Blocked by:** Task 3.3

### Steps
1. Create migration for `devices` table per schema spec
2. Model with relationships, `HasUuids`
3. Factory

### Acceptance Criteria
- [ ] Migration with unique constraint on `(environment_id, device_id)`
- [ ] Model with proper relationships

---

## Task 3.7: Create Sessions Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Tasks 3.5, 3.6

### Steps
1. Create migration for `sessions` table per schema spec (name it `analytics_sessions` to avoid conflict with Laravel's `sessions` table)
2. Model with relationships to AppUser, Device, Environment
3. Factory
4. Scopes for active sessions, completed sessions

### Acceptance Criteria
- [ ] Table named `analytics_sessions` to avoid conflict
- [ ] Indexes for efficient querying
- [ ] Factory generates valid session data

---

## Task 3.8: Create Events Migration & Model
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Tasks 3.5, 3.6, 3.7

### Steps
1. Create migration for `events` table per schema spec
2. Add GIN index on `properties` jsonb column
3. Model with relationships, `HasUuids`, enum casts
4. Factory with states for each event type
5. Scopes: `byName()`, `inDateRange()`, `forUser()`, `forSession()`

### Acceptance Criteria
- [ ] GIN index on properties for ad-hoc filtering
- [ ] All required indexes created
- [ ] Factory with event type states
- [ ] Query scopes for common filters

---

## Task 3.9: Create CrashReports Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 3.3

### Steps
1. Create migration for `crash_reports` table per schema spec
2. Model with relationships, jsonb cast for breadcrumbs
3. Factory
4. Scopes: `byFingerprint()`, `fatal()`, `inDateRange()`

### Acceptance Criteria
- [ ] Migration with proper indexes
- [ ] Breadcrumbs cast as jsonb
- [ ] Factory generates realistic crash data

---

## Task 3.10: Create Traces Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 3.3

### Steps
1. Create migration for `traces` table per schema spec
2. Model with relationships, jsonb cast for attributes
3. Factory
4. Scopes: `byName()`, `inDateRange()`

### Acceptance Criteria
- [ ] Migration with proper indexes
- [ ] Factory generates realistic trace data

---

## Task 3.11: Create Billing Placeholder Models
**Priority:** Low | **Estimate:** 1-2 hours | **Blocked by:** Task 3.1

### Steps
1. Create migration for `plans` table (seeded, not user-created)
2. Create migration for `billing_subscriptions` table
3. Create `Plan` and `BillingSubscription` models
4. Create seeder for default plans (Free/Trial/Pro/Enterprise)
5. Add `subscription()` relationship to `Team` model

### Acceptance Criteria
- [ ] Plans seeded with 4 tiers
- [ ] Team has subscription relationship
- [ ] Subscription defaults to Free plan

---

## Task 3.12: Create Compliance Tables
**Priority:** High | **Estimate:** 1-2 hours | **Blocked by:** Task 3.3

### Steps
1. Create migration for `data_export_jobs` table
2. Create migration for `data_deletion_requests` table
3. Create `DataExportJob` and `DataDeletionRequest` models
4. Factories for both

### Acceptance Criteria
- [ ] Migrations run successfully
- [ ] Models with proper relationships and enum casts

---

## Task 3.13: Project Management API Controllers
**Priority:** High | **Estimate:** 4-6 hours | **Blocked by:** Tasks 3.2-3.4

### Steps
1. Create `ProjectController` (API, Sanctum-protected):
   - `index()` - list team's projects
   - `store()` - create project (auto-creates prod/staging/dev environments)
   - `show()` - project detail with environments
   - `update()` - update project name/platform
   - `destroy()` - soft delete project
2. Create `EnvironmentController` (nested under project):
   - `index()`, `show()`, `update()` (name is immutable, settings are editable)
3. Create `ProjectKeyController` (nested under environment):
   - `index()`, `store()` (returns plain token once), `destroy()` (revoke)
4. Create Form Requests: `StoreProjectRequest`, `UpdateProjectRequest`, `UpdateEnvironmentRequest`, `StoreProjectKeyRequest`
5. Create API Resources: `ProjectResource`, `EnvironmentResource`, `ProjectKeyResource`
6. Register routes in `routes/api.php`

### Acceptance Criteria
- [ ] Full CRUD for projects with authorization
- [ ] Environment settings management
- [ ] Key generation with display-once semantics (returns plain token + full DSN)
- [ ] DSN format: `https://<token>@<host>/<project-id>/<environment>`
- [ ] Key revocation
- [ ] API Resources for consistent JSON responses
- [ ] Form Request validation on all endpoints

---

## Task 3.14: Project Management UI (Livewire)
**Priority:** High | **Estimate:** 6-8 hours | **Blocked by:** Tasks 3.2-3.4, Plan 01 (design system)

### Steps
1. Create Livewire page: `ProjectList` - team's projects grid/list
2. Create Livewire page: `ProjectCreate` - create project form with platform selection
3. Create Livewire page: `ProjectSettings` - project settings with environment tabs
4. Create Livewire component: `EnvironmentSettings` - retention, PII, hashing config
5. Create Livewire component: `ProjectKeyManager` - generate, copy, revoke keys
6. Add project navigation to sidebar
7. Wire up routes in `routes/web.php`

### Acceptance Criteria
- [ ] Project list displays all team projects
- [ ] Create project form works with auto-environment creation
- [ ] Environment settings editable per environment
- [ ] Project keys can be generated (with full DSN displayed), copied (DSN to clipboard), and revoked
- [ ] All pages use custom design system
- [ ] Dark mode compatible

---

## Task 3.15: Write Data Model Tests
**Priority:** Critical | **Estimate:** 4-6 hours | **Blocked by:** Tasks 3.2-3.14

### Steps
1. Unit tests for all model relationships
2. Unit tests for all enum values and casting
3. Unit tests for ProjectKey generation and hashing
4. Unit tests for AppUser property operations
5. Feature tests for Project CRUD API
6. Feature tests for Environment API
7. Feature tests for ProjectKey API (create, display-once, revoke)
8. Feature tests for authorization (team-scoped access)
9. Livewire component tests
10. Run full test suite

### Acceptance Criteria
- [ ] All relationship tests pass
- [ ] All CRUD operation tests pass
- [ ] Authorization tests verify team-scoped access
- [ ] Zero test failures in full suite
