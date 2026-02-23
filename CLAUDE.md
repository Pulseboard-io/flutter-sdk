# Pulseboard Platform - AI Agent Instructions

## Project Overview
This is a multi-tenant, Laravel-based mobile app analytics platform for Flutter-first apps. It provides event analytics, sessionization, user properties, crash reporting, and performance tracing. The primary target market is **Europe** (GDPR-first, privacy-by-default).

## Repository Structure
```
pulseboard/
├── CLAUDE.md              # This file - AI instructions
├── AGENTS.md              # Agent-specific instructions
├── STATUS.md              # Project status - UPDATE ON EVERY CHANGE
├── Docs/
│   ├── PRD.md             # Product Requirements Document (source of truth)
│   ├── Plans/             # Implementation plans (01-09)
│   └── Tasks/             # Task breakdowns per plan
└── Source Code/
    ├── aa-api/            # Laravel 12 backend API
    └── flutter-sdk/       # Flutter analytics SDK package
```

## Critical Rules

### 1. Status Tracking
- **Every change must be documented in `STATUS.md`** at the project root
- Update the relevant epic progress percentage
- Add a dated entry under "Recent Changes" describing what was done
- Log any decisions made under "Decisions Log"
- Update blockers if applicable

### 2. No Laravel Passport
- **Do NOT install or use Laravel Passport** anywhere in this project
- Use **Laravel Sanctum** for all API token and authentication needs
- Sanctum token abilities replace Passport scopes
- All API routes use `auth:sanctum` guard

### 3. EU Privacy First
- This application targets the **European market** as its primary audience
- **GDPR compliance is mandatory**, not optional
- All privacy defaults must be strict:
  - IP truncation: ON by default
  - User ID hashing: SHA-256 by default
  - PII mode: strict by default
  - Data region: EU by default
- Consent management must be built into the SDK and API
- 30-day SLA for all Data Subject Access Requests (DSARs)
- Audit trail for all data processing activities
- Data minimization principle: only collect what's necessary

### 4. Technology Stack (Do Not Change)
**Backend (aa-api):**
- Laravel 12 (PHP 8.2-8.5)
- Jetstream 5.x (Livewire stack) - authentication, teams, API tokens
- Sanctum 4.x - API authentication (no Passport)
- Horizon 5.x - Redis queue monitoring
- Pennant 1.x - feature flags
- Pest 4.x - testing framework
- Livewire 3.x - reactive UI components
- Tailwind CSS 3.x - styling
- PostgreSQL - primary database (NOT SQLite for development)
- Redis - queues, caching

**Flutter SDK (flutter-sdk):**
- Dart SDK >= 3.0.0
- Flutter >= 3.10.0
- http package for API calls (not dio)
- Schema version: 1.0

### 5. Laravel Best Practices
- Use `php artisan make:*` commands to create files
- Pass `--no-interaction` to all Artisan commands
- Always create Form Request classes for validation (no inline validation)
- Use Eloquent relationships, avoid `DB::` facade
- Use constructor property promotion (PHP 8)
- Explicit return types on all methods
- Use `casts()` method on models (not `$casts` property)
- Use queued jobs with `ShouldQueue` for heavy operations
- Run `vendor/bin/pint --dirty --format agent` after modifying PHP files
- Every change must have tests (Pest)
- Run tests with `php artisan test --compact` or `--filter=testName`

### 6. Flutter/Dart Best Practices
- Follow effective Dart style guide
- Strict lint rules via `analysis_options.yaml`
- Null safety everywhere
- Use `mocktail` for mocking in tests
- Keep dependencies minimal
- All models have `toJson()` and `fromJson()`
- Public API through barrel file (`lib/app_analytics.dart`)

### 7. Testing Requirements
- **Every change must be programmatically tested**
- Backend: Pest (unit >= 90% core services, integration >= 80%)
- Flutter: flutter_test + mocktail
- Run relevant tests before considering work complete
- Never delete existing tests without approval

## Hosting & Deployment

### Infrastructure
- **Cloud Provider**: Hetzner Cloud, Germany (EU data residency -- aligns with GDPR-first approach)
- **Server Management**: Laravel Forge (provisioning, deployments, SSL, daemon management)
- **Operating System**: Ubuntu 24.04 LTS

### Services
- **Database**: PostgreSQL 16 on Hetzner
- **Cache / Queues**: Redis 7 on Hetzner
- **SSL**: Let's Encrypt certificates, automatically managed by Forge
- **Queue Workers**: Managed as Forge daemons (one per queue: `default`, `ingest`, `compliance`)
- **Queue Monitoring**: Laravel Horizon dashboard (`/horizon`)

### Deployment Notes
- Forge handles zero-downtime deployments via deploy script
- Environment variables managed through Forge dashboard (never commit `.env`)
- Forge daemon keeps Horizon running and auto-restarts on failure
- All data stays within Germany / EU -- no cross-border data transfers for core operations

---

## MCP Tools & Documentation

### For Laravel Work (aa-api)
- **Use `laravel-boost` MCP server** (search-docs, tinker, database-query, database-schema, list-artisan-commands)
- Search docs BEFORE making code changes
- Use multiple broad queries: `['rate limiting', 'routing rate limiting']`
- Use `database-schema` tool to inspect tables before writing migrations

### For Flutter Work (flutter-sdk)
- **Use `dart-mcp` server** for Dart/Flutter specific operations
- Use **Context7** for Flutter/Dart package documentation

### For Any Documentation
- **Use Context7** to query up-to-date library documentation
- Always resolve library ID first, then query docs

## Key Domain Concepts

### Multi-Tenancy Model
```
User -> Team (Jetstream) -> Project -> Environment -> ProjectKey
                                    -> AppUser, Device, Session
                                    -> Event, CrashReport, Trace
```

### DSN (Data Source Name) System
The platform uses a Sentry-like DSN to simplify SDK configuration. A single DSN string encodes all connection details.

**DSN Format:** `https://<public_key>@<host>/<project-id>/<environment>`
**Example:** `https://wk_abc123def456@pulseboard.example.com/proj_uuid/production`

**How it works:**
- When a user creates a project key, the UI displays the full DSN string
- The Flutter SDK only requires one config parameter: `dsn`
- The SDK parses the DSN to extract:
  - `host` -> API endpoint (`https://pulseboard.example.com`)
  - `public_key` (userinfo before `@`) -> Authentication key
  - First path segment -> Project ID
  - Second path segment -> Environment name
- The public key is sent as `Authorization: Bearer <public_key>` in API requests
- The server-side auth middleware hashes the Bearer token and looks it up in `project_keys.token_hash` (same flow as before, the key just comes from the DSN now)
- No separate API keys, write keys, or endpoint configuration needed

**SDK Usage:**
```dart
await AppAnalytics.initialize(
  AnalyticsConfig(dsn: 'https://wk_abc123def456@pulseboard.example.com/proj_uuid/production'),
);
```

### Ingestion Flow
```
Flutter SDK (parses DSN) -> POST /api/v1/ingest/batch (Bearer <public_key from DSN>)
                         -> Validate + Rate Limit
                         -> Store raw batch
                         -> Dispatch ProcessIngestBatch job (Redis/Horizon)
                         -> Normalize, Deduplicate, Sessionize, PII Filter
                         -> Persist to PostgreSQL
```

### API Authentication
- **Web dashboard**: Jetstream session auth (Sanctum)
- **API tokens**: Sanctum personal access tokens with abilities
- **Ingestion**: Public key from DSN sent as Bearer token, matched against project_keys by token_hash
- **No Passport, no OAuth2 server**

## Plans & Tasks Reference
- Plans are in `Docs/Plans/01-09-*.md`
- Tasks are in `Docs/Tasks/01-09-*-tasks.md`
- Always check the relevant plan and task file before starting work
- Follow the dependency order: Plan 01 -> 02 -> 03 -> 04/05 (parallel) -> 06 -> 07 -> 08 -> 09

## Skill Activation (Laravel Boost)
Activate these skills when working in their domains:
- `pest-testing` - when writing or running tests
- `livewire-development` - when creating UI components
- `pennant-development` - when working with feature flags
- `tailwindcss-development` - when styling components
- `mcp-development` - when building MCP tools

## File Naming Conventions
- Migrations: `YYYY_MM_DD_HHMMSS_description.php`
- Models: PascalCase singular (`Project.php`, `CrashReport.php`)
- Controllers: PascalCase with suffix (`IngestController.php`)
- Form Requests: PascalCase descriptive (`IngestBatchRequest.php`)
- Jobs: PascalCase verb-noun (`ProcessIngestBatch.php`)
- Services: PascalCase in domain directory (`Ingestion/EventNormalizer.php`)
- Enums: PascalCase singular (`Platform.php`, `EventType.php`)
- Tests: PascalCase with `Test` suffix (`IngestBatchTest.php`)
- Dart files: snake_case (`analytics_client.dart`, `batch_processor.dart`)
