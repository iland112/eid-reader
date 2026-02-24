import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';

/// Singleton debug log service.
///
/// Subscribes to [Logger.root] and:
///   1. Maintains an in-memory [logs] buffer (observable via [ValueNotifier])
///      so the UI can display log messages on-screen.
///   2. Writes every log line to a timestamped file in the app documents
///      directory so the user can share it for debugging.
class DebugLogService {
  static final DebugLogService instance = DebugLogService._();

  DebugLogService._();

  /// In-memory log lines observable by UI widgets.
  final ValueNotifier<List<String>> logs = ValueNotifier(const []);

  static const int _maxLines = 500;

  IOSink? _fileSink;

  /// Absolute path to the current log file. Available after [init].
  String? logFilePath;

  /// Initialises the service: creates the log file and subscribes to
  /// [Logger.root.onRecord].
  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final file = File('${dir.path}/eid_debug_$ts.log');
    _fileSink = file.openWrite(mode: FileMode.append);
    logFilePath = file.path;

    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen(_onRecord);

    _addLine('[DebugLog] Session started — file: ${file.path}');
  }

  void _onRecord(LogRecord record) {
    final h = record.time.hour.toString().padLeft(2, '0');
    final m = record.time.minute.toString().padLeft(2, '0');
    final s = record.time.second.toString().padLeft(2, '0');
    final ms = record.time.millisecond.toString().padLeft(3, '0');
    final line = '$h:$m:$s.$ms [${record.loggerName}] ${record.message}';

    _addLine(line);

    // Write to file
    _fileSink?.writeln(line);
    if (record.error != null) {
      _fileSink?.writeln('  Error: ${record.error}');
    }
    if (record.stackTrace != null) {
      _fileSink?.writeln('  Stack: ${record.stackTrace}');
    }
  }

  void _addLine(String line) {
    final current = List<String>.from(logs.value);
    current.add(line);
    if (current.length > _maxLines) {
      current.removeRange(0, current.length - _maxLines);
    }
    logs.value = current;
  }

  /// Flushes pending writes to disk (e.g. before sharing the file).
  Future<void> flush() async {
    await _fileSink?.flush();
  }

  /// Flushes and closes the log file.
  Future<void> close() async {
    _addLine('[DebugLog] Session ended');
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
  }
}
