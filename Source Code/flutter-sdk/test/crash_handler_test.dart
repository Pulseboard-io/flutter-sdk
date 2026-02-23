import 'package:pulseboard_analytics/src/models/breadcrumb.dart';
import 'package:pulseboard_analytics/src/models/crash_report.dart';
import 'package:pulseboard_analytics/src/services/crash_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CrashHandler', () {
    late List<CrashReport> capturedCrashes;
    late CrashHandler handler;

    setUp(() {
      capturedCrashes = [];
      handler = CrashHandler(
        maxBreadcrumbs: 3,
        onCrash: (report) => capturedCrashes.add(report),
      );
    });

    tearDown(() {
      handler.uninstall();
    });

    test('breadcrumbs are limited to maxBreadcrumbs', () {
      handler.addBreadcrumb(Breadcrumb(type: 'a', message: '1'));
      handler.addBreadcrumb(Breadcrumb(type: 'b', message: '2'));
      handler.addBreadcrumb(Breadcrumb(type: 'c', message: '3'));
      handler.addBreadcrumb(Breadcrumb(type: 'd', message: '4'));

      expect(handler.breadcrumbs.length, 3);
      expect(handler.breadcrumbs.first.type, 'b');
      expect(handler.breadcrumbs.last.type, 'd');
    });

    test('clearBreadcrumbs empties the buffer', () {
      handler.addBreadcrumb(Breadcrumb(type: 'a', message: '1'));
      handler.clearBreadcrumbs();

      expect(handler.breadcrumbs, isEmpty);
    });

    test('install and uninstall are idempotent', () {
      handler.install();
      handler.install(); // Should not throw
      handler.uninstall();
      handler.uninstall(); // Should not throw
    });
  });
}
