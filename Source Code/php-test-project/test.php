<?php

require_once __DIR__ . '/vendor/autoload.php';

use Pulseboard\Sdk\Client;

// DSN: scheme://public_key@host/project_id/environment (host must not include scheme)
$dsn = 'http://wk_WXQrLDETAKKBRWG9qbnPIYZboILzYuz0VIIxQlbfsl1hVgVQ@aa-api.test/019c8c55-71c1-731e-b287-a13b4bd411b6/production';

$client = Client::init($dsn);
$client->track('page_view', ['path' => '/']);

// Send queued events to the API (required; otherwise nothing is sent before script exit)
$client->flush();
echo "Sent page_view to Pulseboard.\n";
