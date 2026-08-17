import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/app_controller.dart';
import '../services/release_service.dart';
import 'about_page.dart';
import 'config_page.dart';
import 'dashboard_page.dart';
import 'logs_page.dart';
import 'releases_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    const destinations = [
      NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: '概览',
      ),
      NavigationDestination(
        icon: Icon(Icons.cloud_download_outlined),
        selectedIcon: Icon(Icons.cloud_download),
        label: '版本',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long),
        label: '日志',
      ),
      NavigationDestination(
        icon: Icon(Icons.tune_outlined),
        selectedIcon: Icon(Icons.tune),
        label: '配置',
      ),
      NavigationDestination(
        icon: Icon(Icons.info_outline),
        selectedIcon: Icon(Icons.info),
        label: '关于',
      ),
    ];
    const pages = [
      DashboardPage(),
      ReleasesPage(),
      LogsPage(),
      ConfigPage(),
      AboutPage(),
    ];
    return Obx(() {
      final index = controller.currentIndex.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          return Scaffold(
            body: Column(
              children: [
                const _GlobalDownloadProgress(),
                Expanded(
                  child: Row(
                    children: [
                      if (wide)
                        NavigationRail(
                          selectedIndex: index,
                          onDestinationSelected: (value) =>
                              controller.currentIndex.value = value,
                          labelType: NavigationRailLabelType.all,
                          destinations: destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: item.icon,
                                  selectedIcon: item.selectedIcon ?? item.icon,
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                        ),
                      Expanded(
                        child: IndexedStack(index: index, children: pages),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: index,
                    onDestinationSelected: (value) =>
                        controller.currentIndex.value = value,
                    destinations: destinations,
                  ),
          );
        },
      );
    });
  }
}

class _GlobalDownloadProgress extends StatelessWidget {
  const _GlobalDownloadProgress();

  @override
  Widget build(BuildContext context) {
    final releases = Get.find<ReleaseService>();
    return Obx(() {
      if (!releases.downloading.value) return const SizedBox.shrink();
      final progress = releases.downloadProgress.value;
      final percentage = (progress * 100).toStringAsFixed(0);
      return Material(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const Icon(Icons.downloading, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '正在下载 ${releases.downloadLabel.value}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: progress),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$percentage%'),
            ],
          ),
        ),
      );
    });
  }
}
