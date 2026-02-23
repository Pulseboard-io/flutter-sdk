<?php

declare(strict_types=1);

namespace Pulseboard\Laravel\Tests;

use Illuminate\Foundation\Application;
use Illuminate\Support\Facades\Facade;
use Orchestra\Testbench\TestCase;
use Pulseboard\Laravel\PulseboardServiceProvider;

class ServiceProviderTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
    }

    protected function getPackageProviders($app): array
    {
        return [PulseboardServiceProvider::class];
    }

    protected function getPackageAliases($app): array
    {
        return [];
    }

    public function test_config_is_merged(): void
    {
        $this->assertSame('', config('pulseboard.dsn'));
        $this->assertNotEmpty(config('pulseboard.app_name'));
    }

    public function test_manager_resolves_when_dsn_empty(): void
    {
        $manager = $this->app->make(\Pulseboard\Laravel\PulseboardManager::class);
        $this->assertInstanceOf(\Pulseboard\Laravel\PulseboardManager::class, $manager);
        $this->assertFalse($manager->isConfigured());
    }
}
