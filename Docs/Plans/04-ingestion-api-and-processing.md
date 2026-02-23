# Plan 04: Ingestion API & Processing Pipeline

## Objective
Build the REST ingestion endpoint (`POST /api/v1/ingest/batch`), validation pipeline, queue-based processing with Horizon, and normalized storage of events, crashes, traces, and sessions.

## Current State
- No ingestion endpoint exists
- No queue jobs defined
- Horizon installed but no jobs to process
- Redis configured but queue connection set to database

## Target State
- `POST /api/v1/ingest/batch` endpoint accepting batched telemetry
- Bearer token auth via ProjectKey (the public key from the DSN is sent as Bearer token)
- Rate limiting per project/environment
- Schema validation with clear error payloads
- 202 Accepted response with batch_id
- Queue-based processing (ProcessIngestBatch job)
- Idempotency via event_id deduplication
- Normalized storage: events, user properties, crash reports, traces
- Sessionization: attach events to sessions, infer if missing
- PII filtering based on environment governance settings
- Derived aggregates: daily active users, crash-free rate, p95 trace duration

## Implementation Steps

### 4.1 Ingestion Auth Middleware
- Create `AuthenticateProjectKey` middleware:
  - Extract Bearer token from Authorization header
    - The Bearer token is the public key portion of the DSN (`https://<public_key>@<host>/...`)
    - The Flutter SDK parses the DSN and sends `Authorization: Bearer <public_key>`
  - Look up `project_keys` by `token_hash` (hash the incoming token)
  - Reject if revoked or not found (401)
  - Resolve environment_id and project_id from the key
  - Attach environment and project to the request
  - Update `last_seen_at` on the key (debounced/async)

### 4.2 Rate Limiting
- Configure named rate limiter `ingest` in `AppServiceProvider`:
  - Limit per environment_id (e.g., 120 requests/minute for MVP)
  - Return 429 with `Retry-After` header
- Apply via `throttle:ingest` middleware on the ingest route

### 4.3 Ingest Batch Form Request
- Create `IngestBatchRequest` with validation rules matching the PRD contract:
  - `schema_version`: required, in:1.0
  - `sent_at`: required, ISO 8601 datetime
  - `environment`: required, string
  - `app.bundle_id`: required, string
  - `app.version_name`: required, string
  - `app.build_number`: required, string
  - `device.device_id`: required, string (uuid or identifier)
  - `device.platform`: required, in:android,ios
  - `device.os_version`: required, string
  - `device.model`: required, string
  - `user.anonymous_id`: required, string
  - `user.user_id`: optional, string
  - `events`: required, array, min:0
  - `events.*.type`: required, in:event,user_properties,crash,trace
  - `events.*.event_id`: required, uuid
  - `events.*.timestamp`: required, ISO 8601
  - Conditional rules based on event type
- Custom error messages for SDK debugging
- Return 422 with structured error payload on validation failure

### 4.4 Ingest Controller
- `IngestController::batch()` method:
  1. Validate via `IngestBatchRequest`
  2. Check idempotency (optional `Idempotency-Key` header)
  3. Store raw batch payload with checksum in `ingest_batches` table
  4. Dispatch `ProcessIngestBatch` job to Redis queue
  5. Return 202 Accepted with `batch_id`, `received_at`, `accepted`, `rejected`, `warnings`

### 4.5 Ingest Batches Table
- Migration for `ingest_batches`:
  - `id (uuid pk)`, `environment_id (fk)`, `idempotency_key (string, nullable, unique)`, `payload_checksum (string)`, `event_count (int)`, `status (enum: received/processing/processed/failed)`, `accepted (int, nullable)`, `rejected (int, nullable)`, `error_message (text, nullable)`, `processed_at (nullable)`, `created_at`, `updated_at`

### 4.6 ProcessIngestBatch Job
- Implements `ShouldQueue` with Horizon-managed queue
- Steps:
  1. Load batch from `ingest_batches`
  2. Parse payload
  3. For each event in the batch:
     a. **Deduplicate**: check `(environment_id, event_id)` uniqueness
     b. **Normalize timestamps**: convert to UTC, validate ranges
     c. **Upsert AppUser**: find/create by `(environment_id, anonymous_id)`, update `user_id` if provided
     d. **Upsert Device**: find/create by `(environment_id, device_id)`
     e. **Sessionize**: find/create session by `session_id` or infer by device+user+time gap
     f. **Apply PII policy**: check environment's `pii_mode`, drop/transform forbidden keys
     g. **Persist**: write to appropriate table based on type:
        - `event` -> `events` table
        - `user_properties` -> apply operations (set, set_once, increment, unset) to `app_users.properties`
        - `crash` -> `crash_reports` table
        - `trace` -> `traces` table
  4. Update batch status to `processed` with accepted/rejected counts
  5. Update derived aggregates (increment counters, update session end time)

### 4.7 Derived Aggregates
- Create `daily_aggregates` table:
  - `id`, `environment_id`, `date`, `metric (enum)`, `dimension (string, nullable)`, `value (decimal)`, `created_at`, `updated_at`
  - Unique index: `(environment_id, date, metric, dimension)`
- Metrics to track: `total_events`, `active_users`, `sessions`, `crash_free_users_pct`, `p95_cold_start_ms`
- Update aggregates in the ProcessIngestBatch job or a separate scheduled job

### 4.8 API Routes
```php
Route::prefix('v1')->group(function () {
    Route::middleware(['auth.project_key', 'throttle:ingest'])
        ->post('/ingest/batch', [IngestController::class, 'batch']);
});
```

## Dependencies
- Plan 01 (PostgreSQL + Redis + Horizon)
- Plan 03 (Data Model - all tables must exist)

## Testing Requirements
- Feature test: valid batch returns 202 with batch_id (PRD example)
- Feature test: invalid payload returns 422 with structured errors
- Feature test: invalid/revoked write key returns 401
- Feature test: rate limiting returns 429 at threshold
- Feature test: idempotency key prevents duplicate processing
- Unit test: ProcessIngestBatch job normalizes and stores events correctly
- Unit test: deduplication logic
- Unit test: sessionization logic
- Unit test: PII filtering based on environment config
- Unit test: user property operations (set, set_once, increment, unset)
- Integration test: end-to-end batch ingest -> queue -> stored events

## Estimated Effort
6-9 person-weeks

## Files to Create/Modify
- `app/Http/Middleware/AuthenticateProjectKey.php` (new)
- `app/Http/Controllers/Api/V1/IngestController.php` (new)
- `app/Http/Requests/Api/V1/IngestBatchRequest.php` (new)
- `app/Jobs/ProcessIngestBatch.php` (new)
- `app/Services/Ingestion/EventNormalizer.php` (new)
- `app/Services/Ingestion/Deduplicator.php` (new)
- `app/Services/Ingestion/Sessionizer.php` (new)
- `app/Services/Ingestion/PiiFilter.php` (new)
- `app/Services/Ingestion/UserPropertyApplicator.php` (new)
- `app/Services/Ingestion/AggregateUpdater.php` (new)
- `app/Models/IngestBatch.php` (new)
- `database/migrations/*_create_ingest_batches_table.php` (new)
- `database/migrations/*_create_daily_aggregates_table.php` (new)
- `routes/api.php` (modify)
- `bootstrap/app.php` (modify - register middleware alias)
- `app/Providers/AppServiceProvider.php` (modify - rate limiter)
- `config/horizon.php` (modify - queue configuration)
- 15+ test files
