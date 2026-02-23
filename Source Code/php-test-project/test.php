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

// Random event names and sample properties
$eventTemplates = [
    'page_view' => fn () => ['path' => ['/', '/dashboard', '/settings', '/profile', '/api-docs'][array_rand(['/', '/dashboard', '/settings', '/profile', '/api-docs'])], 'title' => 'Test Page'],
    'button_clicked' => fn () => ['button' => ['submit', 'cancel', 'save', 'delete', 'refresh'][array_rand(['submit', 'cancel', 'save', 'delete', 'refresh'])], 'section' => ['header', 'sidebar', 'modal'][array_rand(['header', 'sidebar', 'modal'])]],
    'search_performed' => fn () => ['query' => 'query_' . bin2hex(random_bytes(4)), 'results_count' => random_int(0, 100)],
    'item_viewed' => fn () => ['item_id' => (string) random_int(1000, 9999), 'category' => ['A', 'B', 'C'][array_rand(['A', 'B', 'C'])]],
    'form_submitted' => fn () => ['form' => ['login', 'signup', 'contact'][array_rand(['login', 'signup', 'contact'])], 'valid' => (bool) random_int(0, 1)],
    'api_called' => fn () => ['endpoint' => '/api/v' . random_int(1, 2) . '/items', 'method' => ['GET', 'POST', 'PUT'][array_rand(['GET', 'POST', 'PUT'])], 'status' => [200, 201, 400, 404][array_rand([200, 201, 400, 404])]],
];

// Random crash messages and exception types
$crashTemplates = [
    ['class' => \RuntimeException::class, 'messages' => ['Simulated runtime error', 'Operation failed', 'Resource unavailable', 'Timeout exceeded']],
    ['class' => \InvalidArgumentException::class, 'messages' => ['Invalid user input', 'Bad request parameter', 'Missing required field']],
    ['class' => \LogicException::class, 'messages' => ['Invalid state transition', 'Unexpected flow', 'Assertion failed']],
];

$numEvents = random_int(8, 20);
$numCrashes = random_int(2, 5);

for ($i = 0; $i < $numEvents; $i++) {
    $name = array_rand($eventTemplates);
    $props = $eventTemplates[$name]();
    $client->track($name, $props);
}

// Performance traces (keep a couple)
$t0 = hrtime(true);
usleep(random_int(20_000, 80_000));
$client->trace('database_query', (int) round((hrtime(true) - $t0) / 1e6), ['query' => 'SELECT * FROM users', 'table' => 'users']);
$t0 = hrtime(true);
usleep(random_int(50_000, 200_000));
$client->trace('api_request', (int) round((hrtime(true) - $t0) / 1e6), ['endpoint' => '/api/v1/projects', 'method' => 'GET', 'status' => 200]);

for ($i = 0; $i < $numCrashes; $i++) {
    $template = $crashTemplates[array_rand($crashTemplates)];
    $message = $template['messages'][array_rand($template['messages'])];
    try {
        throw new $template['class']($message . ' (#' . ($i + 1) . ')');
    } catch (\Throwable $e) {
        $client->captureException($e, fatal: (bool) random_int(0, 1));
    }
}

// Grant consent so the API accepts events, crashes, and performance traces (required when environment has consent_required)
$client->grantConsent('analytics', true);
$client->grantConsent('crash_reporting', true);
$client->grantConsent('performance', true);

echo "Sending {$numEvents} events, 2 traces, {$numCrashes} crashes...\n";
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
