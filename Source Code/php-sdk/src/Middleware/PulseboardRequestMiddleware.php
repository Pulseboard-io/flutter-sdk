<?php

namespace Pulseboard\Laravel\Middleware;

use Closure;
use Illuminate\Http\Request;
use Pulseboard\Laravel\PulseboardCollector;
use Symfony\Component\HttpFoundation\Response;

class PulseboardRequestMiddleware
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function handle(Request $request, Closure $next): Response
    {
        if (! $this->collector->isEnabled() || ! $this->shouldCapture($request)) {
            return $next($request);
        }

        // Sample rate check
        if (mt_rand(1, 10000) / 10000 > (float) config('pulseboard.sample_rate', 1.0)) {
            return $next($request);
        }

        $executionId = PulseboardCollector::generateId();
        $startedAt = now();

        $this->collector->startExecution('request', $executionId);

        $response = $next($request);

        $durationMs = (int) round((microtime(true) - LARAVEL_START) * 1000);

        $this->collector->recordExecution(
            type: 'request',
            id: $executionId,
            startedAt: $startedAt,
            durationMs: $durationMs,
            meta: [
                'method' => $request->method(),
                'url' => $request->fullUrl(),
                'route_name' => $request->route()?->getName(),
                'status_code' => $response->getStatusCode(),
                'user_id' => $request->user()?->getAuthIdentifier(),
                'ip_address' => $request->ip(),
            ],
        );

        $this->collector->flush();

        return $response;
    }

    private function shouldCapture(Request $request): bool
    {
        $path = $request->path();
        $ignoredPaths = config('pulseboard.ignored_paths', []);

        foreach ($ignoredPaths as $pattern) {
            if (fnmatch($pattern, $path)) {
                return false;
            }
        }

        return true;
    }
}
