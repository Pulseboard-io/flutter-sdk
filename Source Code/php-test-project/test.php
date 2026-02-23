<?php

require_once __DIR__ . '/vendor/autoload.php';

use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use Pulseboard\Sdk\Client;

// DSN: scheme://public_key@host/project_id/environment (host must not include scheme)
$dsn = 'http://wk_WXQrLDETAKKBRWG9qbnPIYZboILzYuz0VIIxQlbfsl1hVgVQ@aa-api.test/019c8c55-71c1-731e-b287-a13b4bd411b6/production';

// Capture last HTTP response so we can surface API errors
$lastResponse = null;
$handler = HandlerStack::create();
$handler->push(Middleware::mapResponse(function ($response) use (&$lastResponse) {
    $lastResponse = $response;

    return $response;
}));
$httpClient = new \GuzzleHttp\Client([
    'handler' => $handler,
    'http_errors' => false,
    'timeout' => 10,
]);

$client = Client::init($dsn, null, $httpClient);
$client->track('page_view', ['path' => '/test']);

// Performance: measure real work and send traces (shows in project Performance explorer)
$t0 = hrtime(true);
usleep(50_000); // simulate 50ms work
$client->trace('database_query', (int) round((hrtime(true) - $t0) / 1e6), [
    'query' => 'SELECT * FROM users',
    'table' => 'users',
]);

$t0 = hrtime(true);
usleep(120_000); // simulate 120ms work
$client->trace('api_request', (int) round((hrtime(true) - $t0) / 1e6), [
    'endpoint' => '/api/v1/projects',
    'method' => 'GET',
    'status' => 200,
]);

// Simulate a crash: throw, catch, and report to Pulseboard
try {
    throw new \RuntimeException('Simulated crash from PHP test project');
} catch (\Throwable $e) {
    $client->captureException($e, fatal: true);
}

$client->flush();

if ($lastResponse === null) {
    echo "No request was sent (queue was empty or send failed silently).\n";
    exit(1);
}

$status = $lastResponse->getStatusCode();
$body = (string) $lastResponse->getBody();

if ($status === 202) {
    echo "OK: Batch accepted (202). Events are queued for processing.\n";
    echo "If you still don't see events in the project:\n";
    echo "  1. Run a queue worker for the 'ingest' queue:\n";
    echo "     php artisan queue:work --queue=ingest\n";
    echo "     (or run Horizon: php artisan horizon)\n";
    echo "  2. Check the project's environment matches (e.g. production).\n";
    exit(0);
}

echo "API error: HTTP {$status}\n";
echo $body !== '' ? "Body: {$body}\n" : "(no body)\n";
exit(1);
