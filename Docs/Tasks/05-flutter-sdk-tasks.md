# Tasks: Plan 05 - Flutter SDK

## References
- Plan: [05-flutter-sdk.md](../Plans/05-flutter-sdk.md)
- PRD: [PRD.md](../PRD.md) (lines 56-63, 466-473)

---

## Task 5.1: Initialize Flutter Package
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** None

### Steps
1. Create `pubspec.yaml` in `Source Code/flutter-sdk/`:
   ```yaml
   name: app_analytics
   description: Flutter analytics SDK for the Pulseboard platform
   version: 0.1.0
   repository: (TBD)
   environment:
     sdk: ">=3.0.0 <4.0.0"
     flutter: ">=3.10.0"
   dependencies:
     flutter:
       sdk: flutter
     http: ^1.2.0
     shared_preferences: ^2.3.0
     uuid: ^4.5.0
     device_info_plus: ^10.1.0
     package_info_plus: ^8.1.0
     connectivity_plus: ^6.1.0
     path_provider: ^2.1.0
   dev_dependencies:
     flutter_test:
       sdk: flutter
     flutter_lints: ^4.0.0
     mocktail: ^1.0.0
   ```
2. Create `analysis_options.yaml` with strict lint rules
3. Create directory structure: `lib/src/`, `test/`, `example/`
4. Create barrel file: `lib/app_analytics.dart`
5. Run `flutter pub get`

### Acceptance Criteria
- [ ] Package structure created
- [ ] Dependencies resolve
- [ ] `flutter analyze` passes
- [ ] Barrel file exports public API

---

## Task 5.2: Create Data Models
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Task 5.1

### Steps
1. Create `lib/src/models/`:
   - `analytics_event.dart` - event with type, name, properties, timestamps, idempotency
   - `batch_payload.dart` - complete batch request matching PRD schema v1.0
   - `batch_response.dart` - server response (batch_id, accepted, rejected, warnings)
   - `app_info.dart` - bundle_id, version_name, build_number
   - `device_info.dart` - device_id, platform, os_version, model
   - `user_info.dart` - anonymous_id, user_id
   - `crash_report.dart` - exception type, message, stacktrace, breadcrumbs, fingerprint
   - `trace_event.dart` - trace_id, name, duration_ms, attributes
   - `user_property_op.dart` - operation (set/set_once/increment/unset), key, value
   - `breadcrumb.dart` - timestamp, type, message
2. Implement `toJson()` and `fromJson()` for all models
3. Ensure JSON output matches PRD contract exactly
4. Write unit tests for serialization/deserialization

### Acceptance Criteria
- [ ] All models created with proper JSON serialization
- [ ] JSON output matches PRD schema v1.0 exactly
- [ ] Unit tests verify serialization roundtrip
- [ ] Null safety handled correctly

---

## Task 5.3: Create Configuration Class
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 5.1

### Steps
1. Create `lib/src/config.dart`:
   ```dart
   class AnalyticsConfig {
     final String dsn; // Required. Sentry-like DSN encoding all connection info.
                       // Format: https://<public_key>@<host>/<project-id>/<environment>
                       // Example: https://abc123def456@pulseboard.example.com/proj_uuid/production
     final Duration flushInterval;
     final int flushAt;
     final int maxQueueSize;
     final bool enableCrashReporting;
     final bool enablePerformanceTracing;
     final bool enableSessionTracking;
     final double samplingRate;
     final bool debug;
     final bool consentRequired; // EU: hold events until consent granted

     // Parsed from DSN (read-only getters):
     String get endpoint => _parsedEndpoint;   // https://<host>
     String get publicKey => _parsedPublicKey;  // <public_key> (used as Bearer token)
     String get projectId => _parsedProjectId;  // <project-id>
     String get environment => _parsedEnvironment; // <environment>
   }
   ```
2. Implement DSN parsing logic:
   - Parse DSN as URI: extract `userInfo` as publicKey, `host` as endpoint host, path segments as projectId and environment
   - Validate DSN format: must have scheme (https), userInfo, host, and exactly 2 path segments
   - Throw `ArgumentError` if DSN is malformed
3. Validate other configuration values (sampling rate 0.0-1.0, flushAt > 0, etc.)
4. Provide sensible defaults for non-DSN fields

### Acceptance Criteria
- [ ] DSN parsed correctly into endpoint, publicKey, projectId, environment
- [ ] Invalid DSN throws clear error message
- [ ] Configuration validates all values
- [ ] Defaults are sensible and documented
- [ ] `consentRequired` flag for EU consent mode

---

## Task 5.4: Create HTTP Client
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Tasks 5.2, 5.3

### Steps
1. Create `lib/src/services/http_client.dart`
2. Methods:
   - `sendBatch(BatchPayload payload) -> BatchResponse`
3. Derive endpoint and auth from parsed DSN config:
   - Base URL: `config.endpoint` (extracted from DSN host)
   - POST to `${config.endpoint}/api/v1/ingest/batch`
4. Headers per PRD:
   - `Authorization: Bearer <config.publicKey>` (public key extracted from DSN)
   - `Content-Type: application/json`
   - `X-SDK: flutter`
   - `X-SDK-Version: 0.1.0`
   - `X-Schema-Version: 1.0`
   - `Idempotency-Key: <uuid>` (generated per batch)
5. Handle responses:
   - 202: Parse BatchResponse
   - 422: Parse validation errors, log warnings
   - 429: Rate limited, return with retry-after info
   - 5xx: Server error, throw for retry handling
   - Network error: Throw for offline queue handling
6. Configurable timeout (default 30s)
7. Write tests with mock HTTP client

### Acceptance Criteria
- [ ] Endpoint and auth derived correctly from DSN
- [ ] Sends correct headers with Bearer token from DSN public key
- [ ] Handles all response codes
- [ ] Throws appropriate exceptions for retry logic
- [ ] Timeout configurable
- [ ] Tests cover all response scenarios

---

## Task 5.5: Create Batch Processor
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 5.4

### Steps
1. Create `lib/src/services/batch_processor.dart`
2. Maintains in-memory event queue
3. Flush triggers:
   - Queue size reaches `flushAt`
   - Timer interval reaches `flushInterval`
   - Explicit `flush()` call
   - App going to background
4. Batch construction:
   - Collect queued events
   - Build `BatchPayload` with app info, device info, user info
   - Generate `Idempotency-Key`
5. Response handling:
   - 202: Remove events from queue
   - 429/5xx: Retry with exponential backoff (max 3 retries)
   - Network error: Keep in queue, persist to disk
6. Sampling: drop events based on `samplingRate` before queuing
7. Consent mode: hold events until `consentGranted()` called
8. Write tests

### Acceptance Criteria
- [ ] Flushes at threshold and interval
- [ ] Retry with exponential backoff
- [ ] Network errors trigger persistence
- [ ] Sampling works correctly
- [ ] Consent mode holds events
- [ ] Tests verify all flush triggers

---

## Task 5.6: Create Session Manager
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Task 5.5

### Steps
1. Create `lib/src/services/session_manager.dart`
2. Implements `WidgetsBindingObserver`
3. `didChangeAppLifecycleState`:
   - `resumed`: start new session or resume if within timeout (default 5 min)
   - `paused`/`inactive`: end session (schedule timeout)
4. Generate `session_id` using UUID
5. Track session start time, event count
6. Emit `session_start` and `session_end` events via batch processor
7. Expose `currentSessionId` for tagging events
8. Write widget tests

### Acceptance Criteria
- [ ] Session auto-starts on app foreground
- [ ] Session auto-ends on app background (with timeout)
- [ ] Quick resume doesn't create new session
- [ ] Session events emitted
- [ ] Tests simulate lifecycle changes

---

## Task 5.7: Create Crash Handler
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 5.5

### Steps
1. Create `lib/src/services/crash_handler.dart`
2. Setup:
   - Override `FlutterError.onError` for framework errors
   - Set `PlatformDispatcher.instance.onError` for root isolate errors
   - Preserve original handlers (chain, don't replace)
3. Capture:
   - Exception type and message
   - Stack trace (formatted string)
   - Fatal flag: true for PlatformDispatcher, false for FlutterError
   - Breadcrumbs: last 20 events/interactions before crash
   - Fingerprint: `flutter:{exception_type}:{top_frame_hash}`
4. Breadcrumb collection:
   - Maintain circular buffer of last 20 breadcrumbs
   - Add breadcrumb for: screen views, user taps, network calls, log messages
5. Queue crash events for immediate flush (don't wait for interval)
6. Write tests (mock error handlers)

### Acceptance Criteria
- [ ] Framework errors captured via FlutterError.onError
- [ ] Root isolate errors captured via PlatformDispatcher
- [ ] Breadcrumbs collected and included
- [ ] Fingerprint generated consistently
- [ ] Crash events flushed immediately
- [ ] Original error handlers preserved

---

## Task 5.8: Create Device & App Info Providers
**Priority:** High | **Estimate:** 1-2 hours | **Blocked by:** Task 5.1

### Steps
1. Create `lib/src/services/device_info_provider.dart`
   - Use `device_info_plus` to collect device_id, platform, os_version, model
   - Generate persistent anonymous device_id if not available
   - Cache results (doesn't change during session)
2. Create app info provider using `package_info_plus`
   - Collect bundle_id, version_name, build_number
   - Cache results

### Acceptance Criteria
- [ ] Device info collected on first call, cached
- [ ] App info collected on first call, cached
- [ ] Platform-specific implementations work (Android/iOS)

---

## Task 5.9: Create Offline Persistence
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Tasks 5.1, 5.5

### Steps
1. Create `lib/src/services/persistence.dart`
2. Serialize pending events to JSON file on disk using `path_provider`
3. Load persisted events on SDK initialization
4. Flush persisted events when connectivity restores (use `connectivity_plus`)
5. Limit persisted queue size (configurable, default 1000 events)
6. Handle file corruption gracefully (discard and recreate)
7. Write tests

### Acceptance Criteria
- [ ] Events persist to disk on network failure
- [ ] Persisted events loaded on init
- [ ] Events flushed when connectivity restores
- [ ] Queue size limited
- [ ] Corruption handled gracefully

---

## Task 5.10: Create Main Analytics Client
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Tasks 5.2-5.9

### Steps
1. Create `lib/src/analytics_client.dart` - singleton `AppAnalytics`
2. Public API:
   - `static Future<void> initialize(AnalyticsConfig config)`
   - `static void track(String name, {Map<String, dynamic>? properties})`
   - `static void identify(String userId, {Map<String, dynamic>? properties})`
   - `static void setUserProperty(String key, dynamic value)`
   - `static void setUserPropertyOnce(String key, dynamic value)`
   - `static void incrementUserProperty(String key, num amount)`
   - `static void unsetUserProperty(String key)`
   - `static TraceHandle startTrace(String name, {Map<String, dynamic>? attributes})`
   - `static Future<void> flush()`
   - `static void reset()`
   - `static void optOut()` / `static void optIn()`
   - `static void grantConsent()` / `static void revokeConsent()` (EU consent mode)
3. Orchestrate all services: session, crash, batch, persistence
4. Thread-safe operations
5. Update barrel file exports
6. Write comprehensive tests

### Acceptance Criteria
- [ ] Singleton initializes correctly
- [ ] All public API methods work
- [ ] Services properly orchestrated
- [ ] Consent mode works (EU)
- [ ] Opt-out prevents all tracking
- [ ] Reset clears user identity
- [ ] Tests cover all public API methods

---

## Task 5.11: Create Example App
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 5.10

### Steps
1. Create `example/` directory with Flutter app
2. Demonstrate:
   - SDK initialization with DSN (`AnalyticsConfig(dsn: 'https://abc123@pulseboard.example.com/proj_uuid/production')`)
   - Event tracking on button press
   - User identification
   - Session tracking (auto)
   - Manual trace timing
   - Consent flow (EU)
3. Add README with usage examples

### Acceptance Criteria
- [ ] Example app builds and runs
- [ ] Demonstrates all SDK features
- [ ] Code is well-commented and instructional

---

## Task 5.12: Write SDK Tests
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 5.10

### Steps
1. Unit tests for all models (serialization/deserialization)
2. Unit tests for batch processor (flush triggers, retry, sampling)
3. Unit tests for session manager (lifecycle transitions)
4. Unit tests for crash handler (error capture, breadcrumbs)
5. Unit tests for HTTP client (headers, response handling)
6. Unit tests for offline persistence
7. Unit tests for consent mode
8. Integration test: full track -> batch -> HTTP call flow
9. Run `flutter test` to verify all pass

### Acceptance Criteria
- [ ] All tests pass
- [ ] >80% code coverage
- [ ] Edge cases covered
- [ ] No flaky tests
