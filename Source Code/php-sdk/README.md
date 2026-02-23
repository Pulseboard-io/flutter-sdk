# Pulseboard PHP SDK

Pulseboard analytics SDK for PHP.

Pulseboard is a product of [Pixel & Process](https://pixelandprocess.de).

## Install

```bash
composer require pulseboard/php-sdk
```

## Usage

```php
<?php

use Pulseboard\Sdk\Client;
use Pulseboard\Sdk\Config;

// Initialize with your DSN
$client = Client::init('https://wk_YOUR_KEY@api.pulseboard.example.com/PROJECT_ID/production');

// Optional config
$config = new Config(
    dsn: 'https://...',
    appId: 'my-app',
    appVersion: '1.0.0',
    buildNumber: '1',
);
$client = Client::init($config->dsn, $config);

// Track events
$client->track('page_view', ['path' => '/', 'title' => 'Home']);

// Identify user
$client->identify('user_123');

// User properties
$client->setUserProperties([
    ['op' => 'set', 'key' => 'plan', 'value' => 'pro'],
]);

// Capture exceptions
try {
    // ...
} catch (\Throwable $e) {
    $client->captureException($e, fingerprint: null, fatal: true);
}

// Performance trace
$client->trace('request_handled', 150, ['route' => '/api/users']);

// Flush before shutdown
$client->flush();
```

## API

- `Client::init(string $dsn, ?Config $config = null, ?ClientInterface $httpClient = null)` – Initialize the SDK
- `track(string $name, array $properties = [])` – Track a named event
- `identify(?string $userId)` – Set the current user ID
- `setUserProperties(array $operations)` – Set user properties (set, set_once, increment, unset)
- `captureException(\Throwable $e, ?string $fingerprint = null, bool $fatal = false)` – Send a crash event
- `trace(string $name, int $durationMs, array $attributes = [])` – Record a performance trace
- `flush()` – Send queued events to the server

Events are batched (50 per request) and sent to `POST /api/v1/ingest/batch`. Schema version: 1.0.

## License

MIT. See [LICENSE](LICENSE).
