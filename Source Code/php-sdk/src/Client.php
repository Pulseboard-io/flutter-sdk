<?php

declare(strict_types=1);

namespace Pulseboard\Sdk;

use GuzzleHttp\ClientInterface;
use Pulseboard\Sdk\Exception\NotInitializedException;

final class Client
{
    private const SCHEMA_VERSION = '1.0';
    private const BATCH_SIZE = 50;

    private static ?self $instance = null;

    private Dsn $dsn;
    private Config $config;
    private Transport $transport;
    private string $deviceId;
    private string $anonymousId;
    private ?string $userId = null;
    /** @var list<array<string, mixed>> */
    private array $queue = [];

    private function __construct(Dsn $dsn, Config $config, Transport $transport)
    {
        $this->dsn = $dsn;
        $this->config = $config;
        $this->transport = $transport;
        $this->deviceId = $config->deviceId ?? gethostname() ?: 'php-'.bin2hex(random_bytes(8));
        $this->anonymousId = 'anon-'.bin2hex(random_bytes(16));
    }

    public static function init(string $dsn, ?Config $config = null, ?ClientInterface $httpClient = null): self
    {
        $config = $config ?? new Config($dsn);
        $parsed = Dsn::parse($dsn);
        $httpClient = $httpClient ?? new \GuzzleHttp\Client(['timeout' => 10]);
        $transport = new Transport($httpClient, $parsed, $config->sdkName, $config->sdkVersion);
        self::$instance = new self($parsed, $config, $transport);

        return self::$instance;
    }

    public static function getInstance(): self
    {
        if (self::$instance === null) {
            throw new NotInitializedException('Pulseboard SDK not initialized. Call Client::init($dsn) first.');
        }

        return self::$instance;
    }

    /**
     * @param array<string, mixed> $properties
     */
    public function track(string $name, array $properties = []): void
    {
        $this->enqueue([
            'type' => 'event',
            'event_id' => $this->uuid(),
            'timestamp' => $this->now(),
            'name' => $name,
            'properties' => $properties,
        ]);
    }

    public function identify(?string $userId): void
    {
        $this->userId = $userId;
    }

    /**
     * @param list<array{op: string, key: string, value?: mixed}> $operations
     */
    public function setUserProperties(array $operations): void
    {
        $this->enqueue([
            'type' => 'user_properties',
            'event_id' => $this->uuid(),
            'timestamp' => $this->now(),
            'operations' => $operations,
        ]);
    }

    /**
     * Grant or revoke consent for the current user (anonymous_id).
     * Consent types: 'analytics', 'crash_reporting', 'performance'.
     * Call before flush when the environment has consent_required so trace/crash/event types are accepted.
     */
    public function grantConsent(string $consentType, bool $granted = true): bool
    {
        return $this->transport->sendConsent($this->anonymousId, $consentType, $granted);
    }

    public function captureException(\Throwable $e, ?string $fingerprint = null, bool $fatal = false): void
    {
        $this->enqueue([
            'type' => 'crash',
            'event_id' => $this->uuid(),
            'timestamp' => $this->now(),
            'fingerprint' => $fingerprint ?? $e::class,
            'fatal' => $fatal,
            'exception' => [
                'type' => $e::class,
                'message' => $e->getMessage(),
                'stacktrace' => $e->getTraceAsString(),
            ],
        ]);
    }

    /**
     * @param array<string, mixed> $attributes
     */
    public function trace(string $name, int $durationMs, array $attributes = []): void
    {
        $this->enqueue([
            'type' => 'trace',
            'event_id' => $this->uuid(),
            'timestamp' => $this->now(),
            'trace' => [
                'trace_id' => $this->uuid(),
                'name' => $name,
                'duration_ms' => $durationMs,
                'attributes' => $attributes,
            ],
        ]);
    }

    public function flush(): void
    {
        if ($this->queue === []) {
            return;
        }
        $batch = array_splice($this->queue, 0, self::BATCH_SIZE);
        $payload = $this->buildPayload($batch);
        $this->transport->send($payload);
    }

    /**
     * @param list<array<string, mixed>> $events
     *
     * @return array<string, mixed>
     */
    private function buildPayload(array $events): array
    {
        return [
            'schema_version' => self::SCHEMA_VERSION,
            'sent_at' => $this->now(),
            'environment' => $this->dsn->environment,
            'app' => [
                'bundle_id' => $this->config->appId,
                'version_name' => $this->config->appVersion,
                'build_number' => $this->config->buildNumber,
            ],
            'device' => [
                'device_id' => $this->deviceId,
                'platform' => 'php',
                'os_version' => PHP_VERSION,
                'model' => gethostname() ?: 'server',
            ],
            'user' => [
                'anonymous_id' => $this->anonymousId,
                'user_id' => $this->userId,
            ],
            'events' => $events,
        ];
    }

    /**
     * @param array<string, mixed> $event
     */
    private function enqueue(array $event): void
    {
        $this->queue[] = $event;
        if (count($this->queue) >= self::BATCH_SIZE) {
            $this->flush();
        }
    }

    private function uuid(): string
    {
        $data = random_bytes(16);
        $data[6] = chr(ord($data[6]) & 0x0f | 0x40);
        $data[8] = chr(ord($data[8]) & 0x3f | 0x80);

        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($data), 4));
    }

    private function now(): string
    {
        return (new \DateTimeImmutable('now', new \DateTimeZone('UTC')))->format('Y-m-d\TH:i:s.u\Z');
    }
}
