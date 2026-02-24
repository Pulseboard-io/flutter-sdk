<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Mail\Events\MessageSent;
use Illuminate\Support\Facades\Event;
use Pulseboard\Laravel\PulseboardCollector;

class MailEventListener
{
    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        Event::listen(MessageSent::class, function (MessageSent $event) {
            if (! $this->collector->getCurrentExecutionId()) {
                return;
            }

            $message = $event->message;
            $to = $message->getTo();
            $recipientsCount = is_array($to) ? count($to) : 1;

            $this->collector->recordEvent(
                type: 'mail',
                payload: [
                    'subject' => $message->getSubject() ?? '',
                    'recipients_count' => $recipientsCount,
                ],
            );
        });
    }
}
