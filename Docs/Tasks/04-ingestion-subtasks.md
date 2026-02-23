# Sub-Tasks: Plan 04 - Ingestion API & Processing Pipeline

---

## Task 4.1: Create IngestBatch Migration & Model

### Sub-task 4.1.1: Generate model, migration, factory
- Run `php artisan make:model IngestBatch -mf --no-interaction`

### Sub-task 4.1.2: Define ingest_batches migration
- `uuid('id')->primary()`, `foreignUuid('environment_id')->constrained()->cascadeOnDelete()`, `string('idempotency_key')->nullable()->unique()`, `string('payload_checksum', 64)`, `json('raw_payload')`, `integer('event_count')`, `string('status', 16)->default('received')`, `integer('accepted')->nullable()`, `integer('rejected')->nullable()`, `text('error_message')->nullable()`, `timestamp('processed_at')->nullable()`, `timestamps()`
- Index: `['environment_id', 'created_at desc']`
- Index: `['status']`

### Sub-task 4.1.3: Define IngestBatch model
- Traits: `HasUuids`
- Casts: `status` → BatchStatus, `raw_payload` → `array`
- Relationships: `environment(): BelongsTo`
- Methods: `markProcessing()`, `markProcessed(int $accepted, int $rejected)`, `markFailed(string $error)`

### Sub-task 4.1.4: Define factory
- States: `received()`, `processing()`, `processed()`, `failed()`

---

## Task 4.2: Create AuthenticateProjectKey Middleware

### Sub-task 4.2.1: Create middleware file
- Run `php artisan make:middleware AuthenticateProjectKey --no-interaction`

### Sub-task 4.2.2: Implement token extraction
- In `handle()` method:
  - Get `Authorization` header
  - Extract Bearer token: `$token = $request->bearerToken()`
    - Note: The Bearer token is the public key portion of the DSN (`https://<public_key>@<host>/<project-id>/<environment>`)
    - The Flutter SDK parses the DSN and sends `Authorization: Bearer <public_key>`
  - If no token: return `response()->json(['error' => 'unauthenticated', 'message' => 'Missing or invalid Authorization header'], 401)`

### Sub-task 4.2.3: Implement token lookup
- Hash token: `$hash = hash('sha256', $token)`
- Find key: `$projectKey = ProjectKey::where('token_hash', $hash)->first()`
- If not found: return 401

### Sub-task 4.2.4: Implement revocation check
- If `$projectKey->isRevoked()`: return `response()->json(['error' => 'token_revoked', 'message' => 'This API key has been revoked'], 401)`

### Sub-task 4.2.5: Implement write-key check
- If `!$projectKey->isWriteKey()`: return `response()->json(['error' => 'insufficient_permissions', 'message' => 'Read keys cannot be used for ingestion'], 403)`

### Sub-task 4.2.6: Attach context to request
- Load relationships: `$projectKey->load('environment.project')`
- Set attributes:
  ```php
  $request->attributes->set('project_key', $projectKey);
  $request->attributes->set('environment', $projectKey->environment);
  $request->attributes->set('project', $projectKey->environment->project);
  ```

### Sub-task 4.2.7: Async update last_seen_at
- Dispatch async: `UpdateProjectKeyLastSeen::dispatch($projectKey->id)` (simple job to update timestamp)
- Or use `$projectKey->markSeen()` directly if performance is acceptable for MVP

### Sub-task 4.2.8: Register middleware alias
- Open `bootstrap/app.php`
- Add in `withMiddleware()`:
  ```php
  $middleware->alias([
      'auth.project_key' => \App\Http\Middleware\AuthenticateProjectKey::class,
  ]);
  ```

### Sub-task 4.2.9: Write middleware tests
- Test: valid write key (public key from DSN) passes through, request has environment/project attributes
- Test: no Authorization header returns 401
- Test: invalid token returns 401
- Test: revoked token returns 401
- Test: read key returns 403 (insufficient permissions)
- Test: last_seen_at is updated

---

## Task 4.3: Configure Ingest Rate Limiting

### Sub-task 4.3.1: Register ingest rate limiter
- Open `app/Providers/AppServiceProvider.php`
- Add in `boot()`:
  ```php
  RateLimiter::for('ingest', function (Request $request) {
      $environment = $request->attributes->get('environment');
      return Limit::perMinute(120)->by($environment?->id ?? $request->ip());
  });
  ```

### Sub-task 4.3.2: Verify throttle response format
- Test that 429 response includes `Retry-After` header
- Verify JSON response body matches expected format
- Customize 429 response if needed in exception handler

### Sub-task 4.3.3: Write rate limit test
- Reproduce PRD example test:
  - Send 120 requests quickly
  - 121st request should return 429
  - Check `Retry-After` header present

---

## Task 4.4: Create IngestBatchRequest (Form Request)

### Sub-task 4.4.1: Create Form Request class
- Run `php artisan make:request Api/V1/IngestBatchRequest --no-interaction`

### Sub-task 4.4.2: Define top-level validation rules
- `schema_version`: `required|in:1.0`
- `sent_at`: `required|date_format:Y-m-d\TH:i:s.v\Z` (ISO 8601 with ms)
- `environment`: `required|string`
- `app`: `required|array`
- `app.bundle_id`: `required|string|max:255`
- `app.version_name`: `required|string|max:64`
- `app.build_number`: `required|string|max:32`
- `device`: `required|array`
- `device.device_id`: `required|string|max:255`
- `device.platform`: `required|in:android,ios`
- `device.os_version`: `required|string|max:32`
- `device.model`: `required|string|max:128`
- `user`: `required|array`
- `user.anonymous_id`: `required|string|max:255`
- `user.user_id`: `nullable|string|max:255`
- `events`: `required|array|min:0|max:500`

### Sub-task 4.4.3: Define per-event base rules
- `events.*`: `required|array`
- `events.*.type`: `required|in:event,user_properties,crash,trace`
- `events.*.event_id`: `required|uuid`
- `events.*.timestamp`: `required|date_format:Y-m-d\TH:i:s.v\Z`

### Sub-task 4.4.4: Define conditional rules for type=event
- `events.*.name`: `required_if:events.*.type,event|string|max:255`
- `events.*.session_id`: `nullable|string|max:255`
- `events.*.properties`: `nullable|array`

### Sub-task 4.4.5: Define conditional rules for type=user_properties
- `events.*.operations`: `required_if:events.*.type,user_properties|array`
- `events.*.operations.*.op`: `required|in:set,set_once,increment,unset`
- `events.*.operations.*.key`: `required|string|max:255`
- `events.*.operations.*.value`: `required_unless:events.*.operations.*.op,unset`

### Sub-task 4.4.6: Define conditional rules for type=crash
- `events.*.fingerprint`: `required_if:events.*.type,crash|string|max:512`
- `events.*.fatal`: `boolean`
- `events.*.exception`: `required_if:events.*.type,crash|array`
- `events.*.exception.type`: `required_with:events.*.exception|string|max:255`
- `events.*.exception.message`: `required_with:events.*.exception|string|max:2048`
- `events.*.exception.stacktrace`: `nullable|string|max:65535`
- `events.*.breadcrumbs`: `nullable|array|max:50`
- `events.*.breadcrumbs.*.ts`: `required|string`
- `events.*.breadcrumbs.*.type`: `required|string|max:32`
- `events.*.breadcrumbs.*.message`: `required|string|max:512`

### Sub-task 4.4.7: Define conditional rules for type=trace
- `events.*.trace`: `required_if:events.*.type,trace|array`
- `events.*.trace.trace_id`: `required_with:events.*.trace|string|max:255`
- `events.*.trace.name`: `required_with:events.*.trace|string|max:255`
- `events.*.trace.duration_ms`: `required_with:events.*.trace|integer|min:0`
- `events.*.trace.attributes`: `nullable|array`

### Sub-task 4.4.8: Define custom error messages
- Write clear, SDK-debug-friendly messages for every rule
- Example: `'events.*.name.required_if' => 'The name field is required when type=event.'`
- Example: `'schema_version.in' => 'Unsupported schema_version. Supported: 1.0'`

### Sub-task 4.4.9: Override failedValidation for JSON response
- Ensure 422 response matches PRD format:
  ```json
  {"error": "validation_failed", "message": "Invalid payload", "details": {...}}
  ```

### Sub-task 4.4.10: Write validation tests
- Test: valid payload for each event type passes
- Test: missing schema_version fails with correct message
- Test: invalid event type fails
- Test: missing name for event type fails
- Test: missing operations for user_properties fails
- Test: missing exception for crash fails
- Test: missing trace for trace type fails
- Test: empty events array is valid
- Test: 500+ events fails max validation

---

## Task 4.5: Create IngestController

### Sub-task 4.5.1: Create controller
- Run `php artisan make:controller Api/V1/IngestController --no-interaction`

### Sub-task 4.5.2: Implement batch() method
- Resolve environment from request attributes
- Get optional `Idempotency-Key` header
- Check for duplicate: `IngestBatch::where('idempotency_key', $idempotencyKey)->exists()`
- If duplicate: return existing batch response
- Calculate checksum: `hash('sha256', $request->getContent())`
- Create IngestBatch record
- Dispatch ProcessIngestBatch to `ingest` queue
- Return 202 response

### Sub-task 4.5.3: Define 202 response format
- Match PRD exactly:
  ```php
  return response()->json([
      'batch_id' => $batch->id,
      'received_at' => now()->toIso8601String(),
      'accepted' => count($request->events),
      'rejected' => 0,
      'warnings' => [],
  ], 202);
  ```

### Sub-task 4.5.4: Register API route
- In `routes/api.php`:
  ```php
  Route::prefix('v1')->group(function () {
      Route::middleware(['auth.project_key', 'throttle:ingest'])
          ->post('/ingest/batch', [\App\Http\Controllers\Api\V1\IngestController::class, 'batch'])
          ->name('api.v1.ingest.batch');
  });
  ```

### Sub-task 4.5.5: Write PRD example test
- Reproduce the PRD test verbatim (lines 492-526)
- Use test write key with proper setup

---

## Task 4.6: Create Ingestion Service Classes

### Sub-task 4.6.1: Create EventNormalizer service
- Normalize timestamps to UTC Carbon instances
- Validate range: not more than 24h in future, not more than 30 days in past
- Trim whitespace from string fields
- Ensure event_id is valid UUID format

### Sub-task 4.6.2: Write EventNormalizer tests
- Test UTC conversion from various timezones
- Test timestamp range rejection
- Test valid/invalid UUID handling

### Sub-task 4.6.3: Create Deduplicator service
- Check Redis SET `seen_events:{env_id}` with TTL of 24h
- If event_id in SET: mark as duplicate, skip
- If not in SET: add to SET, proceed
- Fallback: catch unique constraint violation on insert

### Sub-task 4.6.4: Write Deduplicator tests
- Test first event passes through
- Test duplicate event_id is rejected
- Test different environments don't interfere

### Sub-task 4.6.5: Create Sessionizer service
- `resolveSession(Environment $env, string $sessionKey, AppUser $user, Device $device, Carbon $timestamp): AnalyticsSession`
- If sessionKey provided: find or create session by `(environment_id, session_key)`
- If no sessionKey: find latest session for device+user within 30-minute window
- If no matching session: create new one
- Update session `ended_at` and `event_count` on each event

### Sub-task 4.6.6: Write Sessionizer tests
- Test explicit session_id finds existing session
- Test implicit sessionization by time gap
- Test new session created when gap exceeds 30 minutes
- Test event count incremented

### Sub-task 4.6.7: Create PiiFilter service
- Load environment settings: pii_mode, allowlist, denylist, ip_truncation, user_id_hashing
- Filter properties: remove denylist keys, in strict mode only keep allowlist keys
- Auto-detect PII: regex for emails (`/\S+@\S+\.\S+/`), phone numbers, IP addresses in values
- Truncate IPs: IPv4 last octet to 0, IPv6 last 80 bits to 0
- Hash user_id if configured: `hash('sha256', $userId . $envSecret)`
- Log dropped fields for audit: `Log::channel('audit')->info('PII dropped', [...])`

### Sub-task 4.6.8: Write PiiFilter tests
- Test strict mode drops unlisted properties
- Test permissive mode allows all but denylist
- Test email detection in values
- Test IP truncation for IPv4 and IPv6
- Test user_id hashing with SHA-256
- Test allowlist overrides denylist
- Test default denylist includes common PII fields

### Sub-task 4.6.9: Create UserPropertyApplicator service
- `apply(AppUser $appUser, array $operations): void`
- Process each operation in order
- Handle type mismatches gracefully (e.g., increment on string → reset to 0 + amount)

### Sub-task 4.6.10: Write UserPropertyApplicator tests
- Test all 4 operations
- Test multiple operations in sequence
- Test type mismatch handling

---

## Task 4.7: Create ProcessIngestBatch Job

### Sub-task 4.7.1: Create job class
- Run `php artisan make:job ProcessIngestBatch --no-interaction`
- Add `implements ShouldQueue`
- Set `$queue = 'ingest'`
- Set `$tries = 3`, `$backoff = [10, 60, 300]`

### Sub-task 4.7.2: Implement constructor
- Accept `public string $batchId` via constructor promotion
- Add `$timeout = 120` property

### Sub-task 4.7.3: Implement handle() method - load and parse
- Load batch: `$batch = IngestBatch::findOrFail($this->batchId)`
- Update status: `$batch->markProcessing()`
- Parse raw payload events

### Sub-task 4.7.4: Implement handle() - upsert AppUser
- Find or create: `AppUser::updateOrCreate(['environment_id' => ..., 'anonymous_id' => ...], ['user_id' => ..., ...])`
- Update user_id if provided and different
- Apply user_id hashing per environment settings
- Update first_seen_at / last_seen_at

### Sub-task 4.7.5: Implement handle() - upsert Device
- Find or create: `Device::updateOrCreate(['environment_id' => ..., 'device_id' => ...], ['platform' => ..., ...])`
- Update last_seen_at

### Sub-task 4.7.6: Implement handle() - process each event
- For each event in batch:
  1. Normalize (EventNormalizer)
  2. Deduplicate (Deduplicator) — skip if duplicate
  3. Sessionize (Sessionizer)
  4. Apply PII filter (PiiFilter)
  5. Route by type:
     - `event` → create Event record
     - `user_properties` → call UserPropertyApplicator
     - `crash` → create CrashReport record
     - `trace` → create Trace record
  6. Increment accepted/rejected counters

### Sub-task 4.7.7: Implement handle() - finalize batch
- Update batch: `$batch->markProcessed($accepted, $rejected)`
- If any errors: log details to batch error_message

### Sub-task 4.7.8: Implement failed() method
- On unrecoverable failure:
- `$batch->markFailed($exception->getMessage())`
- Log error with batch context

### Sub-task 4.7.9: Write integration test for job
- Create environment, project key, ingest batch
- Dispatch job synchronously
- Verify events created in correct tables
- Verify batch status updated
- Verify AppUser and Device upserted

---

## Task 4.8: Create Daily Aggregates

### Sub-task 4.8.1: Create daily_aggregates migration
- All columns per plan spec
- Unique index on `(environment_id, date, metric, dimension)`

### Sub-task 4.8.2: Create DailyAggregate model
- HasUuids, fillable, scopes

### Sub-task 4.8.3: Create AggregateUpdater service
- `incrementEventCount(Environment $env, Carbon $date, int $count)`
- `updateActiveUsers(Environment $env, Carbon $date)`
- `updateCrashFreeRate(Environment $env, Carbon $date)`
- `updateP95ColdStart(Environment $env, Carbon $date)`

### Sub-task 4.8.4: Create analytics:update-aggregates command
- Recalculate all aggregates for a given date range
- Register in scheduler: daily at 2:30 AM UTC

### Sub-task 4.8.5: Write aggregate tests
- Test incremental update
- Test full recalculation matches incremental

---

## Task 4.9: Write Ingestion Integration Tests

### Sub-task 4.9.1: E2E test: valid batch → stored events
- Create team, project, environment, write key
- POST valid batch payload
- Assert 202 response
- Process job
- Assert events in database

### Sub-task 4.9.2: Test each event type stored correctly
- Test `type=event` creates Event record
- Test `type=user_properties` updates AppUser properties
- Test `type=crash` creates CrashReport
- Test `type=trace` creates Trace

### Sub-task 4.9.3: Test idempotency
- POST same batch with same Idempotency-Key twice
- Assert second request returns same batch_id
- Assert events not duplicated

### Sub-task 4.9.4: Test event deduplication
- POST two batches with overlapping event_ids
- Assert duplicate events not created

### Sub-task 4.9.5: Test rate limiting (PRD example)
- Send 121 requests → assert 429 on last

### Sub-task 4.9.6: Test validation errors
- Missing schema_version → 422 with details
- Invalid event type → 422 with details
- Multiple errors → all returned in details

### Sub-task 4.9.7: Test PII filtering
- POST batch with email in properties
- Process job in strict PII mode
- Assert email property removed from stored event

### Sub-task 4.9.8: Test sessionization
- POST batch with explicit session_id
- Assert events linked to same session
- POST batch without session_id
- Assert session inferred
