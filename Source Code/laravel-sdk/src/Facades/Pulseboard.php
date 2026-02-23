<?php

declare(strict_types=1);

namespace Pulseboard\Laravel\Facades;

use Illuminate\Support\Facades\Facade;
use Pulseboard\Laravel\PulseboardManager;

/**
 * @method static void track(string $name, array $properties = [])
 * @method static void identify(?string $userId)
 * @method static void setUserProperties(array $operations)
 * @method static void captureException(\Throwable $e, ?string $fingerprint = null, bool $fatal = false)
 * @method static void trace(string $name, int $durationMs, array $attributes = [])
 * @method static void flush()
 * @method static bool isConfigured()
 *
 * @see PulseboardManager
 */
class Pulseboard extends Facade
{
    protected static function getFacadeAccessor(): string
    {
        return PulseboardManager::class;
    }
}
