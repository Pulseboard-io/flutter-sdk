# Pulseboard Platform - Agent Instructions

## Agent Roles & Responsibilities

This document defines instructions for AI agents working on the Pulseboard Platform. All agents must follow the rules in `CLAUDE.md` in addition to their role-specific instructions.

## Universal Agent Rules

### Before Starting Any Work
1. Read `CLAUDE.md` for project-wide rules
2. Read `STATUS.md` to understand current project state
3. Read the relevant plan in `Docs/Plans/` for context
4. Read the relevant task file in `Docs/Tasks/` for detailed steps
5. Check the PRD (`Docs/PRD.md`) for requirements when in doubt

### After Completing Any Work
1. **Update `STATUS.md`** with:
   - What was changed (under "Recent Changes" with date)
   - Updated progress percentage for the relevant epic
   - Any new decisions made (under "Decisions Log")
   - Any new blockers identified
2. Run relevant tests and ensure they pass
3. Run `vendor/bin/pint --dirty --format agent` for PHP file changes

### Do NOT
- Install Laravel Passport (use Sanctum instead)
- Use SQLite for development (use PostgreSQL)
- Skip writing tests
- Make changes without updating STATUS.md
- Change the technology stack without approval
- Delete existing tests without approval
- Use `DB::` facade (use Eloquent)
- Use inline validation (use Form Requests)
- Ignore EU privacy requirements (GDPR-first)

---

## Hosting Environment Context

All agents should be aware of the hosting setup when making infrastructure-related decisions:

- **Hetzner Cloud (Germany)**: All servers are in Germany for EU data residency. Do not introduce services or dependencies that require data to leave the EU.
- **Laravel Forge**: Server provisioning, deployments, SSL (Let's Encrypt), and daemon management are handled via Forge. Do not write manual systemd units or Nginx configs -- Forge manages these.
- **Ubuntu 24.04 LTS**: Target OS for all server-side work.
- **PostgreSQL 16**: Primary database, hosted on Hetzner. Use PostgreSQL-specific features (jsonb, GIN indexes) confidently.
- **Redis 7**: Used for queues and caching, hosted on Hetzner.
- **Queue Workers**: Run as Forge daemons. Horizon monitors all queues (`default`, `ingest`, `compliance`).
- **SSL**: Let's Encrypt via Forge -- no manual certificate management needed.

When writing deployment-related code (e.g. deploy scripts, health checks, scheduled tasks), assume the Forge environment.

---

## Agent: Backend Developer (Laravel)

### Tools
- **Primary**: laravel-boost MCP server (search-docs, tinker, database-query, database-schema, list-artisan-commands)
- **Documentation**: Context7 for Laravel ecosystem packages
- **Code Quality**: `vendor/bin/pint --dirty --format agent`
- **Testing**: `php artisan test --compact --filter=TestName`

### Workflow
1. Search Laravel Boost docs BEFORE writing code
2. Use `php artisan make:*` commands to scaffold files
3. Write implementation following existing conventions (check sibling files)
4. Create Form Request for any endpoint validation
5. Write Pest tests for all new functionality
6. Run tests to verify
7. Run Pint for formatting
8. Update STATUS.md

### Architecture Guidelines
- **Models**: Always use `HasUuids` trait, `casts()` method, proper relationships with return types
- **Controllers**: Thin controllers, business logic in Service classes
- **Services**: Domain-organized (`app/Services/Ingestion/`, `app/Services/Compliance/`)
- **Jobs**: Implement `ShouldQueue`, specify queue name, configure retries
- **Enums**: String-backed, TitleCase keys, stored in `app/Enums/`
- **Policies**: Team-scoped authorization for all project resources
- **API Resources**: Use Eloquent API Resources for all JSON responses
- **Middleware**: Register aliases in `bootstrap/app.php`

### Database Rules
- PostgreSQL is the primary database
- All primary keys are UUIDs
- All timestamps in UTC
- Use `jsonb` for flexible property storage
- Create proper indexes (check plan files for index specs)
- Privacy-by-default values in migrations (IP truncation ON, hashing ON)

### Queue Architecture
- `default` queue: general jobs
- `ingest` queue: ingestion processing (ProcessIngestBatch)
- `compliance` queue: deletion/export jobs (longer running, lower priority)
- All queues monitored via Horizon

---

## Agent: Flutter SDK Developer

### Tools
- **Primary**: dart-mcp server for Dart/Flutter operations
- **Documentation**: Context7 for Flutter/Dart package docs
- **Testing**: `flutter test`
- **Analysis**: `flutter analyze`

### Workflow
1. Query Context7 for relevant package docs BEFORE writing code
2. Follow effective Dart style guide
3. Implement with null safety
4. Write unit tests with mocktail
5. Run `flutter analyze` to check for issues
6. Run `flutter test` to verify
7. Update STATUS.md

### Architecture Guidelines
- **Singleton pattern** for `AppAnalytics` main client
- **Service classes** for each concern (session, crash, batch, persistence)
- **Models** with `toJson()`/`fromJson()` matching PRD schema exactly
- **Barrel file** (`lib/app_analytics.dart`) exports only public API
- **Minimal dependencies**: use `http` not `dio`, `shared_preferences` for simple storage
- **Testability**: inject dependencies, use abstractions for time/platform
- **Privacy**: consent mode support (EU), opt-in/opt-out, sampling

### SDK API Contract
The SDK must produce payloads matching the PRD schema v1.0 exactly:
- `schema_version: "1.0"`
- Headers: `X-SDK: flutter`, `X-SDK-Version: 0.1.0`, `X-Schema-Version: 1.0`
- Event types: `event`, `user_properties`, `crash`, `trace`
- Idempotency keys on every batch

### EU-Specific SDK Requirements
- `consentRequired` config flag
- Events held in queue until `grantConsent()` called
- `revokeConsent()` stops tracking and flushes held events
- Respect `optOut()` / `optIn()` for user choice
- No PII in default device/app metadata collection

---

## Agent: UI/Frontend Developer

### Tools
- **Primary**: laravel-boost (search-docs for Livewire, Tailwind)
- **Styling**: Activate `tailwindcss-development` skill
- **Components**: Activate `livewire-development` skill
- **Documentation**: Context7 for Tailwind/Alpine.js docs

### Workflow
1. Check existing components before creating new ones
2. Activate relevant skills (Tailwind, Livewire)
3. Search docs for Tailwind/Livewire patterns
4. Build with custom design system (NOT stock Jetstream)
5. Ensure dark mode compatibility
6. Write Livewire component tests
7. Run `npm run build` after frontend changes
8. Update STATUS.md

### Design System Rules
- Custom color palette (defined in `tailwind.config.js`)
- Non-stock Jetstream appearance (override all default views)
- Dark mode via Tailwind `class` strategy
- Sidebar navigation layout for project pages
- Reusable components: KpiCard, DataTable, Chart wrappers, DateRangePicker
- All components must work in both light and dark mode

---

## Agent: Testing & Quality

### Tools
- **Backend**: `php artisan test --compact`
- **Flutter**: `flutter test`
- **Formatting**: `vendor/bin/pint --dirty --format agent`
- **Coverage**: `php artisan test --coverage --min=80`

### Test Organization
```
tests/
├── Unit/Services/       # Service class unit tests
├── Unit/Models/         # Model relationship tests
├── Unit/Enums/          # Enum value tests
├── Feature/Auth/        # Authentication tests
├── Feature/Teams/       # Team management tests
├── Feature/Api/         # API endpoint tests
├── Feature/Livewire/    # Livewire component tests
├── Feature/Compliance/  # GDPR workflow tests
├── Contract/            # API contract compliance tests
└── E2E/                 # End-to-end smoke tests
```

### Coverage Targets
- Core services (Ingestion, Compliance, Metrics): >= 90%
- Controllers + Jobs: >= 80%
- Models: >= 70%
- Overall: >= 80%

---

## Agent: Compliance & Privacy

### Special Focus
- This agent handles GDPR/ePrivacy compliance work
- All defaults must be EU-strict
- Document lawful basis for all processing activities
- 30-day SLA on all DSARs
- Audit trail on all data operations
- Data minimization principle in all designs

### Key GDPR Articles to Reference
- Art. 5: Principles (lawfulness, data minimization, storage limitation)
- Art. 7: Conditions for consent
- Art. 15: Right of access
- Art. 17: Right to erasure
- Art. 20: Right to data portability
- Art. 25: Data protection by design and by default
- Art. 30: Records of processing activities
- Art. 33: Notification of breach (72 hours)

---

## Dependency Order for Implementation

```
Plan 01: Platform Foundation
    ↓
Plan 02: Auth & Org Model ←── Plan 09: Quality & CI/CD (parallel)
    ↓
Plan 03: Data Model & Project Management
    ↓
Plan 04: Ingestion API ──┬── Plan 05: Flutter SDK (parallel)
    ↓                     │
Plan 06: Analytics Dashboards
    ↓
Plan 07: Compliance & Governance
    ↓
Plan 08: Billing Placeholder
```

Plans 04 and 05 can be developed in parallel. Plan 09 (CI/CD) is set up early and tests accumulate throughout.
