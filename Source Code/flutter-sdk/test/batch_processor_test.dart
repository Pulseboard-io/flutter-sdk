import 'dart:convert';

import 'package:pulseboard_analytics/src/config.dart';
import 'package:pulseboard_analytics/src/services/batch_processor.dart';
import 'package:pulseboard_analytics/src/services/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

void main() {
  late AnalyticsConfig config;
  late int sendCount;
  late List<Map<String, dynamic>> lastSentEvents;

  http_testing.MockClient createMockClient({int statusCode = 202}) {
    return http_testing.MockClient((request) async {
      sendCount++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      lastSentEvents = (body['events'] as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      return http.Response(
        jsonEncode({
          'batch_id': 'b$sendCount',
          'received_at': DateTime.now().toIso8601String(),
          'accepted': lastSentEvents.length,
          'rejected': 0,
          'warnings': <String>[],
        }),
        statusCode,
      );
    });
  }

  setUp(() {
    sendCount = 0;
    lastSentEvents = [];
    config = AnalyticsConfig(
      dsn: 'https://key@host/proj/env',
      flushAt: 3,
      flushIntervalSeconds: 60,
      maxRetries: 0,
    );
  });

  test('auto-flushes when queue reaches flushAt', () async {
    final httpClient = AnalyticsHttpClient(
      config: config,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: config,
      httpClient: httpClient,
    );

    processor.enqueue({'type': 'event', 'event_id': '1', 'timestamp': 't', 'name': 'a'});
    processor.enqueue({'type': 'event', 'event_id': '2', 'timestamp': 't', 'name': 'b'});

    // Not flushed yet
    expect(sendCount, 0);

    processor.enqueue({'type': 'event', 'event_id': '3', 'timestamp': 't', 'name': 'c'});

    // Give async flush time to complete
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(sendCount, 1);
    expect(lastSentEvents.length, 3);
    expect(processor.queueLength, 0);
  });

  test('explicit flush sends queued events', () async {
    final httpClient = AnalyticsHttpClient(
      config: config,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: config,
      httpClient: httpClient,
    );

    processor.enqueue({'type': 'event', 'event_id': '1', 'timestamp': 't', 'name': 'a'});
    await processor.flush();

    expect(sendCount, 1);
    expect(lastSentEvents.length, 1);
  });

  test('flush does nothing when queue is empty', () async {
    final httpClient = AnalyticsHttpClient(
      config: config,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: config,
      httpClient: httpClient,
    );

    await processor.flush();
    expect(sendCount, 0);
  });

  test('opted out clears queue and drops events', () async {
    final httpClient = AnalyticsHttpClient(
      config: config,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: config,
      httpClient: httpClient,
    );

    processor.enqueue({'type': 'event', 'event_id': '1', 'timestamp': 't', 'name': 'a'});
    processor.setOptOut(true);

    expect(processor.queueLength, 0);

    // New events should be dropped
    processor.enqueue({'type': 'event', 'event_id': '2', 'timestamp': 't', 'name': 'b'});
    expect(processor.queueLength, 0);
  });

  test('consent revoked clears queue', () async {
    final httpClient = AnalyticsHttpClient(
      config: config,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: config,
      httpClient: httpClient,
    );

    processor.enqueue({'type': 'event', 'event_id': '1', 'timestamp': 't', 'name': 'a'});
    processor.setConsent(false);

    expect(processor.queueLength, 0);

    // New events should be dropped
    processor.enqueue({'type': 'event', 'event_id': '2', 'timestamp': 't', 'name': 'b'});
    expect(processor.queueLength, 0);
  });

  test('sampling drops events based on rate', () {
    final lowSampleConfig = AnalyticsConfig(
      dsn: 'https://key@host/proj/env',
      flushAt: 1000,
      sampleRate: 0.0, // Drop all
    );
    final httpClient = AnalyticsHttpClient(
      config: lowSampleConfig,
      client: createMockClient(),
    );
    final processor = BatchProcessor(
      config: lowSampleConfig,
      httpClient: httpClient,
    );

    for (var i = 0; i < 100; i++) {
      processor.enqueue({'type': 'event', 'event_id': '$i', 'timestamp': 't', 'name': 'test'});
    }

    expect(processor.queueLength, 0);
  });
}
