<?php

require_once __DIR__ . '/vendor/autoload.php';

use Pulseboard\Sdk\Client;
use Pulseboard\Sdk\Config;

$dsn = 'http://wk_bPk2pCZ6wXunJ1q0n3vCcZnrlvs9wBAAI8OCzpirrv18aoHC@aa-api.test/019c8c3d-0481-7102-b4e8-848cbbbb860f/production';

echo "=== Pulseboard PHP SDK Test ===\n\n";

// Initialize the SDK
$client = Client::init($dsn, new Config(
    dsn: $dsn,
    appId: 'php-test-project',
    appVersion: '1.0.0',
    buildNumber: '1',
));

echo "[1] SDK initialized\n";

// Identify a test user
$client->identify('test-user-php-001');
echo "[2] User identified: test-user-php-001\n";

// Set user properties
$client->setUserProperties([
    ['op' => 'set', 'key' => 'plan', 'value' => 'pro'],
    ['op' => 'set', 'key' => 'language', 'value' => 'en'],
    ['op' => 'set', 'key' => 'country', 'value' => 'DE'],
]);
echo "[3] User properties set (plan=pro, language=en, country=DE)\n";

// Track some events
$client->track('app_launched', [
    'source' => 'cli',
    'environment' => 'testing',
]);
echo "[4] Tracked: app_launched\n";

$client->track('page_viewed', [
    'page' => '/dashboard',
    'referrer' => 'direct',
]);
echo "[5] Tracked: page_viewed (/dashboard)\n";

$client->track('button_clicked', [
    'button' => 'create_project',
    'section' => 'header',
]);
echo "[6] Tracked: button_clicked (create_project)\n";

$client->track('settings_updated', [
    'setting' => 'notifications',
    'enabled' => true,
]);
echo "[7] Tracked: settings_updated\n";

$client->track('search_performed', [
    'query' => 'analytics dashboard',
    'results_count' => 12,
]);
echo "[8] Tracked: search_performed\n";

// Capture an exception
try {
    throw new RuntimeException('Test exception from PHP SDK');
} catch (Throwable $e) {
    $client->captureException($e, fatal: false);
    echo "[9] Captured exception: " . $e->getMessage() . "\n";
}

// Record a performance trace
$client->trace('database_query', 45, [
    'query' => 'SELECT * FROM users',
    'table' => 'users',
]);
echo "[10] Traced: database_query (45ms)\n";

$client->trace('api_request', 230, [
    'endpoint' => '/api/v1/projects',
    'method' => 'GET',
    'status' => 200,
]);
echo "[11] Traced: api_request (230ms)\n";

// Flush all queued events
echo "\n--- Flushing events to Pulseboard ---\n";
$client->flush();
echo "--- Done! ---\n";
