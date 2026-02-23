import 'package:app_analytics/src/config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnalyticsConfig DSN parsing', () {
    test('parses a valid DSN', () {
      final config = AnalyticsConfig(
        dsn: 'https://wk_abc123@pulseboard.example.com/proj_uuid/production',
      );

      expect(config.endpoint, 'https://pulseboard.example.com');
      expect(config.publicKey, 'wk_abc123');
      expect(config.projectId, 'proj_uuid');
      expect(config.environment, 'production');
    });

    test('parses DSN with port', () {
      final config = AnalyticsConfig(
        dsn: 'https://key@localhost:8080/project/staging',
      );

      expect(config.endpoint, 'https://localhost:8080');
      expect(config.publicKey, 'key');
      expect(config.projectId, 'project');
      expect(config.environment, 'staging');
    });

    test('parses DSN with http scheme', () {
      final config = AnalyticsConfig(
        dsn: 'http://key@localhost/proj/dev',
      );

      expect(config.endpoint, 'http://localhost');
    });

    test('throws on missing public key', () {
      expect(
        () => AnalyticsConfig(dsn: 'https://pulseboard.example.com/proj/env'),
        throwsFormatException,
      );
    });

    test('throws on missing path segments', () {
      expect(
        () => AnalyticsConfig(dsn: 'https://key@host/proj'),
        throwsFormatException,
      );
    });

    test('throws on invalid URI', () {
      expect(
        () => AnalyticsConfig(dsn: ''),
        throwsFormatException,
      );
    });

    test('throws on ftp scheme', () {
      expect(
        () => AnalyticsConfig(dsn: 'ftp://key@host/proj/env'),
        throwsFormatException,
      );
    });

    test('clamps sample rate', () {
      final config = AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        sampleRate: 2.0,
      );
      expect(config.sampleRate, 1.0);

      final config2 = AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        sampleRate: -1.0,
      );
      expect(config2.sampleRate, 0.0);
    });

    test('uses default values', () {
      final config = AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
      );

      expect(config.flushAt, 20);
      expect(config.flushIntervalSeconds, 30);
      expect(config.debug, false);
      expect(config.sampleRate, 1.0);
      expect(config.maxRetries, 3);
      expect(config.sessionTimeoutMinutes, 5);
      expect(config.maxBreadcrumbs, 20);
      expect(config.maxPersistedEvents, 1000);
    });

    test('accepts custom values', () {
      final config = AnalyticsConfig(
        dsn: 'https://key@host/proj/env',
        flushAt: 50,
        flushIntervalSeconds: 60,
        debug: true,
        sampleRate: 0.5,
        maxRetries: 5,
        sessionTimeoutMinutes: 10,
        maxBreadcrumbs: 50,
        maxPersistedEvents: 500,
      );

      expect(config.flushAt, 50);
      expect(config.flushIntervalSeconds, 60);
      expect(config.debug, true);
      expect(config.sampleRate, 0.5);
      expect(config.maxRetries, 5);
      expect(config.sessionTimeoutMinutes, 10);
      expect(config.maxBreadcrumbs, 50);
      expect(config.maxPersistedEvents, 500);
    });
  });
}
