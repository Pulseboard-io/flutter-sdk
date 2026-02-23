<?php

declare(strict_types=1);

namespace Pulseboard\Sdk\Tests;

use GuzzleHttp\Client;
use GuzzleHttp\Handler\MockHandler;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;
use GuzzleHttp\Psr7\Response;
use PHPUnit\Framework\TestCase;
use Pulseboard\Sdk\Client as SdkClient;
use Pulseboard\Sdk\Exception\NotInitializedException;
use Psr\Http\Message\RequestInterface;

final class ClientTest extends TestCase
{
    public function test_init_creates_instance(): void
    {
        $client = SdkClient::init('https://wk_key@host.com/proj/env');
        $this->assertInstanceOf(SdkClient::class, $client);
    }

    public function test_get_instance_throws_when_not_initialized(): void
    {
        $ref = new \ReflectionClass(SdkClient::class);
        $prop = $ref->getProperty('instance');
        $prop->setAccessible(true);
        $prop->setValue(null, null);

        $this->expectException(NotInitializedException::class);
        SdkClient::getInstance();
    }

    public function test_track_and_flush_sends_payload(): void
    {
        $requests = [];
        $mock = new MockHandler([new Response(202)]);
        $handler = HandlerStack::create($mock);
        $handler->push(Middleware::mapRequest(static function (RequestInterface $req) use (&$requests) {
            $requests[] = $req;
            return $req;
        }));
        $guzzle = new Client(['handler' => $handler]);

        $client = SdkClient::init('https://wk_key@host.com/proj/env', null, $guzzle);
        $client->track('page_view', ['path' => '/']);
        $client->flush();

        $this->assertCount(1, $requests);
        $req = $requests[0];
        $this->assertSame('POST', $req->getMethod());
        $this->assertStringContainsString('/api/v1/ingest/batch', (string) $req->getUri());
        $this->assertSame('Bearer wk_key', $req->getHeaderLine('Authorization'));
        $body = json_decode((string) $req->getBody(), true);
        $this->assertSame('1.0', $body['schema_version']);
        $this->assertCount(1, $body['events']);
        $this->assertSame('event', $body['events'][0]['type']);
        $this->assertSame('page_view', $body['events'][0]['name']);
        $this->assertSame('php', $body['device']['platform']);
    }
}
