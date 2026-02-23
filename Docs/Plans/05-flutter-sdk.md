# Plan 05: Flutter SDK

## Objective
Build the Flutter analytics SDK (`app_analytics`) for the Pulseboard platform that supports events, sessions, user properties, crash reports, and performance traces with offline queue, batching, and privacy controls.

## Current State
- `Source Code/flutter-sdk/` directory is completely empty
- No pubspec.yaml, no Dart files, no structure whatsoever

## Target State
- Published-ready Flutter package with:
  - Event tracking (custom events with properties)
  - Automatic session management via lifecycle hooks
  - User identification and property management
  - Crash capture (Flutter framework errors + platform errors)
  - Performance trace capture
  - Offline queue with persistence
  - Batch API calls with configurable flush intervals
  - Idempotency key generation
  - Privacy controls (opt-out, sampling, redaction)
  - Schema versioning (v1.0)

## Package Architecture
```
flutter-sdk/
├── lib/
│   ├── app_analytics.dart              # Public API barrel file
│   └── src/
│       ├── analytics_client.dart       # Main client class (singleton)
│       ├── config.dart                 # SDK configuration
│       ├── models/
│       │   ├── event.dart              # Event model
│       │   ├── batch_payload.dart      # Batch request payload
│       │   ├── batch_response.dart     # Batch response model
│       │   ├── app_info.dart           # App metadata
│       │   ├── device_info.dart        # Device metadata
│       │   ├── user_info.dart          # User identity
│       │   ├── crash_report.dart       # Crash event model
│       │   ├── trace.dart              # Performance trace model
│       │   └── user_property_op.dart   # Property operation model
│       ├── services/
│       │   ├── http_client.dart        # HTTP client for API calls
│       │   ├── batch_processor.dart    # Batch queue + flush logic
│       │   ├── session_manager.dart    # Lifecycle-based sessions
│       │   ├── crash_handler.dart      # Error capture setup
│       │   ├── device_info_provider.dart # Platform device info
│       │   └── persistence.dart        # Local storage for offline queue
│       └── utils/
│           ├── id_generator.dart       # UUID/idempotency key generation
│           ├── clock.dart              # Testable clock abstraction
│           └── logger.dart             # Internal SDK logging
├── test/
│   ├── analytics_client_test.dart
│   ├── batch_processor_test.dart
│   ├── session_manager_test.dart
│   ├── crash_handler_test.dart
│   ├── http_client_test.dart
│   └── models/
│       └── batch_payload_test.dart
├── example/
│   ├── lib/main.dart
│   └── pubspec.yaml
├── pubspec.yaml
├── analysis_options.yaml
├── CHANGELOG.md
├── LICENSE
└── README.md
```

## Implementation Steps

### 5.1 Package Initialization
- Create `pubspec.yaml` with dependencies:
  - `http: ^1.0.0` (HTTP client)
  - `shared_preferences: ^2.0.0` (persistence)
  - `uuid: ^4.0.0` (ID generation)
  - `device_info_plus: ^10.0.0` (device metadata)
  - `package_info_plus: ^8.0.0` (app metadata)
  - `connectivity_plus: ^6.0.0` (network state)
  - `path_provider: ^2.0.0` (file storage for offline queue)
- Create `analysis_options.yaml` with strict lint rules
- Set SDK constraint: `>=3.0.0 <4.0.0`

### 5.2 Configuration & Client
- `AnalyticsConfig` class:
  - `dsn` (required) - Sentry-like Data Source Name encoding all connection details
    - Format: `https://<public_key>@<host>/<project-id>/<environment>`
    - Example: `https://abc123def456@pulseboard.example.com/proj_uuid/production`
    - The SDK parses the DSN to extract:
      - `host` -> API endpoint (e.g., `https://pulseboard.example.com`)
      - `public_key` (userinfo portion) -> Authentication key (sent as `Bearer <public_key>`)
      - `project-id` (first path segment) -> Project identifier
      - `environment` (second path segment) -> Environment name (e.g., production, staging)
    - No separate `writeKey`, `endpoint`, or `environment` fields needed
  - `flushInterval` (default: 30 seconds)
  - `flushAt` (default: 20 events)
  - `maxQueueSize` (default: 1000)
  - `enableCrashReporting` (default: true)
  - `enablePerformanceTracing` (default: true)
  - `enableSessionTracking` (default: true)
  - `samplingRate` (default: 1.0, range 0.0-1.0)
  - `debug` (default: false)
- `AppAnalytics` singleton class with:
  - `initialize(AnalyticsConfig config)`
  - `track(String name, {Map<String, dynamic>? properties})`
  - `identify(String userId, {Map<String, dynamic>? properties})`
  - `alias(String newId)`
  - `setUserProperty(String key, dynamic value)`
  - `setUserPropertyOnce(String key, dynamic value)`
  - `incrementUserProperty(String key, num amount)`
  - `unsetUserProperty(String key)`
  - `startTrace(String name, {Map<String, dynamic>? attributes}) -> TraceHandle`
  - `flush()`
  - `reset()` (clear user identity, useful for logout)
  - `optOut()` / `optIn()`

### 5.3 Session Manager
- Uses `WidgetsBindingObserver.didChangeAppLifecycleState`
- Auto-starts session on app foreground
- Auto-ends session on app background (with configurable timeout for quick resume)
- Generates `session_id` as UUID
- Tracks session duration and event count
- Emits `session_start` and `session_end` as system events

### 5.4 Crash Handler
- Set up `FlutterError.onError` for framework-caught errors
- Set up `PlatformDispatcher.instance.onError` for root isolate unhandled errors
- Capture:
  - Exception type and message
  - Stack trace (formatted)
  - Breadcrumbs (last N UI/network/log events before crash)
  - Fatal flag (true for unhandled, false for caught)
  - Fingerprint generation (exception type + top frame hash)
- Queue crash events for batch submission

### 5.5 Batch Processor
- Maintains in-memory queue of events
- Flushes when:
  - Queue reaches `flushAt` threshold
  - Timer reaches `flushInterval`
  - `flush()` called explicitly
  - App going to background (best-effort)
- Constructs batch payload per PRD schema (v1.0)
- Handles HTTP responses:
  - 202: Success, remove from queue
  - 422: Validation error, log and discard (malformed events)
  - 429: Rate limited, retry with exponential backoff
  - 5xx: Server error, retry with backoff
  - Network error: Keep in queue, persist to disk

### 5.6 Offline Persistence
- Serialize pending events to JSON file on disk
- Load on SDK initialization
- Flush persisted events on connectivity restore
- Limit persisted queue size to prevent disk abuse

### 5.7 HTTP Client
- Uses `package:http` for API calls
- Derives endpoint and auth from parsed DSN:
  - Base URL: `https://<host>` extracted from DSN
  - Authorization header: `Bearer <public_key>` where `public_key` is the userinfo from DSN
- Sends headers: `Authorization`, `Content-Type`, `X-SDK`, `X-SDK-Version`, `X-Schema-Version`, `Idempotency-Key`
- Configurable timeout
- Response parsing into `BatchResponse` model

### 5.8 Device & App Info Providers
- Use `device_info_plus` to collect: device_id, platform, os_version, model
- Use `package_info_plus` to collect: bundle_id, version_name, build_number
- Cache info on first collection (doesn't change during session)

### 5.9 Performance Traces
- `startTrace(name)` returns a `TraceHandle`
- `TraceHandle.stop()` records duration and queues trace event
- Optional: integrate with Dart `Timeline` for CPU/wall-time segments
- Attributes can be added to traces

## Dependencies
- Plan 04 (Ingestion API must exist for integration testing)
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0

## Testing Requirements
- Unit test: event tracking adds to queue
- Unit test: session manager starts/stops on lifecycle changes
- Unit test: crash handler captures FlutterError and PlatformDispatcher errors
- Unit test: batch processor flushes at threshold and interval
- Unit test: offline persistence saves and loads events
- Unit test: HTTP client sends correct headers and payload format
- Unit test: user property operations generate correct event types
- Unit test: sampling rate correctly filters events
- Unit test: opt-out prevents all event tracking
- Integration test: full flow from track() to batch POST (with mock server)
- Widget test: session manager integrates with app lifecycle

## Estimated Effort
6-10 person-weeks

## Key Decisions
- Use `http` package (not `dio`) for minimal dependency footprint
- Singleton pattern for `AppAnalytics` for easy global access
- JSON file persistence (not SQLite) for simplicity in MVP
- Schema version hardcoded to "1.0" in MVP
