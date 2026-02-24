<?php

namespace Pulseboard\Laravel;

use Illuminate\Support\ServiceProvider;
use Pulseboard\Laravel\Listeners\CacheEventListener;
use Pulseboard\Laravel\Listeners\ExceptionListener;
use Pulseboard\Laravel\Listeners\JobEventListener;
use Pulseboard\Laravel\Listeners\MailEventListener;
use Pulseboard\Laravel\Listeners\QueryListener;
use Pulseboard\Laravel\Listeners\OutgoingRequestListener;

class PulseboardServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->mergeConfigFrom(__DIR__.'/../config/pulseboard.php', 'pulseboard');

        $this->app->singleton(PulseboardCollector::class, function ($app) {
            return new PulseboardCollector(
                config('pulseboard.dsn'),
                config('pulseboard.batch_size', 100),
            );
        });

        $this->app->singleton(PulseboardClient::class, function ($app) {
            $dsn = config('pulseboard.dsn');
            if (! $dsn) {
                return new PulseboardClient('', '', '', '');
            }

            $parsed = DsnParser::parse($dsn);

            return new PulseboardClient(
                $parsed['host'],
                $parsed['public_key'],
                $parsed['project_id'],
                $parsed['environment'],
            );
        });
    }

    public function boot(): void
    {
        $this->publishes([
            __DIR__.'/../config/pulseboard.php' => config_path('pulseboard.php'),
        ], 'pulseboard-config');

        if (! config('pulseboard.enabled') || ! config('pulseboard.dsn')) {
            return;
        }

        $this->registerListeners();
    }

    private function registerListeners(): void
    {
        if (config('pulseboard.capture.queries')) {
            $this->app->make(QueryListener::class)->register();
        }

        if (config('pulseboard.capture.cache')) {
            $this->app->make(CacheEventListener::class)->register();
        }

        if (config('pulseboard.capture.jobs')) {
            $this->app->make(JobEventListener::class)->register();
        }

        if (config('pulseboard.capture.mail')) {
            $this->app->make(MailEventListener::class)->register();
        }

        if (config('pulseboard.capture.exceptions')) {
            $this->app->make(ExceptionListener::class)->register();
        }

        if (config('pulseboard.capture.outgoing_requests')) {
            $this->app->make(OutgoingRequestListener::class)->register();
        }
    }
}
