<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Pulseboard DSN
    |--------------------------------------------------------------------------
    |
    | The DSN (Data Source Name) for your Pulseboard project.
    | Format: https://<public_key>@<host>/<project-id>/<environment>
    |
    */
    'dsn' => env('PULSEBOARD_DSN'),

    /*
    |--------------------------------------------------------------------------
    | Enabled
    |--------------------------------------------------------------------------
    |
    | Enable or disable Pulseboard monitoring.
    |
    */
    'enabled' => env('PULSEBOARD_ENABLED', true),

    /*
    |--------------------------------------------------------------------------
    | Sampling
    |--------------------------------------------------------------------------
    |
    | Sample rate for request monitoring (0.0 to 1.0).
    | 1.0 = capture everything, 0.1 = capture 10% of requests.
    |
    */
    'sample_rate' => env('PULSEBOARD_SAMPLE_RATE', 1.0),

    /*
    |--------------------------------------------------------------------------
    | Queue
    |--------------------------------------------------------------------------
    |
    | The queue connection and name for uploading batches.
    |
    */
    'queue' => [
        'connection' => env('PULSEBOARD_QUEUE_CONNECTION', 'default'),
        'name' => env('PULSEBOARD_QUEUE_NAME', 'default'),
    ],

    /*
    |--------------------------------------------------------------------------
    | Batch Size
    |--------------------------------------------------------------------------
    |
    | Maximum events to collect before flushing.
    |
    */
    'batch_size' => env('PULSEBOARD_BATCH_SIZE', 100),

    /*
    |--------------------------------------------------------------------------
    | Capture Settings
    |--------------------------------------------------------------------------
    */
    'capture' => [
        'queries' => env('PULSEBOARD_CAPTURE_QUERIES', true),
        'outgoing_requests' => env('PULSEBOARD_CAPTURE_OUTGOING_REQUESTS', true),
        'cache' => env('PULSEBOARD_CAPTURE_CACHE', true),
        'jobs' => env('PULSEBOARD_CAPTURE_JOBS', true),
        'mail' => env('PULSEBOARD_CAPTURE_MAIL', true),
        'logs' => env('PULSEBOARD_CAPTURE_LOGS', true),
        'exceptions' => env('PULSEBOARD_CAPTURE_EXCEPTIONS', true),
    ],

    /*
    |--------------------------------------------------------------------------
    | Slow Query Threshold
    |--------------------------------------------------------------------------
    |
    | Log queries slower than this threshold (in milliseconds).
    | Set to 0 to capture all queries.
    |
    */
    'slow_query_threshold' => env('PULSEBOARD_SLOW_QUERY_THRESHOLD', 0),

    /*
    |--------------------------------------------------------------------------
    | Ignored Paths
    |--------------------------------------------------------------------------
    |
    | URL paths that should not be monitored.
    |
    */
    'ignored_paths' => [
        '_debugbar*',
        'telescope*',
        'horizon*',
        'pulse*',
    ],

    /*
    |--------------------------------------------------------------------------
    | Redacted Headers
    |--------------------------------------------------------------------------
    |
    | Request headers to redact from captured data.
    |
    */
    'redact_headers' => [
        'Authorization',
        'Cookie',
        'Set-Cookie',
        'X-XSRF-TOKEN',
    ],
];
