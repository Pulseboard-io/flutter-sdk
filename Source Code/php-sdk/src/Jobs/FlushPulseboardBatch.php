<?php

namespace Pulseboard\Laravel\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Pulseboard\Laravel\PulseboardClient;

class FlushPulseboardBatch implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public int $backoff = 5;

    /**
     * @param array<int, array<string, mixed>> $events
     */
    public function __construct(
        public array $events,
    ) {}

    public function handle(PulseboardClient $client): void
    {
        $client->sendBatch($this->events);
    }
}
