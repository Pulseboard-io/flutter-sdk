<?php

declare(strict_types=1);

namespace Pulseboard\Sdk\Tests;

use PHPUnit\Framework\TestCase;
use Pulseboard\Sdk\Dsn;

final class DsnTest extends TestCase
{
    public function test_parses_valid_dsn(): void
    {
        $dsn = Dsn::parse('https://wk_abc123@api.example.com/proj_xyz/production');
        $this->assertSame('wk_abc123', $dsn->publicKey);
        $this->assertSame('api.example.com', $dsn->host);
        $this->assertSame('proj_xyz', $dsn->projectId);
        $this->assertSame('production', $dsn->environment);
        $this->assertSame('https://api.example.com', $dsn->baseUrl);
    }

    public function test_accepts_http(): void
    {
        $dsn = Dsn::parse('http://wk_key@localhost:8000/proj/env');
        $this->assertSame('wk_key', $dsn->publicKey);
        $this->assertSame('http://localhost:8000', $dsn->baseUrl);
    }

    public function test_throws_when_missing_public_key(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('public key');
        Dsn::parse('https://api.example.com/proj/env');
    }

    public function test_throws_when_path_too_short(): void
    {
        $this->expectException(\InvalidArgumentException::class);
        $this->expectExceptionMessage('path');
        Dsn::parse('https://wk_key@api.example.com/proj');
    }
}
