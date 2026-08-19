import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:yaml/yaml.dart';

class ConfigField {
  const ConfigField({required this.path, required this.value});

  final String path;
  final dynamic value;

  String get displayValue {
    if (value is Map || value is List) {
      return const JsonEncoder.withIndent('  ').convert(value);
    }
    return '$value';
  }
}

class ConfigService extends GetxService {
  final values = <String, dynamic>{}.obs;
  final path = ''.obs;
  final loading = false.obs;
  final dirty = false.obs;
  final error = RxnString();
  final revision = 0.obs;

  Future<void> load(String filePath) async {
    loading.value = true;
    error.value = null;
    path.value = filePath;
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        values.assignAll(_defaults());
        dirty.value = true;
        revision.value++;
        return;
      }
      final parsed = loadYaml(await file.readAsString());
      final normalized = _normalize(parsed);
      final merged = _defaults();
      if (normalized is Map) _merge(merged, normalized);
      values.assignAll(merged);
      dirty.value = false;
      revision.value++;
    } catch (exception) {
      error.value = '$exception';
      revision.value++;
    } finally {
      loading.value = false;
    }
  }

  Future<void> save() async {
    final file = File(path.value);
    await file.parent.create(recursive: true);
    await file.writeAsString(_encode(values), flush: true);
    dirty.value = false;
  }

  List<ConfigField> fields() {
    final result = <ConfigField>[];
    void visit(dynamic value, String prefix) {
      if (value is Map) {
        for (final entry in value.entries) {
          final key = '$prefix${entry.key}';
          visit(entry.value, '$key.');
        }
      } else {
        result.add(
          ConfigField(
            path: prefix.substring(0, prefix.length - 1),
            value: value,
          ),
        );
      }
    }

    visit(values, '');
    return result;
  }

  void setField(String fieldPath, String input) {
    final segments = fieldPath.split('.');
    dynamic current = values;
    for (var index = 0; index < segments.length - 1; index++) {
      current = current[segments[index]] as Map<String, dynamic>;
    }
    final key = segments.last;
    final original = current[key];
    setValue(fieldPath, _parseInput(input, original));
  }

  dynamic valueAt(String fieldPath) {
    dynamic current = values;
    for (final segment in fieldPath.split('.')) {
      if (current is! Map || !current.containsKey(segment)) return null;
      current = current[segment];
    }
    return current;
  }

  void setValue(String fieldPath, dynamic value) {
    final segments = fieldPath.split('.');
    dynamic current = values;
    for (var index = 0; index < segments.length - 1; index++) {
      final segment = segments[index];
      if (current[segment] is! Map) current[segment] = <String, dynamic>{};
      current = current[segment];
    }
    current[segments.last] = value;
    dirty.value = true;
  }

  dynamic _parseInput(String input, dynamic original) {
    final value = input.trim();
    if (original is bool) return value.toLowerCase() == 'true';
    if (original is int) return int.tryParse(value) ?? original;
    if (original is double) return double.tryParse(value) ?? original;
    if (original is List || original is Map) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return original;
      }
    }
    return input;
  }

  dynamic _normalize(dynamic value) {
    if (value is YamlMap) {
      return value.map((key, item) => MapEntry('$key', _normalize(item)));
    }
    if (value is YamlList) return value.map(_normalize).toList();
    return value;
  }

  Map<String, dynamic> _defaults() => {
    'telegram': {'bot_token': ''},
    'default': {
      'max_rounds': 12,
      'image_max_edge': 1024,
      'mcp_max_tools': 128,
      'tool_permissions': <String, bool>{},
    },
    'security': {'allow_private_ip': false},
    'database': {'type': 'sqlite', 'path': 'atri-bot.db', 'dsn': ''},
    'external': {'browser_url': ''},
    'files': {'max_storage_mb': 1024, 'cleanup_after': '7d'},
    'atri_cwd': '.',
  };

  void _merge(Map<String, dynamic> target, Map source) {
    for (final entry in source.entries) {
      final key = '${entry.key}';
      final value = _normalize(entry.value);
      if (target[key] is Map && value is Map) {
        _merge(target[key] as Map<String, dynamic>, value);
      } else {
        target[key] = value;
      }
    }
  }

  String _encode(dynamic value, [int indent = 0]) {
    final spaces = ' ' * indent;
    if (value is Map) {
      final buffer = StringBuffer();
      for (final entry in value.entries) {
        final key = '${entry.key}';
        if (entry.value is Map) {
          buffer.writeln('$spaces$key:');
          buffer.write(_encode(entry.value, indent + 2));
        } else if (entry.value is List) {
          buffer.writeln('$spaces$key:');
          buffer.write(_encode(entry.value, indent + 2));
        } else {
          buffer.writeln('$spaces$key: ${_scalar(entry.value)}');
        }
      }
      return buffer.toString();
    }
    if (value is List) {
      final buffer = StringBuffer();
      for (final item in value) {
        if (item is Map || item is List) {
          buffer.writeln('$spaces-');
          buffer.write(_encode(item, indent + 2));
        } else {
          buffer.writeln('$spaces- ${_scalar(item)}');
        }
      }
      return buffer.toString();
    }
    return '$spaces${_scalar(value)}\n';
  }

  String _scalar(dynamic value) {
    if (value == null) return 'null';
    if (value is String) return jsonEncode(value);
    return '$value';
  }
}
