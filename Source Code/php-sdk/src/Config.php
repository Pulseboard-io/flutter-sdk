<?php

declare(strict_types=1);

namespace Pulseboard\Sdk;

final class Config
{
    public function __construct(
        public readonly string $dsn,
        public readonly string $appId = 'php',
        public readonly string $appVersion = '1.0.0',
        public readonly string $buildNumber = '1',
        public readonly string $sdkName = 'php',
        public readonly string $sdkVersion = '1.0.0',
        public readonly ?string $deviceId = null,
    ) {}
}
