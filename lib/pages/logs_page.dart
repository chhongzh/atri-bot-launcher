import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../services/log_service.dart';

class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = Get.find<LogService>();
    return Obx(
      () => Column(
        children: [
          ListTile(
            title: Text(
              '启动器与内核日志',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            subtitle: Text('${logs.entries.length} 条结构化记录'),
            trailing: IconButton(
              onPressed: logs.clear,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空日志',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: logs.entries.isEmpty
                ? const Center(child: Text('下载、安装和启动过程的日志会显示在这里。'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: logs.entries.length,
                    itemBuilder: (context, index) {
                      final log = logs.entries[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            log.level == 'error'
                                ? Icons.error_outline
                                : log.level == 'warn'
                                ? Icons.warning_amber
                                : Icons.info_outline,
                          ),
                          title: Text(log.message),
                          subtitle: Text(
                            log.timestamp?.toLocal().toString() ?? '即时日志',
                          ),
                          trailing: log.fields.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () =>
                                      _showFields(context, log.fields),
                                  icon: const Icon(Icons.data_object),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showFields(BuildContext context, Map<String, dynamic> fields) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SelectableText(const JsonEncoder.withIndent('  ').convert(fields)),
        ],
      ),
    );
  }
}
