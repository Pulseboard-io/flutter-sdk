<?php

namespace Pulseboard\Laravel\Listeners;

use Illuminate\Queue\Events\JobFailed;
use Illuminate\Queue\Events\JobProcessed;
use Illuminate\Queue\Events\JobProcessing;
use Illuminate\Support\Facades\Event;
use Pulseboard\Laravel\PulseboardCollector;

class JobEventListener
{
    /** @var array<string, array{id: string, started_at: \DateTimeInterface}> */
    private array $activeJobs = [];

    public function __construct(
        private PulseboardCollector $collector,
    ) {}

    public function register(): void
    {
        Event::listen(JobProcessing::class, function (JobProcessing $event) {
            $jobId = $event->job->getJobId();
            $executionId = PulseboardCollector::generateId();

            $this->activeJobs[$jobId] = [
                'id' => $executionId,
                'started_at' => now(),
            ];

            $this->collector->startExecution('job', $executionId);
        });

        Event::listen(JobProcessed::class, function (JobProcessed $event) {
            $this->finalizeJob($event->job->getJobId(), $event);
        });

        Event::listen(JobFailed::class, function (JobFailed $event) {
            if ($event->exception) {
                $this->collector->recordEvent(
                    type: 'exception',
                    payload: [
                        'class' => get_class($event->exception),
                        'message' => $event->exception->getMessage(),
                        'file' => $event->exception->getFile(),
                        'line' => $event->exception->getLine(),
                    ],
                );
            }

            $this->finalizeJob($event->job->getJobId(), $event);
        });
    }

    private function finalizeJob(string $jobId, JobProcessed|JobFailed $event): void
    {
        if (! isset($this->activeJobs[$jobId])) {
            return;
        }

        $info = $this->activeJobs[$jobId];
        $durationMs = (int) round(now()->diffInMilliseconds($info['started_at']));

        $this->collector->recordExecution(
            type: 'job',
            id: $info['id'],
            startedAt: $info['started_at'],
            durationMs: $durationMs,
            meta: [
                'job_class' => $event->job->resolveName(),
                'queue' => $event->job->getQueue(),
                'connection' => $event->connectionName,
                'attempts' => $event->job->attempts(),
            ],
        );

        $this->collector->flush();
        unset($this->activeJobs[$jobId]);
    }
}
