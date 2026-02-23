import 'dart:io';

import 'package:pulseboard_analytics/src/services/persistence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late Persistence persistence;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pulseboard_test_');
    persistence = Persistence(
      maxEvents: 5,
      directoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('loadEvents returns empty list when no file exists', () async {
    final events = await persistence.loadEvents();
    expect(events, isEmpty);
  });

  test('saveEvents and loadEvents round-trip', () async {
    final events = [
      {'type': 'event', 'event_id': '1', 'name': 'test1'},
      {'type': 'event', 'event_id': '2', 'name': 'test2'},
    ];

    await persistence.saveEvents(events);
    final loaded = await persistence.loadEvents();

    expect(loaded.length, 2);
    expect(loaded[0]['event_id'], '1');
    expect(loaded[1]['event_id'], '2');
  });

  test('saveEvents appends to existing', () async {
    await persistence.saveEvents([
      {'type': 'event', 'event_id': '1', 'name': 'a'},
    ]);
    await persistence.saveEvents([
      {'type': 'event', 'event_id': '2', 'name': 'b'},
    ]);

    final loaded = await persistence.loadEvents();
    expect(loaded.length, 2);
  });

  test('saveEvents trims to maxEvents', () async {
    await persistence.saveEvents([
      for (var i = 0; i < 10; i++)
        {'type': 'event', 'event_id': '$i', 'name': 'evt$i'},
    ]);

    final loaded = await persistence.loadEvents();
    expect(loaded.length, 5);
    // Should keep newest (5-9)
    expect(loaded.first['event_id'], '5');
  });

  test('clear empties the file', () async {
    await persistence.saveEvents([
      {'type': 'event', 'event_id': '1', 'name': 'test'},
    ]);
    await persistence.clear();

    final loaded = await persistence.loadEvents();
    expect(loaded, isEmpty);
  });
}
