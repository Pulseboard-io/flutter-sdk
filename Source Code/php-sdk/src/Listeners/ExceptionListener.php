<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use Pulseboard\Laravel\PulseboardCollector;

class ExceptionListener
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        Event::listen(MessageLogged::class, function (MessageLogged $event) {
            if (! $this->collector->getCurrentExecutionId()) {
                return;
            }

            if (! in_array($event->level, ['error', 'critical', 'alert', 'emergency'], true)) {
                return;
            }

            $exception = $event->context['exception'] ?? null;

            if ($exception instanceof \Throwable) {
                $this->collector->recordEvent(
                    type: 'exception',
                    payload: [
                        'class' => get_class($exception),
                        'message' => $exception->getMessage(),
                        'file' => $exception->getFile(),
                        'line' => $exception->getLine(),
                    ],
                );
            }
        });
    }
}
