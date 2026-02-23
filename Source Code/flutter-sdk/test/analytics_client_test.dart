import 'dart:convert';

import 'package:pulseboard_analytics/pulseboard_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> sentBatches;

  http_testing.MockClient createMockClient() {
    return http_testing.MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      sentBatches.add(body);
      return http.Response(
        jsonEncode({
          'batch_id': 'b1',
          'received_at': DateTime.now().toIso8601String(),
          'accepted': (body['events'] as List<dynamic>).length,
          'rejected': 0,
          'warnings': <String>[],
        }),
        202,
      );
    });
  }

  setUp(() {
    sentBatches = [];
    SharedPreferences.setMockInitialValues({});
    AppAnalytics.resetForTesting();
  });

  tearDown(() async {
    if (AppAnalytics.isInitialized) {
      await AppAnalytics.instance.shutdown();
    }
  });

  test('initialize creates singleton', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    expect(AppAnalytics.isInitialized, true);
    expect(AppAnalytics.instance, isNotNull);
  });

  test('instance throws when not initialized', () {
    expect(() => AppAnalytics.instance, throwsStateError);
  });

  test('track enqueues event and flush sends it', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.track('test_event', properties: {'x': 1});
    await AppAnalytics.instance.flush();

    expect(sentBatches.length, 1);
    final events = sentBatches.first['events'] as List;
    expect(events.length, greaterThanOrEqualTo(1));

    // Find the tracked event (session_start may also be present)
    final tracked = events.firstWhere(
      (e) => (e as Map)['name'] == 'test_event',
    ) as Map;
    expect(tracked['type'], 'event');
    expect(tracked['properties'], {'x': 1});
  });

  test('identify sets user ID', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.identify('user_42');
    AppAnalytics.instance.track('after_identify');
    await AppAnalytics.instance.flush();

    expect(sentBatches.isNotEmpty, true);
    expect(sentBatches.first['user']['anonymous_id'], isNotEmpty);
  });

  test('setUserProperty enqueues user_properties event', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.setUserProperty('plan', 'premium');
    await AppAnalytics.instance.flush();

    expect(sentBatches.isNotEmpty, true);
    final events = sentBatches.first['events'] as List;
    final propEvent = events.firstWhere(
      (e) => (e as Map)['type'] == 'user_properties',
    ) as Map;
    expect(propEvent['operations'][0]['op'], 'set');
    expect(propEvent['operations'][0]['key'], 'plan');
    expect(propEvent['operations'][0]['value'], 'premium');
  });

  test('optOut prevents tracking', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.optOut();
    AppAnalytics.instance.track('should_not_send');
    await AppAnalytics.instance.flush();

    // Only session_start may have been sent before optOut
    final allEvents = sentBatches.expand(
      (b) => (b['events'] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
    expect(
      allEvents.any((e) => e['name'] == 'should_not_send'),
      false,
    );
  });

  test('payload matches API schema', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.track('schema_test');
    await AppAnalytics.instance.flush();

    expect(sentBatches.isNotEmpty, true);
    final batch = sentBatches.first;

    // Verify top-level structure
    expect(batch['schema_version'], '1.0');
    expect(batch.containsKey('sent_at'), true);
    expect(batch.containsKey('environment'), true);
    expect(batch.containsKey('app'), true);
    expect(batch.containsKey('device'), true);
    expect(batch.containsKey('user'), true);
    expect(batch.containsKey('events'), true);

    // App context
    final app = batch['app'] as Map;
    expect(app.containsKey('bundle_id'), true);
    expect(app.containsKey('version_name'), true);
    expect(app.containsKey('build_number'), true);

    // Device context
    final device = batch['device'] as Map;
    expect(device.containsKey('device_id'), true);
    expect(device.containsKey('platform'), true);
    expect(device.containsKey('os_version'), true);
    expect(device.containsKey('model'), true);

    // User context
    final user = batch['user'] as Map;
    expect(user.containsKey('anonymous_id'), true);
  });

  test('reset changes anonymous ID', () async {
    await AppAnalytics.initialize(
      AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 100,
      ),
      httpClient: createMockClient(),
    );

    AppAnalytics.instance.track('before_reset');
    await AppAnalytics.instance.flush();
    final firstAnonymousId =
        sentBatches.first['user']['anonymous_id'] as String;

    await AppAnalytics.instance.reset();
    AppAnalytics.instance.track('after_reset');
    await AppAnalytics.instance.flush();

    final secondAnonymousId =
        sentBatches.last['user']['anonymous_id'] as String;
    expect(secondAnonymousId, isNot(firstAnonymousId));
  });
}
