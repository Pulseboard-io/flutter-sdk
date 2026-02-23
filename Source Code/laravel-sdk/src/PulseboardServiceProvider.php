<?php

declare(strict_types=1);

namespace Pulseboard\Laravel;

use Illuminate\Support\ServiceProvider;
use Pulseboard\Sdk\Client;
use Pulseboard\Sdk\Config;

class PulseboardServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->mergeConfigFrom(__DIR__.'/../config/pulseboard.php', 'pulseboard');

        $this->app->singleton(Client::class, function () {
            $dsn = config('pulseboard.dsn', '');
            if ($dsn === '') {
                return null;
            }
            $config = new Config(
                dsn: $dsn,
                appId: config('pulseboard.app_name', 'laravel'),
                appVersion: config('pulseboard.app_version', '1.0.0'),
                buildNumber: (string) config('pulseboard.build_number', '1'),
                sdkName: 'laravel',
                sdkVersion: '1.0.0',
            );

            return Client::init($dsn, $config);
        });

        $this->app->singleton(PulseboardManager::class, function () {
            return new PulseboardManager($this->app->make(Client::class));
        });
    }

    public function boot(): void
    {
        if ($this->app->runningInConsole()) {
            $this->publishes([
                __DIR__.'/../config/pulseboard.php' => config_path('pulseboard.php'),
            ], 'pulseboard-config');
        }
    }
}
