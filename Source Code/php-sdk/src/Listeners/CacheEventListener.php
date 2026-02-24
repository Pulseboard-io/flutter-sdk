<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Cache\Events\CacheHit;
use Illuminate\Cache\Events\CacheMissed;
use Illuminate\Cache\Events\KeyForgotten;
use Illuminate\Cache\Events\KeyWritten;
use Illuminate\Support\Facades\Event;
use Pulseboard\Laravel\PulseboardCollector;

class CacheEventListener
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        Event::listen(CacheHit::class, function (CacheHit $event) {
            $this->record('hit', $event->key, $event->storeName ?? 'default');
        });

        Event::listen(CacheMissed::class, function (CacheMissed $event) {
            $this->record('miss', $event->key, $event->storeName ?? 'default');
        });

        Event::listen(KeyWritten::class, function (KeyWritten $event) {
            $this->record('write', $event->key, $event->storeName ?? 'default');
        });

        Event::listen(KeyForgotten::class, function (KeyForgotten $event) {
            $this->record('delete', $event->key, $event->storeName ?? 'default');
        });
    }

    private function record(string $operation, string $key, string $store): void
    {
        if (! $this->collector->getCurrentExecutionId()) {
            return;
        }

        $this->collector->recordEvent(
            type: 'cache',
            payload: [
                'key' => $key,
                'operation' => $operation,
                'store' => $store,
            ],
        );
    }
}
