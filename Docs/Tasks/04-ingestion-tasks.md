# Tasks: Plan 04 - Ingestion API & Processing Pipeline

## References
- Plan: [04-ingestion-api-and-processing.md](../Plans/04-ingestion-api-and-processing.md)
- PRD: [PRD.md](../PRD.md) (lines 126-236, 377-414)

---

## Task 4.1: Create IngestBatch Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Plan 03

### Steps
1. Create migration for `ingest_batches` table:
   - `id (uuid pk)`, `environment_id (fk environments)`, `idempotency_key (string, nullable, unique)`, `payload_checksum (string)`, `event_count (int)`, `status (string, default 'received')`, `accepted (int, nullable)`, `rejected (int, nullable)`, `error_message (text, nullable)`, `processed_at (timestamp, nullable)`, `created_at`, `updated_at`
2. Create `IngestBatch` model with `HasUuids`, relationships, enum casts
3. Create factory

### Acceptance Criteria
- [ ] Migration runs successfully
- [ ] Model with proper casts and relationships
- [ ] Idempotency key uniqueness enforced

---

## Task 4.2: Create AuthenticateProjectKey Middleware
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Plan 03 (Task 3.4)

### Steps
1. Create `AuthenticateProjectKey` middleware in `app/Http/Middleware/`
2. Implementation:
   - Extract Bearer token from `Authorization` header
     - The Bearer token is the public key extracted from the DSN by the SDK
     - DSN format: `https://<public_key>@<host>/<project-id>/<environment>`
     - The SDK sends `Authorization: Bearer <public_key>`
   - Hash the incoming token (SHA-256)
   - Look up `project_keys` by `token_hash`
   - If not found or revoked: return 401 JSON response
   - Resolve environment and project from the key
   - Attach `environment`, `project`, and `projectKey` to request attributes
   - Dispatch async update for `last_seen_at` (avoid blocking request)
3. Register middleware alias `auth.project_key` in `bootstrap/app.php`
4. Write tests

### Acceptance Criteria
- [ ] Valid write key (public key from DSN) allows request through
- [ ] Invalid/missing key returns 401
- [ ] Revoked key returns 401
- [ ] Environment and project attached to request
- [ ] `last_seen_at` updated (async)

---

## Task 4.3: Configure Ingest Rate Limiting
**Priority:** High | **Estimate:** 1-2 hours | **Blocked by:** Task 4.2

### Steps
1. Register named rate limiter `ingest` in `AppServiceProvider::boot()`:
   ```php
   RateLimiter::for('ingest', function (Request $request) {
       $envId = $request->attributes->get('environment')?->id ?? 'unknown';
       return Limit::perMinute(120)->by($envId);
   });
   ```
2. Apply `throttle:ingest` middleware to the ingest route
3. Ensure 429 response includes proper headers (`Retry-After`, `X-RateLimit-*`)
4. Write rate limiting test (matches PRD example test)

### Acceptance Criteria
- [ ] Rate limiter configured per environment
- [ ] 429 response at threshold with correct headers
- [ ] Test matches PRD contract test

---

## Task 4.4: Create IngestBatchRequest (Form Request)
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 3.1 (Enums)

### Steps
1. Create `IngestBatchRequest` in `app/Http/Requests/Api/V1/`
2. Validation rules per PRD schema v1.0:
   - Top-level: `schema_version`, `sent_at`, `environment`, `app.*`, `device.*`, `user.*`, `events`
   - Per-event conditional rules based on `type`:
     - `event`: requires `name`, `session_id`
     - `user_properties`: requires `operations` array with `op`, `key`, `value`
     - `crash`: requires `fingerprint`, `exception.*`, optional `breadcrumbs`
     - `trace`: requires `trace.*` with `trace_id`, `name`, `duration_ms`
3. Custom error messages for SDK debugging (clear, actionable)
4. Return 422 with structured error payload matching PRD format
5. Write validation tests for each event type

### Acceptance Criteria
- [ ] All PRD fields validated
- [ ] Conditional validation per event type
- [ ] Custom error messages for every rule
- [ ] 422 response matches PRD error format
- [ ] Tests cover valid and invalid payloads for all event types

---

## Task 4.5: Create IngestController
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Tasks 4.1-4.4

### Steps
1. Create `IngestController` in `app/Http/Controllers/Api/V1/`
2. `batch()` method:
   - Resolve environment from middleware-attached request attribute
   - Check optional `Idempotency-Key` header for duplicate batch
   - Calculate payload checksum
   - Create `IngestBatch` record with status `received`
   - Dispatch `ProcessIngestBatch` job to `ingest` queue
   - Return 202 Accepted response matching PRD format
3. Register route in `routes/api.php`:
   ```php
   Route::prefix('v1')->group(function () {
       Route::middleware(['auth.project_key', 'throttle:ingest'])
           ->post('/ingest/batch', [IngestController::class, 'batch'])
           ->name('api.v1.ingest.batch');
   });
   ```

### Acceptance Criteria
- [ ] Returns 202 with batch_id on valid request
- [ ] Idempotency key prevents duplicate batch creation
- [ ] Job dispatched to `ingest` queue
- [ ] Response matches PRD 202 format exactly
- [ ] Test matches PRD example test

---

## Task 4.6: Create Ingestion Service Classes
**Priority:** Critical | **Estimate:** 6-8 hours | **Blocked by:** Plan 03

### Steps
1. Create `app/Services/Ingestion/EventNormalizer.php`:
   - Normalize timestamps to UTC
   - Validate timestamp ranges (not too far in past/future)
   - Normalize IDs and required fields
2. Create `app/Services/Ingestion/Deduplicator.php`:
   - Check `(environment_id, event_id)` uniqueness
   - Use a "seen events" cache (Redis SET with TTL) for fast lookup
   - Fallback to database unique constraint
3. Create `app/Services/Ingestion/Sessionizer.php`:
   - Find existing session by `session_id`
   - If no `session_id`, infer by device+user+time gap (30 min default)
   - Create new session if needed
   - Update session end time and event count
4. Create `app/Services/Ingestion/PiiFilter.php`:
   - Load environment PII settings (mode, allowlist, denylist)
   - Filter event properties against allowlist/denylist
   - Auto-detect PII patterns (email, phone, IP in properties)
   - Apply IP truncation (last octet zeroed for IPv4, last 80 bits for IPv6)
   - Hash user_id if configured
   - Log dropped fields for audit
5. Create `app/Services/Ingestion/UserPropertyApplicator.php`:
   - `set`: overwrite property value
   - `set_once`: set only if not already set
   - `increment`: add to numeric value
   - `unset`: remove property key
6. Write comprehensive unit tests for each service

### Acceptance Criteria
- [ ] EventNormalizer handles timezone conversion and range validation
- [ ] Deduplicator prevents duplicate events efficiently
- [ ] Sessionizer creates/updates sessions correctly
- [ ] PiiFilter applies all rules with EU-strict defaults
- [ ] UserPropertyApplicator handles all 4 operations
- [ ] Unit tests cover edge cases for each service

---

## Task 4.7: Create ProcessIngestBatch Job
**Priority:** Critical | **Estimate:** 4-6 hours | **Blocked by:** Task 4.6

### Steps
1. Create `ProcessIngestBatch` job in `app/Jobs/`
2. Implements `ShouldQueue`, configurable queue name (`ingest`)
3. Processing logic:
   a. Load batch from `ingest_batches`, update status to `processing`
   b. Parse events from stored payload
   c. For each event, orchestrate services:
      - Normalize (EventNormalizer)
      - Deduplicate (Deduplicator)
      - Upsert AppUser
      - Upsert Device
      - Sessionize (Sessionizer)
      - Apply PII filter (PiiFilter)
      - Apply user property operations (if type=user_properties)
      - Persist to appropriate table
   d. Track accepted/rejected counts
   e. Update batch status to `processed` or `failed`
   f. Log errors for rejected events
4. Error handling: catch exceptions, mark batch failed, log details
5. Retry configuration: max 3 retries with backoff
6. Write integration tests

### Acceptance Criteria
- [ ] Job processes batch end-to-end
- [ ] Events stored in correct tables by type
- [ ] AppUsers and Devices upserted correctly
- [ ] Sessions created/updated
- [ ] PII filtering applied
- [ ] Batch status updated with accepted/rejected counts
- [ ] Failed batches have error details
- [ ] Retries configured with backoff

---

## Task 4.8: Create Daily Aggregates
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 4.7

### Steps
1. Create migration for `daily_aggregates` table:
   - `id (uuid)`, `environment_id (fk)`, `date`, `metric (string)`, `dimension (string, nullable)`, `value (decimal)`, `created_at`, `updated_at`
   - Unique index: `(environment_id, date, metric, dimension)`
2. Create `DailyAggregate` model
3. Create `AggregateUpdater` service:
   - Methods to increment/update: total_events, active_users, sessions, crash_free_users_pct, p95_cold_start_ms
   - Can be called from ProcessIngestBatch or as a separate scheduled job
4. Create scheduled command `analytics:update-aggregates` for daily recalculation

### Acceptance Criteria
- [ ] Aggregates computed correctly from raw data
- [ ] Incremental updates work during ingestion
- [ ] Scheduled full recalculation works
- [ ] Unique constraint prevents duplicate entries

---

## Task 4.9: Write Ingestion Integration Tests
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Tasks 4.5-4.8

### Steps
1. End-to-end test: POST valid batch -> 202 -> job processes -> events stored
2. Test each event type: event, user_properties, crash, trace
3. Test idempotency: same idempotency key doesn't create duplicate
4. Test deduplication: same event_id doesn't create duplicate event
5. Test rate limiting: 429 at threshold (PRD example test)
6. Test schema validation: invalid payloads return 422 with correct errors
7. Test PII filtering: sensitive properties dropped in strict mode
8. Test sessionization: events grouped into correct sessions

### Acceptance Criteria
- [ ] All integration tests pass
- [ ] Tests match PRD example tests
- [ ] Full pipeline tested end-to-end
- [ ] Edge cases covered
