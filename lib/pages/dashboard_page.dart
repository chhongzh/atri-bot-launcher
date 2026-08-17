import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/kernel_service.dart';
import '../services/release_service.dart';
import '../services/settings_service.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    final kernel = Get.find<KernelService>();
    final releases = Get.find<ReleaseService>();
    final settings = Get.find<SettingsService>();
    return Obx(() {
      final running = kernel.isRunning;
      final installed =
          settings.executablePath.value.isNotEmpty &&
          File(settings.executablePath.value).existsSync();
      final latest = releases.releases.isEmpty ? null : releases.releases.first;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('欢迎回来', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('一键运行Atri-Bot', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(
                running ? Icons.play_circle : Icons.pause_circle,
                size: 40,
              ),
              title: Text(
                running
                    ? '内核运行中'
                    : installed
                    ? '内核已就绪'
                    : '还没有安装内核',
              ),
              subtitle: Text(
                settings.selectedVersion.value.isEmpty
                    ? '最低支持版本 v${SettingsService.minimumVersion}'
                    : '当前版本 ${settings.selectedVersion.value}',
              ),
              trailing: running
                  ? FilledButton.tonalIcon(
                      onPressed: app.stopKernel,
                      icon: const Icon(Icons.stop),
                      label: const Text('停止'),
                    )
                  : FilledButton.icon(
                      onPressed: installed
                          ? app.startKernel
                          : () => app.currentIndex.value = 1,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(installed ? '启动' : '安装'),
                    ),
            ),
          ),
          if (kernel.directStartFailed.value) ...[
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.warning_amber),
                title: Text('Android 直接启动失败'),
                subtitle: Text('系统拒绝了可执行文件启动。当前已保留失败原因；下一步需要切换到 JNI/原生产物方案。'),
              ),
            ),
          ],
          if (app.error.value != null && !kernel.directStartFailed.value)
            Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('需要处理的问题'),
                subtitle: Text(app.error.value!),
              ),
            ),
          const SizedBox(height: 24),
          Text('快速入口', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ActionChip(
                avatar: const Icon(Icons.receipt_long),
                label: const Text('查看日志'),
                onPressed: () => app.currentIndex.value = 2,
              ),
              ActionChip(
                avatar: const Icon(Icons.tune),
                label: const Text('编辑配置'),
                onPressed: () => app.currentIndex.value = 3,
              ),
              ActionChip(
                avatar: const Icon(Icons.cloud_download),
                label: Text(latest == null ? '检查更新' : '最新 ${latest.tagName}'),
                onPressed: app.refreshReleases,
              ),
            ],
          ),
        ],
      );
    });
  }
}
