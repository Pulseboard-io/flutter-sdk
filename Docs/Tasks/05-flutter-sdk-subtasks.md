# Sub-Tasks: Plan 05 - Flutter SDK

---

## Task 5.1: Initialize Flutter Package

### Sub-task 5.1.1: Create pubspec.yaml
- Write `pubspec.yaml` in `Source Code/flutter-sdk/` with name `app_analytics`, version `0.1.0`
- Set SDK constraints: `sdk: ">=3.0.0 <4.0.0"`, `flutter: ">=3.10.0"`

### Sub-task 5.1.2: Add runtime dependencies
- `http: ^1.2.0`, `shared_preferences: ^2.3.0`, `uuid: ^4.5.0`, `device_info_plus: ^10.1.0`, `package_info_plus: ^8.1.0`, `connectivity_plus: ^6.1.0`, `path_provider: ^2.1.0`

### Sub-task 5.1.3: Add dev dependencies
- `flutter_test` (sdk), `flutter_lints: ^4.0.0`, `mocktail: ^1.0.0`

### Sub-task 5.1.4: Create analysis_options.yaml
- Include `flutter_lints`, enable strict rules: `implicit-casts: false`, `implicit-dynamic: false`

### Sub-task 5.1.5: Create directory structure
- `lib/src/models/`, `lib/src/services/`, `lib/src/utils/`, `test/`, `test/models/`, `test/services/`, `example/lib/`, `example/`

### Sub-task 5.1.6: Create barrel file
- `lib/app_analytics.dart`: export `AppAnalytics`, `AnalyticsConfig`, `TraceHandle`

### Sub-task 5.1.7: Run flutter pub get
- Verify all dependencies resolve without conflicts

### Sub-task 5.1.8: Run flutter analyze
- Ensure zero issues

---

## Task 5.2: Create Data Models

### Sub-task 5.2.1: Create AnalyticsEvent model
- Fields: `type` (string), `eventId` (String, UUID), `name` (String?), `timestamp` (DateTime), `sessionId` (String?), `properties` (Map?), `operations` (List? for user_properties), `fingerprint` (String? for crash), `exception` (Map? for crash), `breadcrumbs` (List? for crash), `fatal` (bool? for crash), `trace` (Map? for trace)
- `toJson()` matches PRD `events[*]` schema exactly
- Factory constructor `fromJson()`

### Sub-task 5.2.2: Create BatchPayload model
- Fields: `schemaVersion`, `sentAt`, `environment`, `app` (AppInfo), `device` (DeviceInfo), `user` (UserInfo), `events` (List<AnalyticsEvent>)
- `toJson()` produces exact PRD batch payload format

### Sub-task 5.2.3: Create BatchResponse model
- Fields: `batchId`, `receivedAt`, `accepted`, `rejected`, `warnings`
- Factory constructor `fromJson()` for parsing 202 response

### Sub-task 5.2.4: Create AppInfo model
- Fields: `bundleId`, `versionName`, `buildNumber`
- `toJson()` / `fromJson()`

### Sub-task 5.2.5: Create DeviceInfo model
- Fields: `deviceId`, `platform`, `osVersion`, `model`
- `toJson()` / `fromJson()`

### Sub-task 5.2.6: Create UserInfo model
- Fields: `anonymousId`, `userId` (nullable)
- `toJson()` / `fromJson()`

### Sub-task 5.2.7: Create CrashReport model
- Fields: `exceptionType`, `message`, `stacktrace`, `breadcrumbs`, `fingerprint`, `fatal`
- Nested in event as `exception` + `breadcrumbs`

### Sub-task 5.2.8: Create TraceEvent model
- Fields: `traceId`, `name`, `durationMs`, `attributes`

### Sub-task 5.2.9: Create UserPropertyOp model
- Fields: `op` (enum: set/set_once/increment/unset), `key`, `value`

### Sub-task 5.2.10: Create Breadcrumb model
- Fields: `ts` (DateTime), `type` (String), `message` (String)

### Sub-task 5.2.11: Write serialization tests
- Test each model `toJson()` output matches PRD schema
- Test roundtrip: `fromJson(model.toJson()) == model`
- Test null fields are omitted or handled correctly
- Test full BatchPayload serialization matches PRD example (lines 140-208)

---

## Task 5.3: Create Configuration Class

### Sub-task 5.3.1: Define AnalyticsConfig class
- Single required parameter: `dsn` (String)
- DSN format: `https://<public_key>@<host>/<project-id>/<environment>`
- Example: `https://abc123def456@pulseboard.example.com/proj_uuid/production`
- All other fields with defaults and named constructor parameters
- Parsed DSN fields exposed as read-only getters: `endpoint`, `publicKey`, `projectId`, `environment`

### Sub-task 5.3.2: Implement DSN parsing logic
- Parse DSN string as `Uri`
- Extract `publicKey` from `uri.userInfo` (the portion before `@`)
- Extract `endpoint` as `https://${uri.host}` (with port if non-standard)
- Extract `projectId` from first path segment (e.g., `/proj_uuid/production` -> `proj_uuid`)
- Extract `environment` from second path segment (e.g., `/proj_uuid/production` -> `production`)
- Store parsed values in private fields: `_parsedEndpoint`, `_parsedPublicKey`, `_parsedProjectId`, `_parsedEnvironment`

### Sub-task 5.3.3: Add DSN validation in constructor
- `dsn`: assert not empty
- `dsn`: assert valid URI with `https` scheme
- `dsn`: assert `userInfo` is not empty (public key required)
- `dsn`: assert host is not empty
- `dsn`: assert exactly 2 non-empty path segments (project-id and environment)
- Throw `ArgumentError` with descriptive message for any DSN format violation
- `samplingRate`: assert between 0.0 and 1.0
- `flushAt`: assert > 0
- `maxQueueSize`: assert > 0

### Sub-task 5.3.4: Define default values
- `flushInterval`: `Duration(seconds: 30)`, `flushAt`: 20, `maxQueueSize`: 1000, `enableCrashReporting`: true, `enablePerformanceTracing`: true, `enableSessionTracking`: true, `samplingRate`: 1.0, `debug`: false, `consentRequired`: false
- Note: `environment` is no longer a default value; it is always parsed from the DSN

### Sub-task 5.3.5: Write config tests
- Test valid DSN parses correctly (endpoint, publicKey, projectId, environment extracted)
- Test DSN `https://mykey@analytics.example.com/proj123/staging` extracts all fields
- Test invalid DSN (no scheme) throws ArgumentError
- Test invalid DSN (no public key / userInfo) throws ArgumentError
- Test invalid DSN (missing path segments) throws ArgumentError
- Test invalid DSN (only 1 path segment) throws ArgumentError
- Test invalid sampling rate throws
- Test defaults are applied for non-DSN fields

---

## Task 5.4: Create HTTP Client

### Sub-task 5.4.1: Create AnalyticsHttpClient class
- Constructor: `AnalyticsConfig config`, `http.Client httpClient` (injectable for testing)
- Derive base URL from DSN: `config.endpoint` (parsed from DSN host)
- Derive auth key from DSN: `config.publicKey` (parsed from DSN userInfo)

### Sub-task 5.4.2: Implement sendBatch method
- Serialize BatchPayload to JSON
- Build headers with DSN-derived values:
  - `Authorization: Bearer ${config.publicKey}` (public key parsed from DSN)
  - `Content-Type: application/json`
  - `X-SDK: flutter`
  - `X-SDK-Version: 0.1.0`
  - `X-Schema-Version: 1.0`
  - `Idempotency-Key: <uuid>`
- POST to `${config.endpoint}/api/v1/ingest/batch`
- Set timeout from config

### Sub-task 5.4.3: Implement response handling
- 202: parse body as BatchResponse, return
- 422: parse validation errors, log warnings, throw `ValidationException`
- 429: extract `Retry-After` header, throw `RateLimitedException` with delay info
- 5xx: throw `ServerException`
- Network error (SocketException): throw `NetworkException`

### Sub-task 5.4.4: Create custom exception classes
- `AnalyticsException` (base), `ValidationException`, `RateLimitedException`, `ServerException`, `NetworkException`

### Sub-task 5.4.5: Write HTTP client tests with mocktail
- Mock `http.Client`
- Test 202 response parsed correctly
- Test 422 throws ValidationException with details
- Test 429 throws RateLimitedException with retry-after
- Test 500 throws ServerException
- Test network failure throws NetworkException
- Test correct headers sent (Bearer token from DSN public key)
- Test endpoint URL derived correctly from DSN host
- Test with DSN: `https://testkey123@api.example.com/proj_abc/staging` sends to `https://api.example.com/api/v1/ingest/batch` with `Authorization: Bearer testkey123`

---

## Task 5.5: Create Batch Processor

### Sub-task 5.5.1: Create BatchProcessor class
- Fields: event queue (List), timer (Timer?), config ref, httpClient ref, persistence ref

### Sub-task 5.5.2: Implement enqueue method
- Apply sampling: `if (Random().nextDouble() > config.samplingRate) return`
- Check consent mode: if `consentRequired && !consentGranted`, hold in pending queue
- Add event to queue
- Check if queue size >= flushAt → trigger flush

### Sub-task 5.5.3: Implement timer-based flush
- Start periodic timer on init: `Timer.periodic(config.flushInterval, (_) => flush())`
- Cancel timer on dispose

### Sub-task 5.5.4: Implement flush method
- If queue empty, return
- Take events from queue (up to flushAt)
- Build BatchPayload
- Try sendBatch via HTTP client
- On 202: remove events from queue
- On 429/5xx: schedule retry with exponential backoff
- On network error: persist to disk, don't remove from queue

### Sub-task 5.5.5: Implement retry with exponential backoff
- Retry delays: 1s, 5s, 30s (max 3 retries per batch)
- On final failure: persist events to disk

### Sub-task 5.5.6: Implement consent mode
- If `consentRequired`: events go to `_pendingConsentQueue`
- On `grantConsent()`: move all pending to main queue, flush
- On `revokeConsent()`: clear pending queue

### Sub-task 5.5.7: Write batch processor tests
- Test enqueue adds to queue
- Test flush at threshold
- Test timer flush at interval
- Test 202 removes events
- Test network error triggers persistence
- Test retry with backoff
- Test sampling drops events at configured rate
- Test consent mode holds events

---

## Task 5.6: Create Session Manager

### Sub-task 5.6.1: Create SessionManager class implementing WidgetsBindingObserver
- Fields: `_currentSessionId`, `_sessionStartTime`, `_eventCount`, `_backgroundTimer`, `_sessionTimeout`

### Sub-task 5.6.2: Implement init and registration
- `init()`: register as observer with `WidgetsBinding.instance.addObserver(this)`
- Start initial session
- `dispose()`: remove observer

### Sub-task 5.6.3: Implement didChangeAppLifecycleState
- `resumed`: cancel background timer, if session expired create new, else resume
- `paused`/`inactive`: start background timer (default 5 min timeout)
- `detached`: end session immediately

### Sub-task 5.6.4: Implement session start
- Generate `_currentSessionId` via UUID
- Record `_sessionStartTime`
- Emit `session_start` event via callback

### Sub-task 5.6.5: Implement session end
- Calculate duration
- Emit `session_end` event with duration and event count
- Reset session state

### Sub-task 5.6.6: Expose public API
- `String? get currentSessionId`
- `void incrementEventCount()`

### Sub-task 5.6.7: Write session manager tests
- Test session starts on init
- Test lifecycle resumed after short pause doesn't create new session
- Test lifecycle resumed after long pause creates new session
- Test session_start and session_end events emitted

---

## Task 5.7: Create Crash Handler

### Sub-task 5.7.1: Create CrashHandler class
- Fields: `_breadcrumbs` (circular buffer), `_originalFlutterError`, `_originalPlatformError`

### Sub-task 5.7.2: Implement setup
- Save original handlers: `_originalFlutterError = FlutterError.onError`
- Override: `FlutterError.onError = _handleFlutterError`
- `PlatformDispatcher.instance.onError = _handlePlatformError`

### Sub-task 5.7.3: Implement _handleFlutterError
- Extract exception type, message, stack trace
- Generate fingerprint: `flutter:${exceptionType}:${topFrameHash}`
- Create crash event (fatal: false)
- Call original handler
- Queue for immediate flush

### Sub-task 5.7.4: Implement _handlePlatformError
- Same extraction
- Fatal: true
- Call original handler (return true)
- Queue for immediate flush

### Sub-task 5.7.5: Implement breadcrumb collection
- Circular buffer of last 20 items
- `addBreadcrumb(String type, String message)` method
- Types: `ui`, `network`, `log`, `navigation`

### Sub-task 5.7.6: Implement fingerprint generation
- Format: `flutter:{exception_type}:{hash_of_top_stack_frame}`
- Parse top frame from stack trace string
- Hash using simple string hash

### Sub-task 5.7.7: Implement teardown
- Restore original handlers on dispose

### Sub-task 5.7.8: Write crash handler tests
- Test FlutterError.onError captures error
- Test PlatformDispatcher.onError captures error
- Test breadcrumbs included in crash event
- Test fingerprint generated consistently
- Test original handlers preserved and called
- Test crash events marked for immediate flush

---

## Task 5.8-5.9: Device/App Info & Offline Persistence

### Sub-task 5.8.1: Create DeviceInfoProvider
- Use `device_info_plus` to get platform info
- Generate/load persistent anonymous device_id via SharedPreferences
- Cache after first call

### Sub-task 5.8.2: Create AppInfoProvider
- Use `package_info_plus` to get app metadata
- Cache after first call

### Sub-task 5.9.1: Create EventPersistence service
- File path: `${appDocDir}/app_analytics_queue.json`
- `save(List<AnalyticsEvent> events)`: serialize to JSON, write to file
- `load(): List<AnalyticsEvent>`: read file, deserialize
- `clear()`: delete file

### Sub-task 5.9.2: Implement queue size limit
- If persisted queue exceeds `maxQueueSize`, drop oldest events

### Sub-task 5.9.3: Implement corruption handling
- If JSON parse fails: log warning, delete file, return empty list

### Sub-task 5.9.4: Implement connectivity monitoring
- Use `connectivity_plus` to detect connectivity changes
- On connectivity restored: trigger flush of persisted events

### Sub-task 5.9.5: Write persistence tests
- Test save and load roundtrip
- Test queue size limit enforced
- Test corruption handled gracefully
- Test connectivity change triggers flush

---

## Task 5.10: Create Main Analytics Client

### Sub-task 5.10.1: Create AppAnalytics singleton
- Private constructor
- Static instance with null check for initialization

### Sub-task 5.10.2: Implement initialize()
- Create and wire all services: HttpClient, BatchProcessor, SessionManager, CrashHandler, DeviceInfoProvider, AppInfoProvider, Persistence
- Load persisted events
- Start session manager
- Set up crash handler (if enabled)

### Sub-task 5.10.3: Implement track()
- Create AnalyticsEvent with type=event
- Add session_id from SessionManager
- Enqueue via BatchProcessor

### Sub-task 5.10.4: Implement identify()
- Update UserInfo with userId
- Optionally set user properties

### Sub-task 5.10.5: Implement user property methods
- Each creates AnalyticsEvent with type=user_properties and appropriate operation

### Sub-task 5.10.6: Implement startTrace()
- Return TraceHandle that records start time
- TraceHandle.stop() calculates duration, creates trace event

### Sub-task 5.10.7: Implement consent methods
- `grantConsent()`: set flag, flush pending events
- `revokeConsent()`: set flag, clear pending

### Sub-task 5.10.8: Implement optOut/optIn
- `optOut()`: stop all tracking, clear queue
- `optIn()`: resume tracking

### Sub-task 5.10.9: Implement reset()
- Clear user identity, generate new anonymous_id, clear queue

### Sub-task 5.10.10: Update barrel file exports

### Sub-task 5.10.11: Write comprehensive tests for all public methods

---

## Task 5.11-5.12: Example App & SDK Tests

### Sub-task 5.11.1: Create example app pubspec.yaml with SDK dependency (path)
### Sub-task 5.11.2: Create example main.dart demonstrating all features
- Initialize SDK with DSN: `AppAnalytics.initialize(AnalyticsConfig(dsn: 'https://wk_abc123@pulseboard.example.com/proj_uuid/production'))`
- Show that no separate endpoint, writeKey, or environment config is needed
### Sub-task 5.11.3: Add consent flow example (EU)

### Sub-task 5.12.1-5.12.8: One test file per service (see Task 5.12 steps)
### Sub-task 5.12.9: Integration test with mock server
### Sub-task 5.12.10: Run `flutter test` → all pass
