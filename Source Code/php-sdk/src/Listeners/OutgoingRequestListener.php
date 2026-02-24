<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Http\Client\Events\ResponseReceived;
use Illuminate\Support\Facades\Event;
use Pulseboard\Laravel\PulseboardCollector;

class OutgoingRequestListener
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        Event::listen(ResponseReceived::class, function (ResponseReceived $event) {
            if (! $this->collector->getCurrentExecutionId()) {
                return;
            }

            $request = $event->request;
            $response = $event->response;

            $this->collector->recordEvent(
                type: 'outgoing_request',
                durationMs: $response->transferStats?->getTransferTime()
                    ? (int) round($response->transferStats->getTransferTime() * 1000)
                    : null,
                payload: [
                    'method' => $request->method(),
                    'url' => $request->url(),
                    'status_code' => $response->status(),
                ],
            );
        });
    }
}
