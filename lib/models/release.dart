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
    required this.publishedAt,
    required this.prerelease,
    required this.assets,
  });

  final String tagName;
  final String title;
  final DateTime? publishedAt;
  final bool prerelease;
  final List<ReleaseAsset> assets;

  SemVersion get version => SemVersion.parse(tagName);
}

class SemVersion implements Comparable<SemVersion> {
  const SemVersion(this.major, this.minor, this.patch, [this.preRelease]);

  final int major;
  final int minor;
  final int patch;
  final String? preRelease;

  bool get isStable => preRelease == null;

  static SemVersion parse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
    ).firstMatch(value.trim());
    if (match == null) {
      throw FormatException('Invalid semantic version: $value');
    }
    return SemVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      match.group(4),
    );
  }

  @override
  int compareTo(SemVersion other) {
    final majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) return majorComparison;
    final minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) return minorComparison;
    final patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) return patchComparison;
    if (preRelease == null && other.preRelease == null) return 0;
    if (preRelease == null) return 1;
    if (other.preRelease == null) return -1;
    return preRelease!.compareTo(other.preRelease!);
  }

  @override
  String toString() =>
      '$major.$minor.$patch${preRelease == null ? '' : '-$preRelease'}';
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
