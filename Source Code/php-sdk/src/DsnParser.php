<?php

namespace Pulseboard\Laravel;

use InvalidArgumentException;

class DsnParser
{
    /**
     * Parse a Pulseboard DSN string into its components.
     *
     * Format: https://<public_key>@<host>/<project-id>/<environment>
     *
     * @return array{host: string, public_key: string, project_id: string, environment: string}
     */
    public static function parse(string $dsn): array
    {
        $parsed = parse_url($dsn);

        if (! $parsed || ! isset($parsed['host'], $parsed['user'], $parsed['path'])) {
            throw new InvalidArgumentException("Invalid Pulseboard DSN: {$dsn}");
        }

        $scheme = $parsed['scheme'] ?? 'https';
        $host = $scheme.'://'.$parsed['host'];
        if (isset($parsed['port'])) {
            $host .= ':'.$parsed['port'];
        }

        $publicKey = $parsed['user'];
        $pathSegments = array_values(array_filter(explode('/', trim($parsed['path'], '/'))));

        if (count($pathSegments) < 2) {
            throw new InvalidArgumentException("Invalid Pulseboard DSN path: must contain project ID and environment.");
        }

        return [
            'host' => $host,
            'public_key' => $publicKey,
            'project_id' => $pathSegments[0],
            'environment' => $pathSegments[1],
        ];
    }
}
