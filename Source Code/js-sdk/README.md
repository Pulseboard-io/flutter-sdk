# @pulseboard/sdk

Pulseboard analytics SDK for JavaScript and TypeScript (browser and Node.js).

Pulseboard is a product of [Pixel & Process](https://pixelandprocess.de).

## Install

```bash
npm install @pulseboard/sdk
```

## Usage

```javascript
import { init, track, identify, captureException, flushEvents } from '@pulseboard/sdk';

// Initialize with your DSN (from project settings)
init({ dsn: 'https://wk_YOUR_KEY@api.pulseboard.example.com/PROJECT_ID/production' });

// Track events
track('page_view', { path: '/', title: 'Home' });

// Identify user
identify('user_123');

// Capture exceptions
try {
  // ...
} catch (err) {
  captureException(err, { fatal: true });
}

// Flush before page unload (browser)
window.addEventListener('beforeunload', () => flushEvents());
```

## API

- `init(config)` – Initialize with DSN and optional app/version
- `track(name, properties?)` – Track a named event
- `identify(userId)` – Set the current user ID
- `setUserProperties(operations)` – Set user properties (set, set_once, increment, unset)
- `captureException(error, options?)` – Send a crash event
- `trace(name, durationMs, attributes?)` – Record a performance trace
- `flushEvents()` – Flush queued events to the server
- `isInitialized()` – Return whether the SDK has been initialized

Events are batched and sent to `POST /api/v1/ingest/batch`. Schema version: 1.0.

## License

MIT. See [LICENSE](LICENSE).
