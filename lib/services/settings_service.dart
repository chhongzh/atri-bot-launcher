import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends GetxService {
  static const repositoryOwner = 'chhongzh';
  static const repositoryName = 'atri-bot';
  final selectedVersion = ''.obs;
  final configPath = ''.obs;
  final dataDirectory = ''.obs;
  final executablePath = ''.obs;

  SharedPreferences? _preferences;

  Future<SettingsService> init() async {
    _preferences = await SharedPreferences.getInstance();
    selectedVersion.value =
        _preferences?.getString('selected_version') ?? selectedVersion.value;
    configPath.value = _preferences?.getString('config_path') ?? '';
    executablePath.value = _preferences?.getString('executable_path') ?? '';

    if (executablePath.value.isNotEmpty) {
      final executableName = path.basename(executablePath.value).toLowerCase();
      if (!executableName.startsWith('atri-bot') ||
          !await File(executablePath.value).exists()) {
        executablePath.value = '';
        selectedVersion.value = '';
      }
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final privateDataDirectory = Directory(
      path.join(supportDirectory.path, 'atri-bot'),
    ).path;
    dataDirectory.value = privateDataDirectory;
    if (Platform.isAndroid &&
        executablePath.value.isNotEmpty &&
        !_isWithinDirectory(dataDirectory.value, executablePath.value)) {
      executablePath.value = '';
      selectedVersion.value = '';
    }
    if (Platform.isAndroid &&
        configPath.value.isNotEmpty &&
        !_isWithinDirectory(dataDirectory.value, configPath.value)) {
      configPath.value = '';
    }
    if (configPath.value.isEmpty) {
      configPath.value = File('${dataDirectory.value}/config.yaml').path;
    }
    await alignConfigPathWithExecutable();
    await persist();
    return this;
  }

  bool _isWithinDirectory(String directory, String filePath) {
    final root = path.normalize(directory);
    final target = path.normalize(filePath);
    return target == root || target.startsWith('$root${path.separator}');
  }

  Future<void> alignConfigPathWithExecutable() async {
    final executable = executablePath.value;
    if (executable.isEmpty || !await File(executable).exists()) return;
    final siblingConfig = path.join(path.dirname(executable), 'config.yaml');
    if (configPath.value == siblingConfig) return;
    final previousConfig = File(configPath.value);
    final targetConfig = File(siblingConfig);
    if (configPath.value.isNotEmpty &&
        await previousConfig.exists() &&
        !await targetConfig.exists()) {
      await targetConfig.parent.create(recursive: true);
      await previousConfig.copy(targetConfig.path);
    }
    configPath.value = siblingConfig;
    await persist();
  }

  Future<void> persist() async {
    final preferences = _preferences;
    if (preferences == null) return;
    await preferences.setString('selected_version', selectedVersion.value);
    await preferences.setString('config_path', configPath.value);
    await preferences.setString('executable_path', executablePath.value);
  }
}
