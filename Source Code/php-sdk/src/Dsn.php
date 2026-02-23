<?php

declare(strict_types=1);

namespace Pulseboard\Sdk;

final class Dsn
{
    public function __construct(
        public readonly string $publicKey,
        public readonly string $host,
        public readonly string $projectId,
        public readonly string $environment,
        public readonly string $baseUrl,
    ) {}

    public static function parse(string $dsn): self
    {
        $parsed = parse_url($dsn);
        if ($parsed === false || ! isset($parsed['scheme'], $parsed['host'], $parsed['path'])) {
            throw new \InvalidArgumentException('Invalid DSN: malformed URL');
        }
        if (! in_array($parsed['scheme'], ['http', 'https'], true)) {
            throw new \InvalidArgumentException('DSN must use https or http');
        }
        $publicKey = $parsed['user'] ?? '';
        if ($publicKey === '') {
            throw new \InvalidArgumentException('DSN must contain a public key (userinfo before @)');
        }
        $path = trim($parsed['path'], '/');
        $segments = $path === '' ? [] : explode('/', $path);
        if (count($segments) < 2) {
            throw new \InvalidArgumentException('DSN path must be /<project_id>/<environment>');
        }
        $projectId = $segments[0];
        $environment = $segments[1];
        $port = isset($parsed['port']) ? ':'.$parsed['port'] : '';
        $baseUrl = $parsed['scheme'].'://'.$parsed['host'].$port;

        return new self($publicKey, $parsed['host'].$port, $projectId, $environment, $baseUrl);
    }
}
