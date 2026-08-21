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
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text('欢迎回来', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text('一键运行Atri-Bot', style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
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
                    ? '还没有安装可用版本'
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Icon(Icons.warning_amber),
                title: Text('Android 直接启动失败'),
                subtitle: Text('系统拒绝了可执行文件启动。当前已保留失败原因；下一步需要切换到 JNI/原生产物方案。'),
              ),
            ),
          ],
          if (app.error.value != null && !kernel.directStartFailed.value)
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: const Icon(Icons.error_outline),
                title: const Text('需要处理的问题'),
                subtitle: Text(app.error.value!),
              ),
            ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.shield_outlined),
              title: Text('关于后台保活'),
              subtitle: Text(
                '如果需要让机器人长时间在线，请在系统设置中允许启动器自启动，并关闭电池优化。部分手机会主动限制后台活动，具体效果还会受到系统版本和厂商策略影响。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.public_outlined),
              title: Text('关于网络连接'),
              subtitle: Text(
                '启动器需要通过 GitHub 获取版本，并调用 Telegram API 提供机器人服务。受网络环境等不可抗力因素影响，部分地区可能无法稳定访问这些服务，请按当地情况准备合适的网络连接。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Icon(Icons.volunteer_activism_outlined),
              title: Text('关于项目费用'),
              subtitle: Text(
                '本项目完全开源且免费提供。如果你是付费购买到本项目，基本可以确认自己遇到了欺诈。相关款项也不会流向开发者，无法用于项目的维护和改进，请通过官方渠道获取项目。',
              ),
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
