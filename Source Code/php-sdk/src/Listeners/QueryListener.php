<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Database\Events\QueryExecuted;
use Illuminate\Support\Facades\DB;
use Pulseboard\Laravel\PulseboardCollector;

class QueryListener
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        DB::listen(function (QueryExecuted $query) {
            if (! $this->collector->getCurrentExecutionId()) {
                return;
            }

            $threshold = (int) config('pulseboard.slow_query_threshold', 0);
            $durationMs = (int) round($query->time);

            if ($threshold > 0 && $durationMs < $threshold) {
                return;
            }

            $this->collector->recordEvent(
                type: 'query',
                durationMs: $durationMs,
                payload: [
                    'sql' => $query->sql,
                    'connection' => $query->connectionName,
                    'bindings_count' => count($query->bindings),
                ],
            );
        });
    }
}
