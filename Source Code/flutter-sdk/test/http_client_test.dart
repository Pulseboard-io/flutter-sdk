import 'dart:convert';

import 'package:pulseboard_analytics/src/config.dart';
import 'package:pulseboard_analytics/src/models/app_info.dart';
import 'package:pulseboard_analytics/src/models/batch_payload.dart';
import 'package:pulseboard_analytics/src/models/device_info_model.dart';
import 'package:pulseboard_analytics/src/models/user_info.dart';
import 'package:pulseboard_analytics/src/services/http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

void main() {
  late AnalyticsConfig config;
  late BatchPayload payload;

  setUp(() {
    config = AnalyticsConfig(
      dsn: 'https://test_key@api.example.com/proj_1/production',
    );

    payload = BatchPayload(
      environment: 'production',
      app: const AppInfo(
        bundleId: 'com.test',
        versionName: '1.0',
        buildNumber: '1',
      ),
      device: const DeviceInfoModel(
        deviceId: 'd1',
        platform: 'android',
        osVersion: '14',
        model: 'Test',
      ),
      user: const UserInfo(anonymousId: 'a1'),
      events: [
        {'type': 'event', 'event_id': 'e1', 'timestamp': '2026-01-01T00:00:00Z', 'name': 'test'},
      ],
    );
  });

  test('sends correct headers and body on 202', () async {
    String? capturedBody;
    Map<String, String>? capturedHeaders;

    final mockClient = http_testing.MockClient((request) async {
      capturedBody = request.body;
      capturedHeaders = request.headers;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'batch_id': 'b1',
          'received_at': '2026-01-01T00:00:00Z',
          'accepted': 1,
          'rejected': 0,
          'warnings': <String>[],
        }),
        202,
      );
    });

    final client = AnalyticsHttpClient(
      config: config,
      client: mockClient,
    );

    final result = await client.sendBatch(payload);

    expect(result.success, true);
    expect(result.statusCode, 202);
    expect(result.response?.batchId, 'b1');
    expect(result.response?.accepted, 1);

    expect(capturedHeaders?['Authorization'], 'Bearer test_key');
    expect(capturedHeaders?['Content-Type'], contains('application/json'));
    expect(capturedHeaders?['X-SDK-Name'], 'flutter');
    expect(capturedHeaders?['Idempotency-Key'], isNotEmpty);

    final body = jsonDecode(capturedBody!) as Map<String, dynamic>;
    expect(body['schema_version'], '1.0');
    expect(body['events'], isList);
  });

  test('returns shouldRetry=false on 422', () async {
    final mockClient = http_testing.MockClient((_) async {
      return http.Response(
        jsonEncode(<String, dynamic>{'error': 'validation_failed', 'message': 'bad', 'details': <String, dynamic>{}}),
        422,
      );
    });

    final client = AnalyticsHttpClient(config: config, client: mockClient);
    final result = await client.sendBatch(payload);

    expect(result.success, false);
    expect(result.statusCode, 422);
    expect(result.shouldRetry, false);
  });

  test('returns shouldRetry=true on 429', () async {
    final mockClient = http_testing.MockClient((_) async {
      return http.Response('rate limited', 429);
    });

    final client = AnalyticsHttpClient(config: config, client: mockClient);
    final result = await client.sendBatch(payload);

    expect(result.success, false);
    expect(result.statusCode, 429);
    expect(result.shouldRetry, true);
  });

  test('returns shouldRetry=true on 500', () async {
    final mockClient = http_testing.MockClient((_) async {
      return http.Response('server error', 500);
    });

    final client = AnalyticsHttpClient(config: config, client: mockClient);
    final result = await client.sendBatch(payload);

    expect(result.success, false);
    expect(result.statusCode, 500);
    expect(result.shouldRetry, true);
  });

  test('handles network error with shouldRetry=true', () async {
    final mockClient = http_testing.MockClient((_) async {
      throw Exception('Network unreachable');
    });

    final client = AnalyticsHttpClient(config: config, client: mockClient);
    final result = await client.sendBatch(payload);

    expect(result.success, false);
    expect(result.statusCode, 0);
    expect(result.shouldRetry, true);
    expect(result.error, contains('Network unreachable'));
  });

  test('uses provided idempotency key', () async {
    String? capturedKey;

    final mockClient = http_testing.MockClient((request) async {
      capturedKey = request.headers['Idempotency-Key'];
      return http.Response(
        jsonEncode(<String, dynamic>{
          'batch_id': 'b1',
          'received_at': '2026-01-01T00:00:00Z',
          'accepted': 1,
          'rejected': 0,
          'warnings': <String>[],
        }),
        202,
      );
    });

    final client = AnalyticsHttpClient(config: config, client: mockClient);
    await client.sendBatch(payload, idempotencyKey: 'my-key');

    expect(capturedKey, 'my-key');
  });
}
