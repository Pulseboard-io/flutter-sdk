<?php

return [
    'dsn' => env('PULSEBOARD_DSN', ''),
    'app_name' => env('PULSEBOARD_APP_NAME', env('APP_NAME', 'laravel')),
    'app_version' => env('PULSEBOARD_APP_VERSION', '1.0.0'),
    'environment' => env('PULSEBOARD_ENVIRONMENT', env('APP_ENV', 'production')),
];
