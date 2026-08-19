import 'package:get/get.dart';

import '../models/release.dart';
import '../services/config_service.dart';
import '../services/kernel_service.dart';
import '../services/notification_service.dart';
import '../services/release_service.dart';
import '../services/settings_service.dart';

class AppController extends GetxController {
  AppController(
    this.settings,
    this.releases,
    this.kernel,
    this.config,
    this.notifications,
  );

  final SettingsService settings;
  final ReleaseService releases;
  final KernelService kernel;
  final ConfigService config;
  final NotificationService notifications;
  final currentIndex = 0.obs;
  final initializing = true.obs;
  final busy = false.obs;
  final error = RxnString();

  @override
  void onReady() {
    initialize();
    super.onReady();
  }

  Future<void> initialize() async {
    if (!initializing.value) return;
    try {
      await settings.alignConfigPathWithExecutable();
      await config.load(settings.configPath.value);
      await refreshReleases(showError: false);
    } finally {
      initializing.value = false;
    }
  }

  Future<void> refreshReleases({bool showError = true}) async {
    try {
      await releases.fetchReleases();
    } catch (exception) {
      error.value = '$exception';
      releases.error.value = '$exception';
      if (showError) _showError('获取发布失败', '$exception');
    }
  }

  Future<void> install(BotRelease release) async {
    busy.value = true;
    try {
      await releases.download(release);
      await config.load(settings.configPath.value);
      notifications.showSnackBar('安装完成', '${release.tagName} 已准备就绪');
    } catch (exception) {
      releases.error.value = '$exception';
      _showError('安装失败', '$exception');
    } finally {
      busy.value = false;
    }
  }

  Future<void> startKernel() async {
    busy.value = true;
    try {
      await settings.alignConfigPathWithExecutable();
      if (config.path.value != settings.configPath.value) {
        await config.load(settings.configPath.value);
      }
      if (config.error.value != null) {
        throw StateError('配置文件读取失败：${config.error.value}');
      }
      final botToken = config.valueAt('telegram.bot_token');
      if (botToken is! String || botToken.trim().isEmpty) {
        throw StateError('请先在“配置”页面填写 Telegram Bot Token 并保存');
      }
      await kernel.start();
    } catch (exception) {
      _showError('启动失败', '$exception');
    } finally {
      busy.value = false;
    }
  }

  Future<void> stopKernel() => kernel.stop();

  Future<void> saveConfig() async {
    try {
      await config.save();
      notifications.showSnackBar('配置已保存', '');
    } catch (exception) {
      _showError('保存失败', '$exception');
    }
  }

  void _showError(String title, String message) {
    error.value = message;
    notifications.showSnackBar(title, message, persistent: true);
  }
}
