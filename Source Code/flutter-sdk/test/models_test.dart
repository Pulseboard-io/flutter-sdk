import 'package:app_analytics/src/models/analytics_event.dart';
import 'package:app_analytics/src/models/app_info.dart';
import 'package:app_analytics/src/models/batch_payload.dart';
import 'package:app_analytics/src/models/batch_response.dart';
import 'package:app_analytics/src/models/breadcrumb.dart';
import 'package:app_analytics/src/models/crash_report.dart';
import 'package:app_analytics/src/models/device_info_model.dart';
import 'package:app_analytics/src/models/trace_event.dart';
import 'package:app_analytics/src/models/user_info.dart';
import 'package:app_analytics/src/models/user_property_op.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsEvent', () {
    test('toJson includes required fields', () {
      final event = AnalyticsEvent(
        eventId: 'e1',
        timestamp: '2026-01-01T00:00:00.000Z',
        name: 'test_event',
        sessionId: 's1',
        properties: {'key': 'value'},
      );
      final json = event.toJson();

      expect(json['type'], 'event');
      expect(json['event_id'], 'e1');
      expect(json['timestamp'], '2026-01-01T00:00:00.000Z');
      expect(json['name'], 'test_event');
      expect(json['session_id'], 's1');
      expect(json['properties'], {'key': 'value'});
    });

    test('omits null optional fields', () {
      final event = AnalyticsEvent(
        eventId: 'e1',
        timestamp: '2026-01-01T00:00:00.000Z',
      );
      final json = event.toJson();

      expect(json.containsKey('name'), false);
      expect(json.containsKey('session_id'), false);
      expect(json.containsKey('properties'), false);
    });

    test('fromJson round-trip', () {
      final original = AnalyticsEvent(
        eventId: 'e1',
        timestamp: '2026-01-01T00:00:00.000Z',
        name: 'test',
        properties: {'a': 1},
      );
      final restored = AnalyticsEvent.fromJson(original.toJson());

      expect(restored.eventId, original.eventId);
      expect(restored.name, original.name);
      expect(restored.properties, original.properties);
    });

    test('generates UUID and timestamp when not provided', () {
      final event = AnalyticsEvent(name: 'test');

      expect(event.eventId, isNotEmpty);
      expect(event.timestamp, isNotEmpty);
    });
  });

  group('AppInfo', () {
    test('toJson/fromJson round-trip', () {
      const info = AppInfo(
        bundleId: 'com.example.app',
        versionName: '1.0.0',
        buildNumber: '42',
      );
      final json = info.toJson();
      final restored = AppInfo.fromJson(json);

      expect(restored.bundleId, 'com.example.app');
      expect(restored.versionName, '1.0.0');
      expect(restored.buildNumber, '42');
    });
  });

  group('DeviceInfoModel', () {
    test('toJson/fromJson round-trip', () {
      const info = DeviceInfoModel(
        deviceId: 'd1',
        platform: 'android',
        osVersion: '14',
        model: 'Pixel 8',
      );
      final json = info.toJson();
      final restored = DeviceInfoModel.fromJson(json);

      expect(restored.deviceId, 'd1');
      expect(restored.platform, 'android');
      expect(restored.osVersion, '14');
      expect(restored.model, 'Pixel 8');
    });
  });

  group('UserInfo', () {
    test('toJson includes user_id when set', () {
      const info = UserInfo(anonymousId: 'a1', userId: 'u1');
      final json = info.toJson();

      expect(json['anonymous_id'], 'a1');
      expect(json['user_id'], 'u1');
    });

    test('toJson omits user_id when null', () {
      const info = UserInfo(anonymousId: 'a1');
      final json = info.toJson();

      expect(json.containsKey('user_id'), false);
    });

    test('copyWith', () {
      const info = UserInfo(anonymousId: 'a1');
      final updated = info.copyWith(userId: 'u1');

      expect(updated.anonymousId, 'a1');
      expect(updated.userId, 'u1');
    });
  });

  group('Breadcrumb', () {
    test('toJson/fromJson round-trip', () {
      final bc = Breadcrumb(
        ts: '2026-01-01T00:00:00.000Z',
        type: 'navigation',
        message: 'Opened home',
      );
      final json = bc.toJson();
      final restored = Breadcrumb.fromJson(json);

      expect(restored.ts, '2026-01-01T00:00:00.000Z');
      expect(restored.type, 'navigation');
      expect(restored.message, 'Opened home');
    });
  });

  group('CrashReport', () {
    test('toJson includes all fields', () {
      final report = CrashReport(
        eventId: 'c1',
        timestamp: '2026-01-01T00:00:00.000Z',
        fingerprint: 'fp123',
        fatal: true,
        exception: const CrashException(
          type: 'NullPointerException',
          message: 'null reference',
          stacktrace: '#0 main',
        ),
        breadcrumbs: [
          Breadcrumb(
            ts: '2026-01-01T00:00:00.000Z',
            type: 'ui',
            message: 'clicked button',
          ),
        ],
      );
      final json = report.toJson();

      expect(json['type'], 'crash');
      expect(json['fingerprint'], 'fp123');
      expect(json['fatal'], true);
      expect(json['exception']['type'], 'NullPointerException');
      expect(json['exception']['message'], 'null reference');
      expect(json['exception']['stacktrace'], '#0 main');
      expect((json['breadcrumbs'] as List).length, 1);
    });

    test('fromJson round-trip', () {
      final original = CrashReport(
        eventId: 'c1',
        fingerprint: 'fp',
        exception: const CrashException(
          type: 'Error',
          message: 'oops',
        ),
      );
      final restored = CrashReport.fromJson(original.toJson());

      expect(restored.fingerprint, 'fp');
      expect(restored.exception.type, 'Error');
    });
  });

  group('TraceEvent', () {
    test('toJson includes trace data', () {
      final trace = TraceEvent(
        eventId: 't1',
        timestamp: '2026-01-01T00:00:00.000Z',
        trace: const TraceData(
          traceId: 'tr1',
          name: 'api_call',
          durationMs: 250,
          attributes: {'endpoint': '/users'},
        ),
      );
      final json = trace.toJson();

      expect(json['type'], 'trace');
      expect(json['trace']['trace_id'], 'tr1');
      expect(json['trace']['name'], 'api_call');
      expect(json['trace']['duration_ms'], 250);
      expect(json['trace']['attributes'], {'endpoint': '/users'});
    });

    test('fromJson round-trip', () {
      final original = TraceEvent(
        trace: const TraceData(
          traceId: 'tr1',
          name: 'test',
          durationMs: 100,
        ),
      );
      final restored = TraceEvent.fromJson(original.toJson());

      expect(restored.trace.traceId, 'tr1');
      expect(restored.trace.durationMs, 100);
      expect(restored.trace.attributes, isNull);
    });
  });

  group('UserPropertyOp', () {
    test('set operation toJson', () {
      const op = UserPropertyOp(op: 'set', key: 'plan', value: 'premium');
      final json = op.toJson();

      expect(json['op'], 'set');
      expect(json['key'], 'plan');
      expect(json['value'], 'premium');
    });

    test('unset operation omits value', () {
      const op = UserPropertyOp(op: 'unset', key: 'temp');
      final json = op.toJson();

      expect(json['op'], 'unset');
      expect(json['key'], 'temp');
      expect(json.containsKey('value'), false);
    });

    test('increment operation', () {
      const op = UserPropertyOp(op: 'increment', key: 'count', value: 1);
      final json = op.toJson();

      expect(json['value'], 1);
    });

    test('UserPropertiesEvent toJson', () {
      final event = UserPropertiesEvent(
        eventId: 'up1',
        timestamp: '2026-01-01T00:00:00.000Z',
        operations: [
          const UserPropertyOp(op: 'set', key: 'name', value: 'Alice'),
          const UserPropertyOp(op: 'unset', key: 'old_prop'),
        ],
      );
      final json = event.toJson();

      expect(json['type'], 'user_properties');
      expect((json['operations'] as List).length, 2);
    });
  });

  group('BatchPayload', () {
    test('toJson matches API schema', () {
      final payload = BatchPayload(
        sentAt: '2026-01-01T00:00:00.000Z',
        environment: 'production',
        app: const AppInfo(
          bundleId: 'com.example',
          versionName: '1.0',
          buildNumber: '1',
        ),
        device: const DeviceInfoModel(
          deviceId: 'd1',
          platform: 'android',
          osVersion: '14',
          model: 'Pixel',
        ),
        user: const UserInfo(anonymousId: 'a1'),
        events: [
          {'type': 'event', 'event_id': 'e1', 'timestamp': '2026-01-01T00:00:00.000Z', 'name': 'test'},
        ],
      );
      final json = payload.toJson();

      expect(json['schema_version'], '1.0');
      expect(json['sent_at'], '2026-01-01T00:00:00.000Z');
      expect(json['environment'], 'production');
      expect(json['app']['bundle_id'], 'com.example');
      expect(json['device']['platform'], 'android');
      expect(json['user']['anonymous_id'], 'a1');
      expect((json['events'] as List).length, 1);
    });

    test('fromJson round-trip', () {
      final original = BatchPayload(
        environment: 'staging',
        app: const AppInfo(
          bundleId: 'com.test',
          versionName: '2.0',
          buildNumber: '10',
        ),
        device: const DeviceInfoModel(
          deviceId: 'd2',
          platform: 'ios',
          osVersion: '17',
          model: 'iPhone',
        ),
        user: const UserInfo(anonymousId: 'a2', userId: 'u2'),
        events: [],
      );
      final restored = BatchPayload.fromJson(original.toJson());

      expect(restored.environment, 'staging');
      expect(restored.app.bundleId, 'com.test');
      expect(restored.user.userId, 'u2');
    });
  });

  group('BatchResponse', () {
    test('fromJson', () {
      final response = BatchResponse.fromJson({
        'batch_id': 'b1',
        'received_at': '2026-01-01T00:00:00.000Z',
        'accepted': 10,
        'rejected': 0,
        'warnings': <String>[],
      });

      expect(response.batchId, 'b1');
      expect(response.accepted, 10);
      expect(response.rejected, 0);
      expect(response.warnings, isEmpty);
    });
  });
}
