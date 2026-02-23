# Pulseboard Laravel

Pulseboard analytics SDK for Laravel. Uses [pulseboard/php-sdk](https://github.com/pixelandprocess/pulseboard-php-sdk) under the hood.

Pulseboard is a product of [Pixel & Process](https://pixelandprocess.de).

## Install

```bash
composer require pulseboard/laravel
```

Publish config (optional):

```bash
php artisan vendor:publish --tag=pulseboard-config
```

## Configuration

In `.env`:

```
PULSEBOARD_DSN=https://wk_YOUR_KEY@api.pulseboard.example.com/PROJECT_ID/production
PULSEBOARD_APP_NAME=my-app
PULSEBOARD_APP_VERSION=1.0.0
```

Or in `config/pulseboard.php` after publishing.

## Usage

```php
use Pulseboard\Laravel\Facades\Pulseboard;

// Track events
Pulseboard::track('page_view', ['path' => request()->path()]);

// Identify user (e.g. after login)
Pulseboard::identify(auth()->id());

// User properties
Pulseboard::setUserProperties([
    ['op' => 'set', 'key' => 'plan', 'value' => 'pro'],
]);

// Capture exceptions (e.g. in report() in App\Exceptions\Handler)
Pulseboard::captureException($e, fatal: true);

// Performance trace
Pulseboard::trace('request', (int) ((microtime(true) - $start) * 1000));

// Flush before response (optional; batching handles this)
Pulseboard::flush();
```

When `PULSEBOARD_DSN` is not set, all methods no-op.

## Exception reporting

In `App\Exceptions\Handler::register()` or `reportable()`:

```php
use Pulseboard\Laravel\Facades\Pulseboard;

$this->reportable(function (\Throwable $e) {
    if (Pulseboard::isConfigured()) {
        Pulseboard::captureException($e, fatal: true);
    }
});
```

## License

MIT. See [LICENSE](LICENSE).
