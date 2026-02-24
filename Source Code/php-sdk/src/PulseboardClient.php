<?php

namespace Pulseboard\Laravel;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PulseboardClient
{
    public function __construct(
        private string $host,
        private string $publicKey,
        private string $projectId,
        private string $environment,
    ) {}

    /**
     * Send a batch of events to the Pulseboard API.
     *
     * @param array<int, array<string, mixed>> $events
     * @return array<string, mixed>|null
     */
    public function sendBatch(array $events): ?array
    {
        if (empty($events) || $this->host === '') {
            return null;
        }

        try {
            $response = Http::withToken($this->publicKey)
                ->timeout(10)
                ->retry(2, 500)
                ->post("{$this->host}/api/v1/backend/ingest", [
                    'events' => $events,
                ]);

            if ($response->successful()) {
                return $response->json();
            }

            Log::warning('Pulseboard: Failed to send batch', [
                'status' => $response->status(),
                'body' => $response->body(),
            ]);

            return null;
        } catch (\Throwable $e) {
            Log::warning('Pulseboard: Exception sending batch', [
                'message' => $e->getMessage(),
            ]);

            return null;
        }
    }

    public function getHost(): string
    {
        return $this->host;
    }

    public function getProjectId(): string
    {
        return $this->projectId;
    }

    public function getEnvironment(): string
    {
        return $this->environment;
    }
}
