import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../utils/logger.dart';

/// Persists events to disk for offline support.
class Persistence {
  static const String _fileName = 'pulseboard_events.json';

  final int _maxEvents;
  final SdkLogger _logger;
  final Future<Directory> Function() _directoryProvider;

  Persistence({
    int maxEvents = 1000,
    SdkLogger? logger,
    Future<Directory> Function()? directoryProvider,
  })  : _maxEvents = maxEvents,
        _logger = logger ?? SdkLogger(),
        _directoryProvider =
            directoryProvider ?? getApplicationDocumentsDirectory;

  Future<File> _getFile() async {
    final dir = await _directoryProvider();
    return File('${dir.path}/$_fileName');
  }

  /// Save events to disk.
  Future<void> saveEvents(List<Map<String, dynamic>> events) async {
    try {
      final file = await _getFile();
      final existing = await loadEvents();
      existing.addAll(events);

      // Trim to max size, keeping newest events
      if (existing.length > _maxEvents) {
        existing.removeRange(0, existing.length - _maxEvents);
      }

      await file.writeAsString(jsonEncode(existing));
      _logger.debug('Persisted ${existing.length} events');
    } catch (e) {
      _logger.error('Failed to persist events', e);
    }
  }

  /// Load persisted events from disk.
  Future<List<Map<String, dynamic>>> loadEvents() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return [];

      final content = await file.readAsString();
      if (content.isEmpty) return [];

      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _logger.error('Failed to load persisted events', e);
      return [];
    }
  }

  /// Clear all persisted events.
  Future<void> clear() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.writeAsString('[]');
      }
    } catch (e) {
      _logger.error('Failed to clear persisted events', e);
    }
  }
}
