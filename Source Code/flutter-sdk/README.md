# pulseboard_analytics

Pulseboard Flutter analytics SDK: event tracking, crash reporting, performance tracing, and user properties for Flutter apps. GDPR-aware and configurable via a single DSN.

- **Dart** `>=3.0.0 <4.0.0`
- **Flutter** `>=3.10.0`

## Features

- **Custom events** with optional properties and automatic session context
- **Automatic sessionization** based on app lifecycle (foreground/background)
- **User identification** and **user properties**: `set`, `set_once`, `increment`, `unset`
- **Crash reporting** for Flutter framework errors and root-isolate unhandled errors, with **breadcrumbs**
- **Performance traces** with start/stop and custom attributes
- **DSN-based configuration**: one string for endpoint, key, project, and environment
- **Batched upload** with configurable batch size and interval; **offline persistence**
- **Consent and opt-out**: `grantConsent` / `revokeConsent`, `optIn` / `optOut` for EU and privacy compliance
- **Reset** (new anonymous ID and session) and **shutdown** for clean teardown

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  pulseboard_analytics: ^0.1.0
```

Then run:

```bash
flutter pub get
```

For local development you can use a path dependency:

```yaml
dependencies:
  pulseboard_analytics:
    path: ../path/to/flutter-sdk
```

## Quick start

Initialize the SDK once in `main()` after `WidgetsFlutterBinding.ensureInitialized()`. You get your DSN from your Pulseboard project settings (per-environment).

```dart
import 'package:pulseboard_analytics/pulseboard_analytics.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AppAnalytics.initialize(
    AnalyticsConfig(
      dsn: 'https://wk_YOUR_KEY@pulseboard.example.com/PROJECT_ID/production',
      debug: true, // optional: enable SDK debug logs
    ),
  );

  runApp(const MyApp());
}
```

Then use the singleton to track events and identify users:

```dart
AppAnalytics.instance.track('screen_view', properties: {'screen': 'Home'});
AppAnalytics.instance.identify('user_123');
```

## DSN configuration

The SDK uses a **DSN (Data Source Name)** to configure the API endpoint, authentication, project, and environment in one string.

**Format:** `https://<public_key>@<host>/<project-id>/<environment>`

**Example:** `https://wk_abc123@pulseboard.example.com/proj_uuid/production`

- **public_key** — Used as the Bearer token for ingest requests (no separate endpoint or key config).
- **host** — Your Pulseboard API host (e.g. `pulseboard.example.com`).
- **project-id** — Project UUID from Pulseboard.
- **environment** — Environment name (e.g. `production`, `staging`).

Invalid DSNs throw `FormatException` at config construction.

## Configuration options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `dsn` | `String` | required | Full DSN string. |
| `flushAt` | `int` | `20` | Max events per batch (API max 500). |
| `flushIntervalSeconds` | `int` | `30` | Flush interval in seconds. |
| `debug` | `bool` | `false` | Enable SDK debug logging. |
| `sampleRate` | `double` | `1.0` | Sampling rate 0.0–1.0 (1.0 = send all). |
| `maxRetries` | `int` | `3` | Retry attempts for failed requests. |
| `sessionTimeoutMinutes` | `int` | `5` | Session timeout for resume detection. |
| `maxBreadcrumbs` | `int` | `20` | Max breadcrumbs kept for crash reports. |
| `maxPersistedEvents` | `int` | `1000` | Max events persisted offline. |

## API reference

### Initialization

- **`AppAnalytics.initialize(AnalyticsConfig config, {http.Client? httpClient})`**  
  Returns `Future<AppAnalytics>`. Call once before any other SDK usage; safe to call again (returns existing instance).

- **`AppAnalytics.instance`**  
  Singleton getter. Throws `StateError` if not initialized.

- **`AppAnalytics.isInitialized`**  
  `bool` — whether the SDK has been initialized.

### Events

- **`track(String name, {Map<String, dynamic>? properties})`**  
  Track a named event with optional properties. Session is attached automatically.

### User

- **`identify(String userId)`**  
  Set the current user ID.
- **`setUserProperty(String key, dynamic value)`**  
  Set a user property (overwrites).
- **`setUserPropertyOnce(String key, dynamic value)`**  
  Set a user property only if not already set.
- **`incrementUserProperty(String key, num value)`**  
  Increment a numeric user property.
- **`unsetUserProperty(String key)`**  
  Remove a user property.

### Performance traces

- **`startTrace(String name)`**  
  Returns a `Trace` handle.
- **`Trace.putAttribute(String key, dynamic value)`**  
  Add an attribute to the trace.
- **`Trace.stop()`**  
  End the trace and send it (duration and attributes included).

### Crash context

- **`addBreadcrumb({required String type, required String message})`**  
  Add a breadcrumb for crash context. Crashes are captured automatically once the SDK is initialized (Flutter framework and root-isolate errors); breadcrumbs enrich crash reports.

### Consent and privacy

- **`grantConsent()`**  
  Grant consent for data collection (e.g. after user accepts).
- **`revokeConsent()`**  
  Revoke consent; queued events are cleared.
- **`optOut()`**  
  Opt out of all tracking; clears queue.
- **`optIn()`**  
  Opt back in to tracking.

### Lifecycle

- **`flush()`**  
  `Future<void>` — Flush all queued events immediately.
- **`reset()`**  
  `Future<void>` — Reset SDK state: new anonymous ID, clear user, new session.
- **`shutdown()`**  
  `Future<void>` — Shut down the SDK and release resources (uninstall crash handler, stop session, flush and stop batch processor).

### Read-only

- **`config`**  
  Current `AnalyticsConfig` (read-only).

## EU / privacy

The SDK is designed with GDPR in mind:

- **Consent**: Use `grantConsent()` and `revokeConsent()` to gate collection on user consent; events can be held until consent is granted.
- **Opt-out**: `optOut()` and `optIn()` let users stop or resume tracking; opt-out clears the queue.
- **Reset**: `reset()` gives a new anonymous ID and session, useful for user choice or DSAR-style resets.
- **Data minimization**: No PII in default device/app metadata; only what you send via events and user properties is recorded.

## Example app

The `example/` app demonstrates the main APIs: track, identify, user properties (set, set_once, increment, unset), traces, breadcrumbs, flush, opt-in/opt-out, consent, and reset.

From the SDK root:

```bash
cd example
flutter pub get
flutter run
```

## Development and testing

- **Tests:** `flutter test`
- **Analyze:** `flutter analyze`

**Dependencies:** `http`, `uuid`, `shared_preferences`, `device_info_plus`, `package_info_plus`, `connectivity_plus`, `path_provider`.  
**Dev dependencies:** `flutter_test`, `flutter_lints`, `mocktail`.

Events are sent to `POST /api/v1/ingest/batch` with schema version **1.0**.

## License

See repository root or project documentation for license information.
