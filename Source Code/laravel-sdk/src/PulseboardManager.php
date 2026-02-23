<?php

declare(strict_types=1);

namespace Pulseboard\Laravel;

use Pulseboard\Sdk\Client;

class PulseboardManager
{
    public function __construct(
        private readonly ?Client $client,
    ) {}

    public function track(string $name, array $properties = []): void
    {
        $this->client?->track($name, $properties);
    }

    public function identify(?string $userId): void
    {
        $this->client?->identify($userId);
    }

    public function setUserProperties(array $operations): void
    {
        $this->client?->setUserProperties($operations);
    }

    public function captureException(\Throwable $e, ?string $fingerprint = null, bool $fatal = false): void
    {
        $this->client?->captureException($e, $fingerprint, $fatal);
    }

    public function trace(string $name, int $durationMs, array $attributes = []): void
    {
        $this->client?->trace($name, $durationMs, $attributes);
    }

    public function flush(): void
    {
        $this->client?->flush();
    }

    public function isConfigured(): bool
    {
        return $this->client !== null;
    }
}
