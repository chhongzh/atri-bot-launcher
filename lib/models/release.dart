import 'dart:convert';

class ReleaseAsset {
  const ReleaseAsset({
    required this.name,
    required this.downloadUrl,
    required this.size,
  });

  final String name;
  final String downloadUrl;
  final int size;
}

class BotRelease {
  const BotRelease({
    required this.tagName,
    required this.title,
    required this.notes,
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
  });

  final String tagName;
  final String title;
  final String notes;
  final DateTime? publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;
}

class LogEntry {
  const LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
    required this.fields,
  });

  final String message;
  final String level;
  final DateTime? timestamp;
  final Map<String, dynamic> fields;

  factory LogEntry.fromLine(String line) {
    try {
      final decoded = jsonDecode(line);
      if (decoded is Map) {
        final fields = Map<String, dynamic>.from(decoded);
        final message =
            fields.remove('msg') ?? fields.remove('message') ?? line;
        final level = fields.remove('level') ?? 'info';
        final timestampValue =
            fields.remove('time') ?? fields.remove('timestamp');
        return LogEntry(
          message: '$message',
          level: '$level',
          timestamp: DateTime.tryParse('$timestampValue'),
          fields: fields,
        );
      }
    } catch (_) {}
    return LogEntry(
      message: line,
      level: 'info',
      timestamp: null,
      fields: const {},
    );
  }
}
