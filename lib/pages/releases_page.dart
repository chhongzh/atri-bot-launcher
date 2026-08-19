import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../models/release.dart';
import '../services/release_service.dart';

class ReleasesPage extends StatelessWidget {
  const ReleasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = Get.find<AppController>();
    final releases = Get.find<ReleaseService>();
    return Obx(() {
      if (releases.releases.isEmpty && releases.downloading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      return RefreshIndicator(
        onRefresh: app.refreshReleases,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '版本中心',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: app.refreshReleases,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('请优先选择高版本运行'),
            const SizedBox(height: 16),
            if (releases.releases.isEmpty)
              Card(
                child: ListTile(
                  leading: Icon(
                    releases.error.value == null
                        ? Icons.inventory_2_outlined
                        : Icons.error_outline,
                  ),
                  title: Text(
                    releases.error.value == null ? '暂无可用版本' : '获取版本失败',
                  ),
                  subtitle: Text(
                    releases.error.value ?? '请检查网络，或确认仓库中已有 v2 及以上 release。',
                  ),
                ),
              ),
            ...releases.releases.map(
              (release) => ReleaseTile(
                release: release,
                onInstall: () => app.install(release),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class ReleaseTile extends StatelessWidget {
  const ReleaseTile({
    required this.release,
    required this.onInstall,
    super.key,
  });

  final BotRelease release;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: Text(release.title),
        subtitle: Text('${release.tagName} · ${release.assets.length} 个平台产物'),
        trailing: FilledButton.tonalIcon(
          onPressed: onInstall,
          icon: const Icon(Icons.download),
          label: const Text('安装'),
        ),
      ),
    );
  }
}
