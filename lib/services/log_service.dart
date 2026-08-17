import 'package:get/get.dart';

import '../models/release.dart';

class LogService extends GetxService {
  final entries = <LogEntry>[].obs;

  void info(String message, [Map<String, dynamic> fields = const {}]) {
    _add(message, 'info', fields);
  }

  void warning(String message, [Map<String, dynamic> fields = const {}]) {
    _add(message, 'warn', fields);
  }

  void error(String message, [Map<String, dynamic> fields = const {}]) {
    _add(message, 'error', fields);
  }

  void addProcessLine(String line) {
    if (line.trim().isEmpty) return;
    _append(LogEntry.fromLine(line));
  }

  void clear() => entries.clear();

  void _add(String message, String level, Map<String, dynamic> fields) {
    _append(
      LogEntry(
        message: message,
        level: level,
        timestamp: DateTime.now(),
        fields: fields,
      ),
    );
  }

  void _append(LogEntry entry) {
    entries.add(entry);
    if (entries.length > 1000) {
      entries.removeRange(0, entries.length - 1000);
    }
  }
}
