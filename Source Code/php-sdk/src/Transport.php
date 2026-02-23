<?php

declare(strict_types=1);

namespace Pulseboard\Sdk;

use GuzzleHttp\ClientInterface;
use GuzzleHttp\Exception\GuzzleException;
use GuzzleHttp\Psr7\Request;

final class Transport
{
    private const ENDPOINT_PATH = '/api/v1/ingest/batch';

    public function __construct(
        private readonly ClientInterface $client,
        private readonly Dsn $dsn,
        private readonly string $sdkName,
        private readonly string $sdkVersion,
    ) {}

    public function send(array $payload): bool
    {
        $url = $this->dsn->baseUrl.self::ENDPOINT_PATH;
        $headers = [
            'Content-Type' => 'application/json',
            'Authorization' => 'Bearer '.$this->dsn->publicKey,
            'Idempotency-Key' => $this->generateIdempotencyKey(),
        ];
        if ($this->sdkName !== '') {
            $headers['X-SDK'] = $this->sdkName;
        }
        if ($this->sdkVersion !== '') {
            $headers['X-SDK-Version'] = $this->sdkVersion;
        }
        $request = new Request('POST', $url, $headers, json_encode($payload));

        try {
            $response = $this->client->send($request);
            return $response->getStatusCode() === 202;
        } catch (GuzzleException $e) {
            return false;
        }
    }

    private function generateIdempotencyKey(): string
    {
        return sprintf(
            'batch-%d-%s',
            (int) (microtime(true) * 1000),
            bin2hex(random_bytes(8))
        );
    }
}
