<?php

namespace Pulseboard\Laravel;

use Illuminate\Support\Str;
use Pulseboard\Laravel\Jobs\FlushPulseboardBatch;

class PulseboardCollector
{
    /** @var array<int, array<string, mixed>> */
    private array $events = [];

    private ?string $currentExecutionId = null;

    private string $currentExecutionType = 'request';

    public function __construct(
        private ?string $dsn,
        private int $batchSize = 100,
    ) {}

    public function isEnabled(): bool
    {
        return $this->dsn !== null && $this->dsn !== '';
    }

    public function startExecution(string $type, string $id): void
    {
        $this->currentExecutionId = $id;
        $this->currentExecutionType = $type;
    }

    public function getCurrentExecutionId(): ?string
    {
        return $this->currentExecutionId;
    }

    /**
     * Record a root execution event (request, command, job, scheduled_task).
     *
     * @param array<string, mixed> $meta
     * @param array<string, mixed> $context
     */
    public function recordExecution(
        string $type,
        string $id,
        \DateTimeInterface $startedAt,
        ?int $durationMs = null,
        array $meta = [],
        array $context = [],
    ): void {
        $this->events[] = [
            'type' => $type,
            'id' => $id,
            'timestamp' => $startedAt->format('c'),
            'duration_ms' => $durationMs,
            'meta' => $meta,
            'context' => $context,
        ];

        $this->flushIfNeeded();
    }

    /**
     * Record a child event (query, cache, outgoing_request, etc.).
     *
     * @param array<string, mixed> $payload
     */
    public function recordEvent(
        string $type,
        ?string $executionId = null,
        ?\DateTimeInterface $occurredAt = null,
        ?int $durationMs = null,
        array $payload = [],
    ): void {
        $this->events[] = [
            'type' => $type,
            'execution_id' => $executionId ?? $this->currentExecutionId,
            'timestamp' => ($occurredAt ?? now())->format('c'),
            'duration_ms' => $durationMs,
            'payload' => $payload,
        ];

        $this->flushIfNeeded();
    }

    public function flush(): void
    {
        if (empty($this->events)) {
            return;
        }

        $batch = $this->events;
        $this->events = [];

        dispatch(new FlushPulseboardBatch($batch))
            ->onConnection(config('pulseboard.queue.connection', 'default'))
            ->onQueue(config('pulseboard.queue.name', 'default'));
    }

    private function flushIfNeeded(): void
    {
        if (count($this->events) >= $this->batchSize) {
            $this->flush();
        }
    }

    public static function generateId(): string
    {
        return Str::uuid()->toString();
    }
}
