# Sub-Tasks: Plan 03 - Data Model & Project Management

---

## Task 3.1: Create Enums

### Sub-task 3.1.1: Create Platform enum
- Create `app/Enums/Platform.php`
- Values: `Flutter = 'flutter'`, `ReactNative = 'react_native'`, `Other = 'other'`
- String-backed, TitleCase keys

### Sub-task 3.1.2: Create KeyType enum
- Create `app/Enums/KeyType.php`
- Values: `Write = 'write'`, `Read = 'read'`

### Sub-task 3.1.3: Create PiiMode enum
- Create `app/Enums/PiiMode.php`
- Values: `Strict = 'strict'`, `Permissive = 'permissive'`

### Sub-task 3.1.4: Create UserIdHashing enum
- Create `app/Enums/UserIdHashing.php`
- Values: `None = 'none'`, `Sha256 = 'sha256'`, `Hmac = 'hmac'`

### Sub-task 3.1.5: Create EventType enum
- Create `app/Enums/EventType.php`
- Values: `Event = 'event'`, `UserProperties = 'user_properties'`, `Crash = 'crash'`, `Trace = 'trace'`

### Sub-task 3.1.6: Create BatchStatus enum
- Create `app/Enums/BatchStatus.php`
- Values: `Received = 'received'`, `Processing = 'processing'`, `Processed = 'processed'`, `Failed = 'failed'`

### Sub-task 3.1.7: Create ExportType enum
- Create `app/Enums/ExportType.php`
- Values: `UserExport = 'user_export'`, `FullExport = 'full_export'`

### Sub-task 3.1.8: Create DeletionScope enum
- Create `app/Enums/DeletionScope.php`
- Values: `FullDelete = 'full_delete'`, `Pseudonymize = 'pseudonymize'`

### Sub-task 3.1.9: Create PlanType enum
- Create `app/Enums/PlanType.php`
- Values: `Free = 'free'`, `Trial = 'trial'`, `Pro = 'pro'`, `Enterprise = 'enterprise'`

### Sub-task 3.1.10: Create SubscriptionStatus enum
- Create `app/Enums/SubscriptionStatus.php`
- Values: `Active = 'active'`, `Trialing = 'trialing'`, `Canceled = 'canceled'`, `Expired = 'expired'`

### Sub-task 3.1.11: Create LawfulBasis enum
- Create `app/Enums/LawfulBasis.php`
- Values: `LegitimateInterest = 'legitimate_interest'`, `Consent = 'consent'`

### Sub-task 3.1.12: Create ConsentType enum
- Create `app/Enums/ConsentType.php`
- Values: `Analytics = 'analytics'`, `CrashReporting = 'crash_reporting'`, `Performance = 'performance'`

### Sub-task 3.1.13: Create DsarStatus enum
- Create `app/Enums/DsarStatus.php`
- Values: `Pending = 'pending'`, `Processing = 'processing'`, `Completed = 'completed'`, `Failed = 'failed'`

### Sub-task 3.1.14: Create DataRegion enum
- Create `app/Enums/DataRegion.php`
- Values: `Eu = 'eu'`, `Us = 'us'`, `Auto = 'auto'`

### Sub-task 3.1.15: Write enum unit tests
- Create `tests/Unit/Enums/EnumTest.php`
- Test each enum has expected cases
- Test `value` property returns correct string
- Test `from()` and `tryFrom()` work correctly

---

## Task 3.2: Create Projects Migration & Model

### Sub-task 3.2.1: Generate model, migration, and factory
- Run `php artisan make:model Project -mf --no-interaction`

### Sub-task 3.2.2: Define projects migration
- Open generated migration
- Replace `up()`:
  ```php
  Schema::create('projects', function (Blueprint $table) {
      $table->uuid('id')->primary();
      $table->foreignId('team_id')->constrained()->cascadeOnDelete();
      $table->string('name');
      $table->string('platform_primary')->default('flutter');
      $table->softDeletes();
      $table->timestamps();
      $table->index(['team_id', 'created_at']);
  });
  ```

### Sub-task 3.2.3: Define Project model
- Add `HasUuids`, `SoftDeletes` traits
- Set `$fillable`: `['team_id', 'name', 'platform_primary']`
- Add `casts()`:
  ```php
  protected function casts(): array
  {
      return ['platform_primary' => Platform::class];
  }
  ```
- Add relationships:
  - `team(): BelongsTo` → `Team::class`
  - `environments(): HasMany` → `Environment::class`
  - `projectKeys()`: HasManyThrough via environments

### Sub-task 3.2.4: Add projects() relationship to Team model
- Open `app/Models/Team.php`
- Add: `public function projects(): HasMany { return $this->hasMany(Project::class); }`

### Sub-task 3.2.5: Define ProjectFactory
- Open generated factory
- Define:
  ```php
  'team_id' => Team::factory(),
  'name' => fake()->words(3, true) . ' App',
  'platform_primary' => Platform::Flutter,
  ```

### Sub-task 3.2.6: Create ProjectPolicy
- Run `php artisan make:policy ProjectPolicy --model=Project --no-interaction`
- Implement methods:
  - `viewAny(User $user)`: user belongs to current team
  - `view(User $user, Project $project)`: user belongs to project's team
  - `create(User $user)`: user belongs to current team
  - `update(User $user, Project $project)`: user is owner/admin of project's team
  - `delete(User $user, Project $project)`: user is owner of project's team
- Register policy in `AuthServiceProvider` or auto-discover

### Sub-task 3.2.7: Run migration and verify
- Run `php artisan migrate --no-interaction`
- Verify table: `Schema::hasTable('projects')`
- Test factory: `Project::factory()->create()`

---

## Task 3.3: Create Environments Migration & Model

### Sub-task 3.3.1: Generate model, migration, factory
- Run `php artisan make:model Environment -mf --no-interaction`

### Sub-task 3.3.2: Define environments migration
- EU privacy-by-default values:
  ```php
  Schema::create('environments', function (Blueprint $table) {
      $table->uuid('id')->primary();
      $table->foreignUuid('project_id')->constrained()->cascadeOnDelete();
      $table->string('name', 32); // prod, staging, dev
      $table->integer('retention_days_raw')->default(90);
      $table->integer('retention_days_agg')->default(395);
      $table->string('pii_mode', 16)->default('strict');
      $table->boolean('ip_truncation')->default(true);
      $table->string('user_id_hashing', 16)->default('sha256');
      $table->string('lawful_basis', 32)->default('legitimate_interest');
      $table->boolean('consent_required')->default(false);
      $table->string('data_region', 8)->default('eu');
      $table->json('pii_allowlist')->nullable(); // JSON array of allowed property keys
      $table->json('pii_denylist')->nullable(); // JSON array of denied property keys
      $table->timestamps();
      $table->unique(['project_id', 'name']);
  });
  ```

### Sub-task 3.3.3: Define Environment model
- Traits: `HasUuids`
- Fillable: all settings columns
- Casts: PiiMode, UserIdHashing, LawfulBasis, DataRegion enums; `pii_allowlist` and `pii_denylist` as `array`
- Relationships: `project(): BelongsTo`, `projectKeys(): HasMany`, `appUsers(): HasMany`, `devices(): HasMany`, `sessions(): HasMany`, `events(): HasMany`

### Sub-task 3.3.4: Define EnvironmentFactory
- Generate environments named `prod`, `staging`, `dev`
- Use EU-strict defaults

### Sub-task 3.3.5: Create auto-create environments logic
- In `ProjectObserver` or Project model `booted()`:
- When a project is created, auto-create three environments: `prod`, `staging`, `dev`
- Each with default privacy settings

### Sub-task 3.3.6: Run migration and verify
- Verify unique constraint works: creating two `prod` environments for same project fails
- Verify defaults: new environment has `pii_mode=strict`, `ip_truncation=true`, `data_region=eu`

---

## Task 3.4: Create ProjectKeys Migration & Model

### Sub-task 3.4.1: Generate model, migration, factory
- Run `php artisan make:model ProjectKey -mf --no-interaction`

### Sub-task 3.4.2: Define project_keys migration
- Columns: `uuid('id')->primary()`, `foreignUuid('environment_id')->constrained()->cascadeOnDelete()`, `string('key_type', 8)`, `string('token_prefix', 12)`, `string('token_hash', 64)->unique()`, `string('label')->nullable()`, `timestamp('revoked_at')->nullable()`, `timestamp('last_seen_at')->nullable()`, `timestamps()`
- Index: `['environment_id', 'key_type']`

### Sub-task 3.4.3: Define ProjectKey model
- Traits: `HasUuids`
- Fillable: `['environment_id', 'key_type', 'token_prefix', 'token_hash', 'label', 'revoked_at', 'last_seen_at']`
- Casts: `key_type` → KeyType enum, `revoked_at` → datetime, `last_seen_at` → datetime
- Hidden: `['token_hash']` (never expose in API responses)

### Sub-task 3.4.4: Implement static generate() method
- Signature: `public static function generate(Environment $environment, KeyType $type, ?string $label = null): array`
- Logic:
  1. Generate prefix: `$type === KeyType::Write ? 'wk_' : 'rk_'`
  2. Generate token: `$prefix . Str::random(48)`
  3. Hash token: `hash('sha256', $plainToken)`
  4. Create model: `static::create([...])`
  5. Build DSN string: `https://{$plainToken}@{config('app.dsn_host')}/{$environment->project_id}/{$environment->name}`
     - `config('app.dsn_host')` should be the public-facing API hostname (e.g., `pulseboard.example.com`)
  6. Return `['key' => $model, 'plain_token' => $plainToken, 'dsn' => $dsn]`
- Plain token and DSN are only available at creation time

### Sub-task 3.4.5: Implement helper methods
- `isRevoked(): bool` → `return $this->revoked_at !== null;`
- `revoke(): void` → `$this->update(['revoked_at' => now()]);`
- `markSeen(): void` → `$this->update(['last_seen_at' => now()]);`
- `isWriteKey(): bool` → `return $this->key_type === KeyType::Write;`
- Scope: `scopeActive($query)` → `$query->whereNull('revoked_at')`

### Sub-task 3.4.6: Implement static findByToken() method
- Signature: `public static function findByToken(string $plainToken): ?static`
- Hash the token and look up by `token_hash`
- Return null if not found

### Sub-task 3.4.7: Define ProjectKeyFactory
- Generate valid token hashes
- State methods: `write()`, `read()`, `revoked()`

### Sub-task 3.4.8: Write unit tests for token generation
- Test: `generate()` returns plain token, model, and DSN string
- Test: plain token starts with correct prefix (`wk_` or `rk_`)
- Test: DSN format is `https://<token>@<host>/<project-id>/<environment>`
- Test: DSN contains the correct project ID and environment name
- Test: `findByToken()` finds key by plain token
- Test: `findByToken()` returns null for invalid token
- Test: hash stored in DB, never the plain token
- Test: `isRevoked()` returns correct boolean
- Test: `revoke()` sets `revoked_at`

---

## Task 3.5: Create AppUsers Migration & Model

### Sub-task 3.5.1: Generate model, migration, factory
- Run `php artisan make:model AppUser -mf --no-interaction`

### Sub-task 3.5.2: Define app_users migration
- `uuid('id')->primary()`, `foreignUuid('environment_id')->constrained()->cascadeOnDelete()`, `string('anonymous_id')`, `string('user_id')->nullable()`, `string('user_id_hash')->nullable()`, `jsonb('properties')->default('{}')`, `timestamp('first_seen_at')->nullable()`, `timestamp('last_seen_at')->nullable()`, `timestamps()`
- Unique: `['environment_id', 'anonymous_id']`
- Index: `['environment_id', 'user_id_hash']`

### Sub-task 3.5.3: Define AppUser model
- Traits: `HasUuids`
- Casts: `properties` → `array`, timestamps
- Relationships: `environment()`, `sessions()`, `events()`, `crashReports()`, `traces()`

### Sub-task 3.5.4: Implement applyPropertyOperation() method
- Signature: `public function applyPropertyOperation(string $op, string $key, mixed $value = null): void`
- Logic:
  - `set`: `$props[$key] = $value`
  - `set_once`: `$props[$key] = $props[$key] ?? $value` (only if not already set)
  - `increment`: `$props[$key] = ($props[$key] ?? 0) + $value`
  - `unset`: `unset($props[$key])`
- Save: `$this->update(['properties' => $props])`

### Sub-task 3.5.5: Write tests for property operations
- Test each operation: set, set_once, increment, unset
- Test set_once doesn't overwrite existing value
- Test increment on non-existing key starts from 0
- Test unset removes key entirely

---

## Task 3.6: Create Devices Migration & Model

### Sub-task 3.6.1: Generate model, migration, factory
- Run `php artisan make:model Device -mf --no-interaction`

### Sub-task 3.6.2: Define devices migration
- `uuid('id')->primary()`, `foreignUuid('environment_id')->constrained()->cascadeOnDelete()`, `string('device_id')`, `string('platform', 16)`, `string('os_version', 32)->nullable()`, `string('model', 64)->nullable()`, `timestamp('first_seen_at')->nullable()`, `timestamp('last_seen_at')->nullable()`, `timestamps()`
- Unique: `['environment_id', 'device_id']`

### Sub-task 3.6.3: Define Device model
- Traits: `HasUuids`
- Relationships: `environment()`, `sessions()`, `events()`

### Sub-task 3.6.4: Define DeviceFactory
- Generate realistic device data: android/ios platform, version strings, model names

---

## Task 3.7: Create Sessions Migration & Model

### Sub-task 3.7.1: Generate model, migration, factory
- Run `php artisan make:model AnalyticsSession -mf --no-interaction`
- Note: use `AnalyticsSession` to avoid conflict with Laravel's `Session`

### Sub-task 3.7.2: Define analytics_sessions migration
- `uuid('id')->primary()`, `foreignUuid('environment_id')->constrained()->cascadeOnDelete()`, `string('session_key')`, `foreignUuid('app_user_id')->nullable()->constrained('app_users')->nullOnDelete()`, `foreignUuid('device_id')->nullable()->constrained()->nullOnDelete()`, `timestamp('started_at')`, `timestamp('ended_at')->nullable()`, `integer('duration_ms')->nullable()`, `integer('event_count')->default(0)`, `timestamps()`
- Index: `['environment_id', 'started_at desc']`, `['environment_id', 'app_user_id', 'started_at desc']`
- Index: `['environment_id', 'session_key']`

### Sub-task 3.7.3: Define AnalyticsSession model
- Table name: `protected $table = 'analytics_sessions';`
- Traits: `HasUuids`
- Relationships: `environment()`, `appUser()`, `device()`, `events()`
- Scopes: `scopeActive($query)` (ended_at is null), `scopeCompleted($query)` (ended_at not null)

### Sub-task 3.7.4: Define factory
- Generate realistic session data with start/end times, durations

---

## Task 3.8: Create Events Migration & Model

### Sub-task 3.8.1: Generate model, migration, factory
- Run `php artisan make:model Event -mf --no-interaction`

### Sub-task 3.8.2: Define events migration
- All columns per PRD spec
- Add GIN index: `$table->index('properties', null, 'gin')` (PostgreSQL-specific via raw)
  ```php
  // After Schema::create, add GIN index:
  DB::statement('CREATE INDEX events_properties_gin ON events USING GIN (properties)');
  ```
- Standard indexes: `['environment_id', 'timestamp desc']`, `['environment_id', 'name', 'timestamp desc']`, `['environment_id', 'app_user_id', 'timestamp desc']`
- Unique: `['environment_id', 'event_id']` (for deduplication)

### Sub-task 3.8.3: Define Event model
- Traits: `HasUuids`
- Casts: `type` → EventType, `properties` → `array`, `timestamp` → `datetime`
- Relationships: `environment()`, `appUser()`, `device()`, `session()` (to AnalyticsSession)
- Scopes:
  - `scopeByName($query, string $name)` → `$query->where('name', $name)`
  - `scopeInDateRange($query, Carbon $from, Carbon $to)` → `$query->whereBetween('timestamp', [$from, $to])`
  - `scopeForUser($query, string $appUserId)` → `$query->where('app_user_id', $appUserId)`
  - `scopeForSession($query, string $sessionId)` → `$query->where('session_id', $sessionId)`

### Sub-task 3.8.4: Define EventFactory with states
- Base definition with event type
- States: `event()`, `userProperties()`, `crash()`, `trace()` — each sets appropriate `type` and `name`

### Sub-task 3.8.5: Write tests for scopes
- Test `byName()` filters correctly
- Test `inDateRange()` filters correctly
- Test `forUser()` filters correctly
- Test chained scopes work together

---

## Task 3.9: Create CrashReports Migration & Model

### Sub-task 3.9.1: Generate model, migration, factory
- Run `php artisan make:model CrashReport -mf --no-interaction`

### Sub-task 3.9.2: Define crash_reports migration
- All columns per PRD
- Indexes: `['environment_id', 'fingerprint', 'timestamp desc']`, `['environment_id', 'timestamp desc']`

### Sub-task 3.9.3: Define CrashReport model
- Casts: `breadcrumbs` → `array`, `fatal` → `boolean`
- Scopes: `byFingerprint()`, `fatal()`, `inDateRange()`
- Relationships: `environment()`, `appUser()`, `device()`, `session()`

### Sub-task 3.9.4: Define CrashReportFactory
- Generate realistic crash data with stack traces, exception types, breadcrumbs

---

## Task 3.10: Create Traces Migration & Model

### Sub-task 3.10.1: Generate model, migration, factory
- Run `php artisan make:model Trace -mf --no-interaction`

### Sub-task 3.10.2: Define traces migration
- All columns per PRD
- Indexes: `['environment_id', 'name', 'timestamp desc']`, `['environment_id', 'duration_ms desc']`

### Sub-task 3.10.3: Define Trace model
- Casts: `attributes` → `array`
- Scopes: `byName()`, `inDateRange()`
- Relationships: `environment()`, `appUser()`, `device()`, `session()`

### Sub-task 3.10.4: Define TraceFactory
- Generate realistic trace names (cold_start, api_call, etc.) with durations

---

## Task 3.11: Create Billing Placeholder Models

### Sub-task 3.11.1: Create plans migration
- `id (uuid pk)`, `name`, `slug (unique)`, `description`, `event_limit (int)`, `retention_days (int)`, `team_member_limit (int)`, `project_limit (int)`, `price_monthly_cents (int, nullable)`, `price_yearly_cents (int, nullable)`, `is_active (bool, default true)`, `sort_order (int)`, `timestamps()`

### Sub-task 3.11.2: Create Plan model
- Traits: `HasUuids`
- Method: `isUnlimited(string $resource): bool` — check if limit is -1 (unlimited)

### Sub-task 3.11.3: Create PlanSeeder
- Seed 4 plans:
  - Free: 10k events, 7d retention, 2 members, 1 project, $0
  - Trial: 100k events, 30d retention, 5 members, 3 projects, $0 (14-day trial)
  - Pro: 1M events, 90d retention, 20 members, 10 projects, $49/mo
  - Enterprise: -1 (unlimited) events, 365d retention, -1 members, -1 projects, custom pricing

### Sub-task 3.11.4: Create billing_subscriptions migration
- `uuid('id')->primary()`, `foreignId('team_id')->constrained()->cascadeOnDelete()`, `foreignUuid('plan_id')->constrained()`, `string('status')->default('active')`, `timestamp('trial_ends_at')->nullable()`, `timestamp('current_period_start')`, `timestamp('current_period_end')`, `timestamps()`

### Sub-task 3.11.5: Create BillingSubscription model
- Casts: `status` → SubscriptionStatus, plan_id → relation
- Relationships: `team()`, `plan()`
- Methods: `isTrialing()`, `isActive()`, `isExpired()`

### Sub-task 3.11.6: Add subscription relationship to Team
- `public function subscription(): HasOne { return $this->hasOne(BillingSubscription::class); }`
- `public function plan(): HasOneThrough` or accessor via subscription

---

## Task 3.12: Create Compliance Tables

### Sub-task 3.12.1: Create data_export_jobs migration
- All columns per Plan 07 spec
- Status enum cast

### Sub-task 3.12.2: Create data_deletion_requests migration
- All columns per Plan 07 spec
- Include `sla_deadline_at` timestamp for 30-day GDPR tracking
- Include `deletion_certificate_path` string nullable

### Sub-task 3.12.3: Create DataExportJob model
- Relationships, enum casts, HasUuids

### Sub-task 3.12.4: Create DataDeletionRequest model
- Relationships, enum casts, HasUuids
- Method: `isOverdue(): bool` → `$this->sla_deadline_at < now() && $this->status !== 'completed'`

### Sub-task 3.12.5: Create factories for both models

---

## Task 3.13: Project Management API Controllers

### Sub-task 3.13.1: Create StoreProjectRequest Form Request
- Rules: `name` required string max:255, `platform_primary` required in:flutter,react_native,other

### Sub-task 3.13.2: Create UpdateProjectRequest Form Request
- Rules: `name` sometimes string max:255, `platform_primary` sometimes enum

### Sub-task 3.13.3: Create UpdateEnvironmentRequest Form Request
- Rules: retention days, pii_mode, ip_truncation, user_id_hashing, lawful_basis, consent_required, pii_allowlist, pii_denylist
- All fields `sometimes` (partial update)

### Sub-task 3.13.4: Create StoreProjectKeyRequest Form Request
- Rules: `key_type` required in:write,read, `label` nullable string max:255

### Sub-task 3.13.5: Create ProjectResource API Resource
- Fields: id, name, platform_primary, environments_count, created_at
- Include environments when loaded

### Sub-task 3.13.6: Create EnvironmentResource API Resource
- Fields: id, name, all settings, keys_count, created_at

### Sub-task 3.13.7: Create ProjectKeyResource API Resource
- Fields: id, key_type, token_prefix, label, revoked_at, last_seen_at, created_at
- NEVER include token_hash
- Include `plain_token` only when `$this->resource->wasRecentlyCreated`
- Include `dsn` only when `$this->resource->wasRecentlyCreated` (format: `https://<token>@<host>/<project-id>/<environment>`)

### Sub-task 3.13.8: Create ProjectController
- CRUD methods with policy authorization
- `store()` auto-creates prod/staging/dev environments
- All routes scoped to current team

### Sub-task 3.13.9: Create EnvironmentController
- Nested under project
- `update()` only — name is immutable

### Sub-task 3.13.10: Create ProjectKeyController
- `index()`, `store()` (returns plain token ONCE), `destroy()` (revoke, not delete)

### Sub-task 3.13.11: Register API routes
- Under `routes/api.php` with `auth:sanctum` middleware
- Nested resource routes

---

## Task 3.14: Project Management UI (Livewire)

### Sub-task 3.14.1: Create ProjectList Livewire component
- Query team's projects with environment counts
- Grid or list display with project cards

### Sub-task 3.14.2: Create ProjectCreate Livewire component
- Form: name, platform selector
- On save: create project, redirect to project settings

### Sub-task 3.14.3: Create ProjectSettings Livewire component
- Tabs: one per environment (prod, staging, dev)
- Display project name (editable), platform

### Sub-task 3.14.4: Create EnvironmentSettings Livewire component
- Form fields for all environment settings
- Group by concern: Retention, Privacy/PII, Compliance
- Save button per section

### Sub-task 3.14.5: Create ProjectKeyManager Livewire component
- List existing keys with prefix, label, type, status, last seen
- "Generate Key" button → shows modal with plain token AND full DSN string (copy to clipboard, one-time display)
  - DSN format: `https://<token>@<host>/<project-id>/<environment>`
  - Provide separate "Copy DSN" and "Copy Token" buttons
  - Show usage example: `AnalyticsConfig(dsn: '<dsn_string>')`
- "Revoke" button with confirmation modal

### Sub-task 3.14.6: Register web routes
- `/projects` → ProjectList
- `/projects/create` → ProjectCreate
- `/projects/{project}/settings` → ProjectSettings

### Sub-task 3.14.7: Add project nav to sidebar
- Show team's projects in sidebar under "Projects" heading
- Link to each project's dashboard

---

## Task 3.15: Write Data Model Tests

### Sub-task 3.15.1: Test all model relationships
- Project belongs to Team, has many Environments
- Environment belongs to Project, has many ProjectKeys, AppUsers, etc.
- All inverse relationships work

### Sub-task 3.15.2: Test enum casting
- Creating model with enum value stores correct string
- Loading model returns correct enum instance

### Sub-task 3.15.3: Test ProjectKey generation
- Token prefix, hash, findByToken, revocation

### Sub-task 3.15.4: Test AppUser property operations
- All 4 operations with edge cases

### Sub-task 3.15.5: Test Project CRUD API
- Index, store (auto-environments), show, update, delete with authorization

### Sub-task 3.15.6: Test Environment API
- Show, update settings

### Sub-task 3.15.7: Test ProjectKey API
- Create (display once with plain token + DSN), list (no plain token, no DSN), revoke
- Test DSN format: `https://<token>@<host>/<project-id>/<environment>`

### Sub-task 3.15.8: Test authorization
- Non-team-member cannot access team's projects
- Read-only member cannot delete projects
- Owner can do everything

### Sub-task 3.15.9: Test Livewire components
- ProjectList renders projects
- ProjectCreate creates project with environments
- ProjectKeyManager shows keys, generates, revokes

### Sub-task 3.15.10: Run full regression
- `php artisan test --compact` — zero failures
